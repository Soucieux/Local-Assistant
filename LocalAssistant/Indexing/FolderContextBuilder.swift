import Foundation

/// Builds bounded semantic context for folders without reading or changing their contents.
internal struct FolderContextBuilder: Sendable {
    /// Creates one synthetic searchable passage for every scanned folder.
    /// - Parameter files: Current read-only scan, including the authorized root.
    /// - Returns: Folder passages keyed by their indexed item identifiers.
    internal func chunks(in files: [ScannedFile]) -> [UUID: ContentChunk] {
        var childrenByParentID: [UUID: [IndexedItem]] = [:]
        for scannedFile in files {
            guard let parentID = scannedFile.item.parentID else { continue }
            childrenByParentID[parentID, default: []].append(scannedFile.item)
        }

        var chunks: [UUID: ContentChunk] = [:]
        for scannedFile in files where scannedFile.item.kind == .folder {
            let item = scannedFile.item
            let childNames = (childrenByParentID[item.id] ?? [])
                .map(\.displayName)
                .sorted { left, right in
                    left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                }
            let text = contextText(item: item, childNames: childNames)
            chunks[item.id] = ContentChunk(
                id: StableIdentifier.uuid(
                    for: [
                        item.id.uuidString,
                        String(FileConstants.FolderIndex.version),
                        text
                    ].joined(separator: ExtractionConstants.indexingSeparator)
                ),
                itemID: item.id,
                ordinal: 0,
                text: text,
                characterStart: 0,
                characterEnd: text.count,
                pageNumber: nil,
                sectionName: FileConstants.FolderIndex.sectionName,
                embedding: nil
            )
        }
        return chunks
    }

    /// Produces a bounded natural-language representation of one folder and its direct children.
    /// - Parameters:
    ///   - item: Folder metadata from the current scan.
    ///   - childNames: Names of direct files and folders inside the folder.
    /// - Returns: Local-only text suitable for keyword and semantic indexing.
    private func contextText(item: IndexedItem, childNames: [String]) -> String {
        let visiblePath = item.relativePath.isEmpty ? item.displayName : item.relativePath
        var lines = [
            FileConstants.FolderIndex.titlePrefix + item.displayName,
            FileConstants.FolderIndex.pathPrefix + visiblePath
        ]
        let boundedChildren = childNames.prefix(FileConstants.FolderIndex.maximumChildNames)
        if boundedChildren.isEmpty == false {
            lines.append(
                FileConstants.FolderIndex.contentsPrefix
                    + boundedChildren.joined(separator: FileConstants.FolderIndex.childSeparator)
            )
        }
        return lines.joined(separator: AppConstants.Text.newline)
    }
}
