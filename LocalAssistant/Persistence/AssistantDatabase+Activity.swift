import Foundation

extension AssistantDatabase {
    /// Stores whether automatic monitoring is enabled for one authorized root.
    /// - Parameters:
    ///   - isEnabled: Persisted monitoring preference.
    ///   - rootID: Authorized folder identifier.
    /// - Throws: A local database error when the preference cannot be saved.
    internal func setMonitoringEnabled(_ isEnabled: Bool, rootID: UUID) throws {
        let statement = try preparedStatement(SQLStatements.upsertMonitoringState)
        defer { sqlite3_finalize(statement) }
        try bind(rootID.uuidString, at: 1, in: statement)
        try bind(isEnabled, at: 2, in: statement)
        try bind(Date(), at: 3, in: statement)
        try stepDone(statement)
    }

    /// Returns roots whose automatic monitoring was explicitly paused.
    /// - Returns: Authorized root identifiers with monitoring disabled.
    /// - Throws: A local database error when preferences cannot be read.
    internal func fetchPausedMonitoringRootIDs() throws -> Set<UUID> {
        let statement = try preparedStatement(SQLStatements.fetchMonitoringStates)
        defer { sqlite3_finalize(statement) }
        var paused: Set<UUID> = []
        while try step(statement) {
            guard let rootID = UUID(uuidString: requiredText(statement, column: 0)) else {
                throw LocalAssistantError.database(DatabaseConstants.missingRow)
            }
            if sqlite3_column_int(statement, 1) == DatabaseConstants.sqliteFalse {
                paused.insert(rootID)
            }
        }
        return paused
    }

    /// Inserts the durable summary row for a newly started indexing run.
    /// - Parameter run: Initial run identity, source, and zeroed counts.
    /// - Throws: A local database error when the run cannot be inserted.
    internal func insertIndexingRun(_ run: IndexingRunRecord) throws {
        let statement = try preparedStatement(SQLStatements.insertIndexingRun)
        defer { sqlite3_finalize(statement) }
        try bind(run.id.uuidString, at: 1, in: statement)
        try bind(run.rootID.uuidString, at: 2, in: statement)
        try bind(run.folderName, at: 3, in: statement)
        try bind(run.folderPath, at: 4, in: statement)
        try bind(run.trigger.rawValue, at: 5, in: statement)
        try bind(run.state.rawValue, at: 6, in: statement)
        try bind(run.startedAt, at: 7, in: statement)
        try bind(run.finishedAt, at: 8, in: statement)
        try bind(run.totalItems, at: 9, in: statement)
        try bind(run.newItems, at: 10, in: statement)
        try bind(run.updatedItems, at: 11, in: statement)
        try bind(run.unchangedItems, at: 12, in: statement)
        try bind(run.removedItems, at: 13, in: statement)
        try bind(run.skippedItems, at: 14, in: statement)
        try stepDone(statement)
    }

    /// Updates the mutable outcome fields for an existing indexing run.
    /// - Parameter run: Run summary containing the latest state and counts.
    /// - Throws: A local database error when the row cannot be updated.
    internal func updateIndexingRun(_ run: IndexingRunRecord) throws {
        let statement = try preparedStatement(SQLStatements.updateIndexingRun)
        defer { sqlite3_finalize(statement) }
        try bind(run.state.rawValue, at: 1, in: statement)
        try bind(run.finishedAt, at: 2, in: statement)
        try bind(run.totalItems, at: 3, in: statement)
        try bind(run.newItems, at: 4, in: statement)
        try bind(run.updatedItems, at: 5, in: statement)
        try bind(run.unchangedItems, at: 6, in: statement)
        try bind(run.removedItems, at: 7, in: statement)
        try bind(run.skippedItems, at: 8, in: statement)
        try bind(run.id.uuidString, at: 9, in: statement)
        try stepDone(statement)
    }

