import Foundation

/// Stable fixture values for the model-folder tests.
internal enum ModelStoreTestConstants {
    internal static let libraryPath = "/Users/example/Documents/AI-Models"
    internal static let unreadableBookmark = Data([1])
    internal static let corruptModelContents = Data("not a model".utf8)
}
