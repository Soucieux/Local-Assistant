import Foundation

/// User-visible copy for the focused native interface.
enum UIStrings {
    static let appName = "Local Assistant"
    static let about = "About Local Assistant"
    static let settings = "Settings"
    static let assistant = "Assistant"
    static let backToAssistant = "Back to Assistant"
    static let assistantSubtitle = "Private answers and file search on this Mac"
    static let searchPlaceholder = "Ask or find a local file…"
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
    static let welcomeTitle = "Find anything in your files"
    static let welcomeDetail = "Type or speak. Everything stays on this Mac."
    static let welcomePromptTitle = "Try asking"
    static let welcomePromptOne = "Find the latest budget spreadsheet"
    static let welcomePromptTwo = "Show me PDFs about consulting"
    static let welcomePromptThree = "Where is the project folder?"
    static let composerHint = "Return to send  •  ⌃⌥Space to call Local Assistant"
    static let localOnly = "Local only"
    static let privateOnThisMac = "Private on this Mac"
    static let indexing = "Indexing"
    static let done = "Done"
    static let errorTitle = "Local Assistant could not complete that action"
    static let offlineSetupRequired =
        "Run the offline setup on an internet-connected staging Mac, then transfer the verified package to this Mac."
    static let folderPickerTitle = "Choose folders for Local Assistant"
    static let folderPickerMessage = "Local Assistant receives read-only access to the folders you select."
    static let folderPickerPrompt = "Allow Read-Only Access"
    static let answerWithEvidence = "Send message"
    static let searchResults = "File matches"
    static let indexedItems = "indexed"
    static let skippedItems = "skipped"
    static let neverIndexed = "Not indexed yet"
    static let lastIndexed = "Last indexed"
    static let readOnlyAccess = "Read-only access"
    static let privacyTitle = "Privacy"
    static let privacyNetwork = "No network access"
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
    static let modelsNeedAttention = "Some features need attention"
    static let modelsNeedAttentionDescription =
        "Reinstall the offline model package to restore unavailable features."
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
    static let modelCapabilityReady = "Ready"
    static let modelCapabilityMissing = "Not ready"
    static let modelCapabilityChecking = "Checking"
    static let modelStoragePrivate = "Private app storage"
    static let modelsCheckedOnLaunch = "Checked when the app opens"
    static let listening = "Listening…"
    static let workingLocally = "Working locally…"
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

    /// Formats indexing progress counts.
    /// - Parameters:
    ///   - processed: Completed item count.
    ///   - skipped: Skipped or excluded item count.
    /// - Returns: Compact progress text.
    internal static func indexingCounts(processed: Int, skipped: Int) -> String {
        "\(processed) \(indexedItems), \(skipped) \(skippedItems)"
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
