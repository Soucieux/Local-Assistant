import Foundation

/// Coordinates read-only scanning, extraction, local embedding, and private indexing.
actor IndexingService {
    private let database: AssistantDatabase
    private let scanner: ReadOnlyFileScanner
    private let extractor: ExtractionCoordinator
    private let chunker: TextChunker
    private let embeddings: LocalEmbeddingService

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
            let snapshot = try scanner.scan(root: root, at: access.url)
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
            run.totalItems = snapshot.files.count + staleItems.count + snapshot.exclusions.count

            for excluded in snapshot.exclusions {
                let relativePath = relativePath(for: excluded.url, rootURL: access.url)
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
            processedCount = snapshot.exclusions.count

            for scannedFile in snapshot.files {
                let previous = existingByPath[scannedFile.item.url.path]
                let state: IndexingItemState
                if IndexingDecisionPolicy.itemIsUnchanged(
                    metadataMatches: previous?.metadataHash == scannedFile.item.metadataHash,
                    isExtractable: scannedFile.isExtractable,
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

            for scannedFile in snapshot.files {
                try Task.checkCancellation()
                let previous = existingByPath[scannedFile.item.url.path]
                if IndexingDecisionPolicy.itemIsUnchanged(
                    metadataMatches: previous?.metadataHash == scannedFile.item.metadataHash,
                    isExtractable: scannedFile.isExtractable,
                    previousContentHash: previous?.contentHash
                ) {
                    run.unchangedItems += 1
                    processedCount += 1
                    try await database.updateIndexingRun(run)
                    await progress(
                        makeProgress(
                            run: run,
                            state: .scanning,
                            path: scannedFile.item.relativePath,
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
                        path: scannedFile.item.relativePath,
                        itemState: isNew ? .newIndexing : .modifiedUpdating,
                        processed: processedCount,
                        total: run.totalItems
                    )
                )

                var completedItemState: IndexingItemState = isNew
                    ? .newIndexing
                    : .modifiedUpdating
                do {
                    let item = try itemWithContentHash(scannedFile.item)
                    let chunks: [ContentChunk]
                    if scannedFile.isExtractable {
                        let document = try extractor.extract(item: item)
                        let rawChunks = chunker.chunks(document: document, itemID: item.id)
                        let progressSnapshot = run
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
                                enriched.currentPath = scannedFile.item.relativePath
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
                    completedItemState = finalState
                    try await database.upsertIndexingItem(
                        activityItem(item: item, runID: runID, state: finalState)
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
                        path: scannedFile.item.relativePath,
                        itemState: completedItemState,
                        processed: processedCount,
                        total: run.totalItems
                    )
                )
            }

            try Task.checkCancellation()
            try await database.pruneItems(rootID: root.id, retaining: retainedPaths)
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

    /// Computes a content hash only for regular files that changed.
    /// - Parameter item: Newly scanned metadata.
    /// - Returns: Copy containing a streaming SHA-256 hash when applicable.
    /// - Throws: A local extraction error when a readable file cannot be hashed.
    private func itemWithContentHash(_ item: IndexedItem) throws -> IndexedItem {
        let digest = item.isDirectory ? nil : try FileHasher.sha256(of: item.url)
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

    /// Adds document embeddings sequentially to limit memory pressure.
    /// - Parameters:
    ///   - chunks: Source-aligned chunks without embeddings.
    ///   - progress: Progress callback.
    ///   - totalItems: Total files in the current scan.
    ///   - processedItems: Files completed before the current file.
    ///   - skippedItems: Current skipped count.
    /// - Returns: Copies containing local Qwen embeddings.
    /// - Throws: A local inference error when embedding fails.
    private func embed(
        _ chunks: [ContentChunk],
        progress: @Sendable (IndexingProgress) async -> Void,
        totalItems: Int,
        processedItems: Int,
        skippedItems: Int
    ) async throws -> [ContentChunk] {
        var safeChunks: [ContentChunk] = []
        for chunk in chunks {
            safeChunks.append(contentsOf: try await embeddingSafeChunks(from: chunk))
        }

        var embedded: [ContentChunk] = []
        for (ordinal, chunk) in safeChunks.enumerated() {
            try Task.checkCancellation()
            await progress(
                IndexingProgress(
                    runID: nil,
                    rootID: nil,
                    folderName: nil,
                    trigger: nil,
                    state: .embedding,
                    currentPath: nil,
                    currentItemState: nil,
                    processedItems: processedItems,
                    totalItems: totalItems,
                    skippedItems: skippedItems,
                    newItems: 0,
                    updatedItems: 0,
                    unchangedItems: 0,
                    removedItems: 0,
                    fractionCompleted: totalItems == 0
                        ? 0
                        : Double(processedItems) / Double(totalItems)
                )
            )
            let vector = try await embeddings.embedDocument(chunk.text)
            embedded.append(
                ContentChunk(
                    id: chunkIdentifier(itemID: chunk.itemID, ordinal: ordinal, text: chunk.text),
                    itemID: chunk.itemID,
                    ordinal: ordinal,
                    text: chunk.text,
                    characterStart: chunk.characterStart,
                    characterEnd: chunk.characterEnd,
                    pageNumber: chunk.pageNumber,
                    sectionName: chunk.sectionName,
                    embedding: vector
                )
            )
        }
        return embedded
    }

    /// Recursively subdivides a passage until every fragment fits the native embedding batch.
    /// - Parameter chunk: Source-aligned passage to inspect.
    /// - Returns: Ordered fragments preserving the original character offsets.
    /// - Throws: A local model or tokenization error.
    private func embeddingSafeChunks(from chunk: ContentChunk) async throws -> [ContentChunk] {
        if try await embeddings.canEmbedDocument(chunk.text) { return [chunk] }
        guard chunk.text.count > 1 else {
            throw LocalAssistantError.inference(InferenceConstants.promptTooLong)
        }

        let middle = chunk.text.index(
            chunk.text.startIndex,
            offsetBy: chunk.text.count / 2
        )
        let leftText = String(chunk.text[..<middle])
        let rightText = String(chunk.text[middle...])
        let middleOffset = chunk.characterStart + leftText.count
        let left = ContentChunk(
            id: chunk.id,
            itemID: chunk.itemID,
            ordinal: chunk.ordinal,
            text: leftText,
            characterStart: chunk.characterStart,
            characterEnd: middleOffset,
            pageNumber: chunk.pageNumber,
            sectionName: chunk.sectionName,
            embedding: nil
        )
        let right = ContentChunk(
            id: chunk.id,
            itemID: chunk.itemID,
            ordinal: chunk.ordinal,
            text: rightText,
            characterStart: middleOffset,
            characterEnd: chunk.characterEnd,
            pageNumber: chunk.pageNumber,
            sectionName: chunk.sectionName,
            embedding: nil
        )
        let leftChunks = try await embeddingSafeChunks(from: left)
        let rightChunks = try await embeddingSafeChunks(from: right)
        return leftChunks + rightChunks
    }

    /// Creates a stable identifier for a final embedding-safe passage.
    /// - Parameters:
    ///   - itemID: Parent item identifier.
    ///   - ordinal: Final passage order within the item.
    ///   - text: Passage content.
    /// - Returns: Deterministic passage identifier.
    private func chunkIdentifier(itemID: UUID, ordinal: Int, text: String) -> UUID {
        let identity = [itemID.uuidString, String(ordinal), text].joined(
            separator: ExtractionConstants.indexingSeparator
        )
        return StableIdentifier.uuid(for: identity)
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
            relativePath: item.relativePath,
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
}
