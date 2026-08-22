import Foundation

/// Centralized SQL used by the private embedded database.
enum SQLStatements {
    static let pragmas = """
        PRAGMA foreign_keys = ON;
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        PRAGMA trusted_schema = OFF;
        PRAGMA temp_store = MEMORY;
        """

    static let schema = """
        CREATE TABLE IF NOT EXISTS authorized_roots (
            id TEXT PRIMARY KEY NOT NULL,
            display_name TEXT NOT NULL,
            last_known_path TEXT NOT NULL,
            bookmark_data BLOB NOT NULL,
            added_at REAL NOT NULL,
            last_indexed_at REAL,
            is_available INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS indexed_items (
            id TEXT PRIMARY KEY NOT NULL,
            root_id TEXT NOT NULL REFERENCES authorized_roots(id) ON DELETE CASCADE,
            parent_id TEXT,
            absolute_path TEXT NOT NULL UNIQUE,
            relative_path TEXT NOT NULL,
            display_name TEXT NOT NULL,
            kind TEXT NOT NULL,
            content_type TEXT,
            byte_count INTEGER NOT NULL,
            created_at REAL,
            modified_at REAL,
            content_hash TEXT,
            metadata_hash TEXT NOT NULL,
            is_directory INTEGER NOT NULL,
            is_hidden INTEGER NOT NULL
        );

        CREATE INDEX IF NOT EXISTS indexed_items_root_id ON indexed_items(root_id);
        CREATE INDEX IF NOT EXISTS indexed_items_name ON indexed_items(display_name COLLATE NOCASE);
        CREATE INDEX IF NOT EXISTS indexed_items_relative_path ON indexed_items(relative_path COLLATE NOCASE);
        CREATE INDEX IF NOT EXISTS indexed_items_content_hash ON indexed_items(content_hash);
        CREATE INDEX IF NOT EXISTS indexed_items_modified_at ON indexed_items(modified_at);

        CREATE TABLE IF NOT EXISTS content_chunks (
            row_id INTEGER PRIMARY KEY AUTOINCREMENT,
            id TEXT NOT NULL UNIQUE,
            item_id TEXT NOT NULL REFERENCES indexed_items(id) ON DELETE CASCADE,
            ordinal INTEGER NOT NULL,
            text TEXT NOT NULL,
            character_start INTEGER NOT NULL,
            character_end INTEGER NOT NULL,
            page_number INTEGER,
            section_name TEXT,
            UNIQUE(item_id, ordinal)
        );

        CREATE INDEX IF NOT EXISTS content_chunks_item_id ON content_chunks(item_id);

        CREATE VIRTUAL TABLE IF NOT EXISTS chunk_fts USING fts5(
            chunk_id UNINDEXED,
            item_id UNINDEXED,
            display_name,
            relative_path,
            body,
            tokenize='unicode61 remove_diacritics 2'
        );

        CREATE VIRTUAL TABLE IF NOT EXISTS chunk_vectors USING vec0(
            embedding float[1024]
        );

        CREATE TABLE IF NOT EXISTS saved_searches (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            payload BLOB NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS collections (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            payload BLOB NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS personal_aliases (
            id TEXT PRIMARY KEY NOT NULL,
            phrase TEXT NOT NULL UNIQUE COLLATE NOCASE,
            expansion TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS chat_messages (
            id TEXT PRIMARY KEY NOT NULL,
            role TEXT NOT NULL,
            payload BLOB NOT NULL,
            created_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS app_metadata (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS folder_monitoring_states (
            root_id TEXT PRIMARY KEY NOT NULL REFERENCES authorized_roots(id) ON DELETE CASCADE,
            is_enabled INTEGER NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS indexing_runs (
            id TEXT PRIMARY KEY NOT NULL,
            root_id TEXT NOT NULL,
            folder_name TEXT NOT NULL,
            folder_path TEXT NOT NULL,
            trigger TEXT NOT NULL,
            state TEXT NOT NULL,
            started_at REAL NOT NULL,
            finished_at REAL,
            total_items INTEGER NOT NULL,
            new_items INTEGER NOT NULL,
            updated_items INTEGER NOT NULL,
            unchanged_items INTEGER NOT NULL,
            removed_items INTEGER NOT NULL,
            skipped_items INTEGER NOT NULL
        );

        CREATE INDEX IF NOT EXISTS indexing_runs_started_at ON indexing_runs(started_at DESC);
        CREATE INDEX IF NOT EXISTS indexing_runs_root_id ON indexing_runs(root_id);

        CREATE TABLE IF NOT EXISTS indexing_run_items (
            id TEXT PRIMARY KEY NOT NULL,
            run_id TEXT NOT NULL REFERENCES indexing_runs(id) ON DELETE CASCADE,
            display_name TEXT NOT NULL,
            relative_path TEXT NOT NULL,
            state TEXT NOT NULL,
            detail TEXT,
            updated_at REAL NOT NULL,
            UNIQUE(run_id, relative_path)
        );

        CREATE INDEX IF NOT EXISTS indexing_run_items_run_id ON indexing_run_items(run_id);

        CREATE TABLE IF NOT EXISTS index_activity_events (
            id TEXT PRIMARY KEY NOT NULL,
            root_id TEXT NOT NULL,
            folder_name TEXT NOT NULL,
            kind TEXT NOT NULL,
            occurred_at REAL NOT NULL
        );

        CREATE INDEX IF NOT EXISTS index_activity_events_occurred_at
            ON index_activity_events(occurred_at DESC);
        """

