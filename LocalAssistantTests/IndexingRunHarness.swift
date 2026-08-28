import Foundation

@testable import LocalAssistant

/// Builds an isolated root folder and private database so one indexing run can be observed.
final class IndexingRunHarness {
    let rootURL: URL
    let databaseURL: URL
    let database: AssistantDatabase
    let embeddings: StubDocumentEmbedding
    private let root: AuthorizedRoot

    /// Creates a temporary root holding two readable notes and an empty private index.
    /// - Throws: A file system error when the fixture folder cannot be written.
    internal init() throws {
        rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                IndexingRunTestConstants.rootDirectoryPrefix + UUID().uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try IndexingRunTestConstants.firstNoteText.write(
            to: rootURL.appendingPathComponent(IndexingRunTestConstants.firstNoteName),
            atomically: true,
            encoding: .utf8
        )
        try IndexingRunTestConstants.secondNoteText.write(
            to: rootURL.appendingPathComponent(IndexingRunTestConstants.secondNoteName),
            atomically: true,
            encoding: .utf8
        )
        databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(IndexingRunTestConstants.databaseExtension)
        database = AssistantDatabase(databaseURL: databaseURL)
        embeddings = StubDocumentEmbedding()
        root = AuthorizedRoot(
            id: UUID(),
            displayName: rootURL.lastPathComponent,
            lastKnownPath: rootURL.path,
            bookmarkData: try rootURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ),
            addedAt: Date(),
            lastIndexedAt: nil,
            isAvailable: true
        )
    }

    /// Opens the private index and registers the fixture root.
    /// - Throws: A local database error when the index cannot be prepared.
    internal func open() async throws {
        try await database.open()
        try await database.upsertRoot(root)
    }

    /// Runs one complete indexing pass over the fixture root.
    /// - Parameter embeddings: Embedding source for this run.
    /// - Returns: Completed indexing statistics.
    /// - Throws: Whatever the indexing pipeline reports for this run.
    internal func index(embeddings: DocumentEmbedding) async throws -> IndexingOutcome {
        let service = IndexingService(
            database: database,
            scanner: ReadOnlyFileScanner(),
            extractor: ExtractionCoordinator(),
            chunker: TextChunker(),
            embeddings: embeddings
        )
        let authorizedRoot = root
        let access = try await MainActor.run {
            try ReadOnlyAuthorizationService().beginAccess(to: authorizedRoot)
        }
        return try await service.index(
            root: root,
            access: access,
            trigger: .manual,
            progress: { _ in }
        )
    }

    /// Reads the recorded per-file states of one run keyed by visible name.
    /// - Parameter runID: Durable run identifier.
    /// - Returns: Final state recorded for each named item.
    /// - Throws: A local database error when the activity rows cannot be read.
    internal func itemStates(runID: UUID) async throws -> [String: IndexingItemState] {
        let items = try await database.fetchIndexingItems(runID: runID)
        return Dictionary(
            items.map { ($0.displayName, $0.state) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    /// Reads the relative paths still stored in the private index.
    /// - Returns: Relative path of every item retained for the fixture root.
    /// - Throws: A local database error when the rows cannot be read.
    internal func indexedRelativePaths() async throws -> Set<String> {
        Set(try await database.fetchItems(rootID: root.id).map(\.relativePath))
    }

    /// Replaces the first note's contents so the next run sees a modification.
    /// - Throws: A file system error when the note cannot be rewritten.
    internal func rewriteFirstNote() throws {
        try IndexingRunTestConstants.revisedNoteText.write(
            to: rootURL.appendingPathComponent(IndexingRunTestConstants.firstNoteName),
            atomically: true,
            encoding: .utf8
        )
    }

    /// Deletes the second note so the next run sees a removal.
    /// - Throws: A file system error when the note cannot be removed.
    internal func deleteSecondNote() throws {
        try FileManager.default.removeItem(
            at: rootURL.appendingPathComponent(IndexingRunTestConstants.secondNoteName)
        )
    }

    /// Closes the private index before its files are removed.
    internal func close() async {
        await database.close()
    }

    /// Removes the fixture root, the database, and its transient sidecars.
    internal func tearDown() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: rootURL)
        try? fileManager.removeItem(at: databaseURL)
        try? fileManager.removeItem(
            at: URL(fileURLWithPath: databaseURL.path + DatabaseConstants.writeAheadLogSuffix)
        )
        try? fileManager.removeItem(
            at: URL(fileURLWithPath: databaseURL.path + DatabaseConstants.sharedMemorySuffix)
        )
    }
}
