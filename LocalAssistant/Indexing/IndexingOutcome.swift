import Foundation

/// Summary of one completed read-only indexing run.
struct IndexingOutcome: Sendable {
    let indexedItems: Int
    let unchangedItems: Int
    let skippedItems: Int
    let excludedItems: Int
    let completedAt: Date
}
