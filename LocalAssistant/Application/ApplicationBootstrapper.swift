import Foundation

/// Opens private storage and verified local model runtimes during launch.
internal struct ApplicationBootstrapper: Sendable {
    internal let database: AssistantDatabase
    internal let modelStore: ModelStore
    internal let runtime: LlamaCppRuntime
    internal let voice: LocalVoiceService

    /// Prepares writable app-container directories and local-only runtimes.
    /// - Returns: Verified offline model status.
    /// - Throws: A local storage, integrity, or inference error.
    internal func start() async throws -> LocalModelStatus {
        try AppDirectories.prepare()
        try await database.open()
        let status = try await modelStore.refreshStatus()
        if status.state == .ready {
            try await runtime.load(status: status)
            await voice.configure(modelURL: status.speechURL)
        }
        return status
    }
}
