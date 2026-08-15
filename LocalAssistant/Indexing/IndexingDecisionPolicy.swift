import Foundation

/// Pure indexing decisions shared by the live pipeline and focused native checks.
enum IndexingDecisionPolicy {
    /// Returns whether a scanned item can safely skip extraction and embedding.
    /// - Parameters:
    ///   - metadataMatches: Whether the current and retained metadata hashes match.
    ///   - isExtractable: Whether the file should contain locally extracted text.
    ///   - previousContentHash: Content hash retained by the earlier successful run.
    /// - Returns: `true` when no changed content or failed extraction needs processing.
    internal static func itemIsUnchanged(
        metadataMatches: Bool,
        isExtractable: Bool,
        previousContentHash: String?
    ) -> Bool {
        metadataMatches
            && (isExtractable == false || previousContentHash != nil)
    }

    /// Returns whether a path belongs to a temporarily unreadable scan subtree.
    /// - Parameters:
    ///   - path: Existing indexed absolute path.
    ///   - roots: Unreadable paths reported by the current read-only scan.
    /// - Returns: `true` when the path equals or descends from an unreadable path.
    internal static func pathIsAtOrInside(_ path: String, roots: Set<String>) -> Bool {
        roots.contains { root in
            path == root || path.hasPrefix(root + FileConstants.pathSeparator)
        }
    }

    /// Returns a bounded completion fraction for determinate progress.
    /// - Parameters:
    ///   - processed: Completed work-item count.
    ///   - total: Total work-item count.
    /// - Returns: A value from zero through one, or zero when the total is unknown.
    internal static func progressFraction(processed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(processed) / Double(total)))
    }
}
