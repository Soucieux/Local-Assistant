import Foundation

/// Constructs and retains the app's local-only service graph.
@MainActor
internal final class ServiceContainer {
    internal let database: AssistantDatabase
    internal let authorization: ReadOnlyAuthorizationService
    internal let modelStore: ModelStore
    internal let runtime: LlamaCppRuntime
    internal let embeddings: LocalEmbeddingService
    internal let retrieval: HybridRetrievalService
    internal let reminderSpool: ReminderSpoolService
    internal let reminderRetrieval: ReminderRetrievalService
    internal let reminders: ReminderService
    internal let indexing: IndexingService
    internal let monitoring: FolderMonitorService
    internal let assistant: GroundedAssistantService
    internal let voice: LocalVoiceService

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
