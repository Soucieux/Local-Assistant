import Foundation

/// SQLite identifiers, diagnostic messages, and binding values.
enum DatabaseConstants {
    static let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    static let openFailure = "The private index could not be opened."
    static let vectorRegistrationFailure = "The embedded vector extension could not be registered."
    static let statementPreparationFailure = "A local database statement could not be prepared."
    static let statementExecutionFailure = "A local database statement could not be executed."
    static let missingDatabase = "The private index is not open."
    static let missingRow = "The requested local database row was not found."
    static let sqliteTrue: Int32 = 1
    static let sqliteFalse: Int32 = 0
    static let writeAheadLogSuffix = "-wal"
    static let sharedMemorySuffix = "-shm"

    /// Combines a safe diagnostic prefix with SQLite detail.
    /// - Parameters:
    ///   - prefix: Stable diagnostic prefix.
    ///   - detail: SQLite-generated detail.
    /// - Returns: Combined diagnostic string.
    internal static func message(prefix: String, detail: String) -> String {
        prefix + AppConstants.Text.space + detail
    }
}
