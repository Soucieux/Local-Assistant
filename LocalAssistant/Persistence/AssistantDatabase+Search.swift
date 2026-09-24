import Foundation

extension AssistantDatabase {
    /// Fetches indexed items whose stored category matches a hard file-type constraint.
    /// - Parameters:
    ///   - kinds: Eligible item categories.
    ///   - limit: Maximum combined number of items.
    /// - Returns: Matching items ordered by recency and name.
    /// - Throws: A local database error when the query fails.
    internal func items(kinds: Set<IndexedItemKind>, limit: Int) throws -> [IndexedItem] {
        guard kinds.isEmpty == false, limit > 0 else { return [] }
        var items: [IndexedItem] = []
        for kind in orderedKinds(kinds) {
            let statement = try preparedStatement(SQLStatements.fetchItemsByKind)
            defer { recycle(statement) }
            try bind(kind.rawValue, at: 1, in: statement)
            try bind(limit, at: 2, in: statement)
            while try step(statement) {
                items.append(try readIndexedItem(statement))
            }
        }
        let ordered = items.sorted { left, right in
            let leftDate = left.modifiedAt ?? .distantPast
            let rightDate = right.modifiedAt ?? .distantPast
            if leftDate != rightDate { return leftDate > rightDate }
            let order = left.displayName.localizedCaseInsensitiveCompare(right.displayName)
            if order != .orderedSame { return order == .orderedAscending }
            return left.id.uuidString < right.id.uuidString
        }
        return Array(ordered.prefix(limit))
    }

    /// Searches file names and paths without requiring an embedding model.
    /// - Parameters:
    ///   - text: User-entered name or path terms.
    ///   - kinds: Hard item kinds applied before the result limit.
    ///   - limit: Maximum number of metadata matches.
    /// - Returns: Ordered indexed items.
    /// - Throws: A local database error when the query fails.
    internal func metadataSearch(
        text: String,
        kinds: Set<IndexedItemKind>,
        limit: Int
    ) throws -> [IndexedItem] {
        guard limit > 0 else { return [] }
        let tokens = SearchTextEscaping.tokens(text)
        let prefixPattern = RetrievalConstants.prefixPattern(SearchTextEscaping.escapedLike(text))
        let orderedKinds = orderedKinds(kinds)
        let statement = try singleUseStatement(
            SQLStatements.metadataSearch(kindCount: orderedKinds.count, tokenCount: tokens.count)
        )
        defer { recycle(statement) }
        var bindingIndex = try bindKinds(orderedKinds, in: statement)
        for token in tokens {
            let containsPattern = RetrievalConstants.containsPattern(SearchTextEscaping.escapedLike(token))
            try bind(containsPattern, at: bindingIndex, in: statement)
            bindingIndex += 1
            try bind(containsPattern, at: bindingIndex, in: statement)
            bindingIndex += 1
        }
        try bind(text, at: bindingIndex, in: statement)
        bindingIndex += 1
        try bind(prefixPattern, at: bindingIndex, in: statement)
        bindingIndex += 1
        try bind(limit, at: bindingIndex, in: statement)
        var items: [IndexedItem] = []
        while try step(statement) {
            items.append(try readIndexedItem(statement))
        }
        return items
    }

    /// Returns indexed files and folders contained by one matched folder.
    /// - Parameters:
    ///   - folder: Indexed folder that defines the result scope.
    ///   - kinds: Optional hard item kinds applied before limiting descendants.
    ///   - limit: Maximum number of contained items.
    /// - Returns: Direct children first, followed by deeper descendants in path order.
    /// - Throws: A local database error when the query fails.
    internal func descendants(
        of folder: IndexedItem,
        kinds: Set<IndexedItemKind>,
        limit: Int
    ) throws -> [IndexedItem] {
        guard folder.kind == .folder, limit > 0 else { return [] }
        let orderedKinds = orderedKinds(kinds)
        let statement = try singleUseStatement(
            SQLStatements.descendantItems(kindCount: orderedKinds.count)
        )
        defer { recycle(statement) }
        try bind(folder.rootID.uuidString, at: 1, in: statement)
        try bind(folder.id.uuidString, at: 2, in: statement)
        let prefix = SearchTextEscaping.escapedLike(
            folder.url.path + FileConstants.pathSeparator
        )
        try bind(RetrievalConstants.prefixPattern(prefix), at: 3, in: statement)
        var bindingIndex = try bindKinds(orderedKinds, startingAt: 4, in: statement)
        try bind(folder.id.uuidString, at: bindingIndex, in: statement)
        bindingIndex += 1
        try bind(limit, at: bindingIndex, in: statement)
        var items: [IndexedItem] = []
        while try step(statement) {
            items.append(try readIndexedItem(statement))
        }
        return items
    }

