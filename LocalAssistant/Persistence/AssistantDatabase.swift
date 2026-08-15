import Foundation

/// Owns the single SQLite connection stored in the app's private container.
actor AssistantDatabase {
    internal var connection: OpaquePointer?
    internal let encoder = JSONEncoder()
    internal let decoder = JSONDecoder()
    private let databaseURLOverride: URL?

    /// Creates private storage with the production path or a focused-test override.
    /// - Parameter databaseURL: Optional explicit database URL for an isolated native harness.
    internal init(databaseURL: URL? = nil) {
        databaseURLOverride = databaseURL
    }

    /// Opens the database, registers statically linked vector functions, and creates the schema.
    /// - Throws: A local database error when setup fails.
    internal func open() throws {
        guard connection == nil else { return }
        let databaseURL = try resolvedDatabaseURL()
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK,
              let database else {
            if let database { sqlite3_close(database) }
            throw LocalAssistantError.database(DatabaseConstants.openFailure)
        }

        connection = database
        do {
            guard local_assistant_register_sqlite_vec(database) == SQLITE_OK else {
                throw LocalAssistantError.database(
                    DatabaseConstants.message(
                        prefix: DatabaseConstants.vectorRegistrationFailure,
                        detail: databaseErrorMessage()
                    )
                )
            }

            try execute(SQLStatements.pragmas)
            try execute(SQLStatements.schema)
            try protectDatabaseFiles()
        } catch {
            sqlite3_close(database)
            connection = nil
            throw error
        }
    }

    /// Closes the private SQLite connection.
    internal func close() {
        guard let connection else { return }
        sqlite3_close(connection)
        self.connection = nil
    }

    /// Inserts or refreshes an authorized root record.
    /// - Parameter root: Root metadata and its security-scoped bookmark.
    /// - Throws: A local database error when the record cannot be saved.
    internal func upsertRoot(_ root: AuthorizedRoot) throws {
        let statement = try preparedStatement(SQLStatements.upsertRoot)
        defer { sqlite3_finalize(statement) }
        try bind(root.id.uuidString, at: 1, in: statement)
        try bind(root.displayName, at: 2, in: statement)
        try bind(root.lastKnownPath, at: 3, in: statement)
        try bind(root.bookmarkData, at: 4, in: statement)
        try bind(root.addedAt, at: 5, in: statement)
        try bind(root.lastIndexedAt, at: 6, in: statement)
        try bind(root.isAvailable, at: 7, in: statement)
        try stepDone(statement)
    }

    /// Returns every authorized root in display order.
    /// - Returns: Roots whose bookmarks are stored in the private index.
    /// - Throws: A local database error when records cannot be read.
    internal func fetchRoots() throws -> [AuthorizedRoot] {
        let statement = try preparedStatement(SQLStatements.fetchRoots)
        defer { sqlite3_finalize(statement) }
        var roots: [AuthorizedRoot] = []

        while try step(statement) {
            guard let id = UUID(uuidString: requiredText(statement, column: 0)) else {
                throw LocalAssistantError.database(DatabaseConstants.missingRow)
            }
            roots.append(
                AuthorizedRoot(
                    id: id,
                    displayName: requiredText(statement, column: 1),
                    lastKnownPath: requiredText(statement, column: 2),
                    bookmarkData: requiredData(statement, column: 3),
                    addedAt: requiredDate(statement, column: 4),
                    lastIndexedAt: optionalDate(statement, column: 5),
                    isAvailable: sqlite3_column_int(statement, 6) == DatabaseConstants.sqliteTrue
                )
            )
        }
        return roots
    }

    /// Removes one authorization record and its dependent file metadata.
    /// - Parameter id: Root identifier to remove from the private index.
    /// - Throws: A local database error when deletion fails.
    internal func deleteRoot(id: UUID) throws {
        let items = try fetchItems(rootID: id)
        try inTransaction {
            for item in items {
                try deleteVectors(itemID: item.id)
            }
            let statement = try preparedStatement(SQLStatements.deleteRoot)
            defer { sqlite3_finalize(statement) }
            try bind(id.uuidString, at: 1, in: statement)
            try stepDone(statement)
        }
    }

    /// Executes a group of statements atomically.
    /// - Parameter body: Synchronous work performed on this actor's connection.
    /// - Throws: The original operation error or a transaction error.
    internal func inTransaction(_ body: () throws -> Void) throws {
        try execute(SQLStatements.beginTransaction)
        do {
            try body()
            try execute(SQLStatements.commitTransaction)
        } catch {
            try? execute(SQLStatements.rollbackTransaction)
            throw error
        }
    }

    /// Creates a prepared statement on the active connection.
    /// - Parameter sql: Centralized SQL text.
    /// - Returns: A prepared SQLite statement.
    /// - Throws: A local database error when preparation fails.
    internal func preparedStatement(_ sql: String) throws -> OpaquePointer {
        guard let connection else {
            throw LocalAssistantError.database(DatabaseConstants.missingDatabase)
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw LocalAssistantError.database(
                DatabaseConstants.message(
                    prefix: DatabaseConstants.statementPreparationFailure,
                    detail: databaseErrorMessage()
                )
            )
        }
        return statement
    }

    /// Runs one or more SQL statements without returned rows.
    /// - Parameter sql: Centralized SQL text.
    /// - Throws: A local database error when execution fails.
    internal func execute(_ sql: String) throws {
        guard let connection else {
            throw LocalAssistantError.database(DatabaseConstants.missingDatabase)
        }
        var errorPointer: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(connection, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? databaseErrorMessage()
            sqlite3_free(errorPointer)
            throw LocalAssistantError.database(
                DatabaseConstants.message(prefix: DatabaseConstants.statementExecutionFailure, detail: message)
            )
        }
    }

    /// Advances a mutating statement and requires successful completion.
    /// - Parameter statement: Prepared statement to execute.
    /// - Throws: A local database error when SQLite does not return `SQLITE_DONE`.
    internal func stepDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw LocalAssistantError.database(
                DatabaseConstants.message(
                    prefix: DatabaseConstants.statementExecutionFailure,
                    detail: databaseErrorMessage()
                )
            )
        }
    }

    /// Advances a read statement and distinguishes rows, completion, and failure.
    /// - Parameter statement: Prepared query positioned before or on a row.
    /// - Returns: `true` when a row is available and `false` at normal completion.
    /// - Throws: A local database error when SQLite cannot advance the query.
    internal func step(_ statement: OpaquePointer) throws -> Bool {
        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            return true
        case SQLITE_DONE:
            return false
        default:
            throw LocalAssistantError.database(
                DatabaseConstants.message(
                    prefix: DatabaseConstants.statementExecutionFailure,
                    detail: databaseErrorMessage()
                )
            )
        }
    }

    /// Binds a required string value.
    /// - Parameters:
    ///   - value: Text to copy into SQLite.
    ///   - index: One-based parameter index.
    ///   - statement: Prepared statement receiving the value.
    /// - Throws: A local database error when binding fails.
    internal func bind(_ value: String, at index: Int32, in statement: OpaquePointer) throws {
        guard sqlite3_bind_text(statement, index, value, -1, DatabaseConstants.transientDestructor) == SQLITE_OK else {
            throw LocalAssistantError.database(databaseErrorMessage())
        }
    }

    /// Binds an optional string value.
    /// - Parameters:
    ///   - value: Optional text to copy into SQLite.
    ///   - index: One-based parameter index.
    ///   - statement: Prepared statement receiving the value.
    /// - Throws: A local database error when binding fails.
    internal func bind(_ value: String?, at index: Int32, in statement: OpaquePointer) throws {
        if let value {
            try bind(value, at: index, in: statement)
        } else if sqlite3_bind_null(statement, index) != SQLITE_OK {
            throw LocalAssistantError.database(databaseErrorMessage())
        }
    }

    /// Binds copied binary data.
    /// - Parameters:
    ///   - value: Data to copy into SQLite.
    ///   - index: One-based parameter index.
    ///   - statement: Prepared statement receiving the value.
    /// - Throws: A local database error when binding fails.
    internal func bind(_ value: Data, at index: Int32, in statement: OpaquePointer) throws {
        let result = value.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), DatabaseConstants.transientDestructor)
        }
        guard result == SQLITE_OK else { throw LocalAssistantError.database(databaseErrorMessage()) }
    }

    /// Binds an optional timestamp.
    /// - Parameters:
    ///   - value: Optional date to store as Unix time.
    ///   - index: One-based parameter index.
    ///   - statement: Prepared statement receiving the value.
    /// - Throws: A local database error when binding fails.
    internal func bind(_ value: Date?, at index: Int32, in statement: OpaquePointer) throws {
        if let value {
            guard sqlite3_bind_double(statement, index, value.timeIntervalSince1970) == SQLITE_OK else {
                throw LocalAssistantError.database(databaseErrorMessage())
            }
        } else if sqlite3_bind_null(statement, index) != SQLITE_OK {
            throw LocalAssistantError.database(databaseErrorMessage())
        }
    }

    /// Binds a required timestamp.
    /// - Parameters:
    ///   - value: Date to store as Unix time.
    ///   - index: One-based parameter index.
    ///   - statement: Prepared statement receiving the value.
    /// - Throws: A local database error when binding fails.
    internal func bind(_ value: Date, at index: Int32, in statement: OpaquePointer) throws {
        try bind(Optional(value), at: index, in: statement)
    }

    /// Binds a Boolean as an SQLite integer.
    /// - Parameters:
    ///   - value: Boolean value.
    ///   - index: One-based parameter index.
    ///   - statement: Prepared statement receiving the value.
    /// - Throws: A local database error when binding fails.
    internal func bind(_ value: Bool, at index: Int32, in statement: OpaquePointer) throws {
        let integer = value ? DatabaseConstants.sqliteTrue : DatabaseConstants.sqliteFalse
        guard sqlite3_bind_int(statement, index, integer) == SQLITE_OK else {
            throw LocalAssistantError.database(databaseErrorMessage())
        }
    }

    /// Binds a signed 64-bit integer.
    /// - Parameters:
    ///   - value: Integer value.
    ///   - index: One-based parameter index.
    ///   - statement: Prepared statement receiving the value.
    /// - Throws: A local database error when binding fails.
    internal func bind(_ value: Int64, at index: Int32, in statement: OpaquePointer) throws {
        guard sqlite3_bind_int64(statement, index, value) == SQLITE_OK else {
            throw LocalAssistantError.database(databaseErrorMessage())
        }
    }

    /// Binds a platform integer.
    /// - Parameters:
    ///   - value: Integer value.
    ///   - index: One-based parameter index.
    ///   - statement: Prepared statement receiving the value.
    /// - Throws: A local database error when binding fails.
    internal func bind(_ value: Int, at index: Int32, in statement: OpaquePointer) throws {
        try bind(Int64(value), at: index, in: statement)
    }

    /// Binds an optional platform integer.
    /// - Parameters:
    ///   - value: Optional integer value.
    ///   - index: One-based parameter index.
    ///   - statement: Prepared statement receiving the value.
    /// - Throws: A local database error when binding fails.
    internal func bind(_ value: Int?, at index: Int32, in statement: OpaquePointer) throws {
        if let value {
            try bind(value, at: index, in: statement)
        } else if sqlite3_bind_null(statement, index) != SQLITE_OK {
            throw LocalAssistantError.database(databaseErrorMessage())
        }
    }

    /// Binds a double-precision value.
    /// - Parameters:
    ///   - value: Floating-point value.
    ///   - index: One-based parameter index.
    ///   - statement: Prepared statement receiving the value.
    /// - Throws: A local database error when binding fails.
    internal func bind(_ value: Double, at index: Int32, in statement: OpaquePointer) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw LocalAssistantError.database(databaseErrorMessage())
        }
    }

    /// Returns the current SQLite connection's diagnostic text.
    /// - Returns: A local SQLite message without indexed content.
    internal func databaseErrorMessage() -> String {
        guard let connection, let message = sqlite3_errmsg(connection) else {
            return DatabaseConstants.missingDatabase
        }
        return String(cString: message)
    }

    /// Reads a required text column.
    /// - Parameters:
    ///   - statement: Statement positioned on a row.
    ///   - column: Zero-based column index.
    /// - Returns: The decoded string, or an empty string for a null column.
    internal func requiredText(_ statement: OpaquePointer, column: Int32) -> String {
        guard let value = sqlite3_column_text(statement, column) else { return AppConstants.Text.empty }
        return String(cString: value)
    }

    /// Reads an optional text column.
    /// - Parameters:
    ///   - statement: Statement positioned on a row.
    ///   - column: Zero-based column index.
    /// - Returns: The decoded string or `nil`.
    internal func optionalText(_ statement: OpaquePointer, column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return requiredText(statement, column: column)
    }

    /// Reads a required data column.
    /// - Parameters:
    ///   - statement: Statement positioned on a row.
    ///   - column: Zero-based column index.
    /// - Returns: Copied bytes from SQLite.
    internal func requiredData(_ statement: OpaquePointer, column: Int32) -> Data {
        let count = Int(sqlite3_column_bytes(statement, column))
        guard count > 0, let bytes = sqlite3_column_blob(statement, column) else { return Data() }
        return Data(bytes: bytes, count: count)
    }

    /// Reads a required timestamp column.
    /// - Parameters:
    ///   - statement: Statement positioned on a row.
    ///   - column: Zero-based column index.
    /// - Returns: Date decoded from Unix time.
    internal func requiredDate(_ statement: OpaquePointer, column: Int32) -> Date {
        Date(timeIntervalSince1970: sqlite3_column_double(statement, column))
    }

    /// Reads an optional timestamp column.
    /// - Parameters:
    ///   - statement: Statement positioned on a row.
    ///   - column: Zero-based column index.
    /// - Returns: Decoded date or `nil`.
    internal func optionalDate(_ statement: OpaquePointer, column: Int32) -> Date? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return requiredDate(statement, column: column)
    }

    /// Enforces owner-only permissions on current SQLite files.
    /// - Throws: A local permission error when attributes cannot be set.
    private func protectDatabaseFiles() throws {
        let databaseURL = try resolvedDatabaseURL()
        let candidates = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + DatabaseConstants.writeAheadLogSuffix),
            URL(fileURLWithPath: databaseURL.path + DatabaseConstants.sharedMemorySuffix)
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            do {
                try FileManager.default.setAttributes(
                    [.posixPermissions: AppConstants.Storage.ownerOnlyFilePermissions],
                    ofItemAtPath: candidate.path
                )
            } catch {
                throw LocalAssistantError.permission(error.localizedDescription)
            }
        }
    }

    /// Resolves the production database URL unless an isolated harness supplied one.
    /// - Returns: Writable private SQLite location.
    /// - Throws: A local directory-resolution error for the production path.
    private func resolvedDatabaseURL() throws -> URL {
        if let databaseURLOverride { return databaseURLOverride }
        return try AppDirectories.databaseURL()
    }
}
