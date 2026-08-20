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
    private(set) var monitoredRootIDs: Set<UUID> = []
    var indexingRuns: [IndexingRunRecord] = []
    var indexingItemsByRun: [UUID: [IndexingItemRecord]] = [:]
    var indexActivityEvents: [IndexActivityEventRecord] = []
    var offlineStatus: OfflineStatus = .checking
    var modelCapabilities: [LocalModelCapabilityStatus] = []
    var modelStorageByteCount: Int64 = 0
    var isBusy = false
    var isListening = false

    /// Live audio levels and recognized text while the microphone is open.
    private(set) var voiceCapture: VoiceCaptureState = .preparing

    /// Follows the capture stream and ends the recording when it finishes on its own.
    @ObservationIgnored private var voiceUpdatesTask: Task<Void, Never>?
    var isShortcutAvailable = false
    var inputFocusRequest = 0
    var conversationClearConfirmationIsPresented = false
    var activityClearConfirmationIsPresented = false
    var presentedError: LocalAssistantError?
    private(set) var availableFileMatchItemIDs: Set<UUID> = []
    private var hasStarted = false

    @ObservationIgnored
    private var indexingQueue: [(
        rootID: UUID,
        trigger: IndexingTrigger,
        batchID: UUID?
    )] = []

    @ObservationIgnored
    private var indexingWorker: Task<Void, Never>?

    @ObservationIgnored
    private var activeIndexingTask: Task<IndexingOutcome, Error>?

    private var activeIndexingRootID: UUID?

    @ObservationIgnored
    private var activeIndexingBatchID: UUID?

    @ObservationIgnored
    private var dirtyIndexRequests: [UUID: (
        trigger: IndexingTrigger,
        batchID: UUID?
    )] = [:]

    @ObservationIgnored
    private var monitoringDebounceTasks: [UUID: Task<Void, Never>] = [:]

    @ObservationIgnored
    let services: ServiceContainer

    /// Creates app state with a fresh in-process service container.
    /// - Parameter services: Local-only dependencies used by the app.
    internal init(services: ServiceContainer = ServiceContainer()) {
        self.services = services
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

    /// Submits one plain-language request to local conversation or file retrieval.
    internal func submit() async {
        let question = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard question.isEmpty == false, isBusy == false else { return }
        queryText = AppConstants.Text.empty
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
            availableFileMatchItemIDs.formUnion(
                response.alternatives.map(\.item.id)
            )
        } catch {
            handle(error)
        }
    }

    /// Requests read-only access to a new folder and indexes it.
    internal func addIndexedRoot() async {
        do {
            guard let root = try await services.authorization.authorizeNewRoot() else { return }
            try await services.database.upsertRoot(root)
            try await services.database.setMonitoringEnabled(true, rootID: root.id)
            indexedRoots = try await services.database.fetchRoots()
            pausedMonitoringRootIDs.remove(root.id)
            do {
                try startMonitoring(root)
            } catch {
                try? await recordActivityEvent(root: root, kind: .monitoringUnavailable)
                handle(error)
            }
            requestIndex(root: root, trigger: .manual)
        } catch {
            handle(error)
        }
    }

    /// Refreshes every currently authorized root sequentially.
    internal func indexAll() {
        let batchID = UUID()
        for root in indexedRoots {
            requestIndex(root: root, trigger: .manual, batchID: batchID)
        }
    }

    /// Queues one authorized root for a manual incremental update.
    /// - Parameter root: Folder authorization to scan and index.
    internal func index(root: AuthorizedRoot) {
        requestIndex(root: root, trigger: .manual)
    }

    /// Revokes a folder bookmark and deletes its dependent private index records.
    /// - Parameter root: Folder authorization to forget.
    internal func remove(root: AuthorizedRoot) async {
        do {
            stopMonitoring(rootID: root.id)
            monitoringDebounceTasks.removeValue(forKey: root.id)?.cancel()
            indexingQueue.removeAll { $0.rootID == root.id }
            dirtyIndexRequests.removeValue(forKey: root.id)
            indexingProgressByRoot.removeValue(forKey: root.id)
            try await services.database.deleteRoot(id: root.id)
            indexedRoots = try await services.database.fetchRoots()
            pausedMonitoringRootIDs.remove(root.id)
            try await refreshFileMatchAvailability()
        } catch {
            handle(error)
        }
    }

    /// Deletes persisted local chat history and clears the visible conversation.
    internal func clearConversation() async {
        do {
            try await services.database.clearChatMessages()
            messages = []
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

    /// Opens Settings inside the existing main window.
    internal func showSettings() {
        activeScreen = .settings
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

    /// Reports whether any folder is currently being indexed.
    internal var isIndexing: Bool {
        activeIndexingRootID != nil
    }

    /// Returns whether one folder owns the active indexing run.
    /// - Parameter rootID: Authorized folder identifier.
    /// - Returns: `true` only while that folder is actively indexing.
    internal func indexingIsActive(rootID: UUID) -> Bool {
        activeIndexingRootID == rootID
    }

    /// Returns whether automatic updates are paused for one folder.
    /// - Parameter rootID: Authorized folder identifier.
    /// - Returns: `true` when monitoring is persistently paused.
    internal func monitoringIsPaused(rootID: UUID) -> Bool {
        pausedMonitoringRootIDs.contains(rootID)
    }

    /// Returns whether the native watcher is currently active for one folder.
    /// - Parameter rootID: Authorized folder identifier.
    /// - Returns: `true` when a process-lifetime FSEvents stream is running.
    internal func monitoringIsActive(rootID: UUID) -> Bool {
        monitoredRootIDs.contains(rootID)
    }

    /// Cancels the active run and pauses automatic updates for its folder.
    /// - Parameter rootID: Identifier of the actively indexed folder.
    internal func pauseIndexing(rootID: UUID) {
        guard activeIndexingRootID == rootID else { return }
        indexingProgress.state = .stopping
        indexingProgressByRoot[rootID]?.state = .stopping
        if let activeIndexingBatchID {
            indexingQueue.removeAll { $0.batchID == activeIndexingBatchID }
        }
        activeIndexingTask?.cancel()
        Task { await pauseMonitoring(rootID: rootID) }
    }

    /// Pauses automatic updates for one authorized folder.
    /// - Parameter rootID: Authorized folder identifier.
    internal func pauseMonitoring(rootID: UUID) async {
        guard let root = indexedRoots.first(where: { $0.id == rootID }) else { return }
        do {
            try await services.database.setMonitoringEnabled(false, rootID: rootID)
            pausedMonitoringRootIDs.insert(rootID)
            stopMonitoring(rootID: rootID)
            monitoringDebounceTasks.removeValue(forKey: rootID)?.cancel()
            indexingQueue.removeAll { $0.rootID == rootID && $0.trigger != .manual }
            try await recordActivityEvent(root: root, kind: .monitoringPaused)
        } catch {
            handle(error)
        }
    }

    /// Resumes automatic updates and immediately schedules a catch-up scan.
    /// - Parameter rootID: Authorized folder identifier.
    internal func resumeMonitoring(rootID: UUID) async {
        guard let root = indexedRoots.first(where: { $0.id == rootID }) else { return }
        do {
            try startMonitoring(root)
            do {
                try await services.database.setMonitoringEnabled(true, rootID: rootID)
            } catch {
                stopMonitoring(rootID: rootID)
                throw error
            }
            pausedMonitoringRootIDs.remove(rootID)
            try await recordActivityEvent(root: root, kind: .monitoringResumed)
            requestIndex(root: root, trigger: .automatic)
        } catch {
            handle(error)
        }
    }

    /// Requests confirmation before retained indexing activity is cleared.
    internal func requestActivityClearConfirmation() {
        activityClearConfirmationIsPresented = true
    }

    /// Dismisses the activity-clear confirmation without changing history.
    internal func dismissActivityClearConfirmation() {
        activityClearConfirmationIsPresented = false
    }

    /// Clears retained activity without changing indexed content or authorizations.
    internal func confirmActivityClear() async {
        activityClearConfirmationIsPresented = false
        do {
            try await services.database.clearIndexActivity()
            indexingRuns = []
            indexingItemsByRun = [:]
            indexActivityEvents = []
        } catch {
            handle(error)
        }
    }

    /// Loads file-level details for one expanded activity run.
    internal func loadIndexingItems(runID: UUID) async {
        guard indexingItemsByRun[runID] == nil else { return }
        do {
            indexingItemsByRun[runID] = try await services.database.fetchIndexingItems(
                runID: runID
            )
        } catch {
            handle(error)
        }
    }

    /// Stops process-lifetime monitors and outstanding indexing work during termination.
    internal func shutdown() async {
        let worker = indexingWorker
        let activeTask = activeIndexingTask
        indexingQueue = []
        dirtyIndexRequests = [:]
        worker?.cancel()
        activeTask?.cancel()
        for task in monitoringDebounceTasks.values { task.cancel() }
        monitoringDebounceTasks = [:]
        services.monitoring.stopAll()
        monitoredRootIDs = []
        if let activeTask { _ = await activeTask.result }
        if let worker { await worker.value }
        indexingWorker = nil
        activeIndexingTask = nil
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

    /// Coalesces one folder request into the sequential indexing queue.
    /// - Parameters:
    ///   - root: Authorized folder to update.
    ///   - trigger: Source that requested the update.
    ///   - batchID: Optional identifier shared by an Update All request.
    private func requestIndex(
        root: AuthorizedRoot,
        trigger: IndexingTrigger,
        batchID: UUID? = nil
    ) {
        if activeIndexingRootID == root.id {
            if dirtyIndexRequests[root.id] == nil || trigger == .manual {
                dirtyIndexRequests[root.id] = (trigger: trigger, batchID: batchID)
            }
            return
        }
        if let offset = indexingQueue.firstIndex(where: { $0.rootID == root.id }) {
            if trigger == .manual {
                indexingQueue[offset].trigger = .manual
                indexingQueue[offset].batchID = batchID
            }
        } else {
            indexingQueue.append((rootID: root.id, trigger: trigger, batchID: batchID))
        }
        guard indexingWorker == nil else { return }
        indexingWorker = Task { [weak self] in
            await self?.drainIndexingQueue()
        }
    }

    /// Runs coalesced folder updates one at a time.
    private func drainIndexingQueue() async {
        while Task.isCancelled == false, indexingQueue.isEmpty == false {
            let request = indexingQueue.removeFirst()
            guard let root = indexedRoots.first(where: { $0.id == request.rootID }) else {
                continue
            }
            if request.trigger != .manual,
               pausedMonitoringRootIDs.contains(root.id) {
                continue
            }
            activeIndexingBatchID = request.batchID
            await performIndex(root: root, trigger: request.trigger)
            activeIndexingBatchID = nil
            if let followUp = dirtyIndexRequests.removeValue(forKey: root.id),
               followUp.trigger == .manual
                    || pausedMonitoringRootIDs.contains(root.id) == false {
                indexingQueue.append(
                    (rootID: root.id, trigger: followUp.trigger, batchID: followUp.batchID)
                )
            }
        }
        indexingWorker = nil
        if Task.isCancelled == false, indexingQueue.isEmpty == false {
            indexingWorker = Task { [weak self] in
                await self?.drainIndexingQueue()
            }
        }
    }

    /// Executes one cancellable indexing run under a bounded read-only access scope.
    /// - Parameters:
    ///   - root: Authorized folder to scan read-only.
    ///   - trigger: Source that requested this run.
    private func performIndex(root: AuthorizedRoot, trigger: IndexingTrigger) async {
        activeIndexingRootID = root.id
        let startingProgress = IndexingProgress(
            runID: nil,
            rootID: root.id,
            folderName: root.displayName,
            trigger: trigger,
            state: .scanning,
            currentPath: nil,
            currentItemState: nil,
            processedItems: 0,
            totalItems: 0,
            skippedItems: 0,
            newItems: 0,
            updatedItems: 0,
            unchangedItems: 0,
            removedItems: 0,
            fractionCompleted: 0
        )
        indexingProgress = startingProgress
        indexingProgressByRoot[root.id] = startingProgress
        let access: SecurityScopedAccess
        do {
            access = try services.authorization.beginAccess(to: root)
        } catch {
            indexingProgress.state = .failed
            indexingProgressByRoot[root.id]?.state = .failed
            activeIndexingRootID = nil
            handle(error)
            return
        }
        let service = services.indexing
        let task = Task {
            try await service.index(
                root: root,
                access: access,
                trigger: trigger
            ) { [weak self] value in
                await MainActor.run {
                    self?.indexingProgress = value
                    if let rootID = value.rootID {
                        self?.indexingProgressByRoot[rootID] = value
                    }
                }
            }
        }
        activeIndexingTask = task
        do {
            let outcome = try await task.value
            indexedRoots = try await services.database.fetchRoots()
            if outcome.newItems > 0 || outcome.removedItems > 0 {
                try await refreshFileMatchAvailability()
            }
        } catch is CancellationError {
            indexingProgress.state = .stopped
            indexingProgressByRoot[root.id]?.state = .stopped
        } catch {
            indexingProgress.state = .failed
            indexingProgressByRoot[root.id]?.state = .failed
            handle(error)
        }
        activeIndexingTask = nil
        activeIndexingRootID = nil
        try? await services.database.purgeIndexActivity(before: activityRetentionCutoff)
        try? await refreshIndexActivity()
    }

    /// Starts a process-lifetime FSEvents stream for one enabled folder.
    /// - Parameter root: Authorized folder whose read-only bookmark is resolved.
    /// - Throws: A local permission or indexing error when monitoring cannot start.
    private func startMonitoring(_ root: AuthorizedRoot) throws {
        let access = try services.authorization.beginAccess(to: root)
        monitoredRootIDs.remove(root.id)
        do {
            try services.monitoring.start(root: root, access: access) { [weak self] rootID in
                Task { @MainActor in
                    self?.folderDidChange(rootID: rootID)
                }
            }
        } catch {
            monitoredRootIDs.remove(root.id)
            throw error
        }
        monitoredRootIDs.insert(root.id)
    }

    /// Stops one native watcher and updates observable monitoring state.
    /// - Parameter rootID: Authorized folder identifier.
    private func stopMonitoring(rootID: UUID) {
        services.monitoring.stop(rootID: rootID)
        monitoredRootIDs.remove(rootID)
    }

    /// Debounces rapid filesystem events before scheduling one incremental update.
    /// - Parameter rootID: Identifier reported by the native watcher.
    private func folderDidChange(rootID: UUID) {
        guard pausedMonitoringRootIDs.contains(rootID) == false,
              offlineStatus == .ready,
              indexedRoots.contains(where: { $0.id == rootID }) else { return }
        monitoringDebounceTasks[rootID]?.cancel()
        monitoringDebounceTasks[rootID] = Task { [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: AppConstants.Indexing.changeDebounceNanoseconds
                )
            } catch {
                return
            }
            guard let self,
                  let root = self.indexedRoots.first(where: { $0.id == rootID }),
                  self.pausedMonitoringRootIDs.contains(rootID) == false else { return }
            self.monitoringDebounceTasks[rootID] = nil
            try? await self.recordActivityEvents(
                root: root,
                kinds: [.changesDetected, .updateScheduled]
            )
            self.requestIndex(root: root, trigger: .automatic)
        }
    }

    /// Appends and refreshes one monitoring event.
    /// - Parameters:
    ///   - root: Authorized folder snapshot stored with the event.
    ///   - kind: Monitoring or indexing event to retain.
    /// - Throws: A local database error when the event cannot be retained.
    private func recordActivityEvent(
        root: AuthorizedRoot,
        kind: IndexActivityEventKind
    ) async throws {
        try await recordActivityEvents(root: root, kinds: [kind])
    }

    /// Appends related monitoring events and refreshes history once.
    /// - Parameters:
    ///   - root: Authorized folder snapshot stored with each event.
    ///   - kinds: Ordered events to retain.
    /// - Throws: A local database error when an event or refresh fails.
    private func recordActivityEvents(
        root: AuthorizedRoot,
        kinds: [IndexActivityEventKind]
    ) async throws {
        let occurredAt = Date()
        for (offset, kind) in kinds.enumerated() {
            try await services.database.insertIndexActivityEvent(
                IndexActivityEventRecord(
                    id: UUID(),
                    rootID: root.id,
                    folderName: root.displayName,
                    kind: kind,
                    occurredAt: occurredAt.addingTimeInterval(Double(offset) / 1_000_000)
                )
            )
        }
        try await services.database.purgeIndexActivity(before: activityRetentionCutoff)
        indexActivityEvents = try await services.database.fetchIndexActivityEvents()
    }

    /// Refreshes retained run summaries and monitoring events.
    /// - Throws: A local database error when retained history cannot be read.
    private func refreshIndexActivity() async throws {
        indexingRuns = try await services.database.fetchIndexingRuns()
        indexActivityEvents = try await services.database.fetchIndexActivityEvents()
        let retainedRunIDs = Set(indexingRuns.map(\.id))
        indexingItemsByRun = indexingItemsByRun.filter { retainedRunIDs.contains($0.key) }
    }

    /// Rolling cutoff applied uniformly to all activity rows.
    private var activityRetentionCutoff: Date {
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
    private func refreshFileMatchAvailability() async throws {
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
    private func handle(_ error: Error) {
        if let localError = error as? LocalAssistantError {
            presentedError = localError
        } else {
            presentedError = .unexpected(error.localizedDescription)
        }
    }
}
