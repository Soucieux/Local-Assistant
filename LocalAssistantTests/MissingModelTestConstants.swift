import Foundation

/// Stable fixture values for the missing-model message tests.
internal enum MissingModelTestConstants {
    internal static let settingsLocation = "Settings › Models"
    internal static let request = "What did I write about the budget?"
    internal static let libraryPath = "/Users/example/Documents/AI-Models"
    internal static let chatModelURL = URL(fileURLWithPath: "/Users/example/Documents/AI-Models/gguf/chat.gguf")
    internal static let embeddingModelURL = URL(
        fileURLWithPath: "/Users/example/Documents/AI-Models/gguf/embedding.gguf"
    )
    internal static let speechModelURL = URL(
        fileURLWithPath: "/Users/example/Documents/AI-Models/whisper/speech",
        isDirectory: true
    )

    /// Wording the earlier messages used, which described an offline package and bundled models.
    internal static let retiredWording = [
        "offline setup",
        "staging Mac",
        "transfer the verified package",
        "bundled",
        "not installed",
        "or verified"
    ]
}
