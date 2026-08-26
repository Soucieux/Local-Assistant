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
    let reminderSpool: ReminderSpoolService
    let reminderRetrieval: ReminderRetrievalService
    let reminders: ReminderService
    let indexing: IndexingService
    let monitoring: FolderMonitorService
    let assistant: GroundedAssistantService
    let voice: LocalVoiceService

    /// Creates the complete in-process dependency graph without opening files or models.
    internal init() {
        let database = AssistantDatabase()
        let runtime = LlamaCppRuntime()
        let embeddings = LocalEmbeddingService(runtime: runtime)
        let retrieval = HybridRetrievalService(database: database, embeddings: embeddings)
        let reminderSpool = ReminderSpoolService()
        let reminderRetrieval = ReminderRetrievalService(
            database: database,
            embeddings: embeddings
        )
        let assistant = GroundedAssistantService(
            database: database,
            retrieval: retrieval,
            reminderRetrieval: reminderRetrieval,
            runtime: runtime
        )

        self.database = database
        authorization = ReadOnlyAuthorizationService()
        modelStore = ModelStore()
        self.runtime = runtime
        self.embeddings = embeddings
        self.retrieval = retrieval
        self.reminderSpool = reminderSpool
        self.reminderRetrieval = reminderRetrieval
        reminders = ReminderService(
            database: database,
            embeddings: embeddings,
            spool: reminderSpool
        )
        indexing = IndexingService(
            database: database,
            scanner: ReadOnlyFileScanner(),
            extractor: ExtractionCoordinator(),
            chunker: TextChunker(),
            embeddings: embeddings
        )
        monitoring = FolderMonitorService()
        self.assistant = assistant
        voice = LocalVoiceService()
    }
}
