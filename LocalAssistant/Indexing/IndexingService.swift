import Foundation

/// Coordinates read-only scanning, extraction, local embedding, and private indexing.
actor IndexingService {
    private let database: AssistantDatabase
    private let scanner: ReadOnlyFileScanner
    private let extractor: ExtractionCoordinator
    private let chunker: TextChunker
    let embeddings: LocalEmbeddingService
    private let folderContextBuilder = FolderContextBuilder()

    /// Creates the local indexing pipeline.
    /// - Parameters:
    ///   - database: Private SQLite index.
    ///   - scanner: Read-only file traversal service.
    ///   - extractor: Local content extraction coordinator.
    ///   - chunker: Source-aligned passage splitter.
    ///   - embeddings: Embedded Qwen embedding service.
    internal init(
        database: AssistantDatabase,
        scanner: ReadOnlyFileScanner,
        extractor: ExtractionCoordinator,
        chunker: TextChunker,
        embeddings: LocalEmbeddingService
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
        var run = IndexingRunRecord(
            id: runID,
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
        try await database.insertIndexingRun(run)
        var processedCount = 0
        var currentItem: IndexingItemRecord?
        var currentWaitingState: IndexingItemState?
        var currentItemWasCountedAsSkipped = false

        do {
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
            let snapshot = preparation.snapshot
            let folderChunks = preparation.folderChunks
            let existingByPath = preparation.existingByPath
            let retainedPaths = preparation.retainedPaths
            let staleItems = preparation.staleItems
            let orderedFiles = preparation.orderedFiles
            try Task.checkCancellation()
            run.totalItems = snapshot.files.count + staleItems.count + snapshot.exclusions.count
            processedCount = try await recordInitialActivity(
                runID: runID,
                accessURL: access.url,
                snapshot: snapshot,
                existingByPath: existingByPath,
                staleItems: staleItems,
                run: &run
            )

            for scannedFile in orderedFiles {
                try Task.checkCancellation()
                let previous = existingByPath[scannedFile.item.url.path]
                if IndexingDecisionPolicy.itemIsUnchanged(
                    metadataMatches: previous?.metadataHash == scannedFile.item.metadataHash,
                    requiresContentIndexing: scannedFile.requiresContentIndexing,
                    previousContentHash: previous?.contentHash
                ) {
                    run.unchangedItems += 1
                    processedCount += 1
                    try await database.updateIndexingRun(run)
                    await progress(
                        makeProgress(
                            run: run,
                            state: .scanning,
                            path: visibleRelativePath(for: scannedFile.item),
                            itemState: .unchanged,
                            processed: processedCount,
                            total: run.totalItems
                        )
                    )
                    continue
                }

                let isNew = previous == nil
                currentWaitingState = isNew ? .newWaiting : .modifiedWaiting
                currentItem = activityItem(
                    item: scannedFile.item,
                    runID: runID,
                    state: isNew ? .newIndexing : .modifiedUpdating
                )
                if let currentItem {
                    try await database.upsertIndexingItem(currentItem)
                }
                await progress(
                    makeProgress(
                        run: run,
                        state: .extracting,
                        path: visibleRelativePath(for: scannedFile.item),
                        itemState: isNew ? .newIndexing : .modifiedUpdating,
                        processed: processedCount,
                        total: run.totalItems
                    )
                )

                var completedItemState: IndexingItemState = isNew
                    ? .newIndexing
                    : .modifiedUpdating
                do {
                    completedItemState = try await indexFile(
                        scannedFile,
                        isNew: isNew,
                        folderChunk: folderChunks[scannedFile.item.id],
                        runID: runID,
                        run: &run,
                        processedCount: processedCount,
                        progress: progress
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch let error as LocalAssistantError {
                    switch error {
                    case .modelMissing, .modelIntegrity, .inference:
                        throw error
                    default:
                        run.skippedItems += 1
                        currentItemWasCountedAsSkipped = true
                        completedItemState = .skipped
                        try await database.replaceItem(scannedFile.item, chunks: [])
                        try await database.upsertIndexingItem(
                            activityItem(
                                item: scannedFile.item,
                                runID: runID,
                                state: .skipped,
                                detail: error.localizedDescription
                            )
                        )
                    }
                } catch {
                    run.skippedItems += 1
                    currentItemWasCountedAsSkipped = true
                    completedItemState = .skipped
                    try await database.replaceItem(scannedFile.item, chunks: [])
                    try await database.upsertIndexingItem(
                        activityItem(
                            item: scannedFile.item,
                            runID: runID,
                            state: .skipped,
                            detail: error.localizedDescription
                        )
                    )
                }
                currentItem = nil
                currentWaitingState = nil
                currentItemWasCountedAsSkipped = false
                processedCount += 1
                try await database.updateIndexingRun(run)
                await progress(
                    makeProgress(
                        run: run,
                        state: .saving,
                        path: visibleRelativePath(for: scannedFile.item),
                        itemState: completedItemState,
                        processed: processedCount,
                        total: run.totalItems
                    )
                )
            }

            try Task.checkCancellation()
            try await database.pruneItems(rootID: root.id, retaining: retainedPaths)
            try await removeStaleItems(
                staleItems,
                runID: runID,
                run: &run,
                processedCount: &processedCount,
                progress: progress
            )

            return try await completeRun(
                root: root,
                run: &run,
                processedCount: processedCount,
                progress: progress
            )
        } catch is CancellationError {
            if var currentItem, let currentWaitingState {
                currentItem.state = currentWaitingState
                currentItem.updatedAt = Date()
                try? await database.upsertIndexingItem(currentItem)
            }
            run.state = .stopped
            run.finishedAt = Date()
            try? await database.updateIndexingRun(run)
            try? await database.insertIndexActivityEvent(
                IndexActivityEventRecord(
                    id: UUID(),
                    rootID: root.id,
                    folderName: root.displayName,
                    kind: .indexingStopped,
                    occurredAt: Date()
                )
            )
            await progress(
                makeProgress(
                    run: run,
                    state: .stopped,
                    path: nil,
                    processed: processedCount,
                    total: run.totalItems
                )
            )
            throw CancellationError()
        } catch {
            if var currentItem {
                if currentItemWasCountedAsSkipped == false {
                    run.skippedItems += 1
                }
                currentItem.state = .skipped
                currentItem.detail = error.localizedDescription
                currentItem.updatedAt = Date()
                try? await database.upsertIndexingItem(currentItem)
            }
            run.state = .failed
            run.finishedAt = Date()
            try? await database.updateIndexingRun(run)
            try? await database.insertIndexActivityEvent(
                IndexActivityEventRecord(
                    id: UUID(),
                    rootID: root.id,
                    folderName: root.displayName,
                    kind: .indexingFailed,
                    occurredAt: Date()
                )
            )
            await progress(
                makeProgress(
                    run: run,
                    state: .failed,
                    path: nil,
                    processed: processedCount,
                    total: run.totalItems
                )
            )
            throw error
        }
    }

    /// Read-only facts gathered before any run counters or activity rows are written.
    private struct ScanPreparation {
        let snapshot: ScanSnapshot
        let folderChunks: [UUID: ContentChunk]
        let existingByPath: [String: IndexedItem]
        let retainedPaths: Set<String>
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
            retainedPaths: retainedPaths,
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
        for excluded in snapshot.exclusions {
            let relativePath = relativePath(for: excluded.url, rootURL: accessURL)
            try await database.upsertIndexingItem(
                activityItem(
                    runID: runID,
                    displayName: excluded.url.lastPathComponent,
                    relativePath: relativePath,
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
            try await database.upsertIndexingItem(
                activityItem(item: scannedFile.item, runID: runID, state: state)
            )
        }
        for staleItem in staleItems {
            try await database.upsertIndexingItem(
                activityItem(item: staleItem, runID: runID, state: .missingPendingRemoval)
            )
        }
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

    /// Copies fresh scan metadata while retaining the last successfully indexed content hash.
    /// - Parameters:
    ///   - item: Metadata observed during the current read-only scan.
    ///   - contentHash: Content hash from the previously completed extraction, when available.
    /// - Returns: Metadata row safe to publish before expensive content processing begins.
    private func metadataItem(
        _ item: IndexedItem,
        preservingContentHash contentHash: String?
    ) -> IndexedItem {
        IndexedItem(
            id: item.id,
            rootID: item.rootID,
            parentID: item.parentID,
            url: item.url,
            relativePath: item.relativePath,
            displayName: item.displayName,
            kind: item.kind,
            contentType: item.contentType,
            byteCount: item.byteCount,
            createdAt: item.createdAt,
            modifiedAt: item.modifiedAt,
            contentHash: contentHash,
            metadataHash: item.metadataHash,
            isDirectory: item.isDirectory,
            isHidden: item.isHidden
        )
    }

    /// Computes a content hash for a changed file or synthesized folder context.
    /// - Parameters:
    ///   - item: Newly scanned metadata.
    ///   - synthesizedText: Optional local-only context generated for a folder.
    /// - Returns: Copy containing a streaming SHA-256 hash when applicable.
    /// - Throws: A local extraction error when a readable file cannot be hashed.
    private func itemWithContentHash(
        _ item: IndexedItem,
        synthesizedText: String?
    ) throws -> IndexedItem {
        let digest: String? = if let synthesizedText {
            FileHasher.sha256(of: synthesizedText)
        } else if item.isDirectory {
            nil
        } else {
            try FileHasher.sha256(of: item.url)
        }
        return IndexedItem(
            id: item.id,
            rootID: item.rootID,
            parentID: item.parentID,
            url: item.url,
            relativePath: item.relativePath,
            displayName: item.displayName,
            kind: item.kind,
            contentType: item.contentType,
            byteCount: item.byteCount,
            createdAt: item.createdAt,
            modifiedAt: item.modifiedAt,
            contentHash: digest,
            metadataHash: item.metadataHash,
            isDirectory: item.isDirectory,
            isHidden: item.isHidden
        )
    }




    /// Builds a bounded progress snapshot.
    /// - Parameters:
    ///   - run: Durable run summary supplying identity and counts.
    ///   - state: Active pipeline stage.
    ///   - path: Optional current path.
    ///   - itemState: Optional file-level state for the current path.
    ///   - processed: Completed item count.
    ///   - total: Total item count.
    /// - Returns: Progress value safe for presentation.
    private func makeProgress(
        run: IndexingRunRecord,
        state: IndexingState,
        path: String?,
        itemState: IndexingItemState? = nil,
        processed: Int,
        total: Int
    ) -> IndexingProgress {
        let fraction = IndexingDecisionPolicy.progressFraction(
            processed: processed,
            total: total
        )
        return IndexingProgress(
            runID: run.id,
            rootID: run.rootID,
            folderName: run.folderName,
            trigger: run.trigger,
            state: state,
            currentPath: path,
            currentItemState: itemState,
            processedItems: processed,
            totalItems: total,
            skippedItems: run.skippedItems,
            newItems: run.newItems,
            updatedItems: run.updatedItems,
            unchangedItems: run.unchangedItems,
            removedItems: run.removedItems,
            fractionCompleted: fraction
        )
    }

    /// Creates a durable file-state record from one scanned or stale item.
    /// - Parameters:
    ///   - item: Indexed item supplying visible identity and relative path.
    ///   - runID: Durable parent run identifier.
    ///   - state: Current file-level indexing state.
    ///   - detail: Optional private explanation for a skipped item.
    /// - Returns: Deterministic activity record for the item and run.
    private func activityItem(
        item: IndexedItem,
        runID: UUID,
        state: IndexingItemState,
        detail: String? = nil
    ) -> IndexingItemRecord {
        activityItem(
            runID: runID,
            displayName: item.displayName,
            relativePath: visibleRelativePath(for: item),
            state: state,
            detail: detail
        )
    }

    /// Creates one deterministic file-state record for an indexing run.
    /// - Parameters:
    ///   - runID: Durable parent run identifier.
    ///   - displayName: Visible file or folder name.
    ///   - relativePath: Root-relative path retained for private display.
    ///   - state: Current file-level indexing state.
    ///   - detail: Optional private explanation for a skipped item.
    /// - Returns: Deterministic activity record for the path and run.
    private func activityItem(
        runID: UUID,
        displayName: String,
        relativePath: String,
        state: IndexingItemState,
        detail: String? = nil
    ) -> IndexingItemRecord {
        IndexingItemRecord(
            id: StableIdentifier.uuid(
                for: [runID.uuidString, relativePath].joined(
                    separator: ExtractionConstants.indexingSeparator
                )
            ),
            runID: runID,
            displayName: displayName,
            relativePath: relativePath,
            state: state,
            detail: detail,
            updatedAt: Date()
        )
    }

    /// Returns a root-relative path suitable for private activity presentation.
    /// - Parameters:
    ///   - url: Descendant URL to represent without its root prefix.
    ///   - rootURL: Authorized root URL used as the relative base.
    /// - Returns: Root-relative path or the final path component as a safe fallback.
    private func relativePath(for url: URL, rootURL: URL) -> String {
        let rootComponents = rootURL.standardizedFileURL.pathComponents
        let itemComponents = url.standardizedFileURL.pathComponents
        guard itemComponents.starts(with: rootComponents) else {
            return url.lastPathComponent
        }
        return itemComponents.dropFirst(rootComponents.count).joined(
            separator: FileConstants.pathSeparator
        )
    }

    /// Returns a non-empty root-relative label for progress and activity presentation.
    /// - Parameter item: Indexed file or folder being presented.
    /// - Returns: Relative path, or the root folder name for the authorized root itself.
    private func visibleRelativePath(for item: IndexedItem) -> String {
        item.relativePath.isEmpty ? item.displayName : item.relativePath
    }
}
