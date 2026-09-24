import Foundation

@testable import LocalAssistant

/// Builders for the value types the tests need, keeping each test to its own subject.
internal enum TestFixtures {
    /// Creates one indexed item with only the fields a test cares about.
    /// - Parameters:
    ///   - name: Visible file or folder name.
    ///   - path: Absolute path on disk.
    ///   - relativePath: Optional root-relative path.
    ///   - id: Stable item identifier.
    ///   - rootID: Authorized root identifier.
    ///   - parentID: Optional indexed parent folder identifier.
    ///   - isDirectory: Whether the item represents a folder.
    ///   - kind: Stored item category.
    /// - Returns: An indexed item suitable for formatter and retrieval tests.
    internal static func item(
        name: String,
        path: String? = nil,
        relativePath: String? = nil,
        id: UUID = UUID(),
        rootID: UUID = UUID(),
        parentID: UUID? = nil,
        isDirectory: Bool = false,
        kind: IndexedItemKind = .document
    ) -> IndexedItem {
        let resolvedPath = path ?? "/Users/example/Documents/\(name)"
        return IndexedItem(
            id: id,
            rootID: rootID,
            parentID: parentID,
            url: URL(fileURLWithPath: resolvedPath),
            relativePath: relativePath ?? name,
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
    internal static func result(_ item: IndexedItem) -> SearchResult {
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
    internal static func document(text: String) -> ExtractedDocument {
        ExtractedDocument(
            segments: [ExtractedSegment(text: text, pageNumber: nil, sectionName: nil)]
        )
    }
}
