import Foundation

/// Traverses an authorized root without requesting or performing mutations.
internal struct ReadOnlyFileScanner: Sendable {
    private let exclusionPolicy = ExclusionPolicy()
    private let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .isHiddenKey,
        .isReadableKey,
        .fileSizeKey,
        .creationDateKey,
        .contentModificationDateKey,
        .contentTypeKey
    ]

    /// Builds a metadata snapshot of one selected directory.
    /// - Parameters:
    ///   - root: Authorized root record.
    ///   - rootURL: Bookmark-resolved security-scoped URL.
    /// - Returns: Included paths and transparent exclusion records.
    /// - Throws: A local indexing error when traversal cannot start.
    internal func scan(root: AuthorizedRoot, at rootURL: URL) throws -> ScanSnapshot {
        let fileManager = FileManager.default
        var exclusions: [ExcludedPath] = []
        let rootValues = try rootURL.resourceValues(forKeys: resourceKeys)
        let rootItem = makeItem(root: root, rootURL: rootURL, url: rootURL, values: rootValues)
        var files = [
            ScannedFile(
                item: rootItem,
                isExtractable: FileKindResolver.isExtractable(url: rootURL, kind: rootItem.kind)
            )
        ]
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, _ in
                exclusions.append(ExcludedPath(url: url, reason: .unreadable))
                return true
            }
        ) else {
            throw LocalAssistantError.indexing(rootURL.path)
        }

        for case let url as URL in enumerator {
            try Task.checkCancellation()
            do {
                let values = try url.resourceValues(forKeys: resourceKeys)
                if let reason = exclusionPolicy.reason(for: url, values: values) {
                    exclusions.append(ExcludedPath(url: url, reason: reason))
                    if values.isDirectory == true { enumerator.skipDescendants() }
                    continue
                }
                let item = makeItem(root: root, rootURL: rootURL, url: url, values: values)
                files.append(
                    ScannedFile(
                        item: item,
                        isExtractable: FileKindResolver.isExtractable(url: url, kind: item.kind)
                    )
                )
            } catch {
                exclusions.append(ExcludedPath(url: url, reason: .unreadable))
                enumerator.skipDescendants()
            }
        }
        return ScanSnapshot(files: files, exclusions: exclusions)
    }

    /// Converts file-system resource values into index metadata.
    /// - Parameters:
    ///   - root: Authorized root record.
    ///   - rootURL: Resolved root URL.
    ///   - url: Candidate descendant URL.
    ///   - values: Already-fetched resource values.
    /// - Returns: Stable indexed item metadata.
    private func makeItem(
        root: AuthorizedRoot,
        rootURL: URL,
        url: URL,
        values: URLResourceValues
    ) -> IndexedItem {
        let standardizedURL = url.standardizedFileURL
        let kind = FileKindResolver.kind(for: standardizedURL, values: values)
        let relativeComponents = standardizedURL.pathComponents.dropFirst(rootURL.standardizedFileURL.pathComponents.count)
        let relativePath = relativeComponents.joined(separator: FileConstants.pathSeparator)
        let parentID = standardizedURL == rootURL.standardizedFileURL
            ? nil
            : StableIdentifier.uuid(for: standardizedURL.deletingLastPathComponent().path)
        let byteCount = Int64(values.fileSize ?? 0)
        return IndexedItem(
            id: StableIdentifier.uuid(for: standardizedURL.path),
            rootID: root.id,
            parentID: parentID,
            url: standardizedURL,
            relativePath: relativePath,
            displayName: standardizedURL.lastPathComponent,
            kind: kind,
            contentType: values.contentType?.identifier,
            byteCount: byteCount,
            createdAt: values.creationDate,
            modifiedAt: values.contentModificationDate,
            contentHash: nil,
            metadataHash: FileHasher.metadataHash(
                path: standardizedURL.path,
                byteCount: byteCount,
                modifiedAt: values.contentModificationDate,
                kind: kind
            ),
            isDirectory: values.isDirectory == true,
            isHidden: values.isHidden == true
        )
    }
}