    /// Inserts or advances one file's durable state within an indexing run.
    /// - Parameter item: Deterministic file-state record to insert or advance.
    /// - Throws: A local database error when the item cannot be saved.
    internal func upsertIndexingItem(_ item: IndexingItemRecord) throws {
        let statement = try preparedStatement(SQLStatements.upsertIndexingRunItem)
        defer { sqlite3_finalize(statement) }
        try bind(item.id.uuidString, at: 1, in: statement)
        try bind(item.runID.uuidString, at: 2, in: statement)
        try bind(item.displayName, at: 3, in: statement)
        try bind(item.relativePath, at: 4, in: statement)
        try bind(item.state.rawValue, at: 5, in: statement)
        try bind(item.detail, at: 6, in: statement)
        try bind(item.updatedAt, at: 7, in: statement)
        try stepDone(statement)
    }

    /// Stores many run item rows in a single transaction.
    ///
    /// A run opens by classifying every scanned file at once. Committing each of those rows
    /// separately costs one durable write per file, which dominates the start of a large scan.
    /// - Parameter items: Durable per-file classifications saved together.
    /// - Throws: A local database error when the rows cannot be saved.
    internal func upsertIndexingItems(_ items: [IndexingItemRecord]) throws {
        guard items.isEmpty == false else { return }
        try inTransaction {
            for item in items {
                try upsertIndexingItem(item)
            }
        }
    }

    /// Appends one monitoring or lifecycle event to the activity timeline.
    /// - Parameter event: Durable event snapshot to append.
    /// - Throws: A local database error when the event cannot be inserted.
    internal func insertIndexActivityEvent(_ event: IndexActivityEventRecord) throws {
        let statement = try preparedStatement(SQLStatements.insertIndexActivityEvent)
        defer { sqlite3_finalize(statement) }
        try bind(event.id.uuidString, at: 1, in: statement)
        try bind(event.rootID.uuidString, at: 2, in: statement)
        try bind(event.folderName, at: 3, in: statement)
        try bind(event.kind.rawValue, at: 4, in: statement)
        try bind(event.occurredAt, at: 5, in: statement)
        try stepDone(statement)
    }

    /// Returns every retained indexing run, newest first.
    /// - Returns: Durable run summaries in descending start-time order.
    /// - Throws: A local database error when rows are malformed or unreadable.
    internal func fetchIndexingRuns() throws -> [IndexingRunRecord] {
        let statement = try preparedStatement(SQLStatements.fetchIndexingRuns)
        defer { sqlite3_finalize(statement) }
        var runs: [IndexingRunRecord] = []
        while try step(statement) {
            guard let id = UUID(uuidString: requiredText(statement, column: 0)),
                  let rootID = UUID(uuidString: requiredText(statement, column: 1)),
                  let trigger = IndexingTrigger(rawValue: requiredText(statement, column: 4)),
                  let state = IndexingRunState(rawValue: requiredText(statement, column: 5)) else {
                throw LocalAssistantError.database(DatabaseConstants.missingRow)
            }
            runs.append(
                IndexingRunRecord(
                    id: id,
                    rootID: rootID,
                    folderName: requiredText(statement, column: 2),
                    folderPath: requiredText(statement, column: 3),
                    trigger: trigger,
                    state: state,
                    startedAt: requiredDate(statement, column: 6),
                    finishedAt: optionalDate(statement, column: 7),
                    totalItems: Int(sqlite3_column_int64(statement, 8)),
                    newItems: Int(sqlite3_column_int64(statement, 9)),
                    updatedItems: Int(sqlite3_column_int64(statement, 10)),
                    unchangedItems: Int(sqlite3_column_int64(statement, 11)),
                    removedItems: Int(sqlite3_column_int64(statement, 12)),
                    skippedItems: Int(sqlite3_column_int64(statement, 13))
                )
            )
        }
        return runs
    }

    /// Returns retained file-level states for one indexing run.
    /// - Parameter runID: Parent run identifier.
    /// - Returns: File-level states in root-relative path order.
    /// - Throws: A local database error when rows are malformed or unreadable.
    internal func fetchIndexingItems(runID: UUID) throws -> [IndexingItemRecord] {
        let statement = try preparedStatement(SQLStatements.fetchIndexingRunItems)
        defer { sqlite3_finalize(statement) }
        try bind(runID.uuidString, at: 1, in: statement)
        var items: [IndexingItemRecord] = []
        while try step(statement) {
            guard let id = UUID(uuidString: requiredText(statement, column: 0)),
                  let decodedRunID = UUID(uuidString: requiredText(statement, column: 1)),
                  let state = IndexingItemState(rawValue: requiredText(statement, column: 4)) else {
                throw LocalAssistantError.database(DatabaseConstants.missingRow)
            }
            items.append(
                IndexingItemRecord(
                    id: id,
                    runID: decodedRunID,
                    displayName: requiredText(statement, column: 2),
                    relativePath: requiredText(statement, column: 3),
                    state: state,
                    detail: optionalText(statement, column: 5),
                    updatedAt: requiredDate(statement, column: 6)
                )
            )
        }
        return items
    }

