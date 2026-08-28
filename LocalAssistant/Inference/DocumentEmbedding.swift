import Foundation

/// Supplies the document embeddings the indexing pipeline needs, without naming a runtime.
///
/// `LocalEmbeddingService` is the only shipping conformer; the protocol exists so indexing can be
/// exercised without loading the multi-gigabyte local model.
protocol DocumentEmbedding: Sendable {
    /// Embeds an extracted file passage using the document instruction.
    /// - Parameter text: Local extracted passage.
    /// - Returns: Normalized document vector.
    /// - Throws: A local model or inference error.
    func embedDocument(_ text: String) async throws -> [Float]

    /// Reports whether a document passage fits in one native embedding batch.
    /// - Parameter text: Local passage without the model instruction prefix.
    /// - Returns: `true` when the complete passage can be embedded safely.
    /// - Throws: A local model or tokenization error.
    func canEmbedDocument(_ text: String) async throws -> Bool
}
