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
    var offlineStatus: OfflineStatus = .checking
    var modelCapabilities: [LocalModelCapabilityStatus] = []
    var modelStorageByteCount: Int64 = 0
    var isBusy = false
    var isListening = false
    var isShortcutAvailable = false
    var inputFocusRequest = 0
    var conversationClearConfirmationIsPresented = false
    var presentedError: LocalAssistantError?
    private(set) var availableFileMatchItemIDs: Set<UUID> = []
    private var hasStarted = false

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
            let storedMessages = try await services.database.fetchChatMessages(
                limit: AppConstants.Chat.historyLimit
            )
            messages = try await restoreSavedMessages(in: storedMessages)
            try await refreshFileMatchAvailability()
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
            indexedRoots = try await services.database.fetchRoots()
            await index(root: root)
        } catch {
            handle(error)
        }
    }

    /// Refreshes every currently authorized root sequentially.
    internal func indexAll() async {
        for root in indexedRoots {
            await index(root: root)
            if presentedError != nil { break }
        }
    }

    /// Refreshes one authorized root under an active read-only security scope.
    /// - Parameter root: Folder authorization to scan and index.
    internal func index(root: AuthorizedRoot) async {
        guard isBusy == false else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let access = try services.authorization.beginAccess(to: root)
            _ = try await services.indexing.index(root: root, access: access) { [weak self] value in
                await MainActor.run { self?.indexingProgress = value }
            }
            indexedRoots = try await services.database.fetchRoots()
            try await refreshFileMatchAvailability()
        } catch {
            indexingProgress.state = .failed
            handle(error)
        }
    }

    /// Revokes a folder bookmark and deletes its dependent private index records.
    /// - Parameter root: Folder authorization to forget.
    internal func remove(root: AuthorizedRoot) async {
        do {
            try await services.database.deleteRoot(id: root.id)
            indexedRoots = try await services.database.fetchRoots()
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

    /// Starts local microphone capture after loading Whisper on first use.
    internal func startListening() async {
        guard isListening == false, isBusy == false else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await services.voice.startRecording()
            isListening = true
        } catch {
            handle(error)
        }
    }

    /// Stops local capture, transcribes it, and immediately submits the request.
    internal func stopListening() async {
        guard isListening, isBusy == false else { return }
        isListening = false
        isBusy = true
        do {
            queryText = try await services.voice.stopAndTranscribe()
            isBusy = false
            await submit()
        } catch {
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

    /// Returns to the assistant screen and focuses its composer.
    internal func showAssistant() {
        activeScreen = .assistant
        requestInputFocus()
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
        var availableItemIDs: Set<UUID> = []
        for itemID in itemIDs {
            if try await services.database.fetchItem(id: itemID) != nil {
                availableItemIDs.insert(itemID)
            }
        }
        availableFileMatchItemIDs = availableItemIDs
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
