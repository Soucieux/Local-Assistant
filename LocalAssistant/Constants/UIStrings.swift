import Foundation

/// User-visible copy for the focused native interface.
enum UIStrings {
    static let appName = "Local Assistant"
    static let about = "About Local Assistant"
    static let settings = "Settings"
    static let activity = "Activity"
    static let history = "History"
    static let assistant = "Assistant"
    static let backToAssistant = "Back to Assistant"
    static let startupTitle = "Starting Local Assistant"
    static let startupDetail =
        "Opening the private database and checking local models. Controls will be ready when this finishes."
    static let commandPrompt = "WHAT SHOULD I FIND?"
    static let commandLocalStatus = "CORE OFFLINE / READY"
    static let commandIndexingStatus = "CORE OFFLINE / INDEXING"
    static let commandConnectorStatus = "CORE OFFLINE / CONNECTOR ENABLED"
    static let commandListening = "LISTENING"
    static let commandProcessing = "PROCESSING REQUEST"
    static let commandResponse = "RESPONSE / COMPLETE"
    static let commandClickInputHelp = "CLICK TO SPEAK OR TYPE A REQUEST"
    static let commandHoldInputHelp = "HOLD SPACE TO SPEAK OR CLICK TO TYPE"
    static let commandIndexingCompact = "INDEXING IN BACKGROUND"
    static let historyTitle = "Conversation History"
    static let historyDetail = "Review every request and response retained on this Mac."
    static let historyEmptyTitle = "No conversation history yet"
    static let historyEmptyDetail = "Requests and responses will appear here after you use the assistant."
    static let startListening = "Start speaking"
    static let stopListening = "Stop and send"
    static let addFolder = "Add Folder"
    static let reindex = "Update Index"
    static let clearConversation = "Clear Conversation"
    static let clearConversationTitle = "Clear conversation history?"
    static let clearConversationMessage =
        "This permanently removes saved messages and current file matches. Your files, folders, permissions, and index are not changed."
    static let revealInFinder = "Reveal in Finder"
    static let openFile = "Open File"
    static let openFolder = "Open Folder"
    static let indexing = "Indexing"
    static let indexingInBackground = "Indexing in the background"
    static let scanningForChanges = "Scanning for changes…"
    static let viewActivity = "View Activity"
    static let pauseIndexing = "Pause Indexing"
    static let pausingIndexing = "Pausing…"
    static let monitoringActive = "Automatic updates on"
    static let monitoringPaused = "Automatic updates paused"
    static let monitoringUnavailable = "Automatic updates unavailable"
    static let pauseAutomaticUpdates = "Pause Automatic Updates"
    static let resumeAutomaticUpdates = "Resume Automatic Updates"
    static let done = "Done"
    static let errorTitle = "Local Assistant could not complete that action"
    static let offlineSetupRequired =
        "Run the offline setup on an internet-connected staging Mac, then transfer the verified package to this Mac."
    static let folderPickerTitle = "Choose folders for Local Assistant"
    static let folderPickerMessage = "Local Assistant receives read-only access to the folders you select."
    static let folderPickerPrompt = "Allow Read-Only Access"
    static let answerWithEvidence = "Send message"
    static let searchResults = "Matches"
    static let neverIndexed = "Not indexed yet"
    static let lastIndexed = "Last indexed"
    static let readOnlyAccess = "Read-only access"
    static let privacyTitle = "Privacy"
    static let privacyNetwork = "Local Assistant itself has no network access"
    static let privacyOpenClawException =
        "Only external connection: the separate OpenClaw connector, configured in “OpenClaw Connection” below"
    static let privacyFiles = "Reads only folders you choose"
    static let privacyWrites = "Never changes files inside those folders"
    static let privacySummary =
        "Your files, searches, and conversations stay under your control."
    static let localDatabase = "Private app data"
    static let localDatabaseDescription =
        "SQLite stores indexed metadata and conversation history inside the app's private container. It is embedded, not a database server."
    static let modelStatus = "Models"
    static let modelsSectionDescription =
        "A clear view of what the assistant can do on this Mac."
    static let modelsEverythingReady = "Everything is ready"
    static let modelsEverythingReadyDescription =
        "Chat, file search, and voice input are available."
    static let modelsMissing = "Some features are not installed"
    static let modelsMissingDescription =
        "Install the offline model package to turn on the features listed below."
    static let modelsDamaged = "Some files are damaged"
    static let modelsDamagedDescription =
        "Reinstall the offline model package to replace files that no longer match what the app expects."
    static let modelsChecking = "Checking what is ready"
    static let modelsCheckingDescription =
        "Local Assistant checks its required files when the app opens."
    static let modelChatCapability = "Chat and answers"
    static let modelChatCapabilityDescription =
        "Answers questions and helps understand what you are looking for."
    static let modelFileSearchCapability = "File search"
    static let modelFileSearchCapabilityDescription =
        "Understands file meaning so the most relevant results appear first."
    static let modelVoiceCapability = "Voice input"
    static let modelVoiceCapabilityDescription =
        "Turns speech into text and loads when you use the microphone."
    static let voiceInputModeTitle = "Voice input"
    static let voiceInputModeDescription =
        "Choose how recording starts and when a spoken request is sent."
    static let voiceClickToSpeak = "Click to speak"
    static let voiceHoldSpace = "Hold Space"

