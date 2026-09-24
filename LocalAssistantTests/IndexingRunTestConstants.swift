import Foundation

/// Stable fixture values for end-to-end indexing run tests.
internal enum IndexingRunTestConstants {
    internal static let rootDirectoryPrefix = "indexing-run-root-"
    internal static let databaseExtension = "sqlite3"
    internal static let firstNoteName = "Alpha.txt"
    internal static let secondNoteName = "Beta.txt"
    internal static let firstNoteText = "Alpha covers the local retrieval plan."
    internal static let secondNoteText = "Beta covers the offline embedding plan."
    internal static let revisedNoteText = "Alpha now covers the revised local retrieval plan."
    internal static let embeddingComponent: Float = 0.5
    internal static let extractionFailureDetail = "embedding refused this passage"
    internal static let missingModelDetail = "model file absent"
}
