import Foundation

/// User-visible copy for the focused native interface.
internal enum UIStrings {
    internal static let appName = "Local Assistant"
    internal static let about = "About Local Assistant"
    internal static let settings = "Settings"
    internal static let activity = "Activity"
    internal static let history = "History"
    internal static let assistant = "Assistant"
    internal static let backToAssistant = "Back to Assistant"
    internal static let startupTitle = "Starting Local Assistant"
    internal static let startupDetail =
        "Opening the private database and checking local models. Controls will be ready when this finishes."
    internal static let commandPrompt = "WHAT SHOULD I FIND?"
    internal static let commandLocalStatus = "CORE OFFLINE / READY"
    internal static let commandIndexingStatus = "CORE OFFLINE / INDEXING"
    internal static let commandConnectorStatus = "CORE OFFLINE / CONNECTOR ENABLED"
    internal static let commandListening = "LISTENING"
    internal static let commandProcessing = "PROCESSING REQUEST"
    internal static let commandResponse = "RESPONSE / COMPLETE"
    internal static let commandClickInputHelp = "CLICK TO SPEAK OR TYPE A REQUEST"
    internal static let commandHoldInputHelp = "HOLD SPACE TO SPEAK OR CLICK TO TYPE"
    internal static let commandIndexingCompact = "INDEXING IN BACKGROUND"
    internal static let historyTitle = "Conversation History"
    internal static let historyDetail = "Review every request and response retained on this Mac."
    internal static let historyEmptyTitle = "No conversation history yet"
    internal static let historyEmptyDetail = "Requests and responses will appear here after you use the assistant."
    internal static let startListening = "Start speaking"
    internal static let stopListening = "Stop and send"
    internal static let addFolder = "Add Folder"
    internal static let reindex = "Update Index"
    internal static let clearConversation = "Clear Conversation"
    internal static let clearConversationTitle = "Clear conversation history?"
    internal static let clearConversationMessage =
        "This permanently removes saved messages and current file matches. Your files, folders, permissions, and index are not changed."
    internal static let revealInFinder = "Reveal in Finder"
    internal static let openFile = "Open File"
    internal static let openFolder = "Open Folder"
    internal static let indexing = "Indexing"
    internal static let indexingInBackground = "Indexing in the background"
    internal static let scanningForChanges = "Scanning for changes…"
    internal static let viewActivity = "View Activity"
    internal static let pauseIndexing = "Pause Indexing"
    internal static let pausingIndexing = "Pausing…"
    internal static let monitoringActive = "Automatic updates on"
    internal static let monitoringPaused = "Automatic updates paused"
    internal static let monitoringUnavailable = "Automatic updates unavailable"
    internal static let pauseAutomaticUpdates = "Pause Automatic Updates"
    internal static let resumeAutomaticUpdates = "Resume Automatic Updates"
    internal static let done = "Done"
    internal static let errorTitle = "Local Assistant could not complete that action"
    internal static let offlineSetupRequired =
        "Run the offline setup on an internet-connected staging Mac, then transfer the verified package to this Mac."
    internal static let folderPickerTitle = "Choose folders for Local Assistant"
    internal static let folderPickerMessage = "Local Assistant receives read-only access to the folders you select."
    internal static let folderPickerPrompt = "Allow Read-Only Access"
    internal static let answerWithEvidence = "Send message"
    internal static let searchResults = "Matches"
    internal static let neverIndexed = "Not indexed yet"
    internal static let lastIndexed = "Last indexed"
    internal static let readOnlyAccess = "Read-only access"
    internal static let privacyTitle = "Privacy"
    internal static let privacyNetwork = "Local Assistant itself has no network access"
    internal static let privacyOpenClawException =
        "Only external connection: the separate OpenClaw connector, configured in “OpenClaw Connection” below"
    internal static let privacyFiles = "Reads only folders you choose"
    internal static let privacyWrites = "Never changes files inside those folders"
    internal static let privacySummary =
        "Your files, searches, and conversations stay under your control."
    internal static let localDatabase = "Private app data"
    internal static let localDatabaseDescription =
        "SQLite stores indexed metadata and conversation history inside the app's private container. It is embedded, not a database server."
    internal static let modelStatus = "Models"
    internal static let modelsSectionDescription =
        "A clear view of what the assistant can do on this Mac."
    internal static let modelsEverythingReady = "Everything is ready"
    internal static let modelsEverythingReadyDescription =
        "Chat, file search, and voice input are available."
    internal static let modelsMissing = "Some features are not installed"
    internal static let modelsMissingDescription =
        "Install the offline model package to turn on the features listed below."
    internal static let modelsDamaged = "Some files are damaged"
    internal static let modelsDamagedDescription =
        "Reinstall the offline model package to replace files that no longer match what the app expects."
    internal static let modelsChecking = "Checking what is ready"
    internal static let modelsCheckingDescription =
        "Local Assistant checks its required files when the app opens."
    internal static let modelChatCapability = "Chat and answers"
    internal static let modelChatCapabilityDescription =
        "Answers questions and helps understand what you are looking for."
    internal static let modelFileSearchCapability = "File search"
    internal static let modelFileSearchCapabilityDescription =
        "Understands file meaning so the most relevant results appear first."
    internal static let modelVoiceCapability = "Voice input"
    internal static let modelVoiceCapabilityDescription =
        "Turns speech into text and loads when you use the microphone."
    internal static let voiceInputModeTitle = "Voice input"
    internal static let voiceInputModeDescription =
        "Choose how recording starts and when a spoken request is sent."
    internal static let voiceClickToSpeak = "Click to speak"
    internal static let voiceHoldSpace = "Hold Space"

