import Foundation

/// Shared non-visible constants used throughout the application.
enum AppConstants {
    enum Text {
        static let empty = ""
        static let space = " "
        static let spaceCharacter: Character = " "
        static let newline = "\n"
        static let tabCharacter: Character = "\t"
        static let ellipsis = "…"
        static let markdownDashListPrefix = "- "
        static let markdownAsteriskListPrefix = "* "
        static let visibleBulletPrefix = "• "
        static let markdownListPrefixLength = 2
    }

    enum Identity {
        static let appName = "Local Assistant"
        static let mainWindowIdentifier = "local-assistant-main"
        static let applicationSupportDirectory = "LocalAssistant"
        static let indexDirectory = "Index"
        static let modelsDirectory = "Models"
        static let databaseFilename = "assistant.sqlite3"
        static let modelAssetManifestFilename = "model-assets.sha256"
        static let bundleShortVersionKey = "CFBundleShortVersionString"
        static let fallbackVersion = "0.9"
    }

    enum Chat {
        static let historyLimit = 100
        static let retrievalCandidateLimit = 40
        static let evidenceLimit = 10
        static let maximumOutputTokens = 1_024
        static let contextTokenLimit = 8_192
    }

    enum Indexing {
        static let targetChunkWordCount = 550
        static let overlapWordCount = 80
        static let maximumTextFileBytes: Int64 = 20 * 1_024 * 1_024
        static let maximumOCRPixelCount = 30_000_000
        static let embeddingDimensions = 1_024
        static let completedFraction = 1.0
    }

    enum Storage {
        static let ownerOnlyDirectoryPermissions: Int16 = 0o700
        static let ownerOnlyFilePermissions: Int16 = 0o600
    }
}
