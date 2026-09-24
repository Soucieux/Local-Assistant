import Foundation
import Testing

@testable import LocalAssistant

/// Chunk character offsets are what later highlight an excerpt inside its source file, so
/// they are checked against the real text rather than only counted.
internal struct TextChunkerTests {
    private let chunker = TextChunker()

    @Test("A document with no segments produces no chunks")
    internal func producesNoChunksForEmptyDocument() {
        let document = ExtractedDocument(segments: [])
        #expect(chunker.chunks(document: document, itemID: UUID()).isEmpty)
    }

    @Test("An empty segment is skipped rather than stored as a blank chunk")
    internal func skipsEmptySegments() {
        let document = TestFixtures.document(text: "")
        #expect(chunker.chunks(document: document, itemID: UUID()).isEmpty)
    }

    @Test("Short text becomes exactly one chunk spanning its words")
    internal func keepsShortTextInOneChunk() {
        let document = TestFixtures.document(text: "A short local note.")
        let chunks = chunker.chunks(document: document, itemID: UUID())
        #expect(chunks.count == 1)
        #expect(chunks[0].ordinal == 0)
        // A chunk runs from the first word to the last, so trailing punctuation sits
        // outside the final word range and is not carried into the chunk text.
        #expect(chunks[0].text == "A short local note")
        #expect(chunks[0].characterStart == 0)
    }

    @Test("Text without word characters still yields a chunk")
    internal func handlesTextWithoutWords() {
        let document = TestFixtures.document(text: "!!! ??? ...")
        #expect(chunker.chunks(document: document, itemID: UUID()).isEmpty == false)
    }

    @Test("Every chunk's offsets address its own text inside the segment")
    internal func reportsOffsetsThatMatchTheSource() {
        let words = (1...900).map { "word\($0)" }.joined(separator: " ")
        let document = TestFixtures.document(text: words)
        let chunks = chunker.chunks(document: document, itemID: UUID())
        #expect(chunks.count > 1)
        let characters = Array(words)
        for chunk in chunks {
            #expect(chunk.characterStart >= 0)
            #expect(chunk.characterEnd <= characters.count)
            #expect(chunk.characterStart < chunk.characterEnd)
            let slice = String(characters[chunk.characterStart..<chunk.characterEnd])
            #expect(slice == chunk.text)
        }
    }

    @Test("Chunks are ordered and cover the segment from its start to its end")
    internal func coversTheWholeSegment() {
        let words = (1...900).map { "word\($0)" }.joined(separator: " ")
        let chunks = chunker.chunks(document: TestFixtures.document(text: words), itemID: UUID())
        #expect(chunks.map(\.ordinal) == Array(0..<chunks.count))
        #expect(chunks.first?.characterStart == 0)
        #expect(chunks.last?.characterEnd == words.count)
    }

    @Test("Consecutive chunks overlap so a passage is never split without context")
    internal func overlapsConsecutiveChunks() {
        let words = (1...900).map { "word\($0)" }.joined(separator: " ")
        let chunks = chunker.chunks(document: TestFixtures.document(text: words), itemID: UUID())
        for (earlier, later) in zip(chunks, chunks.dropFirst()) {
            #expect(later.characterStart < earlier.characterEnd)
        }
    }

    @Test("Offsets stay correct after multi-byte characters")
    internal func handlesMultiByteCharacters() {
        // Character offsets must count Characters, not UTF-8 bytes.
        let text = "简体中文 " + (1...600).map { "word\($0)" }.joined(separator: " ")
        let chunks = chunker.chunks(document: TestFixtures.document(text: text), itemID: UUID())
        let characters = Array(text)
        for chunk in chunks {
            #expect(String(characters[chunk.characterStart..<chunk.characterEnd]) == chunk.text)
        }
    }

    @Test("Each chunk carries a stable identifier and the parent item")
    internal func attributesChunksToTheirItem() {
        let itemID = UUID()
        let chunks = chunker.chunks(document: TestFixtures.document(text: "One two three."), itemID: itemID)
        #expect(chunks.allSatisfy { $0.itemID == itemID })
        #expect(Set(chunks.map(\.id)).count == chunks.count)
    }
}