    /// Executes a sanitized FTS5 query over names, paths, and extracted text.
    /// - Parameters:
    ///   - text: Plain user query.
    ///   - kinds: Hard item kinds applied before the result limit.
    ///   - limit: Maximum number of chunk matches.
    /// - Returns: Raw full-text hits for later fusion.
    /// - Throws: A local database error when FTS cannot execute.
    internal func keywordSearch(
        text: String,
        kinds: Set<IndexedItemKind>,
        limit: Int
    ) throws -> [KeywordHit] {
        let query = SearchTextEscaping.ftsQuery(text)
        guard query.isEmpty == false, limit > 0 else { return [] }
        let orderedKinds = orderedKinds(kinds)
        let statement = try singleUseStatement(
            SQLStatements.keywordSearch(kindCount: orderedKinds.count)
        )
        defer { recycle(statement) }
        var bindingIndex = try bindKinds(orderedKinds, in: statement)
        try bind(query, at: bindingIndex, in: statement)
        bindingIndex += 1
        try bind(limit, at: bindingIndex, in: statement)
        var hits: [KeywordHit] = []
        while try step(statement) {
            guard let chunkID = UUID(uuidString: requiredText(statement, column: 0)),
                  let itemID = UUID(uuidString: requiredText(statement, column: 1)) else {
                throw LocalAssistantError.database(DatabaseConstants.missingRow)
            }
            hits.append(
                KeywordHit(
                    chunkID: chunkID,
                    itemID: itemID,
                    text: requiredText(statement, column: 2),
                    rank: sqlite3_column_double(statement, 3)
                )
            )
        }
        return hits
    }

    /// Executes a nearest-neighbor query through statically linked sqlite-vec.
    /// - Parameters:
    ///   - embedding: Local query embedding with the configured dimensions.
    ///   - kinds: Hard item kinds enforced through adaptive neighbor batches.
    ///   - limit: Maximum number of vector neighbors.
    /// - Returns: Raw semantic hits for later fusion.
    /// - Throws: A local database error when dimensions or vector search fail.
    internal func semanticSearch(
        embedding: [Float],
        kinds: Set<IndexedItemKind>,
        limit: Int
    ) throws -> [SemanticHit] {
        guard embedding.count == AppConstants.Indexing.embeddingDimensions else {
            throw LocalAssistantError.database(DatabaseConstants.vectorRegistrationFailure)
        }
        guard limit > 0 else { return [] }
        let orderedKinds = orderedKinds(kinds)
        guard orderedKinds.isEmpty == false else {
            return try semanticSearchBatch(
                embedding: embedding,
                orderedKinds: orderedKinds,
                neighborLimit: DatabaseConstants.boundedVectorNeighborCount(limit)
            )
        }

        guard try eligibleVectorRowCount(orderedKinds) > 0 else { return [] }
        let totalVectorCount = try vectorRowCount()
        let maximumNeighborLimit = DatabaseConstants.boundedVectorNeighborCount(totalVectorCount)
        guard maximumNeighborLimit > 0 else { return [] }
        var neighborLimit = min(limit, maximumNeighborLimit)
        while true {
            let hits = try semanticSearchBatch(
                embedding: embedding,
                orderedKinds: orderedKinds,
                neighborLimit: neighborLimit
            )
            if hits.count >= limit || neighborLimit == maximumNeighborLimit {
                return Array(hits.prefix(limit))
            }
            neighborLimit = DatabaseConstants.nextVectorNeighborCount(
                current: neighborLimit,
                available: maximumNeighborLimit
            )
        }
    }

