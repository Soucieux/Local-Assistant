import CryptoKit
import Foundation

/// Owns read-only full-snapshot reconciliation and locally authorized OpenClaw requests.
actor ReminderService {
    private let database: AssistantDatabase
    private let embeddings: LocalEmbeddingService
    private let spool: ReminderSpoolService
    private let dateFormatter: DateFormatter
    private let routeParser = AssistantRouteParser()

    /// Creates the reminder coordinator from local-only dependencies.
    /// - Parameters:
    ///   - database: Private snapshot cache.
    ///   - embeddings: Embedded local semantic model.
    ///   - spool: File-only connector transport.
    internal init(
        database: AssistantDatabase,
        embeddings: LocalEmbeddingService,
        spool: ReminderSpoolService
    ) {
        self.database = database
        self.embeddings = embeddings
        self.spool = spool
        dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = ReminderConstants.DateText.calendarDateFormat
        dateFormatter.isLenient = false
    }

    /// Returns the completion time of the latest committed complete snapshot.
    internal func lastSuccessfulSync() async throws -> Date? {
        (try await database.reminderSyncMetadata())?.date
    }

    /// Fetches and atomically commits one complete CloudBase reminder snapshot.
    /// - Parameter connectorEnabled: Explicit user opt-in state.
    /// - Throws: A connector, validation, embedding, or database error before replacement.
    internal func sync(connectorEnabled: Bool) async throws {
        try requireEnabled(connectorEnabled)
        let request = connectorRequest(
            skill: ReminderConstants.Identity.reminderSkill,
            operation: ReminderConstants.Routing.operationList,
            calendarPolicy: ReminderConstants.Identity.calendarPolicyNever,
            confirmed: false,
            payload: .empty
        )
        let response = try await spool.perform(request)
        try await reconcile(response)
    }

    /// Commits the newest launchd-originated snapshot when one is waiting locally.
    /// - Returns: Whether a scheduled response was consumed.
    internal func consumeScheduledSnapshot() async throws -> Bool {
        guard let response = try await spool.takeScheduledSnapshot() else { return false }
        try await reconcile(response)
        return true
    }

    /// Validates, embeds, and atomically replaces the complete local snapshot.
    /// - Parameter response: One connector response from either sync trigger.
    private func reconcile(_ response: ReminderConnectorResponse) async throws {
        let remoteItems = try validatedList(response)
        let syncedAt = Date()
        let reminders = remoteItems.map {
            ReminderItem(
                remote: $0,
                contentHash: contentHash($0),
                syncedAt: syncedAt
            )
        }
        let previousHashes = try await database.reminderContentHashes()
        var changedEmbeddings: [String: [Float]] = [:]
        for reminder in reminders where previousHashes[reminder.id] != reminder.contentHash {
            changedEmbeddings[reminder.id] = try await embeddings.embedDocument(
                embeddingText(reminder)
            )
        }
        try await database.reconcileReminders(
            reminders,
            embeddings: changedEmbeddings,
            syncedAt: syncedAt
        )
    }

    /// Sends one locally authorized OpenClaw request with no reminder or file context.
    /// - Parameters:
    ///   - draft: Exact submitted text and stable A2A conversation identity.
    ///   - authorization: Explicit invocation or a user-confirmed reminder mutation.
    ///   - connectorEnabled: Explicit connector opt-in state.
    /// - Returns: OpenClaw's visible answer text.
    /// - Throws: A connector or response-validation error.
    internal func askOpenClaw(
        _ draft: OpenClawRequestDraft,
        authorization: OpenClawRequestAuthorization,
        connectorEnabled: Bool
    ) async throws -> String {
        try requireEnabled(connectorEnabled)
        guard draft.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              draft.message.count
                <= ReminderConstants.Connector.maximumAgentMessageCharacters else {
            throw LocalAssistantError.connector(ReminderStrings.invalidReminderRoute)
        }
        if case .explicitInvocation = authorization,
           routeParser.isExplicitOpenClawRequest(draft.message) == false {
            throw LocalAssistantError.connector(ReminderStrings.invalidReminderRoute)
        }
        var payload = ReminderTaskPayload()
        payload.message = draft.message
        let authorizationValue: String
        switch authorization {
        case .explicitInvocation:
            authorizationValue = ReminderConstants.Connector.authorizationExplicitOpenClaw
        case .confirmedReminderMutation(_):
            authorizationValue =
                ReminderConstants.Connector.authorizationConfirmedReminderMutation
        }
        let request = connectorRequest(
            skill: ReminderConstants.Identity.agentSkill,
            operation: ReminderConstants.Routing.operationChat,
            calendarPolicy: ReminderConstants.Identity.calendarPolicyOpenClawDefault,
            confirmed: true,
            payload: payload,
            authorization: authorizationValue,
            contextID: draft.contextID
        )
        let response = try await spool.perform(request)
        try validateAgentSuccess(response)
        guard let answer = response.payload?.message?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), answer.isEmpty == false,
           answer.count <= ReminderConstants.Connector.maximumAgentMessageCharacters else {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
        return answer
    }

    /// Creates one exact schema-v1 connector envelope.
    /// - Parameters:
    ///   - skill: Narrow reminder-snapshot or agent lane.
    ///   - operation: Lane-specific list or chat operation.
    ///   - calendarPolicy: Calendar mutation boundary required by the lane.
    ///   - confirmed: Whether the user authorized a write-capable agent request.
    ///   - payload: Field-limited connector request body.
    ///   - authorization: Explicit-name or confirmed-reminder authorization proof.
    ///   - contextID: Stable optional A2A conversation identity.
    /// - Returns: Validated request shape ready for the owner-only spool.
    private func connectorRequest(
        skill: String,
        operation: String,
        calendarPolicy: String,
        confirmed: Bool,
        payload: ReminderTaskPayload,
        authorization: String? = nil,
        contextID: UUID? = nil
    ) -> ReminderConnectorRequest {
        ReminderConnectorRequest(
            schemaVersion: ReminderConstants.Connector.schemaVersion,
            taskId: UUID(),
            contextId: contextID,
            skill: skill,
            operation: operation,
            idempotencyKey: UUID(),
            calendarPolicy: calendarPolicy,
            confirmed: confirmed,
            authorization: authorization,
            payload: payload
        )
    }

    /// Validates the full-list response and every remotely controlled row.
    private func validatedList(_ response: ReminderConnectorResponse) throws -> [RemoteReminderItem] {
        try validateReminderSnapshotSuccess(response)
        guard response.payload?.success == true,
              response.payload?.dataIsArray == true,
              let items = response.payload?.data else {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
        var seen: Set<String> = []
        return try items.map { item in
            guard seen.insert(item.id).inserted else {
                throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
            }
            return try validated(remote: item)
        }
    }

    /// Requires proof that a successful snapshot did not change Calendar.
    private func validateReminderSnapshotSuccess(
        _ response: ReminderConnectorResponse
    ) throws {
        guard response.schemaVersion == ReminderConstants.Connector.schemaVersion,
              response.calendarChanged == false else {
            throw LocalAssistantError.connector(ReminderStrings.calendarBoundaryViolation)
        }
        try requireCompleted(response)
    }

    /// Validates an OpenClaw response without making a false Calendar assertion.
    private func validateAgentSuccess(_ response: ReminderConnectorResponse) throws {
        let successfulStatuses = [
            ReminderConstants.Connector.completedStatus,
            ReminderConstants.Connector.inputRequiredStatus
        ]
        guard response.schemaVersion == ReminderConstants.Connector.schemaVersion,
              response.calendarChanged == nil,
              successfulStatuses.contains(response.status),
              response.error == nil else {
            throw LocalAssistantError.connector(
                response.error?.message ?? ReminderStrings.incompleteSnapshot
            )
        }
    }

    /// Requires a completed connector task with no typed error.
    private func requireCompleted(_ response: ReminderConnectorResponse) throws {
        guard response.status == ReminderConstants.Connector.completedStatus,
              response.error == nil else {
            throw LocalAssistantError.connector(
                response.error?.message ?? ReminderStrings.incompleteSnapshot
            )
        }
    }

    /// Validates and normalizes one remote reminder record.
    private func validated(remote: RemoteReminderItem) throws -> RemoteReminderItem {
        let identifier = remote.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = remote.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard identifier.isEmpty == false,
              text.isEmpty == false,
              text.count <= ReminderConstants.Connector.maximumReminderTextCharacters,
              validDate(remote.date),
              validTime(remote.startTime),
              validTime(remote.endTime),
              validOptional(remote.tag),
              validOptional(remote.link),
              validOptional(remote.managedBy),
              validOptional(remote.clientRequestId),
              validOptional(remote.syncPairId),
              validOptional(remote.sourceMessageId) else {
            throw LocalAssistantError.connector(ReminderStrings.incompleteSnapshot)
        }
        return RemoteReminderItem(
            id: identifier,
            text: text,
            date: remote.date,
            startTime: remote.startTime,
            endTime: remote.endTime,
            tag: remote.tag,
            link: remote.link,
            managedBy: remote.managedBy,
            clientRequestId: remote.clientRequestId,
            syncPairId: remote.syncPairId,
            sourceMessageId: remote.sourceMessageId
        )
    }

    /// Validates an optional calendar date exactly as YYYY-MM-DD.
    private func validDate(_ value: String?) -> Bool {
        guard let value else { return true }
        guard value.range(
            of: #"^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$"#,
            options: .regularExpression
        ) != nil,
        let date = dateFormatter.date(from: value) else {
            return false
        }
        return dateFormatter.string(from: date) == value
    }

    /// Validates an optional 24-hour wall-clock time.
    private func validTime(_ value: String?) -> Bool {
        guard let value else { return true }
        return value.range(
            of: #"^([01]\d|2[0-3]):[0-5]\d$"#,
            options: .regularExpression
        ) != nil
    }

    /// Rejects blank or oversized optional reminder strings.
    private func validOptional(_ value: String?) -> Bool {
        guard let value else { return true }
        return value.isEmpty == false
            && value.count <= ReminderConstants.Connector.maximumOptionalFieldCharacters
    }

    /// Builds deterministic local embedding text from user-visible reminder fields.
    private func embeddingText(_ reminder: ReminderItem) -> String {
        [
            reminder.text,
            reminder.date,
            reminder.startTime,
            reminder.endTime,
            reminder.tag,
            reminder.link
        ].compactMap { $0 }.joined(separator: AppConstants.Text.newline)
    }

    /// Hashes every remotely controlled reminder field with unambiguous length framing.
    private func contentHash(_ item: RemoteReminderItem) -> String {
        let fields = [
            item.id,
            item.text,
            item.date,
            item.startTime,
            item.endTime,
            item.tag,
            item.link,
            item.managedBy,
            item.clientRequestId,
            item.syncPairId,
            item.sourceMessageId
        ]
        let framed = fields.map { value in
            guard let value else { return "-1:" }
            return "\(value.utf8.count):\(value)"
        }.joined(separator: "|")
        return SHA256.hash(data: Data(framed.utf8)).map {
            String(format: "%02x", $0)
        }.joined()
    }

    /// Enforces explicit connector opt-in before writing any task file.
    private func requireEnabled(_ connectorEnabled: Bool) throws {
        guard connectorEnabled else {
            throw LocalAssistantError.connector(ReminderStrings.connectorNotEnabled)
        }
    }
}
