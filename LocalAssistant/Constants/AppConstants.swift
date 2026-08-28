import Foundation

/// Shared non-visible constants used throughout the application.
enum AppConstants {
    enum Text {
        static let empty = ""
        static let space = " "
        static let newline = "\n"
        static let ellipsis = "…"
    }

    enum Identity {
        static let appName = "Local Assistant"
        static let mainWindowIdentifier = "local-assistant-main"
        static let applicationSupportDirectory = "LocalAssistant"
        static let indexDirectory = "Index"
        static let modelsDirectory = "Models"
        static let databaseFilename = "assistant.sqlite3"
        static let modelAssetManifestFilename = "model-assets.sha256"
        static let folderMonitorQueueLabel = "com.soucieux.LocalAssistant.folder-monitoring"
        static let bundleShortVersionKey = "CFBundleShortVersionString"
        static let bundleVersionKey = "CFBundleVersion"
        static let fallbackVersion = "Unknown"
    }

    enum Chat {
        static let historyLimit = 100
        static let retrievalCandidateLimit = 40
        static let evidenceLimit = 10
        static let maximumOutputTokens = 1_024
        static let contextTokenLimit = 8_192
    }

    enum Preferences {
        static let voiceInputModeKey = "voice-input-mode"
    }

    enum Indexing {
        static let targetChunkWordCount = 550
        static let overlapWordCount = 80
        static let maximumTextFileBytes: Int64 = 20 * 1_024 * 1_024
        static let maximumArchiveEntryBytes = 20 * 1_024 * 1_024
        static let maximumOCRPixelCount = 30_000_000
        static let embeddingDimensions = 1_024
        static let activityRetentionDays = 30
        static let activityOrderingNudgeSeconds = 1_000_000.0
        static let changeDebounceNanoseconds: UInt64 = 2_000_000_000
        static let monitorCoalescingSeconds: CFTimeInterval = 0.5
    }

    enum Storage {
        static let ownerOnlyDirectoryPermissions: Int16 = 0o700
        static let ownerOnlyFilePermissions: Int16 = 0o600
    }
}
