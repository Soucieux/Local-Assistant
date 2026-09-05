import Foundation
import Testing

@testable import LocalAssistant

/// A statement checked out from the cache must behave exactly like a freshly prepared one.
struct StatementCacheTests {
    @Test("Reopening a closed database serves working statements again")
    internal func servesWorkingStatementsAfterReopening() async throws {
        let fixture = try DatabaseFixture()
        defer { fixture.remove() }
        let database = AssistantDatabase(databaseURL: fixture.databaseURL)
        try await database.open()
        try await database.upsertRoot(root())
        try await database.upsertItemMetadata(items())
        await database.close()

        try await database.open()
        let restored = try await database.fetchItem(id: StatementCacheTestConstants.firstItemID)
        let fileCount = try await database.indexedFileCount()
        await database.close()

        #expect(restored?.displayName == StatementCacheTestConstants.firstName)
        #expect(fileCount == StatementCacheTestConstants.storedFileCount)
    }

    @Test("A lookup abandoned before its last row is reusable afterwards")
    internal func reusesALookupAbandonedBeforeItsLastRow() async throws {
        let fixture = try DatabaseFixture()
        defer { fixture.remove() }
        let database = AssistantDatabase(databaseURL: fixture.databaseURL)
        try await database.open()
        try await database.upsertRoot(root())
        try await database.upsertItemMetadata(items())

        let first = try await database.fetchItem(id: StatementCacheTestConstants.firstItemID)
        let absent = try await database.fetchItem(id: StatementCacheTestConstants.absentItemID)
        let second = try await database.fetchItem(id: StatementCacheTestConstants.secondItemID)
        await database.close()

        #expect(first?.displayName == StatementCacheTestConstants.firstName)
        #expect(absent == nil)
        #expect(second?.displayName == StatementCacheTestConstants.secondName)
    }

    @Test("Batched lookups of different widths keep their own cached statement")
    internal func keepsOneCachedStatementPerBatchWidth() async throws {
        let fixture = try DatabaseFixture()
        defer { fixture.remove() }
        let database = AssistantDatabase(databaseURL: fixture.databaseURL)
        try await database.open()
        try await database.upsertRoot(root())
        try await database.upsertItemMetadata(items())

        let pair = try await database.fetchItems(
            ids: [StatementCacheTestConstants.firstItemID, StatementCacheTestConstants.secondItemID]
        )
        let single = try await database.fetchItems(ids: [StatementCacheTestConstants.secondItemID])
        let pairAgain = try await database.fetchItems(
            ids: [StatementCacheTestConstants.firstItemID, StatementCacheTestConstants.secondItemID]
        )
        await database.close()

        #expect(pair.count == 2)
        #expect(single.count == 1)
        #expect(
            single[StatementCacheTestConstants.secondItemID]?.displayName
                == StatementCacheTestConstants.secondName
        )
        #expect(pairAgain.count == 2)
    }

    /// Creates the authorization the stored items belong to.
    /// - Returns: One available root with a placeholder bookmark.
    private func root() -> AuthorizedRoot {
        AuthorizedRoot(
            id: StatementCacheTestConstants.rootID,
            displayName: StatementCacheTestConstants.rootName,
            lastKnownPath: StatementCacheTestConstants.rootPath,
            bookmarkData: Data([StatementCacheTestConstants.bookmarkByte]),
            addedAt: Date(),
            lastIndexedAt: nil,
            isAvailable: true
        )
    }

    /// Creates the two stored files every test in this suite reads back.
    /// - Returns: Indexed items with stable identifiers.
    private func items() -> [IndexedItem] {
        [
            TestFixtures.item(
                name: StatementCacheTestConstants.firstName,
                path: StatementCacheTestConstants.firstPath,
                id: StatementCacheTestConstants.firstItemID,
                rootID: StatementCacheTestConstants.rootID,
                kind: .pdf
            ),
            TestFixtures.item(
                name: StatementCacheTestConstants.secondName,
                path: StatementCacheTestConstants.secondPath,
                id: StatementCacheTestConstants.secondItemID,
                rootID: StatementCacheTestConstants.rootID,
                kind: .pdf
            )
        ]
    }
}