    /// Returns retained monitoring and lifecycle events, newest first.
    /// - Returns: Durable events in descending occurrence-time order.
    /// - Throws: A local database error when rows are malformed or unreadable.
    internal func fetchIndexActivityEvents() throws -> [IndexActivityEventRecord] {
        let statement = try preparedStatement(SQLStatements.fetchIndexActivityEvents)
        defer { sqlite3_finalize(statement) }
        var events: [IndexActivityEventRecord] = []
        while try step(statement) {
            guard let id = UUID(uuidString: requiredText(statement, column: 0)),
                  let rootID = UUID(uuidString: requiredText(statement, column: 1)),
                  let kind = IndexActivityEventKind(rawValue: requiredText(statement, column: 3)) else {
                throw LocalAssistantError.database(DatabaseConstants.missingRow)
            }
            events.append(
                IndexActivityEventRecord(
                    id: id,
                    rootID: rootID,
                    folderName: requiredText(statement, column: 2),
                    kind: kind,
                    occurredAt: requiredDate(statement, column: 4)
                )
            )
        }
        return events
    }

    /// Removes all activity older than the rolling retention boundary.
    /// - Parameter cutoff: Oldest retained activity timestamp.
    /// - Throws: A local database error when the transaction fails.
    internal func purgeIndexActivity(before cutoff: Date) throws {
        try inTransaction {
            let runs = try preparedStatement(SQLStatements.deleteExpiredIndexingRuns)
            defer { sqlite3_finalize(runs) }
            try bind(cutoff, at: 1, in: runs)
            try stepDone(runs)

            let events = try preparedStatement(SQLStatements.deleteExpiredIndexActivityEvents)
            defer { sqlite3_finalize(events) }
            try bind(cutoff, at: 1, in: events)
            try stepDone(events)
        }
    }

    /// Marks runs interrupted by a prior process exit as safely stopped.
    /// - Parameter date: Recovery time recorded on interrupted runs and items.
    /// - Throws: A local database error when recovery cannot be applied atomically.
    internal func stopInterruptedIndexingRuns(at date: Date) throws {
        try inTransaction {
            let items = try preparedStatement(SQLStatements.resetInterruptedIndexingItems)
            defer { sqlite3_finalize(items) }
            try bind(IndexingItemState.newIndexing.rawValue, at: 1, in: items)
            try bind(IndexingItemState.newWaiting.rawValue, at: 2, in: items)
            try bind(IndexingItemState.modifiedUpdating.rawValue, at: 3, in: items)
            try bind(IndexingItemState.modifiedWaiting.rawValue, at: 4, in: items)
            try bind(date, at: 5, in: items)
            try bind(IndexingRunState.running.rawValue, at: 6, in: items)
            try bind(IndexingItemState.newIndexing.rawValue, at: 7, in: items)
            try bind(IndexingItemState.modifiedUpdating.rawValue, at: 8, in: items)
            try stepDone(items)

            let runs = try preparedStatement(SQLStatements.stopInterruptedIndexingRuns)
            defer { sqlite3_finalize(runs) }
            try bind(IndexingRunState.stopped.rawValue, at: 1, in: runs)
            try bind(date, at: 2, in: runs)
            try bind(IndexingRunState.running.rawValue, at: 3, in: runs)
            try stepDone(runs)
        }
    }

    /// Clears activity history without changing authorizations or indexed content.
    /// - Throws: A local database error when deletion cannot complete atomically.
    internal func clearIndexActivity() throws {
        try inTransaction {
            try execute(SQLStatements.clearIndexingRuns)
            try execute(SQLStatements.clearIndexActivityEvents)
        }
    }
}
