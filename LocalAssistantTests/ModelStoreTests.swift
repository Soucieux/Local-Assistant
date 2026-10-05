import Foundation
import Testing

@testable import LocalAssistant

/// Covers what the model store reports about the model folder the user chooses.
internal struct ModelStoreTests {
    /// Makes an empty UUID-named folder under the temporary directory.
    /// - Returns: The folder; the caller removes it.
    /// - Throws: A file error when the folder cannot be created.
    private func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("reports that no folder is chosen until the user picks one")
    internal func reportsNoChosenFolder() async throws {
        let records = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: records) }

        let status = try await ModelStore(supportDirectory: records).refreshStatus()

        #expect(status.state == .noLibrary)
        #expect(status.libraryPath == nil)
        #expect(status.capabilities.allSatisfy { $0.state == .missing })
    }

    @Test("reports a chosen folder that can no longer be found, at its last known place")
    internal func reportsUnavailableFolder() async throws {
        let records = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: records) }
        let store = ModelStore(supportDirectory: records)

        let status = try await store.selectLibrary(
            ModelLibrarySelection(
                bookmarkData: ModelStoreTestConstants.unreadableBookmark,
                path: ModelStoreTestConstants.libraryPath
            )
        )

        #expect(status.state == .libraryUnavailable)
        #expect(status.libraryPath == ModelStoreTestConstants.libraryPath)
        #expect(status.capabilities.allSatisfy { $0.state == .missing })
    }

    @Test("keeps the chosen folder between launches and forgets it on request")
    internal func keepsAndForgetsChosenFolder() async throws {
        let records = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: records) }
        _ = try await ModelStore(supportDirectory: records).selectLibrary(
            ModelLibrarySelection(
                bookmarkData: ModelStoreTestConstants.unreadableBookmark,
                path: ModelStoreTestConstants.libraryPath
            )
        )
        let reopened = ModelStore(supportDirectory: records)

        #expect(try await reopened.refreshStatus().libraryPath == ModelStoreTestConstants.libraryPath)
        #expect(try await reopened.forgetLibrary().state == .noLibrary)
        #expect(try await ModelStore(supportDirectory: records).refreshStatus().state == .noLibrary)
    }

    @Test("reports every model missing from a folder that holds none")
    internal func reportsMissingModels() async throws {
        let records = try temporaryFolder()
        let library = try temporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: records)
            try? FileManager.default.removeItem(at: library)
        }

        let status = try await ModelStore(supportDirectory: records).refreshStatus(libraryURL: library)

        #expect(status.state == .missingModels)
        #expect(status.libraryPath == library.path)
        #expect(status.capabilities.allSatisfy { $0.state == .missing })
        #expect(status.chatURL == nil)
    }

    @Test("looks for a model at the shared library's path and rejects one that fails its checksum")
    internal func rejectsModelThatFailsItsChecksum() async throws {
        let records = try temporaryFolder()
        let library = try temporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: records)
            try? FileManager.default.removeItem(at: library)
        }
        let languageModels = library.appendingPathComponent(
            ModelConstants.Library.languageModelDirectory,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: languageModels, withIntermediateDirectories: true)
        let chatModel = languageModels.appendingPathComponent(ModelConstants.Chat.filename)
        try ModelStoreTestConstants.corruptModelContents.write(to: chatModel)

        let status = try await ModelStore(supportDirectory: records).refreshStatus(libraryURL: library)

        #expect(status.state == .integrityFailure)
        #expect(status.capabilities.first { $0.kind == .chat }?.state == .integrityFailure)
        #expect(status.capabilities.first { $0.kind == .fileSearch }?.state == .missing)
        #expect(status.chatURL == nil)
        #expect(FileManager.default.fileExists(atPath: chatModel.path))
    }
}
