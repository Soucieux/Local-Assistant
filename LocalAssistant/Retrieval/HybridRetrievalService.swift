import Foundation

/// Combines filename, path, FTS5, vector, and recency signals.
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
        let searchText = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateLimit = max(query.limit, AppConstants.Chat.retrievalCandidateLimit)
        let queryEmbedding: [Float]? = if searchText.isEmpty {
            nil
        } else {
            try await embeddings.embedQuery(searchText)
        }

        var accumulators = try await baseAccumulators(
            query: query,
            searchText: searchText,
            queryEmbedding: queryEmbedding,
            candidateLimit: candidateLimit
        )
        if let queryEmbedding {
            try await applyFolderScope(
                query: query,
                searchText: searchText,
                embedding: queryEmbedding,
                candidateLimit: candidateLimit,
                accumulators: &accumulators
            )
        }

        let candidateItems = try await database.fetchItems(ids: Set(accumulators.keys))
        var results: [SearchResult] = []
        for (itemID, accumulator) in accumulators {
            guard let item = candidateItems[itemID],
                  matches(item: item, filter: query.filter) else { continue }
            let result = finalize(
                accumulator: accumulator,
                item: item,
                matchesFileType: query.filter.kinds.isEmpty == false
            )
            guard searchText.isEmpty || result.score.hasQueryEvidence else { continue }
            results.append(result)
        }
        return Array(results.sorted { $0.score.total > $1.score.total }.prefix(query.limit))
    }

    /// Fetches every retrieval channel and fuses their signals into per-item scores.
    /// - Parameters:
    ///   - query: Normalized search request and filters.
    ///   - searchText: Trimmed query text, empty for a broad type-only listing.
    ///   - queryEmbedding: Local embedding of the query, absent for a broad listing.
    ///   - candidateLimit: Maximum candidates requested per channel.
    /// - Returns: Per-item accumulators before folder scoping is applied.
    /// - Throws: A local database or inference error.
    private func baseAccumulators(
        query: SearchQuery,
        searchText: String,
        queryEmbedding: [Float]?,
        candidateLimit: Int
    ) async throws -> [UUID: ScoreAccumulator] {
        let typeItems: [IndexedItem] = if searchText.isEmpty {
            try await database.items(kinds: query.filter.kinds, limit: candidateLimit)
        } else {
            []
        }
        let metadataItems: [IndexedItem] = if searchText.isEmpty {
            []
        } else {
            try await database.metadataSearch(
                text: searchText,
                kinds: query.filter.kinds,
                limit: candidateLimit
            )
        }
        let keywordHits: [KeywordHit] = if searchText.isEmpty {
            []
        } else {
            try await database.keywordSearch(
                text: searchText,
                kinds: query.filter.kinds,
                limit: candidateLimit
            )
        }
        let semanticHits: [SemanticHit]
        if let queryEmbedding {
            semanticHits = try await database.semanticSearch(
                embedding: queryEmbedding,
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
        return accumulators
    }

    /// Promotes items inside a strongly matched folder and restricts results to it when named.
    /// - Parameters:
    ///   - query: Normalized search request and filters.
    ///   - searchText: Trimmed query text used to find candidate folder scopes.
    ///   - embedding: Local query embedding reused from ordinary semantic retrieval.
    ///   - candidateLimit: Maximum descendants requested per matched folder.
    ///   - accumulators: Per-item score state updated in place.
    /// - Throws: A local database error when folder or descendant lookups fail.
    private func applyFolderScope(
        query: SearchQuery,
        searchText: String,
        embedding: [Float],
        candidateLimit: Int,
        accumulators: inout [UUID: ScoreAccumulator]
    ) async throws {
        let folderScopes = try await folderScopeMatches(
            text: searchText,
            embedding: embedding,
            limit: candidateLimit
        )
        let literalScopes = folderScopes.filter(\.isLiteral)
        if query.filter.kinds == Set([IndexedItemKind.folder]) {
            if literalScopes.isEmpty == false {
                let literalFolderIDs = Set(literalScopes.map(\.folder.id))
                accumulators = accumulators.filter { literalFolderIDs.contains($0.key) }
            }
            return
        }
        let activeScopes = literalScopes.isEmpty ? folderScopes : literalScopes
        var literalDescendantIDs: Set<UUID> = []
        for (rank, scope) in activeScopes.enumerated() {
            let descendants = try await database.descendants(
                of: scope.folder,
                kinds: query.filter.kinds,
                limit: candidateLimit
            )
            addFolderScope(
                items: descendants,
                scope: scope,
                rank: rank,
                to: &accumulators
            )
            if scope.isLiteral {
                literalDescendantIDs.formUnion(descendants.map(\.id))
            }
        }
        if literalScopes.isEmpty == false {
            accumulators = accumulators.filter {
                literalDescendantIDs.contains($0.key)
            }
        }
    }

    /// Seeds broad type-only listing requests before relevance signals are fused.
    /// - Parameters:
    ///   - items: Items fetched by their indexed category.
    ///   - accumulators: Mutable per-item score state.
    private func addFileTypes(
        items: [IndexedItem],
        to accumulators: inout [UUID: ScoreAccumulator]
    ) {
        for (rank, item) in items.enumerated() {
            var accumulator = accumulators[item.id] ?? ScoreAccumulator()
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
        let tokens = SearchTextEscaping.tokens(queryText)
        for (rank, item) in items.enumerated() {
            var accumulator = accumulators[item.id] ?? ScoreAccumulator()
            if item.displayName.compare(queryText, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                accumulator.exactName = 1
            } else if item.displayName.localizedCaseInsensitiveContains(queryText) {
                accumulator.exactName = 0.65
            } else if tokens.isEmpty == false,
                      tokens.allSatisfy(item.displayName.localizedCaseInsensitiveContains) {
                accumulator.exactName = RetrievalConstants.metadataTokenMatch
            }
            if item.relativePath.localizedCaseInsensitiveContains(queryText) {
                accumulator.path = RetrievalConstants.metadataPathMatch
            } else if tokens.isEmpty == false,
                      tokens.allSatisfy(item.relativePath.localizedCaseInsensitiveContains) {
                accumulator.path = RetrievalConstants.metadataPathTokenMatch
            }
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

    /// Finds folders whose names, paths, or generated local context define a strong scope.
    /// - Parameters:
    ///   - text: Normalized user search text.
    ///   - embedding: One local query embedding reused from ordinary semantic retrieval.
    ///   - limit: Maximum metadata and semantic candidates to inspect.
    /// - Returns: Strongest folder scopes in descending confidence order.
    /// - Throws: A local database error when candidates cannot be loaded.
    private func folderScopeMatches(
        text: String,
        embedding: [Float],
        limit: Int
    ) async throws -> [FolderScopeMatch] {
        let metadataFolders = try await database.metadataSearch(
            text: text,
            kinds: Set([IndexedItemKind.folder]),
            limit: limit
        )
        var strengths: [UUID: Double] = [:]
        let literalFolderIDs = Set(metadataFolders.map(\.id))
        for folder in metadataFolders {
            strengths[folder.id] = metadataFolderScopeStrength(folder: folder, text: text)
        }

        let semanticFolders = try await database.semanticSearch(
            embedding: embedding,
            kinds: Set([IndexedItemKind.folder]),
            limit: limit
        )
        for hit in semanticFolders {
            let similarity = max(0, 1 - hit.distance)
            guard similarity >= RetrievalConstants.minimumFolderScopeSemanticSimilarity else {
                continue
            }
            strengths[hit.itemID] = max(strengths[hit.itemID] ?? 0, similarity)
        }

        let foldersByID = try await database.fetchItems(ids: Set(strengths.keys))
        return strengths.compactMap { itemID, strength in
            guard let folder = foldersByID[itemID], folder.kind == .folder else { return nil }
            return FolderScopeMatch(
                folder: folder,
                strength: strength,
                isLiteral: literalFolderIDs.contains(itemID)
            )
        }
        .sorted { left, right in left.strength > right.strength }
        .prefix(RetrievalConstants.maximumFolderScopeCount)
        .map { $0 }
    }

    /// Calculates deterministic folder-scope strength from an exact metadata result.
    /// - Parameters:
    ///   - folder: Folder returned by literal name and path search.
    ///   - text: Normalized query used for the metadata search.
    /// - Returns: Strong path signal used to promote contained items.
    private func metadataFolderScopeStrength(folder: IndexedItem, text: String) -> Double {
        if folder.displayName.compare(
            text,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) == .orderedSame {
            return RetrievalConstants.exactFolderScopeMatch
        }
        if folder.displayName.localizedCaseInsensitiveContains(text) {
            return RetrievalConstants.nameFolderScopeMatch
        }
        return RetrievalConstants.pathFolderScopeMatch
    }

    /// Promotes descendants and records the matched folder as visible evidence.
    /// - Parameters:
    ///   - items: Files and folders contained by the matched scope.
    ///   - scope: Matched folder and calibrated strength.
    ///   - rank: Position among bounded folder scopes.
    ///   - accumulators: Mutable per-item score state.
    private func addFolderScope(
        items: [IndexedItem],
        scope: FolderScopeMatch,
        rank: Int,
        to accumulators: inout [UUID: ScoreAccumulator]
    ) {
        for item in items {
            var accumulator = accumulators[item.id] ?? ScoreAccumulator()
            if scope.strength > accumulator.path {
                accumulator.path = scope.strength
                accumulator.folderEvidence = scope.folder.displayName
            }
            accumulator.reciprocalRank += reciprocal(rank: rank)
            accumulators[item.id] = accumulator
        }
    }

    /// Converts raw signals into an explainable result.
    /// - Parameters:
    ///   - accumulator: Raw fused signals.
    ///   - item: Matching indexed item.
    ///   - matchesFileType: Whether the item satisfies an explicit user-requested kind.
    /// - Returns: Calibrated search result with evidence.
    private func finalize(
        accumulator: ScoreAccumulator,
        item: IndexedItem,
        matchesFileType: Bool
    ) -> SearchResult {
        let recency = recencyScore(date: item.modifiedAt)
        let fileType = matchesFileType ? 1.0 : 0.0
        let total = accumulator.exactName * RetrievalConstants.exactNameWeight
            + accumulator.path * RetrievalConstants.pathWeight
            + accumulator.keyword * RetrievalConstants.keywordWeight
            + accumulator.semantic * RetrievalConstants.semanticWeight
            + fileType * RetrievalConstants.fileTypeWeight
            + recency * RetrievalConstants.recencyWeight
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
                fileType: fileType,
                recency: recency,
                reciprocalRank: accumulator.reciprocalRank,
                total: total
            ),
            confidence: confidence,
            explanation: explanation(
                accumulator: accumulator,
                matchesFileType: matchesFileType,
                confidence: confidence
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
    ///   - matchesFileType: Whether the item satisfies an explicit user-requested kind.
    ///   - confidence: Calibrated certainty used to avoid overstating semantic evidence.
    /// - Returns: Concise user-visible reason summary.
    private func explanation(
        accumulator: ScoreAccumulator,
        matchesFileType: Bool,
        confidence: ConfidenceLevel
    ) -> String {
        if accumulator.exactName == 1 { return RetrievalStrings.exactNameEvidence }
        if let folderName = accumulator.folderEvidence {
            return RetrievalStrings.folderScopeEvidence(folderName)
        }
        if accumulator.exactName > 0 { return RetrievalStrings.nameEvidence }
        if accumulator.path > 0 { return RetrievalStrings.pathEvidence }
        if let evidence = accumulator.keywordEvidence?.1 {
            return RetrievalStrings.keywordEvidence(explanationExcerpt(evidence))
        }
        if let evidence = accumulator.semanticEvidence?.1 {
            return RetrievalStrings.semanticEvidence(
                explanationExcerpt(evidence),
                isUncertain: confidence == .low
            )
        }
        return matchesFileType ? RetrievalStrings.fileTypeMatch : RetrievalStrings.fallbackMatch
    }

    /// Produces a compact single-line passage for one result-card explanation.
    /// - Parameter text: Indexed passage that produced the match.
    /// - Returns: Whitespace-normalized evidence bounded for the card layout.
    private func explanationExcerpt(_ text: String) -> String {
        let normalized = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: AppConstants.Text.space)
        guard normalized.count > RetrievalConstants.maximumExplanationEvidenceCharacters else {
            return normalized
        }
        let end = normalized.index(
            normalized.startIndex,
            offsetBy: RetrievalConstants.maximumExplanationEvidenceCharacters
        )
        return String(normalized[..<end]) + AppConstants.Text.ellipsis
    }
}

/// Mutable internal state used while fusing search channels.
private struct ScoreAccumulator {
    var exactName = 0.0
    var path = 0.0
    var keyword = 0.0
    var semantic = 0.0
    var reciprocalRank = 0.0
    var keywordEvidence: (UUID, String)?
    var semanticEvidence: (UUID, String)?
    var folderEvidence: String?
}

/// One folder whose metadata or semantic context can scope descendant retrieval.
private struct FolderScopeMatch {
    let folder: IndexedItem
    let strength: Double
    let isLiteral: Bool
}