    static let beginTransaction = "BEGIN IMMEDIATE TRANSACTION;"
    static let commitTransaction = "COMMIT;"
    static let rollbackTransaction = "ROLLBACK;"

    static let upsertRoot = """
        INSERT INTO authorized_roots (
            id, display_name, last_known_path, bookmark_data, added_at, last_indexed_at, is_available
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            display_name = excluded.display_name,
            last_known_path = excluded.last_known_path,
            bookmark_data = excluded.bookmark_data,
            last_indexed_at = excluded.last_indexed_at,
            is_available = excluded.is_available;
        """
    static let fetchRoots = """
        SELECT id, display_name, last_known_path, bookmark_data, added_at, last_indexed_at, is_available
        FROM authorized_roots ORDER BY display_name COLLATE NOCASE;
        """
    static let deleteRoot = "DELETE FROM authorized_roots WHERE id = ?;"

    static let upsertItem = """
        INSERT INTO indexed_items (
            id, root_id, parent_id, absolute_path, relative_path, display_name, kind, content_type,
            byte_count, created_at, modified_at, content_hash, metadata_hash, is_directory, is_hidden
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(absolute_path) DO UPDATE SET
            id = excluded.id,
            root_id = excluded.root_id,
            parent_id = excluded.parent_id,
            relative_path = excluded.relative_path,
            display_name = excluded.display_name,
            kind = excluded.kind,
            content_type = excluded.content_type,
            byte_count = excluded.byte_count,
            created_at = excluded.created_at,
            modified_at = excluded.modified_at,
            content_hash = excluded.content_hash,
            metadata_hash = excluded.metadata_hash,
            is_directory = excluded.is_directory,
            is_hidden = excluded.is_hidden;
        """
    static let fetchItem = """
        SELECT id, root_id, parent_id, absolute_path, relative_path, display_name, kind, content_type,
               byte_count, created_at, modified_at, content_hash, metadata_hash, is_directory, is_hidden
        FROM indexed_items WHERE id = ?;
        """
    static let fetchItemsForRoot = """
        SELECT id, root_id, parent_id, absolute_path, relative_path, display_name, kind, content_type,
               byte_count, created_at, modified_at, content_hash, metadata_hash, is_directory, is_hidden
        FROM indexed_items WHERE root_id = ?;
        """
    static let fetchItemsByKind = """
        SELECT id, root_id, parent_id, absolute_path, relative_path, display_name, kind, content_type,
               byte_count, created_at, modified_at, content_hash, metadata_hash, is_directory, is_hidden
        FROM indexed_items
        WHERE kind = ?
        ORDER BY modified_at DESC, display_name COLLATE NOCASE
        LIMIT ?;
        """
    static let deleteItem = "DELETE FROM indexed_items WHERE id = ?;"
    static let deleteChunksForItem = "DELETE FROM content_chunks WHERE item_id = ?;"
    static let deleteFTSForItem = "DELETE FROM chunk_fts WHERE item_id = ?;"
    static let fetchChunkRowsForItem = "SELECT row_id FROM content_chunks WHERE item_id = ?;"
    static let deleteVector = "DELETE FROM chunk_vectors WHERE rowid = ?;"
    static let insertChunk = """
        INSERT INTO content_chunks (
            id, item_id, ordinal, text, character_start, character_end, page_number, section_name
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
    static let insertFTS = """
        INSERT INTO chunk_fts (chunk_id, item_id, display_name, relative_path, body)
        VALUES (?, ?, ?, ?, ?);
        """
    static let insertVector = "INSERT INTO chunk_vectors(rowid, embedding) VALUES (?, ?);"
    static let vectorCount = "SELECT COUNT(*) FROM chunk_vectors;"

    /// Counts vectors belonging to the requested item kinds.
    ///
    /// Adaptive neighbor expansion widens until it finds enough eligible matches, so a
    /// kind with no vectors at all would otherwise widen until it had scanned every
    /// vector, on every query. This count settles that in one cheap statement.
    /// - Parameter kindCount: Number of kind values bound to the statement.
    /// - Returns: Parameterized eligible-vector count SQL.
    internal static func eligibleVectorCount(kindCount: Int) -> String {
        """
        SELECT COUNT(*)
        FROM chunk_vectors AS v
        JOIN content_chunks AS c ON c.row_id = v.rowid
        JOIN indexed_items AS i ON i.id = c.item_id
        WHERE \(kindPredicate(column: "i.kind", count: kindCount));
        """
    }
    static let insertChatMessage = "INSERT OR REPLACE INTO chat_messages (id, role, payload, created_at) VALUES (?, ?, ?, ?);"
    static let fetchChatMessages = "SELECT payload FROM chat_messages ORDER BY created_at DESC LIMIT ?;"
    static let clearChatMessages = "DELETE FROM chat_messages;"

    static let upsertMonitoringState = """
        INSERT INTO folder_monitoring_states (root_id, is_enabled, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(root_id) DO UPDATE SET
            is_enabled = excluded.is_enabled,
            updated_at = excluded.updated_at;
        """
    static let fetchMonitoringStates = "SELECT root_id, is_enabled FROM folder_monitoring_states;"
    static let insertIndexingRun = """
        INSERT INTO indexing_runs (
            id, root_id, folder_name, folder_path, trigger, state, started_at, finished_at,
            total_items, new_items, updated_items, unchanged_items, removed_items, skipped_items
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
    static let updateIndexingRun = """
        UPDATE indexing_runs SET
            state = ?, finished_at = ?, total_items = ?, new_items = ?, updated_items = ?,
            unchanged_items = ?, removed_items = ?, skipped_items = ?
        WHERE id = ?;
        """
    static let fetchIndexingRuns = """
        SELECT id, root_id, folder_name, folder_path, trigger, state, started_at, finished_at,
               total_items, new_items, updated_items, unchanged_items, removed_items, skipped_items
        FROM indexing_runs ORDER BY started_at DESC;
        """
    static let upsertIndexingRunItem = """
        INSERT INTO indexing_run_items (id, run_id, display_name, relative_path, state, detail, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(run_id, relative_path) DO UPDATE SET
            display_name = excluded.display_name,
            state = excluded.state,
            detail = excluded.detail,
            updated_at = excluded.updated_at;
        """
    static let fetchIndexingRunItems = """
        SELECT id, run_id, display_name, relative_path, state, detail, updated_at
        FROM indexing_run_items WHERE run_id = ?
        ORDER BY relative_path COLLATE NOCASE;
        """
    static let insertIndexActivityEvent = """
        INSERT INTO index_activity_events (id, root_id, folder_name, kind, occurred_at)
        VALUES (?, ?, ?, ?, ?);
        """
    static let fetchIndexActivityEvents = """
        SELECT id, root_id, folder_name, kind, occurred_at
        FROM index_activity_events ORDER BY occurred_at DESC;
        """
    static let deleteExpiredIndexingRuns = "DELETE FROM indexing_runs WHERE started_at < ?;"
    static let deleteExpiredIndexActivityEvents = "DELETE FROM index_activity_events WHERE occurred_at < ?;"
    static let clearIndexingRuns = "DELETE FROM indexing_runs;"
    static let clearIndexActivityEvents = "DELETE FROM index_activity_events;"
    static let stopInterruptedIndexingRuns = """
        UPDATE indexing_runs SET state = ?, finished_at = ? WHERE state = ?;
        """
    static let resetInterruptedIndexingItems = """
        UPDATE indexing_run_items
        SET state = CASE state
                WHEN ? THEN ?
                WHEN ? THEN ?
                ELSE state
            END,
            updated_at = ?
        WHERE run_id IN (SELECT id FROM indexing_runs WHERE state = ?)
          AND state IN (?, ?);
        """

    /// Builds metadata retrieval with hard item kinds applied before the row limit.
    /// - Parameter kindCount: Number of kind values that will be bound first.
    /// - Returns: Parameterized metadata search SQL.
    internal static func metadataSearch(kindCount: Int, tokenCount: Int) -> String {
        """
        SELECT id, root_id, parent_id, absolute_path, relative_path, display_name, kind, content_type,
               byte_count, created_at, modified_at, content_hash, metadata_hash, is_directory, is_hidden
        FROM indexed_items
        WHERE \(kindPredicate(column: "kind", count: kindCount))
          AND \(tokenPredicate(count: tokenCount))
        ORDER BY
            CASE WHEN lower(display_name) = lower(?) THEN 0
                 WHEN lower(display_name) LIKE lower(?) ESCAPE '\\' THEN 1
                 ELSE 2 END,
            modified_at DESC
        LIMIT ?;
        """
    }

    /// Builds a bounded query for items contained by one indexed folder.
    /// - Parameter kindCount: Number of optional hard item kinds bound after the folder path.
    /// - Returns: Parameterized descendant search SQL.
    internal static func descendantItems(kindCount: Int) -> String {
        """
        SELECT id, root_id, parent_id, absolute_path, relative_path, display_name, kind, content_type,
               byte_count, created_at, modified_at, content_hash, metadata_hash, is_directory, is_hidden
        FROM indexed_items
        WHERE root_id = ?
          AND id != ?
          AND absolute_path LIKE ? ESCAPE '\\'
          AND \(kindPredicate(column: "kind", count: kindCount))
        ORDER BY
            CASE WHEN parent_id = ? THEN 0 ELSE 1 END,
            relative_path COLLATE NOCASE
        LIMIT ?;
        """
    }

    /// Builds a batched item lookup for a bounded set of identifiers.
    ///
    /// Resolving candidates one at a time costs a prepared statement and an actor hop per
    /// item, which dominates both search and conversation restore once an index grows.
    /// - Parameter idCount: Number of identifiers bound to the statement.
    /// - Returns: Parameterized multi-item lookup SQL.
    internal static func fetchItems(idCount: Int) -> String {
        let placeholders = Array(repeating: "?", count: idCount).joined(separator: ", ")
        return """
            SELECT id, root_id, parent_id, absolute_path, relative_path, display_name, kind, content_type,
                   byte_count, created_at, modified_at, content_hash, metadata_hash, is_directory, is_hidden
            FROM indexed_items WHERE id IN (\(placeholders));
            """
    }

    /// Requires every search token to appear in the display name or the relative path.
    ///
    /// One pattern built from the whole query only matches a name containing the words
    /// contiguously and with identical spacing, which hyphenated and underscored
    /// filenames never do.
    /// - Parameter count: Number of tokens bound before the ordering parameters.
    /// - Returns: An always-true predicate or a parameterized per-token predicate.
    private static func tokenPredicate(count: Int) -> String {
        guard count > 0 else { return "1 = 1" }
        let clause = "(display_name LIKE ? ESCAPE '\\' OR relative_path LIKE ? ESCAPE '\\')"
        return Array(repeating: clause, count: count).joined(separator: " AND ")
    }

    /// Builds FTS retrieval with hard item kinds applied before the row limit.
    /// - Parameter kindCount: Number of kind values that will be bound first.
    /// - Returns: Parameterized full-text search SQL.
    internal static func keywordSearch(kindCount: Int) -> String {
        """
        SELECT chunk_fts.chunk_id, chunk_fts.item_id, chunk_fts.body,
               bm25(chunk_fts, 0.0, 0.0, 6.0, 3.0, 1.0) AS rank
        FROM chunk_fts
        JOIN indexed_items AS i ON i.id = chunk_fts.item_id
        WHERE \(kindPredicate(column: "i.kind", count: kindCount))
          AND chunk_fts MATCH ?
        ORDER BY rank
        LIMIT ?;
        """
    }

    /// Builds vector retrieval with hard item kinds applied to each neighbor batch.
    /// - Parameter kindCount: Number of kind values that will be bound first.
    /// - Returns: Parameterized nearest-neighbor search SQL.
    internal static func semanticSearch(kindCount: Int) -> String {
        """
        SELECT c.id, c.item_id, c.text, v.distance
        FROM chunk_vectors AS v
        JOIN content_chunks AS c ON c.row_id = v.rowid
        JOIN indexed_items AS i ON i.id = c.item_id
        WHERE \(kindPredicate(column: "i.kind", count: kindCount))
          AND v.embedding MATCH ? AND k = ?
        ORDER BY v.distance;
        """
    }

    /// Creates a safe placeholder-only kind predicate for a fixed internal column.
    /// - Parameters:
    ///   - column: Internal SQL column name selected by the caller.
    ///   - count: Number of bound kind values.
    /// - Returns: An always-true predicate or a parameterized `IN` predicate.
    private static func kindPredicate(column: String, count: Int) -> String {
        guard count > 0 else { return "1 = 1" }
        let placeholders = Array(repeating: "?", count: count).joined(separator: ", ")
        return "\(column) IN (\(placeholders))"
    }
}
