import Foundation

/// Constructs and retains the app's local-only service graph.
@MainActor
final class ServiceContainer {
    let database: AssistantDatabase
    let authorization: ReadOnlyAuthorizationService
    let modelStore: ModelStore
    let runtime: LlamaCppRuntime
    let embeddings: LocalEmbeddingService
    let retrieval: HybridRetrievalService
    let indexing: IndexingService
    let assistant: GroundedAssistantService
    let voice: LocalVoiceService

    /// Creates the complete in-process dependency graph without opening files or models.
    internal init() {
        let database = AssistantDatabase()
        let runtime = LlamaCppRuntime()
        let embeddings = LocalEmbeddingService(runtime: runtime)
        let retrieval = HybridRetrievalService(database: database, embeddings: embeddings)
        let assistant = GroundedAssistantService(
            database: database,
            retrieval: retrieval,
            runtime: runtime
        )

        self.database = database
        authorization = ReadOnlyAuthorizationService()
        modelStore = ModelStore()
        self.runtime = runtime
        self.embeddings = embeddings
        self.retrieval = retrieval
        indexing = IndexingService(
            database: database,
            scanner: ReadOnlyFileScanner(),
            extractor: ExtractionCoordinator(),
            chunker: TextChunker(),
            embeddings: embeddings
        )
        self.assistant = assistant
        voice = LocalVoiceService()
    }
}
