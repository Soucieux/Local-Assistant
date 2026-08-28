import Foundation

/// Stable fixture values for end-to-end indexing run tests.
enum IndexingRunTestConstants {
    static let rootDirectoryPrefix = "indexing-run-root-"
    static let databaseExtension = "sqlite3"
    static let firstNoteName = "Alpha.txt"
    static let secondNoteName = "Beta.txt"
    static let firstNoteText = "Alpha covers the local retrieval plan."
    static let secondNoteText = "Beta covers the offline embedding plan."
    static let revisedNoteText = "Alpha now covers the revised local retrieval plan."
    static let embeddingComponent: Float = 0.5
    static let extractionFailureDetail = "embedding refused this passage"
    static let missingModelDetail = "model file absent"
}
