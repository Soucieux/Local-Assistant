import Foundation

extension AssistantDatabase {
    /// Saves current file-system metadata without replacing existing extracted passages.
    /// - Parameter items: Complete scanned hierarchy with prior content hashes preserved.
    /// - Throws: A local database error or cancellation when the metadata pass cannot finish.
    internal func upsertItemMetadata(_ items: [IndexedItem]) throws {
        try inTransaction {
            for item in items {
                try Task.checkCancellation()
                try upsertItem(item)
            }
        }
    }

    /// Replaces one indexed item and all of its extracted passages atomically.
    /// - Parameters:
    ///   - item: Current read-only file metadata.
    ///   - chunks: Extracted passages and optional local embeddings.
    /// - Throws: A local database error when the update cannot be committed.
    internal func replaceItem(_ item: IndexedItem, chunks: [ContentChunk]) throws {
        try inTransaction {
            try deleteVectors(itemID: item.id)
            try deleteFTS(itemID: item.id)
            try deleteChunks(itemID: item.id)
            try upsertItem(item)

            for chunk in chunks {
                let rowID = try insertChunk(chunk)
                try insertFTS(chunk: chunk, item: item)
                if let embedding = chunk.embedding {
                    try insertVector(embedding, rowID: rowID)
                }
            }
        }
    }

    /// Returns an indexed item by identifier.
    /// - Parameter id: Stable item identifier.
    /// - Returns: Matching item or `nil`.
    /// - Throws: A local database error when the lookup fails.
    internal func fetchItem(id: UUID) throws -> IndexedItem? {
        let statement = try preparedStatement(SQLStatements.fetchItem)
        defer { recycle(statement) }
        try bind(id.uuidString, at: 1, in: statement)
        guard try step(statement) else { return nil }
        return try readIndexedItem(statement)
    }

    /// Returns every stored item matching a bounded set of identifiers.
    ///
    /// One statement per batch replaces a lookup per identifier, which otherwise costs an
    /// actor hop and a prepared statement for every search candidate and restored card.
    /// - Parameter ids: Identifiers to resolve.
    /// - Returns: Items keyed by identifier, omitting identifiers with no stored row.
    /// - Throws: A local database error when rows cannot be read.
    internal func fetchItems(ids: Set<UUID>) throws -> [UUID: IndexedItem] {
        guard ids.isEmpty == false else { return [:] }
        let identifiers = Array(ids)
        var items: [UUID: IndexedItem] = [:]
        var lowerBound = 0
        while lowerBound < identifiers.count {
            let upperBound = min(
                lowerBound + DatabaseConstants.maximumBoundIdentifiers,
                identifiers.count
            )
            let batch = identifiers[lowerBound..<upperBound]
            let statement = try singleUseStatement(SQLStatements.fetchItems(idCount: batch.count))
            defer { recycle(statement) }
            for (offset, id) in batch.enumerated() {
                try bind(id.uuidString, at: Int32(offset + 1), in: statement)
            }
            while try step(statement) {
                let item = try readIndexedItem(statement)
                items[item.id] = item
            }
            lowerBound = upperBound
        }
        return items
    }

    /// Returns every item currently recorded for one authorized root.
    /// - Parameter rootID: Root identifier.
    /// - Returns: Current item metadata.
    /// - Throws: A local database error when rows cannot be read.
    internal func fetchItems(rootID: UUID) throws -> [IndexedItem] {
        let statement = try preparedStatement(SQLStatements.fetchItemsForRoot)
        defer { recycle(statement) }
        try bind(rootID.uuidString, at: 1, in: statement)
        var items: [IndexedItem] = []
        while try step(statement) {
            items.append(try readIndexedItem(statement))
        }
        return items
    }

    /// Deletes records for files no longer present in a completed root scan.
    /// - Parameter staleItems: Items the completed scan already proved are gone.
    /// - Throws: A local database error when stale rows cannot be removed.
    internal func pruneItems(_ staleItems: [IndexedItem]) throws {
        try inTransaction {
            for item in staleItems {
                try deleteVectors(itemID: item.id)
                let statement = try preparedStatement(SQLStatements.deleteItem)
                defer { recycle(statement) }
                try bind(item.id.uuidString, at: 1, in: statement)
                try stepDone(statement)
            }
        }
    }

