import Foundation
import Testing

@testable import LocalAssistant

/// Folder indexing must preserve hierarchy and provide bounded local search context.
struct FolderIndexingTests {
    @Test("The authorized root and its child hierarchy are included in a scan")
    internal func scansAuthorizedRootAsFolder() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                FolderIndexTestConstants.scannerDirectoryPrefix + UUID().uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let noteURL = rootURL.appendingPathComponent(FolderIndexTestConstants.noteName)
        try FolderIndexTestConstants.noteText.write(
            to: noteURL,
            atomically: true,
            encoding: .utf8
        )
        let root = AuthorizedRoot(
            id: FolderIndexTestConstants.rootID,
            displayName: rootURL.lastPathComponent,
            lastKnownPath: rootURL.path,
            bookmarkData: Data([FolderIndexTestConstants.bookmarkByte]),
            addedAt: Date(),
            lastIndexedAt: nil,
            isAvailable: true
        )

        let snapshot = try ReadOnlyFileScanner().scan(root: root, at: rootURL)
        let rootItem = try #require(snapshot.files.first?.item)
        let noteItem = try #require(
            snapshot.files.first(where: {
                $0.item.displayName == FolderIndexTestConstants.noteName
            })?.item
        )

        #expect(rootItem.kind == .folder)
        #expect(rootItem.relativePath.isEmpty)
        #expect(rootItem.parentID == nil)
        #expect(noteItem.parentID == rootItem.id)
    }

    @Test("Folder context includes the root identity and direct children")
    internal func buildsFolderContext() throws {
        let items = folderItems()
        let scannedItems = items.map { item in
            ScannedFile(item: item, isExtractable: item.kind != .folder)
        }
        let chunks = FolderContextBuilder().chunks(in: scannedItems)
        let rootChunk = try #require(chunks[FolderIndexTestConstants.rootItemID])

        #expect(rootChunk.text.contains(FileConstants.FolderIndex.titlePrefix + FolderIndexTestConstants.schoolName))
        #expect(rootChunk.text.contains(FileConstants.FolderIndex.pathPrefix + FolderIndexTestConstants.schoolName))
        #expect(rootChunk.text.contains(FolderIndexTestConstants.biologyName))
        #expect(rootChunk.text.contains(FolderIndexTestConstants.transcriptName))
    }

    @Test("Folders require a searchable context before they can be unchanged")
    internal func requiresFolderContentHash() {
        let folder = ScannedFile(item: folderItems()[0], isExtractable: false)
        #expect(folder.requiresContentIndexing)
        #expect(
            IndexingDecisionPolicy.itemIsUnchanged(
                metadataMatches: true,
                requiresContentIndexing: folder.requiresContentIndexing,
                previousContentHash: nil
            ) == false
        )
        #expect(
            IndexingDecisionPolicy.itemIsUnchanged(
                metadataMatches: true,
                requiresContentIndexing: folder.requiresContentIndexing,
                previousContentHash: FolderIndexTestConstants.folderHash
            )
        )
    }

    @Test("Descendant lookup keeps a hard PDF constraint inside the matched folder")
    internal func filtersFolderDescendantsByKind() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(FolderIndexTestConstants.databaseExtension)
        let database = AssistantDatabase(databaseURL: databaseURL)
        try await database.open()
        let root = AuthorizedRoot(
            id: FolderIndexTestConstants.rootID,
            displayName: FolderIndexTestConstants.schoolName,
            lastKnownPath: FolderIndexTestConstants.schoolPath,
            bookmarkData: Data([FolderIndexTestConstants.bookmarkByte]),
            addedAt: Date(),
            lastIndexedAt: nil,
            isAvailable: true
        )
        try await database.upsertRoot(root)
        let items = folderItems()
        for item in items {
            try await database.replaceItem(item, chunks: [])
        }

        let results = try await database.descendants(
            of: items[0],
            kinds: Set([IndexedItemKind.pdf]),
            limit: AppConstants.Chat.retrievalCandidateLimit
        )
        await database.close()
        removeDatabaseFiles(at: databaseURL)

        #expect(results.map(\.id) == [FolderIndexTestConstants.childFileID])
    }

    @Test("Metadata publication makes the complete folder hierarchy searchable immediately")
    internal func publishesFolderHierarchyBeforeContent() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(FolderIndexTestConstants.databaseExtension)
        let database = AssistantDatabase(databaseURL: databaseURL)
        try await database.open()
        let root = AuthorizedRoot(
            id: FolderIndexTestConstants.rootID,
            displayName: FolderIndexTestConstants.schoolName,
            lastKnownPath: FolderIndexTestConstants.schoolPath,
            bookmarkData: Data([FolderIndexTestConstants.bookmarkByte]),
            addedAt: Date(),
            lastIndexedAt: nil,
            isAvailable: true
        )
        try await database.upsertRoot(root)
        let items = folderItems()
        try await database.upsertItemMetadata(items)

        let folderMatches = try await database.metadataSearch(
            text: FolderIndexTestConstants.schoolSearchTerm,
            kinds: [.folder],
            limit: AppConstants.Chat.retrievalCandidateLimit
        )
        let descendants = try await database.descendants(
            of: items[0],
            kinds: [],
            limit: AppConstants.Chat.retrievalCandidateLimit
        )
        await database.close()
        removeDatabaseFiles(at: databaseURL)

        #expect(folderMatches.first?.id == FolderIndexTestConstants.rootItemID)
        #expect(descendants.map(\.id).contains(FolderIndexTestConstants.childFolderID))
        #expect(descendants.map(\.id).contains(FolderIndexTestConstants.childFileID))
    }

    @Test("Metadata publication preserves previously extracted searchable passages")
    internal func preservesContentDuringMetadataPublication() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(FolderIndexTestConstants.databaseExtension)
        let database = AssistantDatabase(databaseURL: databaseURL)
        try await database.open()
        let root = AuthorizedRoot(
            id: FolderIndexTestConstants.rootID,
            displayName: FolderIndexTestConstants.schoolName,
            lastKnownPath: FolderIndexTestConstants.schoolPath,
            bookmarkData: Data([FolderIndexTestConstants.bookmarkByte]),
            addedAt: Date(),
            lastIndexedAt: nil,
            isAvailable: true
        )
        try await database.upsertRoot(root)
        let transcript = folderItems()[2]
        let chunk = ContentChunk(
            id: UUID(),
            itemID: transcript.id,
            ordinal: 0,
            text: FolderIndexTestConstants.transcriptSearchText,
            characterStart: 0,
            characterEnd: FolderIndexTestConstants.transcriptSearchText.count,
            pageNumber: nil,
            sectionName: nil,
            embedding: nil
        )
        try await database.replaceItem(transcript, chunks: [chunk])
        try await database.upsertItemMetadata([transcript])

        let keywordHits = try await database.keywordSearch(
            text: FolderIndexTestConstants.transcriptSearchText,
            kinds: [],
            limit: AppConstants.Chat.retrievalCandidateLimit
        )
        await database.close()
        removeDatabaseFiles(at: databaseURL)

        #expect(keywordHits.first?.itemID == transcript.id)
    }

    @Test("Clearing the search index removes indexed content but keeps folders and conversations")
    internal func clearsSearchIndexWithoutTouchingRootsOrConversations() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(FolderIndexTestConstants.databaseExtension)
        let database = AssistantDatabase(databaseURL: databaseURL)
        try await database.open()
        let root = AuthorizedRoot(
            id: FolderIndexTestConstants.rootID,
            displayName: FolderIndexTestConstants.schoolName,
            lastKnownPath: FolderIndexTestConstants.schoolPath,
            bookmarkData: Data([FolderIndexTestConstants.bookmarkByte]),
            addedAt: Date(),
            lastIndexedAt: nil,
            isAvailable: true
        )
        try await database.upsertRoot(root)
        let transcript = folderItems()[2]
        let chunk = ContentChunk(
            id: UUID(),
            itemID: transcript.id,
            ordinal: 0,
            text: FolderIndexTestConstants.transcriptSearchText,
            characterStart: 0,
            characterEnd: FolderIndexTestConstants.transcriptSearchText.count,
            pageNumber: nil,
            sectionName: nil,
            embedding: nil
        )
        try await database.replaceItem(transcript, chunks: [chunk])
        try await database.insertChatMessage(.user(FolderIndexTestConstants.schoolSearchTerm))

        let countBeforeClear = try await database.indexedFileCount()
        try await database.clearSearchIndex()
        let countAfterClear = try await database.indexedFileCount()
        let remainingRoots = try await database.fetchRoots()
        let remainingMessages = try await database.fetchChatMessages(
            limit: AppConstants.Chat.historyLimit
        )
        await database.close()
        removeDatabaseFiles(at: databaseURL)

        #expect(countBeforeClear == 1)
        #expect(countAfterClear == 0)
        #expect(remainingRoots.map(\.id) == [root.id])
        #expect(remainingMessages.isEmpty == false)
    }

    @Test("Database storage size reflects the file actually written to disk")
    internal func reportsDatabaseByteCountFromDisk() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(FolderIndexTestConstants.databaseExtension)
        let database = AssistantDatabase(databaseURL: databaseURL)
        try await database.open()
        let root = AuthorizedRoot(
            id: FolderIndexTestConstants.rootID,
            displayName: FolderIndexTestConstants.schoolName,
            lastKnownPath: FolderIndexTestConstants.schoolPath,
            bookmarkData: Data([FolderIndexTestConstants.bookmarkByte]),
            addedAt: Date(),
            lastIndexedAt: nil,
            isAvailable: true
        )
        try await database.upsertRoot(root)

        let byteCount = try await database.databaseByteCount()
        await database.close()
        let onDiskSize = try FileManager.default
            .attributesOfItem(atPath: databaseURL.path)[.size] as? Int64
        removeDatabaseFiles(at: databaseURL)

        #expect(byteCount > 0)
        #expect(byteCount >= onDiskSize ?? 0)
    }

    /// Creates one root folder, one direct folder, and one direct PDF fixture.
    /// - Returns: Hierarchical indexed items in root-first order.
    private func folderItems() -> [IndexedItem] {
        let root = TestFixtures.item(
            name: FolderIndexTestConstants.schoolName,
            path: FolderIndexTestConstants.schoolPath,
            relativePath: AppConstants.Text.empty,
            id: FolderIndexTestConstants.rootItemID,
            rootID: FolderIndexTestConstants.rootID,
            isDirectory: true,
            kind: .folder
        )
        let biology = TestFixtures.item(
            name: FolderIndexTestConstants.biologyName,
            path: FolderIndexTestConstants.biologyPath,
            id: FolderIndexTestConstants.childFolderID,
            rootID: FolderIndexTestConstants.rootID,
            parentID: FolderIndexTestConstants.rootItemID,
            isDirectory: true,
            kind: .folder
        )
        let transcript = TestFixtures.item(
            name: FolderIndexTestConstants.transcriptName,
            path: FolderIndexTestConstants.transcriptPath,
            id: FolderIndexTestConstants.childFileID,
            rootID: FolderIndexTestConstants.rootID,
            parentID: FolderIndexTestConstants.rootItemID,
            kind: .pdf
        )
        return [root, biology, transcript]
    }

    /// Removes the isolated SQLite database and its transient sidecars.
    /// - Parameter url: Main temporary database URL.
    private func removeDatabaseFiles(at url: URL) {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: url)
        try? fileManager.removeItem(
            at: URL(fileURLWithPath: url.path + DatabaseConstants.writeAheadLogSuffix)
        )
        try? fileManager.removeItem(
            at: URL(fileURLWithPath: url.path + DatabaseConstants.sharedMemorySuffix)
        )
    }
}
