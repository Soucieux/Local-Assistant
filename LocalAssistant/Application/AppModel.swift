import AppKit
import Foundation
import Observation

/// Main-actor presentation state for the local-only assistant.
@MainActor
@Observable
final class AppModel {
    var activeScreen: AppScreen = .assistant
    var queryText = AppConstants.Text.empty
    var messages: [ChatMessage] = []
    var indexedRoots: [AuthorizedRoot] = []
    var indexingProgress = IndexingProgress.idle
    var indexingProgressByRoot: [UUID: IndexingProgress] = [:]
    var pausedMonitoringRootIDs: Set<UUID> = []
    var monitoredRootIDs: Set<UUID> = []
    var indexingRuns: [IndexingRunRecord] = []
    var indexingItemsByRun: [UUID: [IndexingItemRecord]] = [:]
    var indexActivityEvents: [IndexActivityEventRecord] = []
    var offlineStatus: OfflineStatus = .checking
    var modelCapabilities: [LocalModelCapabilityStatus] = []
    var modelStorageByteCount: Int64 = 0
    var indexedFileCount = 0
    var indexStorageByteCount: Int64 = 0
    private(set) var voiceInputMode: VoiceInputMode
    var isBusy = false
    var isListening = false
    private(set) var isComposingRequest = false
    private(set) var currentRequestText = AppConstants.Text.empty
    private(set) var currentResponse: ChatMessage?

    /// Live audio levels and recognized text while the microphone is open.
    private(set) var voiceCapture: VoiceCaptureState = .preparing

    /// Follows the capture stream and ends the recording when it finishes on its own.
    @ObservationIgnored private var voiceUpdatesTask: Task<Void, Never>?
    var isShortcutAvailable = false
    var inputFocusRequest = 0
    var conversationClearConfirmationIsPresented = false
    var activityClearConfirmationIsPresented = false
    var modelRemovalConfirmationIsPresented = false
    var searchIndexClearConfirmationIsPresented = false
    var presentedError: LocalAssistantError?
    private(set) var availableFileMatchItemIDs: Set<UUID> = []
    private var hasStarted = false

    @ObservationIgnored
    var indexingQueue: [(
        rootID: UUID,
        trigger: IndexingTrigger,
        batchID: UUID?
    )] = []

    @ObservationIgnored
    var indexingWorker: Task<Void, Never>?

    @ObservationIgnored
    var activeIndexingTask: Task<IndexingOutcome, Error>?

    var activeIndexingRootID: UUID?

    @ObservationIgnored
    var activeIndexingBatchID: UUID?

    @ObservationIgnored
    var dirtyIndexRequests: [UUID: (
        trigger: IndexingTrigger,
        batchID: UUID?
    )] = [:]

    @ObservationIgnored
    var monitoringDebounceTasks: [UUID: Task<Void, Never>] = [:]

    @ObservationIgnored
    let services: ServiceContainer

    /// Creates app state with a fresh in-process service container.
    /// - Parameter services: Local-only dependencies used by the app.
    internal init(services: ServiceContainer = ServiceContainer()) {
        self.services = services
        voiceInputMode = UserDefaults.standard
            .string(forKey: AppConstants.Preferences.voiceInputModeKey)
            .flatMap(VoiceInputMode.init(rawValue:))
            ?? .clickToSpeak
    }

    /// Opens local storage, verifies models, and restores the private conversation.
    internal func start() async {
        guard hasStarted == false else { return }
        hasStarted = true
        isBusy = true
        defer { isBusy = false }
        do {
            let bootstrapper = ApplicationBootstrapper(
                database: services.database,
                modelStore: services.modelStore,
                runtime: services.runtime,
                voice: services.voice
            )
            let status = try await bootstrapper.start()
            offlineStatus = status.state
            modelCapabilities = status.capabilities
            modelStorageByteCount = status.totalByteCount
            indexedFileCount = try await services.database.indexedFileCount()
            indexStorageByteCount = try await services.database.databaseByteCount()
            indexedRoots = try await services.database.fetchRoots()
            pausedMonitoringRootIDs = try await services.database.fetchPausedMonitoringRootIDs()
            try await services.database.stopInterruptedIndexingRuns(at: Date())
            try await services.database.purgeIndexActivity(before: activityRetentionCutoff)
            let storedMessages = try await services.database.fetchChatMessages(
                limit: AppConstants.Chat.historyLimit
            )
            messages = try await restoreSavedMessages(in: storedMessages)
            try await refreshFileMatchAvailability()
            for root in indexedRoots where pausedMonitoringRootIDs.contains(root.id) == false {
                do {
                    try startMonitoring(root)
                    if offlineStatus == .ready {
                        requestIndex(root: root, trigger: .startup)
                    }
                } catch {
                    try? await services.database.insertIndexActivityEvent(
                        IndexActivityEventRecord(
                            id: UUID(),
                            rootID: root.id,
                            folderName: root.displayName,
                            kind: .monitoringUnavailable,
                            occurredAt: Date()
                        )
                    )
                }
            }
            try await refreshIndexActivity()
        } catch {
            handle(error)
        }
    }

