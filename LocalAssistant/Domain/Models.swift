import Foundation

/// A user-selected directory represented by a security-scoped bookmark.
struct AuthorizedRoot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let lastKnownPath: String
    let bookmarkData: Data
    let addedAt: Date
    var lastIndexedAt: Date?
    var isAvailable: Bool
}

/// Metadata for a file or directory stored in the local index.
struct IndexedItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let rootID: UUID
    let parentID: UUID?
    let url: URL
    let relativePath: String
    let displayName: String
    let kind: IndexedItemKind
    let contentType: String?
    let byteCount: Int64
    let createdAt: Date?
    let modifiedAt: Date?
    let contentHash: String?
    let metadataHash: String
    let isDirectory: Bool
    let isHidden: Bool
}

/// Searchable passage derived from a locally indexed item.
struct ContentChunk: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let itemID: UUID
    let ordinal: Int
    let text: String
    let characterStart: Int
    let characterEnd: Int
    let pageNumber: Int?
    let sectionName: String?
    let embedding: [Float]?
}

/// Optional constraints applied to a local search.
struct SearchFilter: Codable, Hashable, Sendable {
    var rootIDs: Set<UUID>
    var kinds: Set<IndexedItemKind>
    var modifiedAfter: Date?
    var modifiedBefore: Date?
    var minimumBytes: Int64?
    var maximumBytes: Int64?

    static let none = SearchFilter(
        rootIDs: [],
        kinds: [],
        modifiedAfter: nil,
        modifiedBefore: nil,
        minimumBytes: nil,
        maximumBytes: nil
    )

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
struct SearchQuery: Codable, Hashable, Sendable {
    let text: String
    let filter: SearchFilter
    let limit: Int
}

/// Explainable components contributing to a result's rank.
struct ScoreBreakdown: Codable, Hashable, Sendable {
    let exactName: Double
    let path: Double
    let keyword: Double
    let semantic: Double
    let fileType: Double
    let recency: Double
    let reciprocalRank: Double
    let total: Double

    /// Neutral ranking values used only when restoring a legacy cited file card.
    static let zero = ScoreBreakdown(
        exactName: 0,
        path: 0,
        keyword: 0,
        semantic: 0,
        fileType: 0,
        recency: 0,
        reciprocalRank: 0,
        total: 0
    )
}

/// A bounded excerpt linking an answer to a local file.
struct EvidenceCitation: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let itemID: UUID
    let chunkID: UUID?
    let absolutePath: String
    let displayName: String
    let excerpt: String
    let pageNumber: Int?
    let sectionName: String?
    let modifiedAt: Date?
}

/// Ranked file match returned by hybrid retrieval.
struct SearchResult: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let item: IndexedItem
    let score: ScoreBreakdown
    let confidence: ConfidenceLevel
    let explanation: String
    let citations: [EvidenceCitation]
}

/// One item in a local conversation.
struct ChatMessage: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let role: MessageRole
    let text: String
    let createdAt: Date
    let citations: [EvidenceCitation]
    let fileMatches: [SearchResult]

    /// Creates one persistable message with any file cards attached to that turn.
    /// - Parameters:
    ///   - id: Stable message identifier.
    ///   - role: Author of the message.
    ///   - text: Visible conversation text.
    ///   - createdAt: Time the message was created.
    ///   - citations: Bounded local evidence used by the answer.
    ///   - fileMatches: Ranked result snapshots displayed beneath the answer.
    internal init(
        id: UUID,
        role: MessageRole,
        text: String,
        createdAt: Date,
        citations: [EvidenceCitation],
        fileMatches: [SearchResult]
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.citations = citations
        self.fileMatches = fileMatches
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
    }

    /// Encodes the visible message and its reusable file-card snapshots.
    /// - Parameter encoder: JSON encoder writing the private conversation payload.
    /// - Throws: An encoding error when the payload cannot be represented.
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(text, forKey: .text)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(citations, forKey: .citations)
        try container.encode(fileMatches, forKey: .fileMatches)
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
            fileMatches: []
        )
    }

    /// Returns the same saved message with updated visible text and file cards.
    /// - Parameters:
    ///   - text: Card-aware assistant text to display and retain.
    ///   - fileMatches: File cards restored or retained for this message.
    /// - Returns: A replacement preserving the original identity and timestamp.
    internal func restoring(
        text: String,
        fileMatches: [SearchResult]
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            role: role,
            text: text,
            createdAt: createdAt,
            citations: citations,
            fileMatches: fileMatches
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case text
        case createdAt
        case citations
        case fileMatches
    }
}

/// Local conversational response or evidence-grounded file answer.
struct AssistantResponse: Codable, Hashable, Sendable {
    let answer: String
    let citations: [EvidenceCitation]
    let alternatives: [SearchResult]
    let confidence: ConfidenceLevel
}

/// Live progress for a read-only indexing run.
struct IndexingProgress: Codable, Hashable, Sendable {
    var runID: UUID?
    var rootID: UUID?
    var folderName: String?
    var trigger: IndexingTrigger?
    var state: IndexingState
    var currentPath: String?
    var currentItemState: IndexingItemState?
    var processedItems: Int
    var totalItems: Int
    var skippedItems: Int
    var newItems: Int
    var updatedItems: Int
    var unchangedItems: Int
    var removedItems: Int
    var fractionCompleted: Double

    static let idle = IndexingProgress(
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
struct IndexingRunRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let rootID: UUID
    let folderName: String
    let folderPath: String
    let trigger: IndexingTrigger
    var state: IndexingRunState
    let startedAt: Date
    var finishedAt: Date?
    var totalItems: Int
    var newItems: Int
    var updatedItems: Int
    var unchangedItems: Int
    var removedItems: Int
    var skippedItems: Int
}

/// Durable per-file classification retained for the activity details view.
struct IndexingItemRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let runID: UUID
    let displayName: String
    let relativePath: String
    var state: IndexingItemState
    var detail: String?
    var updatedAt: Date
}

/// Durable non-file event retained in the activity timeline.
struct IndexActivityEventRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let rootID: UUID
    let folderName: String
    let kind: IndexActivityEventKind
    let occurredAt: Date
}
