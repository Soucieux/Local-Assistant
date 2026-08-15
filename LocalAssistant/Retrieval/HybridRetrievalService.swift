import Foundation

/// Combines filename, path, FTS5, vector, recency, and alias signals.
actor HybridRetrievalService {
    private let database: AssistantDatabase
    private let embeddings: LocalEmbeddingService

    /// Creates a hybrid retrieval service over private local storage.
    /// - Parameters:
    ///   - database: Embedded SQLite index.
    ///   - embeddings: Local Qwen embedding adapter.
    internal init(database: AssistantDatabase, embeddings: LocalEmbeddingService) {
        self.database = database
        self.embeddings = embeddings
    }

    /// Finds and explains the best local file matches.
    /// - Parameter query: Normalized search request and filters.
    /// - Returns: Ranked, source-cited file results.
    /// - Throws: A local database or inference error.
    internal func search(_ query: SearchQuery) async throws -> [SearchResult] {
        let aliases = try await database.fetchAliases()
        let searchText = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedText = expand(searchText, aliases: aliases)
        let candidateLimit = max(query.limit, AppConstants.Chat.retrievalCandidateLimit)
        let typeItems = try await database.items(kinds: query.filter.kinds, limit: candidateLimit)
        let metadataItems: [IndexedItem] = if expandedText.isEmpty {
            []
        } else {
            try await database.metadataSearch(
                text: expandedText,
                kinds: query.filter.kinds,
                limit: candidateLimit
            )
        }
        let keywordHits: [KeywordHit] = if expandedText.isEmpty {
            []
        } else {
            try await database.keywordSearch(
                text: expandedText,
                kinds: query.filter.kinds,
                limit: candidateLimit
            )
        }
        let semanticHits: [SemanticHit]
        if expandedText.isEmpty == false {
            let vector = try await embeddings.embedQuery(expandedText)
            semanticHits = try await database.semanticSearch(
                embedding: vector,
                kinds: query.filter.kinds,
                limit: candidateLimit
            )
        } else {
            semanticHits = []
        }

        var accumulators: [UUID: ScoreAccumulator] = [:]
        addFileTypes(items: typeItems, to: &accumulators)
        addMetadata(items: metadataItems, queryText: searchText, to: &accumulators)
        addKeywords(hits: keywordHits, to: &accumulators)
        addSemantic(hits: semanticHits, to: &accumulators)

        let matchedAlias = aliases.contains { alias in
            searchText.localizedCaseInsensitiveContains(alias.phrase)
        }
        var results: [SearchResult] = []
        for (itemID, accumulator) in accumulators {
            guard let item = try await database.fetchItem(id: itemID),
                  matches(item: item, filter: query.filter) else { continue }
            let scored = finalize(
                accumulator: accumulator,
                item: item,
                queryText: searchText,
                matchedAlias: matchedAlias
            )
            results.append(scored)
        }
        return Array(results.sorted { $0.score.total > $1.score.total }.prefix(query.limit))
    }

    /// Adds private phrase expansions without replacing the user's original words.
    /// - Parameters:
    ///   - text: Original search text.
    ///   - aliases: Private terminology mappings.
    /// - Returns: Expanded query text.
    private func expand(_ text: String, aliases: [PersonalAlias]) -> String {
        let expansions = aliases.compactMap { alias in
            text.localizedCaseInsensitiveContains(alias.phrase) ? alias.expansion : nil
        }
        guard expansions.isEmpty == false else { return text }
        return ([text] + expansions).joined(separator: AppConstants.Text.space)
    }

    /// Adds hard file-type matches before relevance signals are fused.
    /// - Parameters:
    ///   - items: Items fetched by their indexed category.
    ///   - accumulators: Mutable per-item score state.
    private func addFileTypes(
        items: [IndexedItem],
        to accumulators: inout [UUID: ScoreAccumulator]
    ) {
        for (rank, item) in items.enumerated() {
            var accumulator = accumulators[item.id] ?? ScoreAccumulator()
            accumulator.fileType = 1
            accumulator.reciprocalRank += reciprocal(rank: rank)
            accumulators[item.id] = accumulator
        }
    }

    /// Adds metadata ranks and literal name/path scores.
    /// - Parameters:
    ///   - items: Ordered metadata matches.
    ///   - queryText: Original search text.
    ///   - accumulators: Mutable per-item score state.
    private func addMetadata(
        items: [IndexedItem],
        queryText: String,
        to accumulators: inout [UUID: ScoreAccumulator]
    ) {
        for (rank, item) in items.enumerated() {
            var accumulator = accumulators[item.id] ?? ScoreAccumulator()
            if item.displayName.compare(queryText, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                accumulator.exactName = 1
            } else if item.displayName.localizedCaseInsensitiveContains(queryText) {
                accumulator.exactName = 0.65
            }
            if item.relativePath.localizedCaseInsensitiveContains(queryText) { accumulator.path = 1 }
            accumulator.reciprocalRank += reciprocal(rank: rank)
            accumulators[item.id] = accumulator
        }
    }

    /// Adds FTS ranks and the strongest keyword excerpt per file.
    /// - Parameters:
    ///   - hits: Ordered FTS5 matches.
    ///   - accumulators: Mutable per-item score state.
    private func addKeywords(hits: [KeywordHit], to accumulators: inout [UUID: ScoreAccumulator]) {
        for (rank, hit) in hits.enumerated() {
            var accumulator = accumulators[hit.itemID] ?? ScoreAccumulator()
            accumulator.keyword = max(accumulator.keyword, 1 / Double(rank + 1))
            accumulator.reciprocalRank += reciprocal(rank: rank)
            if accumulator.keywordEvidence == nil {
                accumulator.keywordEvidence = (hit.chunkID, hit.text)
            }
            accumulators[hit.itemID] = accumulator
        }
    }

    /// Adds semantic similarities and the closest excerpt per file.
    /// - Parameters:
    ///   - hits: Ordered sqlite-vec neighbors.
    ///   - accumulators: Mutable per-item score state.
    private func addSemantic(hits: [SemanticHit], to accumulators: inout [UUID: ScoreAccumulator]) {
        for (rank, hit) in hits.enumerated() {
            let similarity = max(0, 1 - hit.distance)
            guard similarity >= RetrievalConstants.minimumSemanticSimilarity else { continue }
            var accumulator = accumulators[hit.itemID] ?? ScoreAccumulator()
            if similarity > accumulator.semantic {
                accumulator.semantic = similarity
                accumulator.semanticEvidence = (hit.chunkID, hit.text)
            }
            accumulator.reciprocalRank += reciprocal(rank: rank)
            accumulators[hit.itemID] = accumulator
        }
    }

    /// Converts raw signals into an explainable result.
    /// - Parameters:
    ///   - accumulator: Raw fused signals.
    ///   - item: Matching indexed item.
    ///   - queryText: Original user request.
    ///   - matchedAlias: Whether private terminology expanded the query.
    /// - Returns: Calibrated search result with evidence.
    private func finalize(
        accumulator: ScoreAccumulator,
        item: IndexedItem,
        queryText: String,
        matchedAlias: Bool
    ) -> SearchResult {
        let recency = recencyScore(date: item.modifiedAt)
        let alias = matchedAlias ? 1.0 : 0.0
        let total = accumulator.exactName * RetrievalConstants.exactNameWeight
            + accumulator.path * RetrievalConstants.pathWeight
            + accumulator.keyword * RetrievalConstants.keywordWeight
            + accumulator.semantic * RetrievalConstants.semanticWeight
            + accumulator.fileType * RetrievalConstants.fileTypeWeight
            + recency * RetrievalConstants.recencyWeight
            + alias * RetrievalConstants.aliasWeight
            + accumulator.reciprocalRank
        let normalized = min(1, total / 10)
        let confidence: ConfidenceLevel = if normalized >= RetrievalConstants.highConfidenceThreshold {
            .high
        } else if normalized >= RetrievalConstants.mediumConfidenceThreshold {
            .medium
        } else {
            .low
        }
        let evidence = accumulator.keywordEvidence ?? accumulator.semanticEvidence
        let citations = evidence.map { chunkID, text in
            [
                EvidenceCitation(
                    id: UUID(),
                    itemID: item.id,
                    chunkID: chunkID,
                    absolutePath: item.url.path,
                    displayName: item.displayName,
                    excerpt: excerpt(text),
                    pageNumber: nil,
                    sectionName: nil,
                    modifiedAt: item.modifiedAt
                )
            ]
        } ?? []
        return SearchResult(
            id: item.id,
            item: item,
            score: ScoreBreakdown(
                exactName: accumulator.exactName,
                path: accumulator.path,
                keyword: accumulator.keyword,
                semantic: accumulator.semantic,
                fileType: accumulator.fileType,
                recency: recency,
                personalAlias: alias,
                reciprocalRank: accumulator.reciprocalRank,
                total: total
            ),
            confidence: confidence,
            explanation: explanation(
                accumulator: accumulator,
                matchedAlias: matchedAlias
            ),
            citations: citations
        )
    }

    /// Applies user-selected filters after source metadata is loaded.
    /// - Parameters:
    ///   - item: Candidate indexed item.
    ///   - filter: Optional query constraints.
    /// - Returns: `true` when the item remains eligible.
    private func matches(item: IndexedItem, filter: SearchFilter) -> Bool {
        if filter.rootIDs.isEmpty == false && filter.rootIDs.contains(item.rootID) == false { return false }
        if filter.kinds.isEmpty == false && filter.kinds.contains(item.kind) == false { return false }
        if let modifiedAfter = filter.modifiedAfter,
           (item.modifiedAt ?? .distantPast) < modifiedAfter { return false }
        if let modifiedBefore = filter.modifiedBefore,
           (item.modifiedAt ?? .distantFuture) > modifiedBefore { return false }
        if let minimumBytes = filter.minimumBytes, item.byteCount < minimumBytes { return false }
        if let maximumBytes = filter.maximumBytes, item.byteCount > maximumBytes { return false }
        return true
    }

    /// Returns an age-decayed modification score.
    /// - Parameter date: Optional modification date.
    /// - Returns: Value between zero and one.
    private func recencyScore(date: Date?) -> Double {
        guard let date else { return 0 }
        let days = max(0, Date().timeIntervalSince(date) / 86_400)
        return exp(-days / 365)
    }

    /// Returns a reciprocal-rank-fusion contribution.
    /// - Parameter rank: Zero-based rank.
    /// - Returns: Small rank-stabilizing score.
    private func reciprocal(rank: Int) -> Double {
        1 / (RetrievalConstants.reciprocalRankConstant + Double(rank + 1))
    }

    /// Produces a bounded excerpt without changing source content.
    /// - Parameter text: Extracted chunk text.
    /// - Returns: Bounded display excerpt.
    private func excerpt(_ text: String) -> String {
        guard text.count > RetrievalConstants.maximumExcerptCharacters else { return text }
        let end = text.index(text.startIndex, offsetBy: RetrievalConstants.maximumExcerptCharacters)
        return String(text[..<end]) + AppConstants.Text.ellipsis
    }

    /// Explains the strongest deterministic matching signals.
    /// - Parameters:
    ///   - accumulator: Raw fused signals.
    ///   - matchedAlias: Whether a private alias contributed.
    /// - Returns: Concise user-visible reason summary.
    private func explanation(
        accumulator: ScoreAccumulator,
        matchedAlias: Bool
    ) -> String {
        var reasons: [String] = []
        if accumulator.exactName == 1 { reasons.append(RetrievalStrings.exactNameMatch) }
        else if accumulator.exactName > 0 { reasons.append(RetrievalStrings.nameMatch) }
        if accumulator.path > 0 { reasons.append(RetrievalStrings.pathMatch) }
        if accumulator.keyword > 0 { reasons.append(RetrievalStrings.keywordMatch) }
        if accumulator.semantic > 0 { reasons.append(RetrievalStrings.semanticMatch) }
        if matchedAlias { reasons.append(RetrievalStrings.aliasMatch) }
        return RetrievalStrings.matchSummary(
            reasons: reasons,
            matchesFileType: accumulator.fileType > 0
        )
    }
}

/// Mutable internal state used while fusing search channels.
private struct ScoreAccumulator {
    var exactName = 0.0
    var path = 0.0
    var keyword = 0.0
    var semantic = 0.0
    var fileType = 0.0
    var reciprocalRank = 0.0
    var keywordEvidence: (UUID, String)?
    var semanticEvidence: (UUID, String)?
}
