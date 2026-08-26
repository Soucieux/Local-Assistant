import Foundation

extension AssistantDatabase {
    /// Returns the complete locally cached reminder snapshot.
    /// - Returns: Reminder rows in chronological display order.
    /// - Throws: A local database error when the query cannot complete.
    internal func fetchReminders() throws -> [ReminderItem] {
        let statement = try preparedStatement(SQLStatements.fetchReminders)
        defer { sqlite3_finalize(statement) }
        var reminders: [ReminderItem] = []
        while try step(statement) {
            guard let ownership = ReminderOwnership(
                rawValue: requiredText(statement, column: 11)
            ) else {
                throw LocalAssistantError.database(DatabaseConstants.missingRow)
            }
            reminders.append(
                ReminderItem(
                    id: requiredText(statement, column: 0),
                    text: requiredText(statement, column: 1),
                    date: optionalText(statement, column: 2),
                    startTime: optionalText(statement, column: 3),
                    endTime: optionalText(statement, column: 4),
                    tag: optionalText(statement, column: 5),
                    link: optionalText(statement, column: 6),
                    managedBy: optionalText(statement, column: 7),
                    clientRequestId: optionalText(statement, column: 8),
                    syncPairId: optionalText(statement, column: 9),
                    sourceMessageId: optionalText(statement, column: 10),
                    ownership: ownership,
                    contentHash: requiredText(statement, column: 12),
                    lastSyncedAt: requiredDate(statement, column: 13)
                )
            )
        }
        return reminders
    }

    /// Returns the current content hash for every cached reminder.
    /// - Returns: Reminder identifiers mapped to stable content hashes.
    /// - Throws: A local database error when the query cannot complete.
    internal func reminderContentHashes() throws -> [String: String] {
        let statement = try preparedStatement(SQLStatements.fetchReminderContentHashes)
        defer { sqlite3_finalize(statement) }
        var hashes: [String: String] = [:]
        while try step(statement) {
            hashes[requiredText(statement, column: 0)] = requiredText(statement, column: 1)
        }
        return hashes
    }

    /// Atomically replaces one complete remote snapshot while retaining unchanged vectors.
    /// - Parameters:
    ///   - reminders: Fully validated rows from one successful list response.
    ///   - embeddings: New local vectors for every new or changed row.
    ///   - syncedAt: Completion time recorded only after every write succeeds.
    /// - Throws: A local database error when the snapshot is incomplete or cannot commit.
    internal func reconcileReminders(
        _ reminders: [ReminderItem],
        embeddings: [String: [Float]],
        syncedAt: Date
    ) throws {
        let incomingIDs = Set(reminders.map(\.id))
        guard incomingIDs.count == reminders.count else {
            throw LocalAssistantError.database(ReminderStrings.incompleteSnapshot)
        }
        let previousHashes = try reminderContentHashes()
        let changedIDs = Set(reminders.compactMap { reminder in
            previousHashes[reminder.id] == reminder.contentHash ? nil : reminder.id
        })
        guard changedIDs.allSatisfy({ embeddings[$0]?.count == AppConstants.Indexing.embeddingDimensions }) else {
            throw LocalAssistantError.database(ReminderStrings.incompleteSnapshot)
        }

        let storedIDs = try reminderIDs()
        try inTransaction {
            for identifier in storedIDs.subtracting(incomingIDs) {
                try deleteReminderRecord(identifier)
            }
            for reminder in reminders {
                try upsertReminderRecord(reminder)
                try replaceReminderFTS(reminder)
                if let embedding = embeddings[reminder.id] {
                    try replaceReminderVector(identifier: reminder.id, embedding: embedding)
                }
            }
            let state = try preparedStatement(SQLStatements.upsertReminderSyncState)
            defer { sqlite3_finalize(state) }
            try bind(syncedAt, at: 1, in: state)
            try bind(reminders.count, at: 2, in: state)
            try stepDone(state)
        }
    }

    /// Returns the last committed complete-snapshot metadata.
    /// - Returns: Completion time and row count, or `nil` before the first sync.
    /// - Throws: A local database error when state cannot be read.
    internal func reminderSyncMetadata() throws -> (date: Date, count: Int)? {
        let statement = try preparedStatement(SQLStatements.fetchReminderSyncState)
        defer { sqlite3_finalize(statement) }
        guard try step(statement) else { return nil }
        return (
            date: requiredDate(statement, column: 0),
            count: Int(sqlite3_column_int64(statement, 1))
        )
    }

    /// Executes a sanitized lexical search over the cached reminder snapshot.
    /// - Parameters:
    ///   - text: Plain reminder query.
    ///   - limit: Maximum ranked identifiers.
    /// - Returns: Reminder identifiers ordered by FTS rank.
    /// - Throws: A local database error when FTS cannot execute.
    internal func reminderKeywordSearch(text: String, limit: Int) throws -> [String] {
        let query = SearchTextEscaping.ftsQuery(text)
        guard query.isEmpty == false, limit > 0 else { return [] }
        let statement = try preparedStatement(SQLStatements.reminderKeywordSearch)
        defer { sqlite3_finalize(statement) }
        try bind(query, at: 1, in: statement)
        try bind(limit, at: 2, in: statement)
        var identifiers: [String] = []
        while try step(statement) {
            identifiers.append(requiredText(statement, column: 0))
        }
        return identifiers
    }