    static let voiceHoldSpaceDescription =
        "Hold Space while the command field is not being edited. Release it or pause for \(Int(VoiceConstants.silenceTimeout)) seconds to send."
    static let modelCapabilityReady = "Ready"
    static let modelCapabilityMissing = "Not installed"
    static let modelCapabilityDamaged = "Damaged"
    static let modelCapabilityChecking = "Checking"
    static let modelStoragePrivate = "Private app storage"
    static let modelsCheckedOnLaunch = "Checked when the app opens"
    static let checkNow = "Check Now"
    static let removeDownloadedModels = "Remove Downloaded Models"
    static let removeDownloadedModelsAction = "Remove Models"
    static let removeDownloadedModelsTitle = "Remove downloaded models?"
    static let removeDownloadedModelsMessage =
        "This deletes every installed model file. Chat, file search, and voice input become unavailable until the models are reinstalled and Local Assistant is reopened."
    static let clearSearchIndex = "Clear Search Index"
    static let clearSearchIndexAction = "Clear Index"
    static let clearSearchIndexTitle = "Clear the search index?"
    static let clearSearchIndexMessage =
        "This deletes every indexed file, passage, and vector, then immediately re-indexes your authorized folders. Folder access, conversations, and models are not changed."
    static let listening = "Listening…"
    static let voiceListening = "Listening. Speak now, then stop when you are done."
    static let topMatch = "Top match"
    static let possibleMatch = "Possible match"
    static let unavailableMatch = "No longer available"
    static let unavailableMatchHelp =
        "This saved file is no longer present in an authorized indexed folder."
    static let whyItMatches = "Why it matches"
    static let folderAccess = "Folder access"
    static let folderAccessDescription = "Choose exactly which folders can be read and indexed."
    static let noAuthorizedFolders = "No folders have been authorized."
    static let revokeAccess = "Revoke Access"
    static let revokeAccessTitle = "Revoke folder access?"
    static let cancel = "Cancel"
    static let quickCallShortcut = "Quick-call shortcut"
    static let shortcutKeyControl = "⌃"
    static let shortcutKeyOption = "⌥"
    static let shortcutKeySpace = "Space"
    static let shortcutAccessibleKeys = "Control, Option, Space"
    static let shortcutAvailable = "Available"
    static let shortcutUnavailable = "Unavailable"
    static let shortcutAvailableDescription = "Works while Local Assistant is running, even when its window is closed."
    static let shortcutUnavailableDescription = "Another app may already be using this key combination."
    static let settingsTitle = "Settings"
    static let settingsDetail = "Manage privacy, folder access, models, and assistant availability."
    static let userMessageSender = "You"
    static let assistantMessageSender = "Local Assistant"
    static let assistantStatus = "Assistant status"
    static let assistantStatusDescription =
        "Bring Local Assistant forward without leaving the app you are using."
    static let updateAllFolders = "Update All Folders"
    static let activityTitle = "Index Activity"
    static let activityDetail = "See automatic updates, indexing progress, and file-level results from the last 30 days."
    static let activityEmptyTitle = "No indexing activity yet"
    static let activityEmptyDetail = "Automatic and manual folder updates will appear here."
    static let activityHistory = "Indexing history"
    static let monitoringEvents = "Monitoring activity"
    static let monitoredFolders = "folders monitored"
    static let clearActivity = "Clear Activity"
    static let clearActivityTitle = "Clear indexing activity?"
    static let clearActivityMessage =
        "This removes the retained 30-day activity history. Indexed files, folder access, and source files are not changed."
    static let noFileDetails = "No file-level details were recorded."
    static let newStatus = "New"
    static let updatedStatus = "Updated"
    static let unchangedStatus = "Unchanged"
    static let removedStatus = "Removed from index"
    static let skippedStatus = "Skipped"
    static let sourceFilter = "Source"
    static let allSources = "All"
    static let folderFilter = "Folder"
    static let allFolders = "All folders"
    static let statusFilter = "Status"
    static let allStatuses = "All statuses"
    static let filterHistory = "Filter history"
    static let filterHistoryDescription = "Narrow the activity list by how it started, folder, or result."
    static let clearFilters = "Clear filters"
    static let listSeparator = "·"