    /// Searches one ordered vector-neighbor batch and filters it to bound kinds.
    /// - Parameters:
    ///   - embedding: Local query embedding with the configured dimensions.
    ///   - orderedKinds: Stable hard-kind bindings.
    ///   - neighborLimit: Number of unfiltered nearest neighbors to inspect.
    /// - Returns: Eligible semantic hits in distance order.
    /// - Throws: A local database error when the vector query fails.
    private func semanticSearchBatch(
        embedding: [Float],
        orderedKinds: [IndexedItemKind],
        neighborLimit: Int
    ) throws -> [SemanticHit] {
        let boundedNeighborLimit = DatabaseConstants.boundedVectorNeighborCount(neighborLimit)
        guard boundedNeighborLimit > 0 else { return [] }
        let statement = try singleUseStatement(
            SQLStatements.semanticSearch(kindCount: orderedKinds.count)
        )
        defer { recycle(statement) }
        var bindingIndex = try bindKinds(orderedKinds, in: statement)
        try bind(embedding, at: bindingIndex, in: statement)
        bindingIndex += 1
        try bind(boundedNeighborLimit, at: bindingIndex, in: statement)
        var hits: [SemanticHit] = []
        while try step(statement) {
            guard let chunkID = UUID(uuidString: requiredText(statement, column: 0)),
                  let itemID = UUID(uuidString: requiredText(statement, column: 1)) else {
                throw LocalAssistantError.database(DatabaseConstants.missingRow)
            }
            hits.append(
                SemanticHit(
                    chunkID: chunkID,
                    itemID: itemID,
                    text: requiredText(statement, column: 2),
                    distance: sqlite3_column_double(statement, 3)
                )
            )
        }
        return hits
    }

    /// Returns the number of vectors available to an exhaustive adaptive search.
    /// - Returns: Current sqlite-vec row count.
    /// - Throws: A local database error when the count cannot be read.
    private func vectorRowCount() throws -> Int {
        let statement = try preparedStatement(SQLStatements.vectorCount)
        defer { recycle(statement) }
        guard try step(statement) else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    /// Counts vectors eligible under the requested hard item kinds.
    ///
    /// A zero result means adaptive expansion could never succeed, so the caller can stop
    /// before scanning the entire vector table.
    /// - Parameter kinds: Stable ordered item kinds.
    /// - Returns: Number of vectors belonging to those kinds.
    /// - Throws: A local database error when the count cannot be read.
    private func eligibleVectorRowCount(_ kinds: [IndexedItemKind]) throws -> Int {
        let statement = try singleUseStatement(SQLStatements.eligibleVectorCount(kindCount: kinds.count))
        defer { recycle(statement) }
        _ = try bindKinds(kinds, in: statement)
        guard try step(statement) else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    /// Orders hard item kinds for deterministic SQL bindings.
    /// - Parameter kinds: Unordered hard file-type constraints.
    /// - Returns: Kinds ordered by their stored raw values.
    private func orderedKinds(_ kinds: Set<IndexedItemKind>) -> [IndexedItemKind] {
        kinds.sorted { $0.rawValue < $1.rawValue }
    }

    /// Binds hard item kinds before ordinary search parameters.
    /// - Parameters:
    ///   - kinds: Stable ordered item kinds.
    ///   - statement: Prepared search statement.
    /// - Returns: The next one-based binding index.
    /// - Throws: A local database error when a binding fails.
    private func bindKinds(
        _ kinds: [IndexedItemKind],
        in statement: OpaquePointer
    ) throws -> Int32 {
        try bindKinds(kinds, startingAt: 1, in: statement)
    }

    /// Binds hard item kinds at an explicit position in a mixed-parameter query.
    /// - Parameters:
    ///   - kinds: Stable ordered item kinds.
    ///   - startingIndex: First one-based binding position.
    ///   - statement: Prepared search statement.
    /// - Returns: The next one-based binding index.
    /// - Throws: A local database error when a binding fails.
    private func bindKinds(
        _ kinds: [IndexedItemKind],
        startingAt startingIndex: Int32,
        in statement: OpaquePointer
    ) throws -> Int32 {
        for (offset, kind) in kinds.enumerated() {
            try bind(kind.rawValue, at: startingIndex + Int32(offset), in: statement)
        }
        return startingIndex + Int32(kinds.count)
    }
}
