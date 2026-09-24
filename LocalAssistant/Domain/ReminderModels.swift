import Foundation

/// Stored ownership domains that keep CloudBase-only and paired reminders separate.
internal enum ReminderOwnership: String, Codable, CaseIterable, Sendable {
    case localAssistant
    case openClaw
    case unknown
}

/// User-facing reminder cached from one complete CloudBase snapshot.
internal struct ReminderItem: Identifiable, Codable, Hashable, Sendable {
    internal let id: String
    internal let text: String
    internal let date: String?
    internal let startTime: String?
    internal let endTime: String?
    internal let tag: String?
    internal let link: String?
    internal let managedBy: String?
    internal let clientRequestId: String?
    internal let syncPairId: String?
    internal let sourceMessageId: String?
    internal let ownership: ReminderOwnership
    internal let contentHash: String
    internal let lastSyncedAt: Date

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
    /// - Parameters:
    ///   - id: CloudBase record identifier.
    ///   - text: Reminder title text.
    ///   - date: Stored calendar date, absent when undated.
    ///   - startTime: Optional stored wall-clock start.
    ///   - endTime: Optional stored wall-clock end.
    ///   - tag: Optional grouping tag.
    ///   - link: Optional external link field.
    ///   - managedBy: Owner marker written by the creating client.
    ///   - clientRequestId: Idempotency identifier for a Local Assistant creation.
    ///   - syncPairId: Pair marker set when OpenClaw manages the reminder.
    ///   - sourceMessageId: Originating message marker set by OpenClaw.
    ///   - ownership: Resolved ownership domain for this record.
    ///   - contentHash: Stable hash of every remotely controlled field.
    ///   - lastSyncedAt: Completion time of the snapshot that produced it.
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

    /// The tag as it should be shown, or `nil` when the reminder carries no usable tag.
    ///
    /// A tag made only of whitespace counts as absent, so it never opens a blank section.
    internal var trimmedTag: String? {
        guard let trimmed = tag?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }

    /// Stable identifier of the tag section this reminder is presented under.
    ///
    /// Tags compare case-insensitively, and a reminder without a usable tag joins the
    /// untagged section. The list summary and the card grid both group by this value, so the
    /// number of groups a summary states always equals the number of sections shown. The
    /// prefix keeps a tag that happens to spell the untagged identifier in its own section.
    internal var tagGroupIdentifier: String {
        guard let trimmedTag else {
            return ReminderConstants.Presentation.untaggedGroupIdentifier
        }
        return ReminderConstants.Presentation.tagGroupPrefix + trimmedTag.lowercased()
    }
}

/// Flat reminder document returned by the CloudBase list endpoint.
internal struct RemoteReminderItem: Decodable, Hashable, Sendable {
    internal let id: String
    internal let text: String
    internal let date: String?
    internal let startTime: String?
    internal let endTime: String?
    internal let tag: String?
    internal let link: String?
    internal let managedBy: String?
    internal let clientRequestId: String?
    internal let syncPairId: String?
    internal let sourceMessageId: String?

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
internal struct ReminderSearchResult: Identifiable, Codable, Hashable, Sendable {
    internal let item: ReminderItem
    internal let score: Double
    internal let explanation: String

    /// Uses the reminder record identifier for stable SwiftUI cards.
    internal var id: String { item.id }
}

/// Current connector and full-snapshot synchronization state.
internal enum ReminderSyncState: String, Sendable {
    case disabled
    case idle
    case syncing
    case failed
}

/// Live health derived only from the separate connector's local status document.
internal enum OpenClawConnectorHealth: String, Sendable {
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
internal enum OpenClawConnectorAppAvailability: String, Sendable {
    case checking
    case installed
    case nearby
    case diskImage
    case incompatible
    case missing
}

/// Non-secret heartbeat written into the owner-only connector spool.
internal struct OpenClawConnectorStatusDocument: Codable, Hashable, Sendable {
    internal let schemaVersion: Int
    internal let runtimeContractVersion: Int?
    internal let running: Bool
    internal let lastSeenAt: String
    internal let lastSuccessAt: String?
    internal let lastError: String?
    internal let pid: Int
}

/// Exact A2A message routed to OpenClaw after the required local authorization.
internal struct OpenClawRequestDraft: Hashable, Sendable {
    internal let message: String
    internal let contextID: UUID
}

/// Local authorization proving why one exact request may cross the Connector boundary.
internal enum OpenClawRequestAuthorization: Hashable, Sendable {
    case explicitInvocation
    case confirmedReminderMutation(ReminderMutationKind)
}

/// Outbound request selected by local inference before presentation applies its safety gate.
internal struct OpenClawRequestIntent: Hashable, Sendable {
    internal let message: String
    internal let authorization: OpenClawRequestAuthorization
}

/// Reminder changes that require an explicit confirmation before OpenClaw is contacted.
internal enum ReminderMutationKind: String, Codable, Hashable, Sendable {
    case create
    case update
    case remove
}

/// Local-model interpretation of the user's conversational confirmation reply.
internal enum ReminderConfirmationDecision: String, Hashable, Sendable {
    case confirm
    case decline
    case unclear
}

/// Card treatment retained with a reminder answer in private conversation history.
internal enum ReminderCardPresentation: String, Codable, Hashable, Sendable {
    case focused
    case grouped
}

/// Read or confirmation-gated write intent selected by local inference.
internal enum ReminderAssistantPlan: Hashable, Sendable {
    case list(query: String)
    case get(query: String)
    case mutate(kind: ReminderMutationKind, request: String)
}

/// JSON payload union used only by the local connector spool.
internal struct ReminderTaskPayload: Codable, Hashable, Sendable {
    internal var message: String? = nil

    /// Empty payload used for a complete snapshot request.
    internal static let empty = ReminderTaskPayload()
}

/// Task written by the sandboxed app for the separate connector process.
internal struct ReminderConnectorRequest: Codable, Hashable, Sendable {
    internal let schemaVersion: Int
    internal let taskId: UUID
    internal let contextId: UUID?
    internal let skill: String
    internal let operation: String
    internal let idempotencyKey: UUID
    internal let calendarPolicy: String
    internal let confirmed: Bool
    internal let authorization: String?
    internal let payload: ReminderTaskPayload
}

/// Typed failure returned by the OpenClaw bridge or local connector.
internal struct ReminderConnectorError: Codable, Hashable, Sendable {
    internal let kind: String
    internal let message: String
    internal let retryable: Bool
}

/// Payload returned by reminder snapshot or OpenClaw agent chat.
internal struct ReminderConnectorPayload: Decodable, Hashable, Sendable {
    internal let success: Bool?
    internal let data: [RemoteReminderItem]?
    internal let dataIsArray: Bool
    internal let message: String?

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
internal struct ReminderConnectorResponse: Decodable, Hashable, Sendable {
    internal let schemaVersion: Int
    internal let taskId: UUID
    internal let contextId: UUID?
    internal let status: String
    internal let calendarChanged: Bool?
    internal let payload: ReminderConnectorPayload?
    internal let error: ReminderConnectorError?
}
