import Foundation

/// Coordinates read-only scanning, extraction, local embedding, and private indexing.
actor IndexingService {
    private let database: AssistantDatabase
    private let scanner: ReadOnlyFileScanner
    private let extractor: ExtractionCoordinator
    private let chunker: TextChunker
    let embeddings: DocumentEmbedding
    private let folderContextBuilder = FolderContextBuilder()

    /// Creates the local indexing pipeline.
    /// - Parameters:
    ///   - database: Private SQLite index.
    ///   - scanner: Read-only file traversal service.
    ///   - extractor: Local content extraction coordinator.
    ///   - chunker: Source-aligned passage splitter.
    ///   - embeddings: Local document embedding source.
    internal init(
        database: AssistantDatabase,
        scanner: ReadOnlyFileScanner,
        extractor: ExtractionCoordinator,
        chunker: TextChunker,
        embeddings: DocumentEmbedding
    ) {
        self.database = database
        self.scanner = scanner
        self.extractor = extractor
        self.chunker = chunker
        self.embeddings = embeddings
    }

    /// Updates one authorized root without modifying its files.
    /// - Parameters:
    ///   - root: Persisted read-only root authorization.
    ///   - access: Active security-scoped access lifetime.
    ///   - trigger: Source that requested the indexing run.
    ///   - progress: Main-actor-safe progress callback.
    /// - Returns: Completed indexing statistics.
    /// - Throws: A local indexing, extraction, database, or inference error.
    internal func index(
        root: AuthorizedRoot,
        access: SecurityScopedAccess,
        trigger: IndexingTrigger,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async throws -> IndexingOutcome {
        let runID = UUID()
        var run = startingRun(id: runID, root: root, trigger: trigger)
        try await database.insertIndexingRun(run)
        var runState = RunState()

        do {
            return try await performRun(
                root: root,
                access: access,
                runID: runID,
                run: &run,
                runState: &runState,
                progress: progress
            )
        } catch is CancellationError {
            await finishInterruptedRun(
                root: root,
                run: &run,
                runState: runState,
                failure: nil,
                progress: progress
            )
            throw CancellationError()
        } catch {
            await finishInterruptedRun(
                root: root,
                run: &run,
                runState: runState,
                failure: error,
                progress: progress
            )
            throw error
        }
    }

    /// Mutable bookkeeping the run's passes share with its interruption handlers.
    private struct RunState {
        var processedCount = 0
        var currentItem: IndexingItemRecord?
        var currentWaitingState: IndexingItemState?
        var currentItemWasCountedAsSkipped = false
    }

    /// Builds the run summary recorded before any scanning begins.
    /// - Parameters:
    ///   - id: Durable run identifier.
    ///   - root: Persisted read-only root authorization.
    ///   - trigger: Source that requested the indexing run.
    /// - Returns: A running summary with empty counters.
    private func startingRun(
        id: UUID,
        root: AuthorizedRoot,
        trigger: IndexingTrigger
    ) -> IndexingRunRecord {
        IndexingRunRecord(
            id: id,
            rootID: root.id,
            folderName: root.displayName,
            folderPath: root.lastKnownPath,
            trigger: trigger,
            state: .running,
            startedAt: Date(),
            finishedAt: nil,
            totalItems: 0,
            newItems: 0,
            updatedItems: 0,
            unchangedItems: 0,
            removedItems: 0,
            skippedItems: 0
        )
    }

    /// Runs every pass of one indexing run, leaving interruption handling to the caller.
    /// - Parameters:
    ///   - root: Persisted read-only root authorization.
    ///   - access: Active security-scoped access lifetime.
    ///   - runID: Durable parent run identifier.
    ///   - run: Run summary updated by every pass.
    ///   - runState: Bookkeeping the interruption handlers read.
    ///   - progress: Main-actor-safe progress callback.
    /// - Returns: Completed indexing statistics.
    /// - Throws: A local indexing, extraction, database, or inference error.
    private func performRun(
        root: AuthorizedRoot,
        access: SecurityScopedAccess,
        runID: UUID,
        run: inout IndexingRunRecord,
        runState: inout RunState,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async throws -> IndexingOutcome {
        let preparation = try await beginRun(
            root: root,
            access: access,
            runID: runID,
            run: &run,
            runState: &runState,
            progress: progress
        )

        for scannedFile in preparation.orderedFiles {
            try Task.checkCancellation()
            let previous = preparation.existingByPath[scannedFile.item.url.path]
            if IndexingDecisionPolicy.itemIsUnchanged(
                metadataMatches: previous?.metadataHash == scannedFile.item.metadataHash,
                requiresContentIndexing: scannedFile.requiresContentIndexing,
                previousContentHash: previous?.contentHash
            ) {
                try await recordUnchangedFile(
                    scannedFile,
                    run: &run,
                    runState: &runState,
                    progress: progress
                )
                continue
            }
            try await indexChangedFile(
                scannedFile,
                isNew: previous == nil,
                folderChunk: preparation.folderChunks[scannedFile.item.id],
                runID: runID,
                run: &run,
                runState: &runState,
                progress: progress
            )
        }

        try Task.checkCancellation()
        try await database.pruneItems(preparation.staleItems)
        try await removeStaleItems(
            preparation.staleItems,
            runID: runID,
            run: &run,
            processedCount: &runState.processedCount,
            progress: progress
        )
        return try await completeRun(
            root: root,
            run: &run,
            processedCount: runState.processedCount,
            progress: progress
        )
    }

    /// Announces the scan, gathers prior state, and records every item's starting state.
    /// - Parameters:
    ///   - root: Persisted read-only root authorization.
    ///   - access: Active security-scoped access lifetime.
    ///   - runID: Durable parent run identifier.
    ///   - run: Run summary given its total and initial skipped counts.
    ///   - runState: Bookkeeping seeded with the starting processed count.
    ///   - progress: Main-actor-safe progress callback.
    /// - Returns: Facts the remaining passes need.
    /// - Throws: A local indexing or database error when the opening pass fails.
    private func beginRun(
        root: AuthorizedRoot,
        access: SecurityScopedAccess,
        runID: UUID,
        run: inout IndexingRunRecord,
        runState: inout RunState,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async throws -> ScanPreparation {
        try Task.checkCancellation()
        await progress(
            makeProgress(
                run: run,
                state: .scanning,
                path: access.url.path,
                processed: 0,
                total: 0
            )
        )
        let preparation = try await prepareScan(root: root, access: access)
        try Task.checkCancellation()
        run.totalItems = preparation.snapshot.files.count
            + preparation.staleItems.count
            + preparation.snapshot.exclusions.count
        runState.processedCount = try await recordInitialActivity(
            runID: runID,
            accessURL: access.url,
            snapshot: preparation.snapshot,
            existingByPath: preparation.existingByPath,
            staleItems: preparation.staleItems,
            run: &run
        )
        return preparation
    }

    /// Counts one file whose metadata and content both match the private index.
    /// - Parameters:
    ///   - scannedFile: File the decision policy reported as unchanged.
    ///   - run: Run summary updated with the unchanged count.
    ///   - runState: Bookkeeping advanced by one completed item.
    ///   - progress: Main-actor-safe progress callback.
    /// - Throws: A local database error when the run summary cannot be saved.
    private func recordUnchangedFile(
        _ scannedFile: ScannedFile,
        run: inout IndexingRunRecord,
        runState: inout RunState,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async throws {
        run.unchangedItems += 1
        runState.processedCount += 1
        try await database.updateIndexingRun(run)
        await progress(
            makeProgress(
                run: run,
                state: .scanning,
                path: visibleRelativePath(for: scannedFile.item),
                itemState: .unchanged,
                processed: runState.processedCount,
                total: run.totalItems
            )
        )
    }

    /// Extracts, embeds, and stores one new or modified file, skipping it when that fails.
    /// - Parameters:
    ///   - scannedFile: File whose content must be indexed.
    ///   - isNew: Whether the file is absent from the private index.
    ///   - folderChunk: Synthesized folder context, for folder items only.
    ///   - runID: Durable parent run identifier.
    ///   - run: Run summary updated with this file's classification.
    ///   - runState: Bookkeeping advanced by one completed item.
    ///   - progress: Main-actor-safe progress callback.
    /// - Throws: A cancellation, model, or database error that must end the whole run.
    private func indexChangedFile(
        _ scannedFile: ScannedFile,
        isNew: Bool,
        folderChunk: ContentChunk?,
        runID: UUID,
        run: inout IndexingRunRecord,
        runState: inout RunState,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async throws {
        try await announceFileStart(
            scannedFile,
            isNew: isNew,
            runID: runID,
            run: run,
            runState: &runState,
            progress: progress
        )

        var completedItemState: IndexingItemState = isNew ? .newIndexing : .modifiedUpdating
        do {
            completedItemState = try await indexFile(
                scannedFile,
                isNew: isNew,
                folderChunk: folderChunk,
                runID: runID,
                run: &run,
                processedCount: runState.processedCount,
                progress: progress
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as LocalAssistantError where Self.endsRun(error) {
            throw error
        } catch {
            completedItemState = .skipped
            try await recordSkippedFile(
                scannedFile,
                runID: runID,
                run: &run,
                runState: &runState,
                failure: error
            )
        }

        runState.currentItem = nil
        runState.currentWaitingState = nil
        runState.currentItemWasCountedAsSkipped = false
        runState.processedCount += 1
        try await database.updateIndexingRun(run)
        await progress(
            makeProgress(
                run: run,
                state: .saving,
                path: visibleRelativePath(for: scannedFile.item),
                itemState: completedItemState,
                processed: runState.processedCount,
                total: run.totalItems
            )
        )
    }

    /// Publishes the in-flight state for one file before extraction begins.
    /// - Parameters:
    ///   - scannedFile: File about to be extracted and embedded.
    ///   - isNew: Whether the file is absent from the private index.
    ///   - runID: Durable parent run identifier.
    ///   - run: Current run summary supplying progress identity and counts.
    ///   - runState: Bookkeeping given the file the interruption handlers must name.
    ///   - progress: Main-actor-safe progress callback.
    /// - Throws: A local database error when the activity row cannot be saved.
    private func announceFileStart(
        _ scannedFile: ScannedFile,
        isNew: Bool,
        runID: UUID,
        run: IndexingRunRecord,
        runState: inout RunState,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async throws {
        let startingState: IndexingItemState = isNew ? .newIndexing : .modifiedUpdating
        let record = activityItem(item: scannedFile.item, runID: runID, state: startingState)
        runState.currentWaitingState = isNew ? .newWaiting : .modifiedWaiting
        runState.currentItem = record
        try await database.upsertIndexingItem(record)
        await progress(
            makeProgress(
                run: run,
                state: .extracting,
                path: visibleRelativePath(for: scannedFile.item),
                itemState: startingState,
                processed: runState.processedCount,
                total: run.totalItems
            )
        )
    }

    /// Records one file the run could not index and leaves the run running.
    /// - Parameters:
    ///   - scannedFile: File whose content processing failed.
    ///   - runID: Durable parent run identifier.
    ///   - run: Run summary updated with the skipped count.
    ///   - runState: Bookkeeping told the skip was already counted.
    ///   - failure: Reason shown in the activity details view.
    /// - Throws: A local database error when the skip cannot be saved.
    private func recordSkippedFile(
        _ scannedFile: ScannedFile,
        runID: UUID,
        run: inout IndexingRunRecord,
        runState: inout RunState,
        failure: Error
    ) async throws {
        run.skippedItems += 1
        runState.currentItemWasCountedAsSkipped = true
        try await database.replaceItem(scannedFile.item, chunks: [])
        try await database.upsertIndexingItem(
            activityItem(
                item: scannedFile.item,
                runID: runID,
                state: .skipped,
                detail: failure.localizedDescription
            )
        )
    }

    /// Reports whether a per-file failure will repeat for every remaining file.
    /// - Parameter error: Failure raised while indexing one file.
    /// - Returns: `true` for model and inference failures that must end the run.
    private static func endsRun(_ error: LocalAssistantError) -> Bool {
        switch error {
        case .modelMissing, .modelIntegrity, .inference: true
        default: false
        }
    }

    /// Records a run that ended early and reports its final state.
    /// - Parameters:
    ///   - root: Authorization whose run ended early.
    ///   - run: Run summary marked stopped or failed.
    ///   - runState: Bookkeeping naming the file that was still in flight.
    ///   - failure: Reported failure, or `nil` when the run was cancelled.
    ///   - progress: Main-actor-safe progress callback.
    private func finishInterruptedRun(
        root: AuthorizedRoot,
        run: inout IndexingRunRecord,
        runState: RunState,
        failure: Error?,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async {
        if var currentItem = runState.currentItem {
            if let failure {
                if runState.currentItemWasCountedAsSkipped == false {
                    run.skippedItems += 1
                }
                currentItem.state = .skipped
                currentItem.detail = failure.localizedDescription
            } else if let waitingState = runState.currentWaitingState {
                currentItem.state = waitingState
            }
            currentItem.updatedAt = Date()
            try? await database.upsertIndexingItem(currentItem)
        }
        run.state = failure == nil ? .stopped : .failed
        run.finishedAt = Date()
        try? await database.updateIndexingRun(run)
        try? await database.insertIndexActivityEvent(
            IndexActivityEventRecord(
                id: UUID(),
                rootID: root.id,
                folderName: root.displayName,
                kind: failure == nil ? .indexingStopped : .indexingFailed,
                occurredAt: Date()
            )
        )
        await progress(
            makeProgress(
                run: run,
                state: failure == nil ? .stopped : .failed,
                path: nil,
                processed: runState.processedCount,
                total: run.totalItems
            )
        )
    }

    /// Read-only facts gathered before any run counters or activity rows are written.
    private struct ScanPreparation {
        let snapshot: ScanSnapshot
        let folderChunks: [UUID: ContentChunk]
        let existingByPath: [String: IndexedItem]
        let staleItems: [IndexedItem]
        let orderedFiles: [ScannedFile]
    }

    /// Scans the root, loads prior state, and publishes fresh metadata early.
    ///
    /// Metadata is upserted here, before extraction and embedding begin, so a file's current
    /// name, size, and modification date are searchable even if content processing fails
    /// or is still running.
    /// - Parameters:
    ///   - root: Persisted read-only root authorization.
    ///   - access: Active security-scoped access lifetime.
    /// - Returns: Facts the run needs before per-file processing starts.
    /// - Throws: A local indexing or database error when scanning or the metadata pass fails.
    private func prepareScan(
        root: AuthorizedRoot,
        access: SecurityScopedAccess
    ) async throws -> ScanPreparation {
        let snapshot = try scanner.scan(root: root, at: access.url)
        let folderChunks = folderContextBuilder.chunks(in: snapshot.files)
        try Task.checkCancellation()
        let existing = try await database.fetchItems(rootID: root.id)
        let existingByPath = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.url.path, $0) }
        )
        let unreadablePaths = Set(
            snapshot.exclusions
                .filter { $0.reason == .unreadable }
                .map { $0.url.standardizedFileURL.path }
        )
        let temporarilyUnreadablePaths = existing.compactMap { item in
            IndexingDecisionPolicy.pathIsAtOrInside(
                item.url.path,
                roots: unreadablePaths
            )
                ? item.url.path
                : nil
        }
        let retainedPaths = Set(snapshot.files.map { $0.item.url.path })
            .union(temporarilyUnreadablePaths)
        let staleItems = existing.filter { retainedPaths.contains($0.url.path) == false }
        let metadataItems = snapshot.files.map { scannedFile in
            metadataItem(
                scannedFile.item,
                preservingContentHash: existingByPath[scannedFile.item.url.path]?.contentHash
            )
        }
        try await database.upsertItemMetadata(metadataItems)
        let orderedFiles = snapshot.files.filter { $0.item.kind == .folder }
            + snapshot.files.filter { $0.item.kind != .folder }
        return ScanPreparation(
            snapshot: snapshot,
            folderChunks: folderChunks,
            existingByPath: existingByPath,
            staleItems: staleItems,
            orderedFiles: orderedFiles
        )
    }

    /// Records skipped exclusions and every file's starting state before processing begins.
    /// - Parameters:
    ///   - runID: Durable parent run identifier.
    ///   - accessURL: Resolved root URL used to compute relative paths for exclusions.
    ///   - snapshot: Current read-only scan.
    ///   - existingByPath: Prior indexed metadata keyed by absolute path.
    ///   - staleItems: Items no longer present in the current scan.
    ///   - run: Run summary updated with the initial skipped count.
    /// - Returns: Starting processed-item count, equal to the number of exclusions.
    /// - Throws: A local database error when an activity row cannot be saved.
    private func recordInitialActivity(
        runID: UUID,
        accessURL: URL,
        snapshot: ScanSnapshot,
        existingByPath: [String: IndexedItem],
        staleItems: [IndexedItem],
        run: inout IndexingRunRecord
    ) async throws -> Int {
        var records: [IndexingItemRecord] = []
        for excluded in snapshot.exclusions {
            records.append(
                activityItem(
                    runID: runID,
                    displayName: excluded.url.lastPathComponent,
                    relativePath: relativePath(for: excluded.url, rootURL: accessURL),
                    state: .skipped,
                    detail: excluded.reason.rawValue
                )
            )
        }
        run.skippedItems = snapshot.exclusions.count

        for scannedFile in snapshot.files {
            let previous = existingByPath[scannedFile.item.url.path]
            let state: IndexingItemState
            if IndexingDecisionPolicy.itemIsUnchanged(
                metadataMatches: previous?.metadataHash == scannedFile.item.metadataHash,
                requiresContentIndexing: scannedFile.requiresContentIndexing,
                previousContentHash: previous?.contentHash
            ) {
                state = .unchanged
            } else if previous == nil {
                state = .newWaiting
            } else {
                state = .modifiedWaiting
            }
            records.append(activityItem(item: scannedFile.item, runID: runID, state: state))
        }
        records.append(
            contentsOf: staleItems.map {
                activityItem(item: $0, runID: runID, state: .missingPendingRemoval)
            }
        )
        try await database.upsertIndexingItems(records)
        try await database.updateIndexingRun(run)
        return snapshot.exclusions.count
    }

    /// Extracts, chunks, embeds, and saves one changed file.
    ///
    /// Errors are not recovered here. They propagate to the caller's existing recovery
    /// switch, which decides whether an error stops the run or is recorded as one skipped
    /// file, so this method only performs the successful path.
    /// - Parameters:
    ///   - scannedFile: Current metadata and extractability for the changed file.
    ///   - isNew: Whether the file has no prior indexed record.
    ///   - folderChunk: Synthesized folder context, when the file is a folder.
    ///   - runID: Durable parent run identifier.
    ///   - run: Run summary updated with the new or updated count.
    ///   - processedCount: Completed item count reported alongside embedding progress.
    ///   - progress: Main-actor-safe progress callback.
    /// - Returns: The file's completed indexing state.
    /// - Throws: A local extraction, database, or inference error.
    private func indexFile(
        _ scannedFile: ScannedFile,
        isNew: Bool,
        folderChunk: ContentChunk?,
        runID: UUID,
        run: inout IndexingRunRecord,
        processedCount: Int,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async throws -> IndexingItemState {
        let item = try itemWithContentHash(
            scannedFile.item,
            synthesizedText: folderChunk?.text
        )
        let rawChunks: [ContentChunk]
        if let folderChunk {
            rawChunks = [folderChunk]
        } else if scannedFile.isExtractable {
            let document = try extractor.extract(item: item)
            rawChunks = chunker.chunks(document: document, itemID: item.id)
        } else {
            rawChunks = []
        }
        let chunks: [ContentChunk]
        if rawChunks.isEmpty == false {
            let progressSnapshot = run
            let visiblePath = visibleRelativePath(for: scannedFile.item)
            chunks = try await embed(
                rawChunks,
                progress: { value in
                    var enriched = value
                    enriched.runID = progressSnapshot.id
                    enriched.rootID = progressSnapshot.rootID
                    enriched.folderName = progressSnapshot.folderName
                    enriched.trigger = progressSnapshot.trigger
                    enriched.newItems = progressSnapshot.newItems
                    enriched.updatedItems = progressSnapshot.updatedItems
                    enriched.unchangedItems = progressSnapshot.unchangedItems
                    enriched.removedItems = progressSnapshot.removedItems
                    enriched.currentPath = visiblePath
                    enriched.currentItemState = isNew
                        ? .newIndexing
                        : .modifiedUpdating
                    await progress(enriched)
                },
                totalItems: run.totalItems,
                processedItems: processedCount,
                skippedItems: run.skippedItems
            )
        } else {
            chunks = []
        }
        try Task.checkCancellation()
        try await database.replaceItem(item, chunks: chunks)
        let finalState: IndexingItemState
        if isNew {
            run.newItems += 1
            finalState = .newIndexed
        } else {
            run.updatedItems += 1
            finalState = .modifiedUpdated
        }
        try await database.upsertIndexingItem(
            activityItem(item: item, runID: runID, state: finalState)
        )
        return finalState
    }

    /// Records every item no longer present in the current scan as removed.
    /// - Parameters:
    ///   - staleItems: Items already pruned from the private index.
    ///   - runID: Durable parent run identifier.
    ///   - run: Run summary updated with the removed count.
    ///   - processedCount: Completed item count advanced as each removal is recorded.
    ///   - progress: Main-actor-safe progress callback.
    /// - Throws: A local database error when an activity row cannot be saved.
    private func removeStaleItems(
        _ staleItems: [IndexedItem],
        runID: UUID,
        run: inout IndexingRunRecord,
        processedCount: inout Int,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async throws {
        for staleItem in staleItems {
            try await database.upsertIndexingItem(
                activityItem(item: staleItem, runID: runID, state: .removedFromIndex)
            )
            run.removedItems += 1
            processedCount += 1
            try await database.updateIndexingRun(run)
            await progress(
                makeProgress(
                    run: run,
                    state: .saving,
                    path: staleItem.relativePath,
                    itemState: .removedFromIndex,
                    processed: processedCount,
                    total: run.totalItems
                )
            )
        }
    }

    /// Marks the run completed and refreshes the root's last-indexed timestamp.
    /// - Parameters:
    ///   - root: Authorization whose successful scan just completed.
    ///   - run: Run summary marked completed and persisted.
    ///   - processedCount: Final completed item count.
    ///   - progress: Main-actor-safe progress callback.
    /// - Returns: Completed indexing statistics.
    /// - Throws: A local database error when final state cannot be saved.
    private func completeRun(
        root: AuthorizedRoot,
        run: inout IndexingRunRecord,
        processedCount: Int,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async throws -> IndexingOutcome {
        let completedAt = Date()
        var refreshedRoot = root
        refreshedRoot.lastIndexedAt = completedAt
        refreshedRoot.isAvailable = true
        try await database.upsertRoot(refreshedRoot)
        run.state = .completed
        run.finishedAt = completedAt
        try await database.updateIndexingRun(run)
        await progress(
            makeProgress(
                run: run,
                state: .idle,
                path: nil,
                processed: processedCount,
                total: run.totalItems
            )
        )
        return IndexingOutcome(
            newItems: run.newItems,
            removedItems: run.removedItems
        )
    }
}
