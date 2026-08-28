import Foundation

@testable import LocalAssistant

/// Stands in for the local model so indexing runs can be exercised without loading it.
actor StubDocumentEmbedding: DocumentEmbedding {
    private let failure: LocalAssistantError?
    private let oversizedTexts: Set<String>
    private(set) var embedCallCount = 0

    /// Creates an embedding stub with an optional scripted failure.
    /// - Parameters:
    ///   - failure: Error thrown by every `embedDocument` call, when supplied.
    ///   - oversizedTexts: Passages reported as too large for one native batch.
    internal init(failure: LocalAssistantError? = nil, oversizedTexts: Set<String> = []) {
        self.failure = failure
        self.oversizedTexts = oversizedTexts
    }

    /// Returns a fixed-width vector so callers can assert storage without a model.
    /// - Parameter text: Local extracted passage.
    /// - Returns: Constant normalized-shaped vector.
    /// - Throws: The scripted failure, when one was supplied.
    internal func embedDocument(_ text: String) async throws -> [Float] {
        embedCallCount += 1
        if let failure { throw failure }
        return Array(
            repeating: IndexingRunTestConstants.embeddingComponent,
            count: AppConstants.Indexing.embeddingDimensions
        )
    }

    /// Reports the scripted batch verdict for a passage.
    /// - Parameter text: Local passage without the model instruction prefix.
    /// - Returns: `false` only for passages the test declared oversized.
    internal func canEmbedDocument(_ text: String) async throws -> Bool {
        oversizedTexts.contains(text) == false
    }
}
