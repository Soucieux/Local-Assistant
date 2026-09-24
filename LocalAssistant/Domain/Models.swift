import Foundation

/// A user-selected directory represented by a security-scoped bookmark.
internal struct AuthorizedRoot: Identifiable, Codable, Hashable, Sendable {
    internal let id: UUID
    internal let displayName: String
    internal let lastKnownPath: String
    internal let bookmarkData: Data
    internal let addedAt: Date
    internal var lastIndexedAt: Date?
    internal var isAvailable: Bool
}

/// Metadata for a file or directory stored in the local index.
internal struct IndexedItem: Identifiable, Codable, Hashable, Sendable {
    internal let id: UUID
    internal let rootID: UUID
    internal let parentID: UUID?
    internal let url: URL
    internal let relativePath: String
    internal let displayName: String
    internal let kind: IndexedItemKind
    internal let contentType: String?
    internal let byteCount: Int64
    internal let createdAt: Date?
    internal let modifiedAt: Date?
    internal let contentHash: String?
    internal let metadataHash: String
    internal let isDirectory: Bool
    internal let isHidden: Bool

    /// Returns the same metadata carrying a different content hash.
    ///
    /// Indexing publishes fresh metadata with the previous hash, then the final hash once
    /// content is processed, so the field-by-field copy lives here instead of in each caller.
    /// - Parameter contentHash: Hash to carry, or `nil` when no content has been indexed.
    /// - Returns: A copy identical in every field except its content hash.
    internal func replacingContentHash(_ contentHash: String?) -> IndexedItem {
        IndexedItem(
            id: id,
            rootID: rootID,
            parentID: parentID,
            url: url,
            relativePath: relativePath,
            displayName: displayName,
            kind: kind,
            contentType: contentType,
            byteCount: byteCount,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            contentHash: contentHash,
            metadataHash: metadataHash,
            isDirectory: isDirectory,
            isHidden: isHidden
        )
    }
}

/// Searchable passage derived from a locally indexed item.
internal struct ContentChunk: Identifiable, Codable, Hashable, Sendable {
    internal let id: UUID
    internal let itemID: UUID
    internal let ordinal: Int
    internal let text: String
    internal let characterStart: Int
    internal let characterEnd: Int
    internal let pageNumber: Int?
    internal let sectionName: String?
    internal let embedding: [Float]?
}

/// Optional constraints applied to a local search.
internal struct SearchFilter: Codable, Hashable, Sendable {
    internal var rootIDs: Set<UUID>
    internal var kinds: Set<IndexedItemKind>
    internal var modifiedAfter: Date?
    internal var modifiedBefore: Date?
    internal var minimumBytes: Int64?
    internal var maximumBytes: Int64?

    /// Creates a filter containing only hard file-type constraints.
    /// - Parameter kinds: Eligible indexed item categories.
    /// - Returns: A search filter with every unrelated constraint disabled.
    internal static func with(kinds: Set<IndexedItemKind>) -> SearchFilter {
        SearchFilter(
            rootIDs: [],
            kinds: kinds,
            modifiedAfter: nil,
            modifiedBefore: nil,
            minimumBytes: nil,
            maximumBytes: nil
        )
    }
}

/// A normalized request sent to the retrieval engine.
internal struct SearchQuery: Codable, Hashable, Sendable {
    internal let text: String
    internal let filter: SearchFilter
    internal let limit: Int
}

/// Explainable components contributing to a result's rank.
internal struct ScoreBreakdown: Codable, Hashable, Sendable {
    internal let exactName: Double
    internal let path: Double
    internal let keyword: Double
    internal let semantic: Double
    internal let fileType: Double
    internal let recency: Double
    internal let reciprocalRank: Double
    internal let total: Double

    /// Neutral ranking values used only when restoring a legacy cited file card.
    internal static let zero = ScoreBreakdown(
        exactName: 0,
        path: 0,
        keyword: 0,
        semantic: 0,
        fileType: 0,
        recency: 0,
        reciprocalRank: 0,
        total: 0
    )

