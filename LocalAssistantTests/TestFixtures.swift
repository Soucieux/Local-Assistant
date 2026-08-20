import Foundation

@testable import LocalAssistant

/// Builders for the value types the tests need, keeping each test to its own subject.
enum TestFixtures {
    /// Creates one indexed item with only the fields a test cares about.
    /// - Parameters:
    ///   - name: Visible file or folder name.
    ///   - path: Absolute path on disk.
    ///   - isDirectory: Whether the item represents a folder.
    ///   - kind: Stored item category.
    /// - Returns: An indexed item suitable for formatter and retrieval tests.
    static func item(
        name: String,
        path: String? = nil,
        isDirectory: Bool = false,
        kind: IndexedItemKind = .document
    ) -> IndexedItem {
        let resolvedPath = path ?? "/Users/example/Documents/\(name)"
        return IndexedItem(
            id: UUID(),
            rootID: UUID(),
            parentID: nil,
            url: URL(fileURLWithPath: resolvedPath),
            relativePath: name,
            displayName: name,
            kind: kind,
            contentType: nil,
            byteCount: 1024,
            createdAt: nil,
            modifiedAt: nil,
            contentHash: nil,
            metadataHash: "hash",
            isDirectory: isDirectory,
            isHidden: false
        )
    }

    /// Wraps an indexed item as a neutral-scored search result.
    /// - Parameter item: Item to present as a card.
    /// - Returns: A search result carrying no ranking signal.
    static func result(_ item: IndexedItem) -> SearchResult {
        SearchResult(
            id: item.id,
            item: item,
            score: .zero,
            confidence: .medium,
            explanation: "",
            citations: []
        )
    }

    /// Builds a single-segment extracted document.
    /// - Parameter text: Segment body.
    /// - Returns: A document with one unnamed section.
    static func document(text: String) -> ExtractedDocument {
        ExtractedDocument(
            segments: [ExtractedSegment(text: text, pageNumber: nil, sectionName: nil)]
        )
    }
}