    /// Re-verifies installed models and re-counts indexed files on demand.
    internal func checkSystemStatus() async {
        do {
            let status = try await services.modelStore.refreshStatus()
            offlineStatus = status.state
            modelCapabilities = status.capabilities
            modelStorageByteCount = status.totalByteCount
            indexedFileCount = try await services.database.indexedFileCount()
            indexStorageByteCount = try await services.database.databaseByteCount()
        } catch {
            handle(error)
        }
    }

    /// Requests confirmation before every installed model file is deleted.
    internal func requestModelRemovalConfirmation() {
        guard isBusy == false, isIndexing == false, isListening == false else { return }
        modelRemovalConfirmationIsPresented = true
    }

    /// Dismisses the model-removal confirmation without deleting anything.
    internal func dismissModelRemovalConfirmation() {
        modelRemovalConfirmationIsPresented = false
    }

    /// Deletes every installed model file and refreshes readiness for all three capabilities.
    internal func confirmModelRemoval() async {
        modelRemovalConfirmationIsPresented = false
        do {
            let status = try await services.modelStore.removeInstalledModels()
            offlineStatus = status.state
            modelCapabilities = status.capabilities
            modelStorageByteCount = status.totalByteCount
        } catch {
            handle(error)
        }
    }

    /// Submits one plain-language request to local conversation or file retrieval.
    internal func submit() async {
        let question = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard question.isEmpty == false, isBusy == false else { return }
        queryText = AppConstants.Text.empty
        currentRequestText = question
        isComposingRequest = false
        currentResponse = nil
        messages.append(ChatMessage.user(question))
        isBusy = true
        defer { isBusy = false }
        do {
            let response = try await services.assistant.answer(
                question: question,
                history: Array(messages.dropLast()),
                persistHistory: true
            )
            let assistantMessage = ChatMessage(
                id: UUID(),
                role: .assistant,
                text: response.answer,
                createdAt: Date(),
                citations: response.citations,
                fileMatches: response.alternatives
            )
            messages.append(assistantMessage)
            currentResponse = assistantMessage
            availableFileMatchItemIDs.formUnion(
                response.alternatives.map(\.item.id)
            )
        } catch {
            handle(error)
        }
    }

    /// Deletes persisted local chat history and clears the visible conversation.
    internal func clearConversation() async {
        do {
            try await services.database.clearChatMessages()
            messages = []
            currentRequestText = AppConstants.Text.empty
            currentResponse = nil
            isComposingRequest = false
            availableFileMatchItemIDs = []
        } catch {
            handle(error)
        }
    }

    /// Requests confirmation before persisted conversation data is removed.
    internal func requestConversationClearConfirmation() {
        guard messages.isEmpty == false,
              isBusy == false,
              isListening == false else { return }
        conversationClearConfirmationIsPresented = true
    }

    /// Dismisses the conversation-clear confirmation without changing data.
    internal func dismissConversationClearConfirmation() {
        conversationClearConfirmationIsPresented = false
    }

    /// Confirms conversation deletion and returns focus to the composer.
    internal func confirmConversationClear() async {
        conversationClearConfirmationIsPresented = false
        await clearConversation()
        requestInputFocus()
    }

    /// Starts local microphone capture and follows its live levels and text.
    ///
    /// Capture is not treated as busy work, because the composer shows the waveform and the
    /// recognized text while it runs.
    internal func startListening() async {
        guard isListening == false, isBusy == false else { return }
        queryText = AppConstants.Text.empty
        isComposingRequest = true
        currentResponse = nil
        do {
            let updates = try await services.voice.startRecording(
                stopsAfterSilence: voiceInputMode.stopsAfterSilence
            )
            voiceCapture = .preparing
            isListening = true
            voiceUpdatesTask = Task { [weak self] in
                for await state in updates {
                    self?.voiceCapture = state
                }
                self?.finishListeningAfterPause()
            }
        } catch {
            handle(error)
        }
    }