    /// Inserts or updates one file metadata row.
    /// - Parameter item: Metadata read from the authorized root.
    /// - Throws: A local database error when the row cannot be saved.
    private func upsertItem(_ item: IndexedItem) throws {
        let statement = try preparedStatement(SQLStatements.upsertItem)
        defer { recycle(statement) }
        try bind(item.id.uuidString, at: 1, in: statement)
        try bind(item.rootID.uuidString, at: 2, in: statement)
        try bind(item.parentID?.uuidString, at: 3, in: statement)
        try bind(item.url.path, at: 4, in: statement)
        try bind(item.relativePath, at: 5, in: statement)
        try bind(item.displayName, at: 6, in: statement)
        try bind(item.kind.rawValue, at: 7, in: statement)
        try bind(item.contentType, at: 8, in: statement)
        try bind(item.byteCount, at: 9, in: statement)
        try bind(item.createdAt, at: 10, in: statement)
        try bind(item.modifiedAt, at: 11, in: statement)
        try bind(item.contentHash, at: 12, in: statement)
        try bind(item.metadataHash, at: 13, in: statement)
        try bind(item.isDirectory, at: 14, in: statement)
        try bind(item.isHidden, at: 15, in: statement)
        try stepDone(statement)
    }

    /// Inserts one extracted passage.
    /// - Parameter chunk: Passage to store.
    /// - Returns: SQLite row identifier used by the vector table.
    /// - Throws: A local database error when insertion fails.
    private func insertChunk(_ chunk: ContentChunk) throws -> Int64 {
        let statement = try preparedStatement(SQLStatements.insertChunk)
        defer { recycle(statement) }
        try bind(chunk.id.uuidString, at: 1, in: statement)
        try bind(chunk.itemID.uuidString, at: 2, in: statement)
        try bind(chunk.ordinal, at: 3, in: statement)
        try bind(chunk.text, at: 4, in: statement)
        try bind(chunk.characterStart, at: 5, in: statement)
        try bind(chunk.characterEnd, at: 6, in: statement)
        try bind(chunk.pageNumber, at: 7, in: statement)
        try bind(chunk.sectionName, at: 8, in: statement)
        try stepDone(statement)
        guard let connection else { throw LocalAssistantError.database(DatabaseConstants.missingDatabase) }
        return sqlite3_last_insert_rowid(connection)
    }

    /// Inserts a passage into the full-text index.
    /// - Parameters:
    ///   - chunk: Passage to make searchable.
    ///   - item: Parent file supplying name and path fields.
    /// - Throws: A local database error when insertion fails.
    private func insertFTS(chunk: ContentChunk, item: IndexedItem) throws {
        let statement = try preparedStatement(SQLStatements.insertFTS)
        defer { recycle(statement) }
        try bind(chunk.id.uuidString, at: 1, in: statement)
        try bind(item.id.uuidString, at: 2, in: statement)
        try bind(item.displayName, at: 3, in: statement)
        try bind(item.relativePath, at: 4, in: statement)
        try bind(chunk.text, at: 5, in: statement)
        try stepDone(statement)
    }

    /// Inserts one fixed-size float vector into sqlite-vec.
    /// - Parameters:
    ///   - embedding: Local document embedding.
    ///   - rowID: Matching content-chunk row identifier.
    /// - Throws: A local database error when dimensions or insertion are invalid.
    private func insertVector(_ embedding: [Float], rowID: Int64) throws {
        guard embedding.count == AppConstants.Indexing.embeddingDimensions else {
            throw LocalAssistantError.database(DatabaseConstants.vectorRegistrationFailure)
        }
        let statement = try preparedStatement(SQLStatements.insertVector)
        defer { recycle(statement) }
        try bind(rowID, at: 1, in: statement)
        try bind(embedding, at: 2, in: statement)
        try stepDone(statement)
    }

    /// Deletes a file's old full-text records.
    /// - Parameter itemID: Parent item identifier.
    /// - Throws: A local database error when deletion fails.
    private func deleteFTS(itemID: UUID) throws {
        let statement = try preparedStatement(SQLStatements.deleteFTSForItem)
        defer { recycle(statement) }
        try bind(itemID.uuidString, at: 1, in: statement)
        try stepDone(statement)
    }