    /// Whether a non-empty query matched something beyond type, recency, or rank position.
    internal var hasQueryEvidence: Bool {
        exactName > 0 || path > 0 || keyword > 0 || semantic > 0
    }
}

/// A bounded excerpt linking an answer to a local file.
internal struct EvidenceCitation: Identifiable, Codable, Hashable, Sendable {
    internal let id: UUID
    internal let itemID: UUID
    internal let chunkID: UUID?
    internal let absolutePath: String
    internal let displayName: String
    internal let excerpt: String
    internal let pageNumber: Int?
    internal let sectionName: String?
    internal let modifiedAt: Date?
}

/// Ranked file match returned by hybrid retrieval.
internal struct SearchResult: Identifiable, Codable, Hashable, Sendable {
    internal let id: UUID
    internal let item: IndexedItem
    internal let score: ScoreBreakdown
    internal let confidence: ConfidenceLevel
    internal let explanation: String
    internal let citations: [EvidenceCitation]
}

/// One item in a local conversation.
internal struct ChatMessage: Identifiable, Codable, Hashable, Sendable {
    internal let id: UUID
    internal let role: MessageRole
    internal let text: String
    internal let createdAt: Date
    internal let citations: [EvidenceCitation]
    internal let fileMatches: [SearchResult]
    internal let reminderMatches: [ReminderSearchResult]
    internal let reminderPresentation: ReminderCardPresentation

    /// Creates one persistable message with any file cards attached to that turn.
    /// - Parameters:
    ///   - id: Stable message identifier.
    ///   - role: Author of the message.
    ///   - text: Visible conversation text.
    ///   - createdAt: Time the message was created.
    ///   - citations: Bounded local evidence used by the answer.
    ///   - fileMatches: Ranked file snapshots displayed beneath the answer.
    ///   - reminderMatches: Ranked reminder snapshots displayed beneath the answer.
    ///   - reminderPresentation: Focused or tag-grouped reminder-card treatment.
    internal init(
        id: UUID,
        role: MessageRole,
        text: String,
        createdAt: Date,
        citations: [EvidenceCitation],
        fileMatches: [SearchResult],
        reminderMatches: [ReminderSearchResult] = [],
        reminderPresentation: ReminderCardPresentation = .focused
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.citations = citations
        self.fileMatches = fileMatches
        self.reminderMatches = reminderMatches
        self.reminderPresentation = reminderPresentation
    }

    /// Decodes current messages and older payloads created before file cards were stored.
    /// - Parameter decoder: JSON decoder reading the private conversation payload.
    /// - Throws: A decoding error when required message fields are invalid.
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(MessageRole.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        citations = try container.decode([EvidenceCitation].self, forKey: .citations)
        fileMatches = try container.decodeIfPresent(
            [SearchResult].self,
            forKey: .fileMatches
        ) ?? []
        reminderMatches = try container.decodeIfPresent(
            [ReminderSearchResult].self,
            forKey: .reminderMatches
        ) ?? []
        reminderPresentation = try container.decodeIfPresent(
            ReminderCardPresentation.self,
            forKey: .reminderPresentation
        ) ?? .focused
    }

    /// Creates a new user-authored message.
    /// - Parameter text: The user's input.
    /// - Returns: A timestamped user message.
    internal static func user(_ text: String) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            role: .user,
            text: text,
            createdAt: Date(),
            citations: [],
            fileMatches: [],
            reminderMatches: [],
            reminderPresentation: .focused
        )
    }

    /// Returns the same saved message with updated visible text and file cards.
    /// - Parameters:
    ///   - text: Card-aware assistant text to display and retain.
    ///   - fileMatches: File cards restored or retained for this message.
    ///   - reminderMatches: Reminder cards restored or retained for this message.
    ///   - reminderPresentation: Optional replacement reminder-card treatment.
    /// - Returns: A replacement preserving the original identity and timestamp.
    internal func restoring(
        text: String,
        fileMatches: [SearchResult],
        reminderMatches: [ReminderSearchResult]? = nil,
        reminderPresentation: ReminderCardPresentation? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            role: role,
            text: text,
            createdAt: createdAt,
            citations: citations,
            fileMatches: fileMatches,
            reminderMatches: reminderMatches ?? self.reminderMatches,
            reminderPresentation: reminderPresentation ?? self.reminderPresentation
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case text
        case createdAt
        case citations
        case fileMatches
        case reminderMatches
        case reminderPresentation
    }
}

