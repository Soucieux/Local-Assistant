import Foundation

/// Applies the Qwen embedding instructions before invoking embedded llama.cpp.
internal actor LocalEmbeddingService: DocumentEmbedding {
    private let runtime: LlamaCppRuntime

    /// Creates a local embedding adapter over the shared runtime.
    /// - Parameter runtime: Embedded llama.cpp owner.
    internal init(runtime: LlamaCppRuntime) {
        self.runtime = runtime
    }

    /// Embeds a retrieval query using the model's query instruction.
    /// - Parameter text: User's local search request.
    /// - Returns: Normalized query vector.
    /// - Throws: A local model or inference error.
    internal func embedQuery(_ text: String) async throws -> [Float] {
        try await runtime.embed(text: ModelConstants.Embedding.queryPrefix + text)
    }

    /// Embeds an extracted file passage using the document instruction.
    /// - Parameter text: Local extracted passage.
    /// - Returns: Normalized document vector.
    /// - Throws: A local model or inference error.
    internal func embedDocument(_ text: String) async throws -> [Float] {
        try await runtime.embed(text: ModelConstants.Embedding.documentPrefix + text)
    }

    /// Reports whether a document passage fits in one native embedding batch.
    /// - Parameter text: Local passage without the model instruction prefix.
    /// - Returns: `true` when the complete passage can be embedded safely.
    /// - Throws: A local model or tokenization error.
    internal func canEmbedDocument(_ text: String) async throws -> Bool {
        try await runtime.canEmbed(text: ModelConstants.Embedding.documentPrefix + text)
    }
}
