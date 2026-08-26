import Foundation

/// Stored ownership domains that keep CloudBase-only and paired reminders separate.
enum ReminderOwnership: String, Codable, CaseIterable, Sendable {
    case localAssistant
    case openClaw
    case unknown
}

/// User-facing reminder cached from one complete CloudBase snapshot.
struct ReminderItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let text: String
    let date: String?
    let startTime: String?
    let endTime: String?
    let tag: String?
    let link: String?
    let managedBy: String?
    let clientRequestId: String?
    let syncPairId: String?
    let sourceMessageId: String?
    let ownership: ReminderOwnership
    let contentHash: String
    let lastSyncedAt: Date

    /// Creates a normalized cache item from an untrusted connector record.
    /// - Parameters:
    ///   - remote: Validated flat CloudBase reminder record.
    ///   - contentHash: Stable hash of every remotely controlled field.
    ///   - syncedAt: Completion time of the full snapshot.
    internal init(
        remote: RemoteReminderItem,
        contentHash: String,
        syncedAt: Date
    ) {
        id = remote.id
        text = remote.text
        date = remote.date
        startTime = remote.startTime
        endTime = remote.endTime
        tag = remote.tag
        link = remote.link
        managedBy = remote.managedBy
        clientRequestId = remote.clientRequestId
        syncPairId = remote.syncPairId
        sourceMessageId = remote.sourceMessageId
        if remote.syncPairId != nil || remote.sourceMessageId != nil {
            ownership = .openClaw
        } else if remote.managedBy == ReminderConstants.Identity.localAssistantOwner,
                  let clientRequestID = remote.clientRequestId,
                  UUID(uuidString: clientRequestID) != nil {
            ownership = .localAssistant
        } else {
            ownership = .unknown
        }
        self.contentHash = contentHash
        lastSyncedAt = syncedAt
    }

    /// Creates a cache item directly for tests and local presentation.
    internal init(
        id: String,
        text: String,
        date: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        tag: String? = nil,
        link: String? = nil,
        managedBy: String? = nil,
        clientRequestId: String? = nil,
        syncPairId: String? = nil,
        sourceMessageId: String? = nil,
        ownership: ReminderOwnership,
        contentHash: String = AppConstants.Text.empty,
        lastSyncedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.tag = tag
        self.link = link
        self.managedBy = managedBy
        self.clientRequestId = clientRequestId
        self.syncPairId = syncPairId
        self.sourceMessageId = sourceMessageId
        self.ownership = ownership
        self.contentHash = contentHash
        self.lastSyncedAt = lastSyncedAt
    }
}

/// Flat reminder document returned by the CloudBase list endpoint.
struct RemoteReminderItem: Decodable, Hashable, Sendable {
    let id: String
    let text: String
    let date: String?
    let startTime: String?
    let endTime: String?
    let tag: String?
    let link: String?
    let managedBy: String?
    let clientRequestId: String?
    let syncPairId: String?
    let sourceMessageId: String?

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case text
        case date
        case startTime
        case endTime
        case tag
        case link
        case managedBy
        case clientRequestId
        case syncPairId
        case sourceMessageId
    }
}

/// Ranked reminder returned by deterministic, lexical, vector, and temporal retrieval.
struct ReminderSearchResult: Identifiable, Codable, Hashable, Sendable {
    let item: ReminderItem
    let score: Double
    let explanation: String

    /// Uses the reminder record identifier for stable SwiftUI cards.
    var id: String { item.id }
}

/// Current connector and full-snapshot synchronization state.
enum ReminderSyncState: String, Sendable {
    case disabled
    case idle
    case syncing
    case failed
}

/// Live health derived only from the separate connector's local status document.
enum OpenClawConnectorHealth: String, Sendable {
    case off
    case checking
    case notDetected
    case updateRequired
    case runningUnverified
    case runningUnreachable
    case ready
    case needsAttention
}

/// Current place from which macOS can launch the separate setup app.
enum OpenClawConnectorAppAvailability: String, Sendable {
    case checking
    case installed
    case nearby
    case diskImage
    case incompatible
    case missing
}

/// Non-secret heartbeat written into the owner-only connector spool.
struct OpenClawConnectorStatusDocument: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let runtimeContractVersion: Int?
    let running: Bool
    let lastSeenAt: String
    let lastSuccessAt: String?
    let lastError: String?
    let pid: Int
}

/// Exact A2A message routed to OpenClaw after the required local authorization.
struct OpenClawRequestDraft: Hashable, Sendable {
    let message: String
    let contextID: UUID
}

/// Local authorization proving why one exact request may cross the Connector boundary.
enum OpenClawRequestAuthorization: Hashable, Sendable {
    case explicitInvocation
    case confirmedReminderMutation(ReminderMutationKind)
}

/// Outbound request selected by local inference before presentation applies its safety gate.
struct OpenClawRequestIntent: Hashable, Sendable {
    let message: String
    let authorization: OpenClawRequestAuthorization
}

/// Reminder changes that require an explicit confirmation before OpenClaw is contacted.
enum ReminderMutationKind: String, Codable, Hashable, Sendable {
    case create
    case update
    case remove
}

/// Local-model interpretation of the user's conversational confirmation reply.
enum ReminderConfirmationDecision: String, Hashable, Sendable {
    case confirm
    case decline
    case unclear
}

/// Card treatment retained with a reminder answer in private conversation history.
enum ReminderCardPresentation: String, Codable, Hashable, Sendable {
    case focused
    case grouped
}

/// Read or confirmation-gated write intent selected by local inference.
enum ReminderAssistantPlan: Hashable, Sendable {
    case list(query: String)
    case get(query: String)
    case mutate(kind: ReminderMutationKind, request: String)
}

/// JSON payload union used only by the local connector spool.
struct ReminderTaskPayload: Codable, Hashable, Sendable {
    var message: String? = nil

    /// Empty payload used for a complete snapshot request.
    static let empty = ReminderTaskPayload()
}

/// Task written by the sandboxed app for the separate connector process.
struct ReminderConnectorRequest: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let taskId: UUID
    let contextId: UUID?
    let skill: String
    let operation: String
    let idempotencyKey: UUID
    let calendarPolicy: String
    let confirmed: Bool
    let authorization: String?
    let payload: ReminderTaskPayload
}

/// Typed failure returned by the OpenClaw bridge or local connector.
struct ReminderConnectorError: Codable, Hashable, Sendable {
    let kind: String
    let message: String
    let retryable: Bool
}

/// Payload returned by reminder snapshot or OpenClaw agent chat.
struct ReminderConnectorPayload: Decodable, Hashable, Sendable {
    let success: Bool?
    let data: [RemoteReminderItem]?
    let dataIsArray: Bool
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case success
        case data
        case message
    }

    /// Decodes list and exact-read payloads into one normalized reminder array.
    /// - Parameter decoder: Connector response payload decoder.
    /// - Throws: A decoding error when the remote payload has an unexpected shape.
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        if let items = try? container.decode([RemoteReminderItem].self, forKey: .data) {
            data = items
            dataIsArray = true
        } else if let item = try? container.decode(RemoteReminderItem.self, forKey: .data) {
            data = [item]
            dataIsArray = false
        } else {
            data = nil
            dataIsArray = false
        }
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

/// Response read back from the connector's owner-only spool.
struct ReminderConnectorResponse: Decodable, Hashable, Sendable {
    let schemaVersion: Int
    let taskId: UUID
    let contextId: UUID?
    let status: String
    let calendarChanged: Bool?
    let payload: ReminderConnectorPayload?
    let error: ReminderConnectorError?
}
