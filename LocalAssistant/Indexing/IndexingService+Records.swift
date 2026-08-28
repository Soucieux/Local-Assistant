import Foundation

/// Builds the durable records and progress values one indexing run publishes.
extension IndexingService {
    /// Copies fresh scan metadata while retaining the last successfully indexed content hash.
    /// - Parameters:
    ///   - item: Metadata observed during the current read-only scan.
    ///   - contentHash: Content hash from the previously completed extraction, when available.
    /// - Returns: Metadata row safe to publish before expensive content processing begins.
    internal func metadataItem(
        _ item: IndexedItem,
        preservingContentHash contentHash: String?
    ) -> IndexedItem {
        IndexedItem(
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
            contentHash: contentHash,
            metadataHash: item.metadataHash,
            isDirectory: item.isDirectory,
            isHidden: item.isHidden
        )
    }

    /// Computes a content hash for a changed file or synthesized folder context.
    /// - Parameters:
    ///   - item: Newly scanned metadata.
    ///   - synthesizedText: Optional local-only context generated for a folder.
    /// - Returns: Copy containing a streaming SHA-256 hash when applicable.
    /// - Throws: A local extraction error when a readable file cannot be hashed.
    internal func itemWithContentHash(
        _ item: IndexedItem,
        synthesizedText: String?
    ) throws -> IndexedItem {
        let digest: String? = if let synthesizedText {
            FileHasher.sha256(of: synthesizedText)
        } else if item.isDirectory {
            nil
        } else {
            try FileHasher.sha256(of: item.url)
        }
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

    /// Builds a bounded progress snapshot.
    /// - Parameters:
    ///   - run: Durable run summary supplying identity and counts.
    ///   - state: Active pipeline stage.
    ///   - path: Optional current path.
    ///   - itemState: Optional file-level state for the current path.
    ///   - processed: Completed item count.
    ///   - total: Total item count.
    /// - Returns: Progress value safe for presentation.
    internal func makeProgress(
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
    internal func activityItem(
        item: IndexedItem,
        runID: UUID,
        state: IndexingItemState,
        detail: String? = nil
    ) -> IndexingItemRecord {
        activityItem(
            runID: runID,
            displayName: item.displayName,
            relativePath: visibleRelativePath(for: item),
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
    internal func activityItem(
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
    internal func relativePath(for url: URL, rootURL: URL) -> String {
        let rootComponents = rootURL.standardizedFileURL.pathComponents
        let itemComponents = url.standardizedFileURL.pathComponents
        guard itemComponents.starts(with: rootComponents) else {
            return url.lastPathComponent
        }
        return itemComponents.dropFirst(rootComponents.count).joined(
            separator: FileConstants.pathSeparator
        )
    }

    /// Returns a non-empty root-relative label for progress and activity presentation.
    /// - Parameter item: Indexed file or folder being presented.
    /// - Returns: Relative path, or the root folder name for the authorized root itself.
    internal func visibleRelativePath(for item: IndexedItem) -> String {
        item.relativePath.isEmpty ? item.displayName : item.relativePath
    }
}