    internal static let voiceHoldSpaceDescription =
        "Hold Space while the command field is not being edited. Release it or pause for \(Int(VoiceConstants.silenceTimeout)) seconds to send."
    internal static let modelCapabilityReady = "Ready"
    internal static let modelCapabilityMissing = "Not installed"
    internal static let modelCapabilityDamaged = "Damaged"
    internal static let modelCapabilityChecking = "Checking"
    internal static let modelStoragePrivate = "Private app storage"
    internal static let modelsCheckedOnLaunch = "Checked when the app opens"
    internal static let checkNow = "Check Now"
    internal static let removeDownloadedModels = "Remove Downloaded Models"
    internal static let removeDownloadedModelsAction = "Remove Models"
    internal static let removeDownloadedModelsTitle = "Remove downloaded models?"
    internal static let removeDownloadedModelsMessage =
        "This deletes every installed model file. Chat, file search, and voice input become unavailable until the models are reinstalled and Local Assistant is reopened."
    internal static let clearSearchIndex = "Clear Search Index"
    internal static let clearSearchIndexAction = "Clear Index"
    internal static let clearSearchIndexTitle = "Clear the search index?"
    internal static let clearSearchIndexMessage =
        "This deletes every indexed file, passage, and vector, then immediately re-indexes your authorized folders. Folder access, conversations, and models are not changed."
    internal static let listening = "Listening…"
    internal static let voiceListening = "Listening. Speak now, then stop when you are done."
    internal static let topMatch = "Top match"
    internal static let possibleMatch = "Possible match"
    internal static let unavailableMatch = "No longer available"
    internal static let unavailableMatchHelp = ErrorStrings.fileUnavailable
    internal static let whyItMatches = "Why it matches"
    internal static let folderAccess = "Folder access"
    internal static let folderAccessDescription = "Choose exactly which folders can be read and indexed."
    internal static let noAuthorizedFolders = "No folders have been authorized."
    internal static let revokeAccess = "Revoke Access"
    internal static let revokeAccessTitle = "Revoke folder access?"
    internal static let cancel = "Cancel"
    internal static let quickCallShortcut = "Quick-call shortcut"
    internal static let shortcutKeyControl = "⌃"
    internal static let shortcutKeyOption = "⌥"
    internal static let shortcutKeySpace = "Space"
    internal static let shortcutAccessibleKeys = "Control, Option, Space"
    internal static let shortcutAvailable = "Available"
    internal static let shortcutUnavailable = "Unavailable"
    internal static let shortcutAvailableDescription = "Works while Local Assistant is running, even when its window is closed."
    internal static let shortcutUnavailableDescription = "Another app may already be using this key combination."
    internal static let settingsTitle = "Settings"
    internal static let settingsDetail = "Manage privacy, folder access, models, and assistant availability."
    internal static let userMessageSender = "You"
    internal static let assistantMessageSender = "Local Assistant"
    internal static let assistantStatus = "Assistant status"
    internal static let assistantStatusDescription =
        "Bring Local Assistant forward without leaving the app you are using."
    internal static let updateAllFolders = "Update All Folders"
    internal static let activityTitle = "Index Activity"
    internal static let activityDetail = "See automatic updates, indexing progress, and file-level results from the last 30 days."
    internal static let activityEmptyTitle = "No indexing activity yet"
    internal static let activityEmptyDetail = "Automatic and manual folder updates will appear here."
    internal static let activityHistory = "Indexing history"
    internal static let monitoringEvents = "Monitoring activity"
    internal static let monitoredFolders = "folders monitored"
    internal static let clearActivity = "Clear Activity"
    internal static let clearActivityTitle = "Clear indexing activity?"
    internal static let clearActivityMessage =
        "This removes the retained 30-day activity history. Indexed files, folder access, and source files are not changed."
    internal static let noFileDetails = "No file-level details were recorded."
    internal static let newStatus = "New"
    internal static let updatedStatus = "Updated"
    internal static let unchangedStatus = "Unchanged"
    internal static let removedStatus = "Removed from index"
    internal static let skippedStatus = "Skipped"
    internal static let sourceFilter = "Source"
    internal static let allSources = "All"
    internal static let folderFilter = "Folder"
    internal static let allFolders = "All folders"
    internal static let statusFilter = "Status"
    internal static let allStatuses = "All statuses"
    internal static let filterHistory = "Filter history"
    internal static let filterHistoryDescription = "Narrow the activity list by how it started, folder, or result."
    internal static let clearFilters = "Clear filters"
    internal static let listSeparator = "·"

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

    /// Presents the running app's marketing version in the About panel and the Settings identity.
    /// - Returns: User-facing version label beginning with `v`, built from the fallback wording
    ///   when the bundle declares no version.
    internal static var installedVersionLabel: String {
        let numericVersion = Bundle.main.object(
            forInfoDictionaryKey: AppConstants.Identity.bundleShortVersionKey
        ) as? String
        return "v\(numericVersion ?? AppConstants.Identity.fallbackVersion)"
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
