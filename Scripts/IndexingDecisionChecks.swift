import Foundation

/// Stable values used by the standalone indexing-decision harness.
private enum CheckValues {
    static let contentHash = "content-hash"
    static let unreadableRoot = "/Authorized/Unreadable"
    static let unreadableChild = "/Authorized/Unreadable/Child/file.txt"
    static let unrelatedPath = "/Authorized/Available/file.txt"
    static let completionFailure = "Progress fraction was not bounded correctly."
    static let retryFailure = "Failed indexable content was not scheduled for retry."
    static let unchangedFailure = "Successfully indexed content was not left unchanged."
    static let metadataFailure = "Changed metadata was incorrectly treated as unchanged."
    static let subtreeFailure = "Unreadable subtree containment was not preserved."
    static let success = "Indexing decision checks passed."
}

/// Standalone deterministic checks for pure incremental-indexing decisions.
@main
internal struct IndexingDecisionChecks {
    /// Executes every focused decision check and exits nonzero on a failed precondition.
    internal static func main() {
        precondition(
            IndexingDecisionPolicy.progressFraction(processed: -1, total: 10) == 0
                && IndexingDecisionPolicy.progressFraction(processed: 5, total: 10) == 0.5
                && IndexingDecisionPolicy.progressFraction(processed: 11, total: 10) == 1,
            CheckValues.completionFailure
        )
        precondition(
            IndexingDecisionPolicy.itemIsUnchanged(
                metadataMatches: true,
                requiresContentIndexing: true,
                previousContentHash: nil
            ) == false,
            CheckValues.retryFailure
        )
        precondition(
            IndexingDecisionPolicy.itemIsUnchanged(
                metadataMatches: true,
                requiresContentIndexing: true,
                previousContentHash: CheckValues.contentHash
            ),
            CheckValues.unchangedFailure
        )
        precondition(
            IndexingDecisionPolicy.itemIsUnchanged(
                metadataMatches: false,
                requiresContentIndexing: false,
                previousContentHash: nil
            ) == false,
            CheckValues.metadataFailure
        )
        precondition(
            IndexingDecisionPolicy.pathIsAtOrInside(
                CheckValues.unreadableChild,
                roots: [CheckValues.unreadableRoot]
            )
                && IndexingDecisionPolicy.pathIsAtOrInside(
                    CheckValues.unrelatedPath,
                    roots: [CheckValues.unreadableRoot]
                ) == false,
            CheckValues.subtreeFailure
        )
        print(CheckValues.success)
    }
}
