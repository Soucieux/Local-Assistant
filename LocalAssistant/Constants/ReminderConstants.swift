import Foundation

/// Non-visible reminder, connector-spool, retrieval, and routing constants.
internal enum ReminderConstants {
    internal enum Identity {
        internal static let localAssistantOwner = "local-assistant"
        internal static let reminderSkill = "cloudbase-reminders"
        internal static let agentSkill = "openclaw-agent"
        internal static let calendarPolicyNever = "never"
        internal static let calendarPolicyOpenClawDefault = "openclaw-default"
        internal static let connectorDirectory = "Connector"
        internal static let connectorSetupBundleIdentifier =
            "com.soucieux.LocalAssistant.OpenClawConnectorSetup"
        internal static let connectorSetupAppFilename = "OpenClaw Connector.app"
        internal static let applicationsDirectory = "/Applications"
        internal static let mountedVolumesDirectory = "/Volumes"
        internal static let requestDirectory = "Requests"
        internal static let processingDirectory = "Processing"
        internal static let responseDirectory = "Responses"
        internal static let statusFilename = "status.json"
        internal static let scheduleFilename = "schedule.json"
        internal static let scheduledSnapshotFilename = "scheduled-reminder-snapshot.json"
        internal static let jsonSuffix = ".json"
        internal static let temporarySuffix = ".tmp"
    }

    /// Keys of the app-owned schedule document the connector reads.
    internal enum ScheduleKey {
        internal static let schemaVersion = "schemaVersion"
        internal static let enabled = "enabled"
        internal static let intervalMinutes = "intervalMinutes"
    }

    internal enum Preferences {
        internal static let connectorEnabledKey = "reminder-connector-enabled"
        internal static let syncIntervalMinutesKey = "reminder-sync-interval-minutes"
        internal static let openClawContextIDKey = "openclaw-context-id"
        internal static let defaultSyncIntervalMinutes = 240
        internal static let allowedSyncIntervalMinutes = [120, 240, 480]
    }

    internal enum Connector {
        internal static let schemaVersion = 1
        internal static let runtimeContractVersion = 3
        internal static let responsePollNanoseconds: UInt64 = 250_000_000
        internal static let responseTimeoutSeconds: TimeInterval = 45
        internal static let healthPollNanoseconds: UInt64 = 1_000_000_000
        internal static let maximumFutureClockSkewSeconds: TimeInterval = 5
        internal static let maximumStatusErrorCharacters = 1_000
        internal static let maximumResponseBytes = 2_097_152
        internal static let maximumRequestBytes = 65_536
        internal static let readChunkBytes = 65_536
        internal static let completedStatus = "completed"
        internal static let inputRequiredStatus = "input-required"
        internal static let maximumReminderTextCharacters = 2_000
        internal static let maximumOptionalFieldCharacters = 1_000
        internal static let maximumAgentMessageCharacters = 8_000
        internal static let authorizationExplicitOpenClaw = "explicit-openclaw"
        internal static let authorizationConfirmedReminderMutation =
            "confirmed-reminder-mutation"

        /// Exact `ERROR_INVALID_REQUEST` text published by the connector runtime.
        /// Source of truth: `OpenClawConnector/src/local_assistant_connector/constants.py`.
        internal static let invalidRequestErrorDetail = "connector request is invalid"
    }

    internal enum Retrieval {
        internal static let defaultLimit = 12
        internal static let mutationCandidateLimit = 3
        internal static let maximumKeywordCandidates = 40
        internal static let maximumVectorCandidates = 40
        internal static let exactIdentifierScore = 1.0
        internal static let keywordScore = 0.72
        internal static let semanticScore = 0.60
        internal static let temporalScore = 0.20
        internal static let reciprocalRankOffset = 60.0
        internal static let minimumDisplayScore = 0.05
        internal static let queryTokenMinimumLength = 2
        internal static let ambiguityScoreGap = 0.12
    }

    internal enum Pattern {
        internal static let calendarDate = #"^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$"#
        internal static let wallClockTime = #"^([01]\d|2[0-3]):[0-5]\d$"#
        internal static let embeddedCalendarDate = #"\b\d{4}-\d{2}-\d{2}\b"#
    }

    internal enum ContentHash {
        internal static let absentField = "-1:"
        internal static let lengthSeparator = ":"
        internal static let fieldSeparator = "|"
    }

    internal enum DateText {
        internal static let calendarDateFormat = "yyyy-MM-dd"
        internal static let posixLocaleIdentifier = "en_US_POSIX"
        internal static let today = "today"
        internal static let tomorrow = "tomorrow"
        internal static let overdue = "overdue"
    }

    internal enum Presentation {
        internal static let untaggedGroupIdentifier = "__untagged__"
        internal static let tagGroupPrefix = "tag:"
    }

    internal enum Routing {
        internal static let reminderToken = "REMINDER_ACTION"
        internal static let operationList = "list"
        internal static let operationGet = "get"
        internal static let operationCreate = "create"
        internal static let operationAdd = "add"
        internal static let operationUpdate = "update"
        internal static let operationComplete = "complete"
        internal static let operationRemove = "remove"
        internal static let operationDelete = "delete"
        internal static let operationChat = "chat"
        internal static let openClawCombinedToken = "openclaw"
        internal static let openClawFirstToken = "open"
        internal static let openClawSecondToken = "claw"
        internal static let explicitReminderTerms: Set<String> = [
            "reminder", "reminders", "remind", "todo", "todos", "deadline", "deadlines"
        ]
        internal static let reminderReadTerms: Set<String> = [
            "show", "list", "what", "which", "when", "anything", "due", "overdue", "upcoming"
        ]
        internal static let reminderCreateTerms: Set<String> = [
            "add", "create", "remind", "schedule"
        ]
        internal static let reminderUpdateTerms: Set<String> = [
            "update", "change", "move", "reschedule", "rename", "complete", "completed", "done"
        ]
        internal static let reminderRemoveTerms: Set<String> = [
            "remove", "delete", "cancel"
        ]
        internal static let reminderTemporalTerms: Set<String> = [
            "today", "tomorrow", "overdue", "monday", "tuesday", "wednesday",
            "thursday", "friday", "saturday", "sunday"
        ]
        internal static let reminderQueryFillerTerms: Set<String> = [
            "show", "list", "what", "which", "when", "anything", "all", "my", "me",
            "i", "do", "have", "are", "there", "please", "the", "reminder", "reminders",
            "due", "upcoming"
        ]
        internal static let needToDoSequence = ["need", "to", "do"]
        internal static let infinitiveToken = "to"
        internal static let reminderDefinitionPrefix = ["what", "is"]
        internal static let reminderDefinitionMaximumTokenCount = 5
        internal static let confirmationAffirmativePhrases: Set<String> = [
            "yes", "yes please", "confirm", "continue", "please continue", "proceed",
            "please proceed", "go ahead", "send it", "do it", "ok", "okay", "sure"
        ]
        internal static let confirmationDeclinePhrases: Set<String> = [
            "no", "decline", "cancel", "stop", "never mind", "nevermind",
            "do not continue", "do not send it", "don t continue", "don t send it"
        ]
    }
}
