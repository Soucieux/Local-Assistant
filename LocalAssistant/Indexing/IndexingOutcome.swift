/// Summary of one completed read-only indexing run.
internal struct IndexingOutcome: Sendable {
    internal let newItems: Int
    internal let removedItems: Int
}