    /// Returns a rich label for the source of an indexing run.
    /// - Parameter trigger: Source that requested the run.
    /// - Returns: Plain-language trigger label.
    internal static func indexingTrigger(_ trigger: IndexingTrigger) -> String {
        switch trigger {
        case .automatic: return "Automatic"
        case .manual: return "Manual"
        case .startup: return "Startup scan"
        }
    }

    /// Returns a precise user-visible file indexing state.
    /// - Parameter state: Durable file-level indexing state.
    /// - Returns: Plain-language state label.
    internal static func indexingItemState(_ state: IndexingItemState) -> String {
        switch state {
        case .newWaiting: return "New — Waiting"
        case .newIndexing: return "New — Indexing"
        case .newIndexed: return "New — Indexed"
        case .modifiedWaiting: return "Modified — Waiting"
        case .modifiedUpdating: return "Modified — Updating"
        case .modifiedUpdated: return "Modified — Updated"
        case .unchanged: return unchangedStatus
        case .missingPendingRemoval: return "Missing — Pending removal from index"
        case .removedFromIndex: return removedStatus
        case .skipped: return "Skipped — Needs attention"
        }
    }

    /// Returns a concise retained run state.
    /// - Parameter state: Durable lifecycle state for a run.
    /// - Returns: Plain-language run state label.
    internal static func indexingRunState(_ state: IndexingRunState) -> String {
        switch state {
        case .running: return "In progress"
        case .completed: return "Completed"
        case .stopped: return "Paused"
        case .failed: return "Needs attention"
        }
    }

    /// Returns plain-language monitoring timeline copy.
    /// - Parameter kind: Durable monitoring or indexing event.
    /// - Returns: Plain-language event description.
    internal static func activityEvent(_ kind: IndexActivityEventKind) -> String {
        switch kind {
        case .changesDetected: return "Folder changes detected"
        case .updateScheduled: return "Automatic update scheduled"
        case .monitoringPaused: return monitoringPaused
        case .monitoringResumed: return "Automatic updates resumed"
        case .indexingStopped: return "Indexing paused safely"
        case .indexingFailed: return "Indexing needs attention"
        case .monitoringUnavailable: return monitoringUnavailable
        }
    }

    /// Formats bounded determinate indexing progress.
    /// - Parameters:
    ///   - processed: Number of completed work items.
    ///   - total: Total number of work items.
    ///   - fraction: Bounded completion fraction.
    /// - Returns: Localized count and percentage text.
    internal static func indexingProgress(processed: Int, total: Int, fraction: Double) -> String {
        let percent = Int((fraction * 100).rounded())
        return "\(processed) of \(total) · \(percent)%"
    }

    /// Describes the click-to-speak pause using the actual configured silence timeout.
    /// - Returns: Plain-language pause guidance that cannot drift from the real duration.
    internal static func voiceClickToSpeakDescription() -> String {
        "Click the voice control and pause for \(Int(VoiceConstants.silenceTimeout)) seconds to send automatically."
    }

    /// Prefixes a folder name with the standard compact separator.
    /// - Parameter folderName: Visible authorized-folder name.
    /// - Returns: Compact secondary folder label.
    internal static func indexingFolderLabel(_ folderName: String) -> String {
        "\(listSeparator) \(folderName)"
    }

    /// Prefixes a numeric bundle release for human-facing presentation.
    /// - Parameter numericVersion: Numeric marketing version stored in bundle metadata.
    /// - Returns: User-facing version label beginning with `v`.
    internal static func displayVersion(_ numericVersion: String) -> String {
        "v\(numericVersion)"
    }

    /// Formats a compact result count for the search section header.
    /// - Parameter count: Number of visible ranked results.
    /// - Returns: Singular or plural match count.
    internal static func matchingFilesCount(_ count: Int) -> String {
        return count == 1 ? "1 match" : "\(count) matches"
    }

