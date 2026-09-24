import AppKit
import Foundation
import Observation

/// Main-actor presentation state for the local-only assistant.
@MainActor
@Observable
internal final class AppModel {
    internal var activeScreen: AppScreen = .assistant
    internal private(set) var isStarting = true
    internal var queryText = AppConstants.Text.empty
    internal var messages: [ChatMessage] = []
    internal var indexedRoots: [AuthorizedRoot] = []
    internal var indexingProgress = IndexingProgress.idle
    internal var indexingProgressByRoot: [UUID: IndexingProgress] = [:]
    internal var pausedMonitoringRootIDs: Set<UUID> = []
    internal var monitoredRootIDs: Set<UUID> = []
    internal var indexingRuns: [IndexingRunRecord] = []
    internal var indexingItemsByRun: [UUID: [IndexingItemRecord]] = [:]
    internal var indexActivityEvents: [IndexActivityEventRecord] = []
    internal var offlineStatus: OfflineStatus = .checking
    internal var modelCapabilities: [LocalModelCapabilityStatus] = []
    internal var modelStorageByteCount: Int64 = 0
    internal var indexedFileCount = 0
    internal var indexStorageByteCount: Int64 = 0
    internal var reminderSyncState: ReminderSyncState = .disabled
    internal var openClawConnectorHealth: OpenClawConnectorHealth = .off
    internal var openClawConnectorAppAvailability: OpenClawConnectorAppAvailability = .checking
    internal var openClawConnectorAppIssue: String?
    internal var lastReminderSyncAt: Date?
    internal var reminderConnectorEnabled: Bool
    internal var reminderSyncIntervalMinutes: Int
    internal let openClawContextID: UUID
    internal private(set) var voiceInputMode: VoiceInputMode
    internal var isBusy = false
    internal var isListening = false
    internal var isComposingRequest = false
    internal private(set) var currentRequestText = AppConstants.Text.empty
    internal var currentResponse: ChatMessage?

    /// Live audio levels and recognized text while the microphone is open.
    internal private(set) var voiceCapture: VoiceCaptureState = .preparing

    /// Follows the capture stream and ends the recording when it finishes on its own.
    @ObservationIgnored private var voiceUpdatesTask: Task<Void, Never>?
    internal var isShortcutAvailable = false
    internal var inputFocusRequest = 0
    internal var conversationClearConfirmationIsPresented = false
    internal var activityClearConfirmationIsPresented = false
    internal var modelRemovalConfirmationIsPresented = false
    internal var searchIndexClearConfirmationIsPresented = false
    internal private(set) var pendingOpenClawRequest: OpenClawRequestIntent?
    internal var presentedError: LocalAssistantError?
    internal private(set) var availableFileMatchItemIDs: Set<UUID> = []
    private var hasStarted = false

    @ObservationIgnored
    internal var reminderSyncTask: Task<Void, Never>?

    @ObservationIgnored
    internal var connectorHealthTask: Task<Void, Never>?

    @ObservationIgnored
    internal var indexingQueue: [(
        rootID: UUID,
        trigger: IndexingTrigger,
        batchID: UUID?
    )] = []

    @ObservationIgnored
    internal var indexingWorker: Task<Void, Never>?

    @ObservationIgnored
    internal var activeIndexingTask: Task<IndexingOutcome, Error>?

    internal var activeIndexingRootID: UUID?

    @ObservationIgnored
    internal var activeIndexingBatchID: UUID?

    @ObservationIgnored
    internal var dirtyIndexRequests: [UUID: (
        trigger: IndexingTrigger,
        batchID: UUID?
    )] = [:]

    @ObservationIgnored
    internal var monitoringDebounceTasks: [UUID: Task<Void, Never>] = [:]

    @ObservationIgnored
    internal let services: ServiceContainer

