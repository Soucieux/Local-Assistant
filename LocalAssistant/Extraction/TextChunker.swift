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
            let ranges = wordRanges(in: segment.text)
            if ranges.isEmpty {
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
                while lowerWord < ranges.count {
                    let upperWord = min(lowerWord + AppConstants.Indexing.targetChunkWordCount, ranges.count)
                    let lowerIndex = ranges[lowerWord].lowerBound
                    let upperIndex = ranges[upperWord - 1].upperBound
                    let chunkText = String(segment.text[lowerIndex..<upperIndex])
                    let localStart = segment.text.distance(from: segment.text.startIndex, to: lowerIndex)
                    let localEnd = segment.text.distance(from: segment.text.startIndex, to: upperIndex)
                    result.append(
                        makeChunk(
                            text: chunkText,
                            itemID: itemID,
                            ordinal: result.count,
                            characterStart: documentOffset + localStart,
                            characterEnd: documentOffset + localEnd,
                            segment: segment
                        )
                    )
                    if upperWord == ranges.count { break }
                    lowerWord = max(lowerWord + 1, upperWord - AppConstants.Indexing.overlapWordCount)
                }
            }
            documentOffset += segment.text.count + AppConstants.Text.newline.count
        }
        return result
    }

    /// Enumerates language-aware word ranges.
    /// - Parameter text: Normalized segment text.
    /// - Returns: Word ranges in source order.
    private func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .localized]) {
            _, range, _, _ in
            ranges.append(range)
        }
        return ranges
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