    /// Ends a recording that stopped on its own after the speaker paused.
    ///
    /// The finish runs in a new task because the caller is the capture-following task, which
    /// stopping cancels. Submitting from a cancelled task abandons the request.
    private func finishListeningAfterPause() {
        guard isListening else { return }
        Task { await stopListening() }
    }

    /// Stops local capture, then submits whatever was recognized.
    internal func stopListening() async {
        guard isListening else { return }
        isListening = false
        voiceUpdatesTask?.cancel()
        voiceUpdatesTask = nil
        isBusy = true
        do {
            let transcript = try await services.voice.stopAndTranscribe()
            voiceCapture = .preparing
            isBusy = false
            guard transcript.isEmpty == false else { return }
            queryText = transcript
            await submit()
        } catch {
            voiceCapture = .preparing
            isBusy = false
            handle(error)
        }
    }

    /// Reveals a currently authorized indexed item in Finder without modifying it.
    /// - Parameter item: Local file or folder to reveal.
    internal func reveal(_ item: IndexedItem) async {
        do {
            let resolved = try await resolveActionableItem(id: item.id)
            NSWorkspace.shared.activateFileViewerSelecting([resolved.actionURL])
            _ = resolved.access
        } catch {
            availableFileMatchItemIDs.remove(item.id)
            handle(error)
        }
    }

    /// Opens a currently authorized indexed item through its default macOS application.
    /// - Parameter item: Local file or folder to open.
    internal func open(_ item: IndexedItem) async {
        do {
            let resolved = try await resolveActionableItem(id: item.id)
            NSWorkspace.shared.open(resolved.actionURL)
            _ = resolved.access
        } catch {
            availableFileMatchItemIDs.remove(item.id)
            handle(error)
        }
    }

    /// Reports whether a saved result still belongs to the current private index.
    /// - Parameter itemID: Stable indexed item identifier stored in a file card.
    /// - Returns: `true` when the item remains available for an explicit action.
    internal func isFileMatchAvailable(_ itemID: UUID) -> Bool {
        availableFileMatchItemIDs.contains(itemID)
    }

    /// Requests that the main query field become first responder.
    internal func requestInputFocus() {
        inputFocusRequest += 1
    }

    /// Begins a new typed request without erasing a draft already being edited.
    internal func beginTextInput() {
        guard isBusy == false, isListening == false, isComposingRequest == false else {
            return
        }
        queryText = AppConstants.Text.empty
        isComposingRequest = true
    }

    /// Clears the previous result when the user begins composing the next request.
    internal func prepareNewRequestPresentation() {
        guard isBusy == false, isListening == false else { return }
        isComposingRequest = true
        currentResponse = nil
    }

    /// Stores the preferred local voice interaction for future launches.
    /// - Parameter mode: Click-to-speak or hold-Space interaction selected in Settings.
    internal func setVoiceInputMode(_ mode: VoiceInputMode) {
        guard isListening == false else { return }
        voiceInputMode = mode
        UserDefaults.standard.set(
            mode.rawValue,
            forKey: AppConstants.Preferences.voiceInputModeKey
        )
    }

    /// Opens Settings inside the existing main window.
    internal func showSettings() {
        activeScreen = .settings
    }

    /// Opens retained conversation history inside the existing main window.
    internal func showHistory() {
        activeScreen = .history
    }

