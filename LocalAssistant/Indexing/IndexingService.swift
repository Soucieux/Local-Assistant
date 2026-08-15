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
    ///   - progress: Main-actor-safe progress callback.
    /// - Returns: Completed indexing statistics.
    /// - Throws: A local indexing, extraction, database, or inference error.
    internal func index(
        root: AuthorizedRoot,
        access: SecurityScopedAccess,
        progress: @Sendable (IndexingProgress) async -> Void
    ) async throws -> IndexingOutcome {
        try Task.checkCancellation()
        await progress(
            IndexingProgress(
                state: .scanning,
                currentPath: access.url.path,
                processedItems: 0,
                totalItems: 0,
                skippedItems: 0,
                fractionCompleted: 0
            )
        )
        let snapshot = try scanner.scan(root: root, at: access.url)
        let existing = try await database.fetchItems(rootID: root.id)
        let existingByPath = Dictionary(uniqueKeysWithValues: existing.map { ($0.url.path, $0) })
        let retainedPaths = Set(snapshot.files.map { $0.item.url.path })
        var indexedCount = 0
        var unchangedCount = 0
        var skippedCount = snapshot.exclusions.count

        for (offset, scannedFile) in snapshot.files.enumerated() {
            try Task.checkCancellation()
            let progressValue = makeProgress(
                state: .extracting,
                path: scannedFile.item.url.path,
                processed: offset,
                total: snapshot.files.count,
                skipped: skippedCount
            )
            await progress(progressValue)

            if let previous = existingByPath[scannedFile.item.url.path],
               previous.metadataHash == scannedFile.item.metadataHash {
                unchangedCount += 1
                continue
            }

            do {
                let item = try itemWithContentHash(scannedFile.item)
                let chunks: [ContentChunk]
                if scannedFile.isExtractable {
                    let document = try extractor.extract(item: item)
                    let rawChunks = chunker.chunks(document: document, itemID: item.id)
                    chunks = try await embed(rawChunks, progress: progress, totalItems: snapshot.files.count, processedItems: offset, skippedItems: skippedCount)
                } else {
                    chunks = []
                }
                try await database.replaceItem(item, chunks: chunks)
                indexedCount += 1
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as LocalAssistantError {
                switch error {
                case .modelMissing, .modelIntegrity, .inference:
                    throw error
                default:
                    skippedCount += 1
                    try await database.replaceItem(scannedFile.item, chunks: [])
                }
            } catch {
                skippedCount += 1
                try await database.replaceItem(scannedFile.item, chunks: [])
            }
        }

        try await database.pruneItems(rootID: root.id, retaining: retainedPaths)
        let completedAt = Date()
        var refreshedRoot = root
        refreshedRoot.lastIndexedAt = completedAt
        refreshedRoot.isAvailable = true
        try await database.upsertRoot(refreshedRoot)
        await progress(
            IndexingProgress(
                state: .idle,
                currentPath: nil,
                processedItems: snapshot.files.count,
                totalItems: snapshot.files.count,
                skippedItems: skippedCount,
                fractionCompleted: AppConstants.Indexing.completedFraction
            )
        )
        return IndexingOutcome(
            indexedItems: indexedCount,
            unchangedItems: unchangedCount,
            skippedItems: skippedCount,
            excludedItems: snapshot.exclusions.count,
            completedAt: completedAt
        )
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
                makeProgress(
                    state: .embedding,
                    path: nil,
                    processed: processedItems,
                    total: totalItems,
                    skipped: skippedItems
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
    ///   - state: Active pipeline stage.
    ///   - path: Optional current path.
    ///   - processed: Completed item count.
    ///   - total: Total item count.
    ///   - skipped: Skipped or excluded item count.
    /// - Returns: Progress value safe for presentation.
    private func makeProgress(
        state: IndexingState,
        path: String?,
        processed: Int,
        total: Int,
        skipped: Int
    ) -> IndexingProgress {
        let fraction = total == 0 ? 0 : Double(processed) / Double(total)
        return IndexingProgress(
            state: state,
            currentPath: path,
            processedItems: processed,
            totalItems: total,
            skippedItems: skipped,
            fractionCompleted: fraction
        )
    }
}