    /// Executes a bounded nearest-neighbor search over reminder vectors.
    /// - Parameters:
    ///   - embedding: Local query embedding with the configured dimensions.
    ///   - limit: Maximum ranked identifiers.
    /// - Returns: Reminder identifiers ordered by vector distance.
    /// - Throws: A local database error when sqlite-vec cannot execute.
    internal func reminderSemanticSearch(
        embedding: [Float],
        limit: Int
    ) throws -> [String] {
        guard embedding.count == AppConstants.Indexing.embeddingDimensions,
              limit > 0 else {
            return []
        }
        let statement = try preparedStatement(SQLStatements.reminderSemanticSearch)
        defer { sqlite3_finalize(statement) }
        let result = embedding.withUnsafeBytes { bytes in
            sqlite3_bind_blob(
                statement,
                1,
                bytes.baseAddress,
                Int32(bytes.count),
                DatabaseConstants.transientDestructor
            )
        }
        guard result == SQLITE_OK else {
            throw LocalAssistantError.database(databaseErrorMessage())
        }
        try bind(limit, at: 2, in: statement)
        var identifiers: [String] = []
        while try step(statement) {
            identifiers.append(requiredText(statement, column: 0))
        }
        return identifiers
    }

    /// Returns the identifiers currently present in the local snapshot.
    private func reminderIDs() throws -> Set<String> {
        let statement = try preparedStatement(SQLStatements.fetchReminderIDs)
        defer { sqlite3_finalize(statement) }
        var identifiers: Set<String> = []
        while try step(statement) {
            identifiers.insert(requiredText(statement, column: 0))
        }
        return identifiers
    }

    /// Inserts or refreshes one reminder row without changing its vector row id.
    private func upsertReminderRecord(_ reminder: ReminderItem) throws {
        let statement = try preparedStatement(SQLStatements.upsertReminder)
        defer { sqlite3_finalize(statement) }
        try bind(reminder.id, at: 1, in: statement)
        try bind(reminder.text, at: 2, in: statement)
        try bind(reminder.date, at: 3, in: statement)
        try bind(reminder.startTime, at: 4, in: statement)
        try bind(reminder.endTime, at: 5, in: statement)
        try bind(reminder.tag, at: 6, in: statement)
        try bind(reminder.link, at: 7, in: statement)
        try bind(reminder.managedBy, at: 8, in: statement)
        try bind(reminder.clientRequestId, at: 9, in: statement)
        try bind(reminder.syncPairId, at: 10, in: statement)
        try bind(reminder.sourceMessageId, at: 11, in: statement)
        try bind(reminder.ownership.rawValue, at: 12, in: statement)
        try bind(reminder.contentHash, at: 13, in: statement)
        try bind(reminder.lastSyncedAt, at: 14, in: statement)
        try stepDone(statement)
    }

    /// Replaces one reminder's full-text row inside the active transaction.
    private func replaceReminderFTS(_ reminder: ReminderItem) throws {
        let deletion = try preparedStatement(SQLStatements.deleteReminderFTS)
        defer { sqlite3_finalize(deletion) }
        try bind(reminder.id, at: 1, in: deletion)
        try stepDone(deletion)

        let insertion = try preparedStatement(SQLStatements.insertReminderFTS)
        defer { sqlite3_finalize(insertion) }
        try bind(reminder.id, at: 1, in: insertion)
        try bind(reminder.text, at: 2, in: insertion)
        try bind(reminder.date, at: 3, in: insertion)
        try bind(reminder.tag, at: 4, in: insertion)
        try bind(reminder.link, at: 5, in: insertion)
        try stepDone(insertion)
    }

    /// Replaces one changed reminder vector inside the active transaction.
    private func replaceReminderVector(identifier: String, embedding: [Float]) throws {
        let rowID = try reminderRowID(identifier)
        let deletion = try preparedStatement(SQLStatements.deleteReminderVector)
        defer { sqlite3_finalize(deletion) }
        try bind(rowID, at: 1, in: deletion)
        try stepDone(deletion)

        let insertion = try preparedStatement(SQLStatements.insertReminderVector)
        defer { sqlite3_finalize(insertion) }
        try bind(rowID, at: 1, in: insertion)
        let result = embedding.withUnsafeBytes { bytes in
            sqlite3_bind_blob(
                insertion,
                2,
                bytes.baseAddress,
                Int32(bytes.count),
                DatabaseConstants.transientDestructor
            )
        }
        guard result == SQLITE_OK else {
            throw LocalAssistantError.database(databaseErrorMessage())
        }
        try stepDone(insertion)
    }

    /// Removes one reminder and its virtual-table rows inside the active transaction.
    private func deleteReminderRecord(_ identifier: String) throws {
        if let rowID = try optionalReminderRowID(identifier) {
            let vector = try preparedStatement(SQLStatements.deleteReminderVector)
            defer { sqlite3_finalize(vector) }
            try bind(rowID, at: 1, in: vector)
            try stepDone(vector)
        }
        let fullText = try preparedStatement(SQLStatements.deleteReminderFTS)
        defer { sqlite3_finalize(fullText) }
        try bind(identifier, at: 1, in: fullText)
        try stepDone(fullText)

        let item = try preparedStatement(SQLStatements.deleteReminder)
        defer { sqlite3_finalize(item) }
        try bind(identifier, at: 1, in: item)
        try stepDone(item)
    }

    /// Returns the stable sqlite-vec row id for one stored reminder.
    private func reminderRowID(_ identifier: String) throws -> Int64 {
        guard let rowID = try optionalReminderRowID(identifier) else {
            throw LocalAssistantError.database(DatabaseConstants.missingRow)
        }
        return rowID
    }

    /// Returns an optional sqlite-vec row id for one reminder identifier.
    private func optionalReminderRowID(_ identifier: String) throws -> Int64? {
        let statement = try preparedStatement(SQLStatements.fetchReminderRowID)
        defer { sqlite3_finalize(statement) }
        try bind(identifier, at: 1, in: statement)
        guard try step(statement) else { return nil }
        return sqlite3_column_int64(statement, 0)
    }
}
