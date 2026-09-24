import Foundation

/// Turns extracted passages into local Qwen embeddings within the native context limit.
extension IndexingService {
    /// Adds document embeddings sequentially to limit memory pressure.
    /// - Parameters:
    ///   - chunks: Source-aligned chunks without embeddings.
    ///   - progress: Progress callback.
    ///   - totalItems: Total files in the current scan.
    ///   - processedItems: Files completed before the current file.
    ///   - skippedItems: Current skipped count.
    /// - Returns: Copies containing local Qwen embeddings.
    /// - Throws: A local inference error when embedding fails.
    internal func embed(
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
                    fractionCompleted: IndexingDecisionPolicy.progressFraction(
                        processed: processedItems,
                        total: totalItems
                    )
                )
            )
            let vector = try await embeddings.embedDocument(chunk.text)
            embedded.append(
                ContentChunk(
                    id: StableIdentifier.chunkID(
                        itemID: chunk.itemID,
                        ordinal: ordinal,
                        text: chunk.text
                    ),
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
}
