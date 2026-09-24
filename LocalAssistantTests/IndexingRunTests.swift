import Foundation
import Testing

@testable import LocalAssistant

/// A complete indexing run must classify every file and survive per-file failures.
internal struct IndexingRunTests {
    @Test("A first run indexes every readable file and completes")
    internal func indexesEveryFileOnFirstRun() async throws {
        let harness = try IndexingRunHarness()
        defer { harness.tearDown() }
        try await harness.open()

        let outcome = try await harness.index(embeddings: harness.embeddings)
        let runs = try await harness.database.fetchIndexingRuns()
        let run = try #require(runs.first)
        let states = try await harness.itemStates(runID: run.id)
        await harness.close()

        #expect(run.state == .completed)
        #expect(run.skippedItems == 0)
        #expect(outcome.newItems == run.newItems)
        #expect(states[IndexingRunTestConstants.firstNoteName] == .newIndexed)
        #expect(states[IndexingRunTestConstants.secondNoteName] == .newIndexed)
    }

    @Test("A second run over untouched files reports them unchanged without re-embedding")
    internal func skipsUnchangedFilesOnSecondRun() async throws {
        let harness = try IndexingRunHarness()
        defer { harness.tearDown() }
        try await harness.open()

        _ = try await harness.index(embeddings: harness.embeddings)
        let callsAfterFirstRun = await harness.embeddings.embedCallCount
        _ = try await harness.index(embeddings: harness.embeddings)
        let callsAfterSecondRun = await harness.embeddings.embedCallCount
        let secondRun = try #require(await harness.database.fetchIndexingRuns().first)
        await harness.close()

        #expect(callsAfterFirstRun > 0)
        #expect(callsAfterSecondRun == callsAfterFirstRun)
        #expect(secondRun.unchangedItems > 0)
        #expect(secondRun.newItems == 0)
    }

    @Test("A modified file is re-indexed and counted as updated")
    internal func reindexesModifiedFiles() async throws {
        let harness = try IndexingRunHarness()
        defer { harness.tearDown() }
        try await harness.open()

        _ = try await harness.index(embeddings: harness.embeddings)
        try harness.rewriteFirstNote()
        _ = try await harness.index(embeddings: harness.embeddings)
        let run = try #require(await harness.database.fetchIndexingRuns().first)
        let states = try await harness.itemStates(runID: run.id)
        await harness.close()

        #expect(run.newItems == 0)
        #expect(states[IndexingRunTestConstants.firstNoteName] == .modifiedUpdated)
        #expect(states[IndexingRunTestConstants.secondNoteName] == .unchanged)
    }

    @Test("A deleted file is removed from the index and counted")
    internal func removesDeletedFiles() async throws {
        let harness = try IndexingRunHarness()
        defer { harness.tearDown() }
        try await harness.open()

        _ = try await harness.index(embeddings: harness.embeddings)
        try harness.deleteSecondNote()
        let outcome = try await harness.index(embeddings: harness.embeddings)
        let run = try #require(await harness.database.fetchIndexingRuns().first)
        let states = try await harness.itemStates(runID: run.id)
        let remainingPaths = try await harness.indexedRelativePaths()
        await harness.close()

        #expect(outcome.removedItems == 1)
        #expect(run.state == .completed)
        #expect(states[IndexingRunTestConstants.secondNoteName] == .removedFromIndex)
        #expect(remainingPaths.contains(IndexingRunTestConstants.firstNoteName))
        #expect(remainingPaths.contains(IndexingRunTestConstants.secondNoteName) == false)
    }

    @Test("A recoverable per-file failure is skipped and the run still completes")
    internal func skipsFilesThatFailRecoverably() async throws {
        let harness = try IndexingRunHarness()
        defer { harness.tearDown() }
        try await harness.open()
        let embeddings = StubDocumentEmbedding(
            failure: .extraction(IndexingRunTestConstants.extractionFailureDetail)
        )

        let outcome = try await harness.index(embeddings: embeddings)
        let run = try #require(await harness.database.fetchIndexingRuns().first)
        let states = try await harness.itemStates(runID: run.id)
        await harness.close()

        #expect(run.state == .completed)
        #expect(outcome.newItems == 0)
        #expect(states.isEmpty == false)
        #expect(states.values.allSatisfy { $0 == .skipped })
    }

    @Test("A missing model aborts the run and records it as failed")
    internal func failsRunWhenTheModelIsMissing() async throws {
        let harness = try IndexingRunHarness()
        defer { harness.tearDown() }
        try await harness.open()
        let embeddings = StubDocumentEmbedding(
            failure: .modelMissing(IndexingRunTestConstants.missingModelDetail)
        )

        await #expect(throws: LocalAssistantError.self) {
            _ = try await harness.index(embeddings: embeddings)
        }
        let run = try #require(await harness.database.fetchIndexingRuns().first)
        let states = try await harness.itemStates(runID: run.id)
        await harness.close()

        #expect(run.state == .failed)
        #expect(run.skippedItems == 1)
        #expect(states.values.contains(.skipped))
    }

    @Test("An oversized passage is split until every fragment can be embedded")
    internal func splitsPassagesThatExceedOneBatch() async throws {
        let harness = try IndexingRunHarness()
        defer { harness.tearDown() }
        try await harness.open()
        let embeddings = StubDocumentEmbedding(
            oversizedTexts: [IndexingRunTestConstants.firstNoteText]
        )

        let outcome = try await harness.index(embeddings: embeddings)
        let run = try #require(await harness.database.fetchIndexingRuns().first)
        await harness.close()

        #expect(run.state == .completed)
        #expect(run.skippedItems == 0)
        #expect(outcome.newItems == run.newItems)
    }
}
