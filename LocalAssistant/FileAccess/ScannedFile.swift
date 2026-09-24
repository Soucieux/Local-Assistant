import Foundation

/// Read-only metadata collected from an authorized root.
internal struct ScannedFile: Hashable, Sendable {
    internal let item: IndexedItem
    internal let isExtractable: Bool

    /// Whether this item needs a searchable local content record.
    internal var requiresContentIndexing: Bool {
        isExtractable || item.kind == .folder
    }
}

/// Reason a path was deliberately excluded from indexing.
internal enum ExclusionReason: String, Sendable {
    case hidden
    case systemDirectory
    case credentialMaterial
    case symbolicLink
    case unreadable
}

/// Excluded path recorded for transparent progress reporting.
internal struct ExcludedPath: Hashable, Sendable {
    internal let url: URL
    internal let reason: ExclusionReason
}

/// Complete snapshot from one read-only directory traversal.
internal struct ScanSnapshot: Sendable {
    internal let files: [ScannedFile]
    internal let exclusions: [ExcludedPath]
}
