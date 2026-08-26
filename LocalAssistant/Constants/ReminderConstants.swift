import Foundation

/// Non-visible reminder, connector-spool, retrieval, and routing constants.
enum ReminderConstants {
    enum Identity {
        static let localAssistantOwner = "local-assistant"
        static let reminderSkill = "cloudbase-reminders"
        static let agentSkill = "openclaw-agent"
        static let calendarPolicyNever = "never"
        static let calendarPolicyOpenClawDefault = "openclaw-default"
        static let connectorDirectory = "Connector"
        static let connectorSetupBundleIdentifier =
            "com.soucieux.LocalAssistant.OpenClawConnectorSetup"
        static let connectorSetupAppFilename = "OpenClaw Connector.app"
        static let applicationsDirectory = "/Applications"
        static let mountedVolumesDirectory = "/Volumes"
        static let requestDirectory = "Requests"
        static let processingDirectory = "Processing"
        static let responseDirectory = "Responses"
        static let statusFilename = "status.json"
        static let scheduleFilename = "schedule.json"
        static let scheduledSnapshotFilename = "scheduled-reminder-snapshot.json"
        static let jsonExtension = "json"
        static let temporarySuffix = ".tmp"
    }

    enum Preferences {
        static let connectorEnabledKey = "reminder-connector-enabled"
        static let syncIntervalMinutesKey = "reminder-sync-interval-minutes"
        static let openClawContextIDKey = "openclaw-context-id"
        static let defaultSyncIntervalMinutes = 240
        static let allowedSyncIntervalMinutes = [120, 240, 480]
    }

    enum Connector {
        static let schemaVersion = 1
        static let responsePollNanoseconds: UInt64 = 250_000_000
        static let responseTimeoutSeconds: TimeInterval = 45
        static let healthPollNanoseconds: UInt64 = 1_000_000_000
        static let maximumFutureClockSkewSeconds: TimeInterval = 5
        static let maximumStatusErrorCharacters = 1_000
        static let maximumResponseBytes = 2_097_152
        static let maximumRequestBytes = 65_536
        static let completedStatus = "completed"
        static let maximumReminderTextCharacters = 2_000
        static let maximumOptionalFieldCharacters = 1_000
        static let maximumAgentMessageCharacters = 8_000
    }

    enum Retrieval {
        static let defaultLimit = 12
        static let maximumKeywordCandidates = 40
        static let maximumVectorCandidates = 40
        static let exactIdentifierScore = 1.0
        static let keywordScore = 0.72
        static let semanticScore = 0.60
        static let temporalScore = 0.20
        static let reciprocalRankOffset = 60.0
        static let minimumDisplayScore = 0.05
        static let queryTokenMinimumLength = 2
        static let ambiguityScoreGap = 0.12
    }

    enum DateText {
        static let calendarDateFormat = "yyyy-MM-dd"
        static let today = "today"
        static let tomorrow = "tomorrow"
        static let overdue = "overdue"
    }

    enum Routing {
        static let reminderToken = "REMINDER_ACTION"
        static let operationList = "list"
        static let operationGet = "get"
        static let operationChat = "chat"
        static let openClawCombinedToken = "openclaw"
        static let openClawFirstToken = "open"
        static let openClawSecondToken = "claw"
    }
}
