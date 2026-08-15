/// Summary of one completed read-only indexing run.
struct IndexingOutcome: Sendable {
    let newItems: Int
    let removedItems: Int
}
