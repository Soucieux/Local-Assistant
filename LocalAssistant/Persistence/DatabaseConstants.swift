import Foundation

/// SQLite identifiers, diagnostic messages, and binding values.
internal enum DatabaseConstants {
    internal static let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    internal static let openFailure = "The private index could not be opened."
    internal static let vectorRegistrationFailure = "The embedded vector extension could not be registered."
    internal static let statementPreparationFailure = "A local database statement could not be prepared."
    internal static let statementExecutionFailure = "A local database statement could not be executed."
    internal static let missingDatabase = "The private index is not open."
    internal static let missingRow = "The requested local database row was not found."
    internal static let maximumBoundIdentifiers = 500
    internal static let maximumVectorNeighborCount = 4_096
    internal static let sqliteTrue: Int32 = 1
    internal static let sqliteFalse: Int32 = 0
    internal static let writeAheadLogSuffix = "-wal"
    internal static let sharedMemorySuffix = "-shm"

    /// Combines a safe diagnostic prefix with SQLite detail.
    /// - Parameters:
    ///   - prefix: Stable diagnostic prefix.
    ///   - detail: SQLite-generated detail.
    /// - Returns: Combined diagnostic string.
    internal static func message(prefix: String, detail: String) -> String {
        prefix + AppConstants.Text.space + detail
    }

    /// Restricts one nearest-neighbor request to the embedded sqlite-vec ceiling.
    /// - Parameter requested: Proposed number of vector neighbors.
    /// - Returns: A nonnegative count no greater than the supported maximum.
    internal static func boundedVectorNeighborCount(_ requested: Int) -> Int {
        min(max(0, requested), maximumVectorNeighborCount)
    }

    /// Doubles an adaptive vector batch without crossing its available or engine ceiling.
    /// - Parameters:
    ///   - current: Current nearest-neighbor batch size.
    ///   - available: Number of vectors available to the search.
    /// - Returns: The next bounded batch size.
    internal static func nextVectorNeighborCount(current: Int, available: Int) -> Int {
        let boundedCurrent = boundedVectorNeighborCount(current)
        let boundedAvailable = boundedVectorNeighborCount(available)
        return min(boundedAvailable, boundedCurrent + boundedCurrent)
    }
}
