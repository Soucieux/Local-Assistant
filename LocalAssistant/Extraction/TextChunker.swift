import Foundation

/// Splits source-aligned text into overlapping retrieval passages.
struct TextChunker: Sendable {
    /// Creates stable chunks for one indexed file.
    /// - Parameters:
    ///   - document: Extracted source-aligned document.
    ///   - itemID: Parent item identifier.
    /// - Returns: Ordered chunks without embeddings.
    internal func chunks(document: ExtractedDocument, itemID: UUID) -> [ContentChunk] {
        var result: [ContentChunk] = []
        var documentOffset = 0
        for segment in document.segments where segment.text.isEmpty == false {
            let positions = wordPositions(in: segment.text)
            if positions.isEmpty {
                result.append(
                    makeChunk(
                        text: segment.text,
                        itemID: itemID,
                        ordinal: result.count,
                        characterStart: documentOffset,
                        characterEnd: documentOffset + segment.text.count,
                        segment: segment
                    )
                )
            } else {
                var lowerWord = 0
                while lowerWord < positions.count {
                    let upperWord = min(lowerWord + AppConstants.Indexing.targetChunkWordCount, positions.count)
                    let lower = positions[lowerWord]
                    let upper = positions[upperWord - 1]
                    let chunkText = String(segment.text[lower.range.lowerBound..<upper.range.upperBound])
                    result.append(
                        makeChunk(
                            text: chunkText,
                            itemID: itemID,
                            ordinal: result.count,
                            characterStart: documentOffset + lower.characterStart,
                            characterEnd: documentOffset + upper.characterEnd,
                            segment: segment
                        )
                    )
                    if upperWord == positions.count { break }
                    lowerWord = max(lowerWord + 1, upperWord - AppConstants.Indexing.overlapWordCount)
                }
            }
            documentOffset += segment.text.count + AppConstants.Text.newline.count
        }
        return result
    }

    /// One word range paired with its character offsets inside the segment.
    private struct WordPosition {
        let range: Range<String.Index>
        let characterStart: Int
        let characterEnd: Int
    }

    /// Enumerates language-aware words and their offsets in a single pass.
    ///
    /// Measuring each chunk boundary from the start of the segment walks the whole string
    /// again per chunk, so a long document costs time proportional to its length squared.
    /// Advancing one running cursor keeps the total cost proportional to the length.
    /// - Parameter text: Normalized segment text.
    /// - Returns: Word positions in source order.
    private func wordPositions(in text: String) -> [WordPosition] {
        var positions: [WordPosition] = []
        var cursor = text.startIndex
        var offset = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .localized]) {
            _, range, _, _ in
            offset += text.distance(from: cursor, to: range.lowerBound)
            let characterStart = offset
            offset += text.distance(from: range.lowerBound, to: range.upperBound)
            positions.append(
                WordPosition(range: range, characterStart: characterStart, characterEnd: offset)
            )
            cursor = range.upperBound
        }
        return positions
    }

    /// Creates one stable source-aligned chunk.
    /// - Parameters:
    ///   - text: Chunk text.
    ///   - itemID: Parent item identifier.
    ///   - ordinal: Document-order position.
    ///   - characterStart: Start offset in the extracted document.
    ///   - characterEnd: End offset in the extracted document.
    ///   - segment: Source segment supplying page and section labels.
    /// - Returns: Content chunk without an embedding.
    private func makeChunk(
        text: String,
        itemID: UUID,
        ordinal: Int,
        characterStart: Int,
        characterEnd: Int,
        segment: ExtractedSegment
    ) -> ContentChunk {
        let identity = [itemID.uuidString, String(ordinal), text].joined(
            separator: ExtractionConstants.indexingSeparator
        )
        return ContentChunk(
            id: StableIdentifier.uuid(for: identity),
            itemID: itemID,
            ordinal: ordinal,
            text: text,
            characterStart: characterStart,
            characterEnd: characterEnd,
            pageNumber: segment.pageNumber,
            sectionName: segment.sectionName,
            embedding: nil
        )
    }
}