    /// Deletes a file's old passage records.
    /// - Parameter itemID: Parent item identifier.
    /// - Throws: A local database error when deletion fails.
    private func deleteChunks(itemID: UUID) throws {
        let statement = try preparedStatement(SQLStatements.deleteChunksForItem)
        defer { recycle(statement) }
        try bind(itemID.uuidString, at: 1, in: statement)
        try stepDone(statement)
    }

    /// Deletes every indexed file, passage, and vector without touching folder
    /// authorizations, monitoring preferences, or conversation history.
    /// - Throws: A local database error when the search index cannot be cleared.
    internal func clearSearchIndex() throws {
        try inTransaction {
            try execute(SQLStatements.clearChunkVectors)
            try execute(SQLStatements.clearChunkFTS)
            try execute(SQLStatements.clearContentChunks)
            try execute(SQLStatements.clearIndexedItems)
        }
        try execute(SQLStatements.vacuum)
    }

    /// Returns the number of indexed files currently searchable, excluding folder entries.
    /// - Returns: Current indexed file count.
    /// - Throws: A local database error when the count cannot be read.
    internal func indexedFileCount() throws -> Int {
        let statement = try preparedStatement(SQLStatements.countIndexedFiles)
        defer { recycle(statement) }
        guard try step(statement) else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    /// Deletes vector rows before their parent passage rows disappear.
    ///
    /// A re-indexed document deletes one vector per extracted passage, so a single checked-out
    /// statement is rebound for each row rather than checked out again for every one of them.
    /// - Parameter itemID: Parent item identifier.
    /// - Throws: A local database error when deletion fails.
    internal func deleteVectors(itemID: UUID) throws {
        let rowsStatement = try preparedStatement(SQLStatements.fetchChunkRowsForItem)
        defer { recycle(rowsStatement) }
        try bind(itemID.uuidString, at: 1, in: rowsStatement)
        var rowIDs: [Int64] = []
        while try step(rowsStatement) {
            rowIDs.append(sqlite3_column_int64(rowsStatement, 0))
        }
        guard rowIDs.isEmpty == false else { return }

        let deleteStatement = try preparedStatement(SQLStatements.deleteVector)
        defer { recycle(deleteStatement) }
        for rowID in rowIDs {
            sqlite3_reset(deleteStatement)
            try bind(rowID, at: 1, in: deleteStatement)
            try stepDone(deleteStatement)
        }
    }

    /// Decodes one item from the standard item column layout.
    /// - Parameter statement: Statement positioned on an item row.
    /// - Returns: Typed indexed item metadata.
    /// - Throws: A local database error when required identifiers are malformed.
    internal func readIndexedItem(_ statement: OpaquePointer) throws -> IndexedItem {
        guard let id = UUID(uuidString: requiredText(statement, column: 0)),
              let rootID = UUID(uuidString: requiredText(statement, column: 1)) else {
            throw LocalAssistantError.database(DatabaseConstants.missingRow)
        }
        let parentID = optionalText(statement, column: 2).flatMap(UUID.init(uuidString:))
        let kind = IndexedItemKind(rawValue: requiredText(statement, column: 6)) ?? .other
        return IndexedItem(
            id: id,
            rootID: rootID,
            parentID: parentID,
            url: URL(fileURLWithPath: requiredText(statement, column: 3)),
            relativePath: requiredText(statement, column: 4),
            displayName: requiredText(statement, column: 5),
            kind: kind,
            contentType: optionalText(statement, column: 7),
            byteCount: sqlite3_column_int64(statement, 8),
            createdAt: optionalDate(statement, column: 9),
            modifiedAt: optionalDate(statement, column: 10),
            contentHash: optionalText(statement, column: 11),
            metadataHash: requiredText(statement, column: 12),
            isDirectory: sqlite3_column_int(statement, 13) == DatabaseConstants.sqliteTrue,
            isHidden: sqlite3_column_int(statement, 14) == DatabaseConstants.sqliteTrue
        )
    }
}
