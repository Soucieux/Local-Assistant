import Foundation

/// Read-only metadata collected from an authorized root.
struct ScannedFile: Hashable, Sendable {
    let item: IndexedItem
    let isExtractable: Bool

    /// Whether this item needs a searchable local content record.
    var requiresContentIndexing: Bool {
        isExtractable || item.kind == .folder
    }
}

/// Reason a path was deliberately excluded from indexing.
enum ExclusionReason: String, Sendable {
    case hidden
    case systemDirectory
    case credentialMaterial
    case symbolicLink
    case unreadable
}

/// Excluded path recorded for transparent progress reporting.
struct ExcludedPath: Hashable, Sendable {
    let url: URL
    let reason: ExclusionReason
}

/// Complete snapshot from one read-only directory traversal.
struct ScanSnapshot: Sendable {
    let files: [ScannedFile]
    let exclusions: [ExcludedPath]
}
