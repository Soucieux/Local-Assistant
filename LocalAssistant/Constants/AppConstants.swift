import Foundation

/// Shared non-visible constants used throughout the application.
internal enum AppConstants {
    internal enum Text {
        internal static let empty = ""
        internal static let space = " "
        internal static let newline = "\n"
        internal static let ellipsis = "…"
        internal static let bullet = "•"
    }

    internal enum Identity {
        internal static let appName = "Local Assistant"
        internal static let mainWindowIdentifier = "local-assistant-main"
        internal static let applicationSupportDirectory = "LocalAssistant"
        internal static let indexDirectory = "Index"
        internal static let modelsDirectory = "Models"
        internal static let databaseFilename = "assistant.sqlite3"
        internal static let modelAssetManifestFilename = "model-assets.sha256"
        internal static let folderMonitorQueueLabel = "com.soucieux.LocalAssistant.folder-monitoring"
        internal static let bundleShortVersionKey = "CFBundleShortVersionString"
        internal static let bundleVersionKey = "CFBundleVersion"
        internal static let fallbackVersion = "Unknown"
    }

    internal enum Chat {
        internal static let historyLimit = 100
        internal static let retrievalCandidateLimit = 40
        internal static let evidenceLimit = 10
        internal static let maximumOutputTokens = 1_024
        internal static let contextTokenLimit = 8_192
    }

    internal enum Preferences {
        internal static let voiceInputModeKey = "voice-input-mode"
    }

    internal enum Indexing {
        internal static let targetChunkWordCount = 550
        internal static let overlapWordCount = 80
        internal static let maximumTextFileBytes: Int64 = 20 * 1_024 * 1_024
        internal static let maximumArchiveEntryBytes = 20 * 1_024 * 1_024
        internal static let maximumOCRPixelCount = 30_000_000
        internal static let embeddingDimensions = 1_024
        internal static let activityRetentionDays = 30
        internal static let activityOrderingNudgesPerSecond = 1_000_000.0
        internal static let changeDebounceNanoseconds: UInt64 = 2_000_000_000
        internal static let monitorCoalescingSeconds: CFTimeInterval = 0.5
    }

    internal enum Storage {
        internal static let ownerOnlyDirectoryPermissions: Int16 = 0o700
        internal static let ownerOnlyFilePermissions: Int16 = 0o600
    }
}