    /// Formats a file-finding number using the command surface's fixed-width notation.
    /// - Parameter index: One-based position of the finding.
    /// - Returns: Two-character numeric label for the finding.
    internal static func commandFindingNumber(_ index: Int) -> String {
        String(format: "%02d", index)
    }

    /// Returns the user-facing name of one assistant capability.
    /// - Parameter kind: Capability supplied by an installed local model.
    /// - Returns: Plain-language capability name.
    internal static func modelCapabilityTitle(_ kind: LocalModelCapabilityKind) -> String {
        switch kind {
        case .chat: return modelChatCapability
        case .fileSearch: return modelFileSearchCapability
        case .voiceInput: return modelVoiceCapability
        }
    }

    /// Returns the user-facing purpose of one assistant capability.
    /// - Parameter kind: Capability supplied by an installed local model.
    /// - Returns: Plain-language explanation of what the capability enables.
    internal static func modelCapabilityDescription(
        _ kind: LocalModelCapabilityKind
    ) -> String {
        switch kind {
        case .chat: return modelChatCapabilityDescription
        case .fileSearch: return modelFileSearchCapabilityDescription
        case .voiceInput: return modelVoiceCapabilityDescription
        }
    }

    /// Formats the number of assistant capabilities that are ready.
    /// - Parameters:
    ///   - ready: Number of capabilities that passed local checks.
    ///   - total: Total number of required capabilities.
    /// - Returns: Compact readiness count.
    internal static func modelReadinessCount(ready: Int, total: Int) -> String {
        "\(ready) of \(total) ready"
    }

    /// Formats the total private storage used by installed model assets.
    /// - Parameter byteCount: Total number of locally installed bytes.
    /// - Returns: Human-readable private-storage usage.
    internal static func modelStorageUsage(_ byteCount: Int64) -> String {
        let formatted = ByteCountFormatter.string(
            fromByteCount: byteCount,
            countStyle: .file
        )
        return "\(formatted) in \(modelStoragePrivate.lowercased())"
    }

    /// Formats the total on-disk size of the private search index.
    /// - Parameter byteCount: Total number of bytes used by the index database.
    /// - Returns: Human-readable index storage usage.
    internal static func indexStorageUsage(_ byteCount: Int64) -> String {
        let formatted = ByteCountFormatter.string(
            fromByteCount: byteCount,
            countStyle: .file
        )
        return "\(formatted) search index"
    }

    /// Formats the number of files currently searchable in the private index.
    /// - Parameter count: Current indexed file count, excluding folders.
    /// - Returns: Singular or plural indexed-file count.
    internal static func indexedFileCount(_ count: Int) -> String {
        count == 1 ? "1 file indexed" : "\(count) files indexed"
    }

    /// Returns a short visible label for an indexed item category.
    /// - Parameter kind: Indexed file or folder category.
    /// - Returns: User-facing file-type label.
    internal static func fileType(_ kind: IndexedItemKind) -> String {
        switch kind {
        case .folder: return "Folder"
        case .document: return "Document"
        case .spreadsheet: return "Spreadsheet"
        case .presentation: return "Presentation"
        case .pdf: return "PDF"
        case .image: return "Image"
        case .code: return "Code"
        case .text: return "Text"
        case .archive: return "Archive"
        case .other: return "File"
        }
    }

    /// Returns the explicit open-action label for a file or folder.
    /// - Parameter kind: Indexed item category shown by the result card.
    /// - Returns: Folder-aware action text.
    internal static func openItem(_ kind: IndexedItemKind) -> String {
        kind == .folder ? openFolder : openFile
    }

    /// Formats a message timestamp using the current locale and time zone.
    /// - Parameters:
    ///   - date: Stored creation time for the message.
    ///   - referenceDate: Date used to decide whether the message was sent today.
    /// - Returns: Time-only text for today or abbreviated date and time for older messages.
    internal static func messageTimestamp(
        _ date: Date,
        relativeTo referenceDate: Date = Date()
    ) -> String {
        if Calendar.autoupdatingCurrent.isDate(date, inSameDayAs: referenceDate) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Describes what folder revocation removes and what remains untouched.
    /// - Parameter folderName: Visible name of the authorized folder.
    /// - Returns: Confirmation detail for a destructive revocation action.
    internal static func revokeAccessMessage(folderName: String) -> String {
        "Local Assistant will forget access to “\(folderName)” and remove its private index entries. "
            + "The folder and its files will not be changed."
    }
}