/// Local conversational response or evidence-grounded file answer.
internal struct AssistantResponse: Hashable, Sendable {
    internal let answer: String
    internal let citations: [EvidenceCitation]
    internal let alternatives: [SearchResult]
    internal let confidence: ConfidenceLevel
    internal let reminderMatches: [ReminderSearchResult]
    internal let reminderPresentation: ReminderCardPresentation
    internal let openClawRequest: OpenClawRequestIntent?

    /// Creates a conversational, file, or reminder response.
    /// - Parameters:
    ///   - answer: Visible assistant text for this turn.
    ///   - citations: Bounded local evidence supporting the answer.
    ///   - alternatives: Ranked file matches offered alongside the answer.
    ///   - confidence: Calibrated confidence for the grounded result.
    ///   - reminderMatches: Ranked reminders from the hidden local snapshot.
    ///   - reminderPresentation: Focused or tag-grouped reminder-card treatment.
    ///   - openClawRequest: Outbound intent awaiting confirmation, when one applies.
    internal init(
        answer: String,
        citations: [EvidenceCitation],
        alternatives: [SearchResult],
        confidence: ConfidenceLevel,
        reminderMatches: [ReminderSearchResult] = [],
        reminderPresentation: ReminderCardPresentation = .focused,
        openClawRequest: OpenClawRequestIntent? = nil
    ) {
        self.answer = answer
        self.citations = citations
        self.alternatives = alternatives
        self.confidence = confidence
        self.reminderMatches = reminderMatches
        self.reminderPresentation = reminderPresentation
        self.openClawRequest = openClawRequest
    }
}

/// Live progress for a read-only indexing run.
internal struct IndexingProgress: Codable, Hashable, Sendable {
    internal var runID: UUID?
    internal var rootID: UUID?
    internal var folderName: String?
    internal var trigger: IndexingTrigger?
    internal var state: IndexingState
    internal var currentPath: String?
    internal var currentItemState: IndexingItemState?
    internal var processedItems: Int
    internal var totalItems: Int
    internal var skippedItems: Int
    internal var newItems: Int
    internal var updatedItems: Int
    internal var unchangedItems: Int
    internal var removedItems: Int
    internal var fractionCompleted: Double

    internal static let idle = IndexingProgress(
        runID: nil,
        rootID: nil,
        folderName: nil,
        trigger: nil,
        state: .idle,
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
}

/// Durable summary of one automatic, manual, or startup indexing run.
internal struct IndexingRunRecord: Identifiable, Codable, Hashable, Sendable {
    internal let id: UUID
    internal let rootID: UUID
    internal let folderName: String
    internal let folderPath: String
    internal let trigger: IndexingTrigger
    internal var state: IndexingRunState
    internal let startedAt: Date
    internal var finishedAt: Date?
    internal var totalItems: Int
    internal var newItems: Int
    internal var updatedItems: Int
    internal var unchangedItems: Int
    internal var removedItems: Int
    internal var skippedItems: Int
}

/// Durable per-file classification retained for the activity details view.
internal struct IndexingItemRecord: Identifiable, Codable, Hashable, Sendable {
    internal let id: UUID
    internal let runID: UUID
    internal let displayName: String
    internal let relativePath: String
    internal var state: IndexingItemState
    internal var detail: String?
    internal var updatedAt: Date
}

/// Durable non-file event retained in the activity timeline.
internal struct IndexActivityEventRecord: Identifiable, Codable, Hashable, Sendable {
    internal let id: UUID
    internal let rootID: UUID
    internal let folderName: String
    internal let kind: IndexActivityEventKind
    internal let occurredAt: Date
}