    /// Creates app state with a fresh in-process service container.
    /// - Parameter services: Local-only dependencies used by the app.
    internal init(services: ServiceContainer = ServiceContainer()) {
        self.services = services
        reminderConnectorEnabled = UserDefaults.standard.bool(
            forKey: ReminderConstants.Preferences.connectorEnabledKey
        )
        let storedSyncInterval = UserDefaults.standard.integer(
            forKey: ReminderConstants.Preferences.syncIntervalMinutesKey
        )
        reminderSyncIntervalMinutes = ReminderConstants.Preferences.allowedSyncIntervalMinutes
            .contains(storedSyncInterval)
            ? storedSyncInterval
            : ReminderConstants.Preferences.defaultSyncIntervalMinutes
        if let storedContext = UserDefaults.standard.string(
            forKey: ReminderConstants.Preferences.openClawContextIDKey
        ).flatMap(UUID.init(uuidString:)) {
            openClawContextID = storedContext
        } else {
            let contextID = UUID()
            openClawContextID = contextID
            UserDefaults.standard.set(
                contextID.uuidString.lowercased(),
                forKey: ReminderConstants.Preferences.openClawContextIDKey
            )
        }
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
        defer {
            isBusy = false
            isStarting = false
        }
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
            lastReminderSyncAt = try await services.reminders.lastSuccessfulSync()
            reminderSyncState = reminderConnectorEnabled ? .idle : .disabled
            restartReminderSyncLoop()
            restartConnectorHealthMonitor()
            await refreshReminderSnapshotIfStale()
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
        let priorHistory = messages
        queryText = AppConstants.Text.empty
        currentRequestText = question
        isComposingRequest = false
        currentResponse = nil
        let userMessage = ChatMessage.user(question)
        messages.append(userMessage)
        isBusy = true
        defer { isBusy = false }
        do {
            if let pendingRequest = pendingOpenClawRequest {
                try await services.database.insertChatMessage(userMessage)
                await handleReminderConfirmationReply(
                    question,
                    pendingRequest: pendingRequest
                )
                return
            }
            let response = try await services.assistant.answer(
                question: question,
                history: priorHistory,
                persistHistory: true
            )
            if let openClawRequest = response.openClawRequest {
                switch openClawRequest.authorization {
                case .explicitInvocation:
                    try await performOpenClawRequest(openClawRequest)
                case let .confirmedReminderMutation(kind):
                    pendingOpenClawRequest = openClawRequest
                    try await appendAssistantMessage(
                        ReminderStrings.mutationConfirmationMessage(
                            kind: kind,
                            request: openClawRequest.message
                        )
                    )
                }
                return
            }
            let assistantMessage = ChatMessage(
                id: UUID(),
                role: .assistant,
                text: response.answer,
                createdAt: Date(),
                citations: response.citations,
                fileMatches: response.alternatives,
                reminderMatches: response.reminderMatches,
                reminderPresentation: response.reminderPresentation
            )
            messages.append(assistantMessage)
            currentResponse = assistantMessage
            availableFileMatchItemIDs.formUnion(
                response.alternatives.map(\.item.id)
            )
        } catch {
            await presentConversationError(error)
        }
    }

    /// Interprets a natural confirmation reply locally and keeps unclear or failed requests pending.
    /// - Parameters:
    ///   - reply: User's newest conversational confirmation response.
    ///   - pendingRequest: Exact reminder request that remains unsent.
    private func handleReminderConfirmationReply(
        _ reply: String,
        pendingRequest: OpenClawRequestIntent
    ) async {
        do {
            let decision = try await services.assistant.reminderConfirmationDecision(
                reply: reply,
                request: pendingRequest
            )
            switch decision {
            case .confirm:
                let health = await services.reminderSpool.connectorHealth()
                openClawConnectorHealth = health
                guard health != .updateRequired else {
                    try await appendAssistantMessage(
                        ReminderStrings.connectorRuntimeUpdateConversation
                    )
                    return
                }
                do {
                    try await performOpenClawRequest(pendingRequest)
                    pendingOpenClawRequest = nil
                } catch {
                    await presentConversationError(error)
                }
            case .decline:
                pendingOpenClawRequest = nil
                try await appendAssistantMessage(
                    ReminderStrings.reminderConfirmationDeclined
                )
            case .unclear:
                try await appendAssistantMessage(
                    ReminderStrings.reminderConfirmationUnclear
                )
            }
        } catch {
            await presentConversationError(error)
        }
    }

    /// Sends one already-authorized exact request and refreshes reminders after success.
    /// - Parameter request: Explicit or user-confirmed OpenClaw request intent.
    /// - Throws: Connector, response-validation, or private-history persistence errors.
    private func performOpenClawRequest(_ request: OpenClawRequestIntent) async throws {
        let answer = try await services.reminders.askOpenClaw(
            OpenClawRequestDraft(
                message: request.message,
                contextID: openClawContextID
            ),
            authorization: request.authorization,
            connectorEnabled: reminderConnectorEnabled
        )
        try await appendAssistantMessage(answer)
        Task { [weak self] in
            await self?.syncReminders(presentErrors: false)
        }
    }

    /// Adds a privacy-safe request failure to the conversation instead of opening a dialog.
    /// - Parameter error: Local or Connector failure approved for user presentation.
    internal func presentConversationError(_ error: Error) async {
        let detail: String
        if let localError = error as? LocalAssistantError {
            detail = localError.localizedDescription
        } else {
            detail = LocalAssistantError.unexpected(
                error.localizedDescription
            ).localizedDescription
        }
        if detail.localizedCaseInsensitiveContains(
            ReminderConstants.Connector.invalidRequestErrorDetail
        ) {
            openClawConnectorHealth = .updateRequired
        }
        let text = ReminderStrings.conversationalError(detail)
        do {
            try await appendAssistantMessage(text)
        } catch {
            let message = ChatMessage(
                id: UUID(),
                role: .assistant,
                text: text,
                createdAt: Date(),
                citations: [],
                fileMatches: [],
                reminderMatches: []
            )
            messages.append(message)
            currentResponse = message
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
            let updates = try await services.voice.startRecording()
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
            withExtendedLifetime(resolved.access) {
                NSWorkspace.shared.activateFileViewerSelecting([resolved.actionURL])
            }
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
            withExtendedLifetime(resolved.access) {
                _ = NSWorkspace.shared.open(resolved.actionURL)
            }
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

    /// Opens the in-app OpenClaw setup guide inside the existing main window.
    internal func showOpenClawSetup() {
        activeScreen = .openClawSetup
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
        reminderSyncTask?.cancel()
        reminderSyncTask = nil
        connectorHealthTask?.cancel()
        connectorHealthTask = nil
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