    /// Opens the retained indexing activity inside the existing main window.
    internal func showActivity() {
        activeScreen = .activity
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.services.database.purgeIndexActivity(
                    before: self.activityRetentionCutoff
                )
                try await self.refreshIndexActivity()
            } catch {
                self.handle(error)
            }
        }
    }

    /// Returns to the assistant screen and focuses its composer.
    internal func showAssistant() {
        activeScreen = .assistant
        requestInputFocus()
    }

    /// Reports whether the current launch has produced a request to present.
    internal var hasCurrentRequest: Bool {
        currentRequestText.isEmpty == false
    }

    /// Reports whether any folder is currently being indexed.
    internal var isIndexing: Bool {
        activeIndexingRootID != nil
    }

    /// Stops process-lifetime monitors and outstanding indexing work during termination.
    internal func shutdown() async {
        await stopIndexing()
        voiceUpdatesTask?.cancel()
        voiceUpdatesTask = nil
        await services.voice.shutdown()
        await services.runtime.shutdown()
        await services.database.close()
    }

    /// Records whether the global quick-call shortcut registered successfully.
    /// - Parameter isAvailable: Current in-process shortcut availability.
    internal func setShortcutAvailable(_ isAvailable: Bool) {
        isShortcutAvailable = isAvailable
    }

    /// Clears a currently presented error.
    internal func dismissError() {
        presentedError = nil
    }

    /// Rolling cutoff applied uniformly to all activity rows.
    internal var activityRetentionCutoff: Date {
        Calendar.current.date(
            byAdding: .day,
            value: -AppConstants.Indexing.activityRetentionDays,
            to: Date()
        ) ?? Date()
    }

    /// Restores legacy cards and removes duplicated card metadata from saved assistant text.
    /// - Parameter storedMessages: Chronological messages decoded from private storage.
    /// - Returns: Messages upgraded with any currently resolvable cited files.
    /// - Throws: A local database error when an item lookup or migration write fails.
    private func restoreSavedMessages(
        in storedMessages: [ChatMessage]
    ) async throws -> [ChatMessage] {
        var restoredMessages: [ChatMessage] = []
        for message in storedMessages {
            guard message.role == .assistant else {
                restoredMessages.append(message)
                continue
            }

            var fileMatches = message.fileMatches
            var seenItemIDs: Set<UUID> = []
            if fileMatches.isEmpty, message.citations.isEmpty == false {
                for citation in message.citations {
                    guard seenItemIDs.insert(citation.itemID).inserted,
                          let item = try await services.database.fetchItem(id: citation.itemID) else {
                        continue
                    }
                    let citations = message.citations.filter { $0.itemID == item.id }
                    fileMatches.append(
                        SearchResult(
                            id: citation.id,
                            item: item,
                            score: .zero,
                            confidence: .low,
                            explanation: RetrievalStrings.savedReference,
                            citations: citations
                        )
                    )
                }
            }

            let visibleText = FileCardAnswerFormatter.visibleAnswer(
                from: message.text,
                results: fileMatches
            )
            guard fileMatches != message.fileMatches || visibleText != message.text else {
                restoredMessages.append(message)
                continue
            }
            let restoredMessage = message.restoring(
                text: visibleText,
                fileMatches: fileMatches
            )
            try await services.database.insertChatMessage(restoredMessage)
            restoredMessages.append(restoredMessage)
        }
        return restoredMessages
    }

    /// Reconciles saved card actions with items still present in the current index.
    /// - Throws: A local database error when an item lookup fails.
    internal func refreshFileMatchAvailability() async throws {
        let itemIDs = Set(
            messages.flatMap(\.fileMatches).map(\.item.id)
        )
        let storedItems = try await services.database.fetchItems(ids: itemIDs)
        availableFileMatchItemIDs = Set(storedItems.keys)
    }

    /// Resolves one saved action against current authorization, index, and disk state.
    /// - Parameter id: Stable item identifier from the displayed card.
    /// - Returns: A symlink-resolved safe action URL and live read-only access token.
    /// - Throws: A safe unavailable or permission error when access is no longer valid.
    private func resolveActionableItem(
        id: UUID
    ) async throws -> (actionURL: URL, access: SecurityScopedAccess) {
        guard let item = try await services.database.fetchItem(id: id),
              let root = indexedRoots.first(where: { $0.id == item.rootID }),
              root.isAvailable else {
            throw LocalAssistantError.fileUnavailable
        }
        let access = try services.authorization.beginAccess(to: root)
        let actionURL = try ReadOnlyActionPolicy.resolvedActionURL(
            for: item.url,
            inside: access.url
        )
        availableFileMatchItemIDs.insert(item.id)
        return (actionURL, access)
    }

    /// Converts arbitrary local errors to a privacy-safe presentation value.
    /// - Parameter error: Error raised by an in-process service.
    internal func handle(_ error: Error) {
        if let localError = error as? LocalAssistantError {
            presentedError = localError
        } else {
            presentedError = .unexpected(error.localizedDescription)
        }
    }
}
