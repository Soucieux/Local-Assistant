import Foundation
import Testing

@testable import LocalAssistant

/// Covers what chat, search, indexing and voice input say when the model they need is not ready.
internal struct MissingModelMessageTests {
    /// Runs an operation and returns the detail of the missing-model error it throws.
    /// - Parameter operation: Call expected to fail because a model is not ready.
    /// - Returns: The error's detail, or `nil` when the call threw another error or none.
    private func missingModelDetail(_ operation: () async throws -> Void) async -> String? {
        do {
            try await operation()
        } catch LocalAssistantError.modelMissing(let detail) {
            return detail
        } catch {
            return nil
        }
        return nil
    }

    /// Builds a model status in which only the given capabilities are ready.
    /// - Parameter ready: Capabilities whose model passed its checks.
    /// - Returns: A status naming the chosen folder, with every other capability missing.
    private func status(ready: Set<LocalModelCapabilityKind>) -> LocalModelStatus {
        LocalModelStatus(
            state: ready.count == LocalModelCapabilityKind.allCases.count ? .ready : .missingModels,
            libraryPath: MissingModelTestConstants.libraryPath,
            chatURL: ready.contains(.chat) ? MissingModelTestConstants.chatModelURL : nil,
            embeddingURL: ready.contains(.fileSearch) ? MissingModelTestConstants.embeddingModelURL : nil,
            speechURL: ready.contains(.voiceInput) ? MissingModelTestConstants.speechModelURL : nil,
            capabilities: LocalModelCapabilityKind.allCases.map {
                LocalModelCapabilityStatus(kind: $0, state: ready.contains($0) ? .ready : .missing, byteCount: 0)
            },
            totalByteCount: 0
        )
    }

    @Test("chat names its model in the conversation and points to Settings › Models")
    internal func chatNamesItsModel() async throws {
        let runtime = LlamaCppRuntime()

        let detail = try #require(
            await missingModelDetail { _ = try await runtime.generate(prompt: MissingModelTestConstants.request) }
        )
        let conversation = ReminderStrings.conversationalError(
            LocalAssistantError.modelMissing(detail).localizedDescription
        )

        #expect(detail.contains(UIStrings.modelChatCapability))
        #expect(conversation.contains(UIStrings.modelChatCapability))
        #expect(conversation.contains(MissingModelTestConstants.settingsLocation))
    }

    @Test("search and indexing name the file search model and point to Settings › Models")
    internal func searchAndIndexingNameTheirModel() async throws {
        let runtime = LlamaCppRuntime()
        let operations: [() async throws -> Void] = [
            { _ = try await runtime.embed(text: MissingModelTestConstants.request) },
            { _ = try await runtime.canEmbed(text: MissingModelTestConstants.request) }
        ]

        for operation in operations {
            let detail = try #require(await missingModelDetail(operation))
            #expect(detail.contains(UIStrings.modelFileSearchCapability))
            #expect(detail.contains(MissingModelTestConstants.settingsLocation))
        }
    }

    @Test("loading names exactly the models that are not ready")
    internal func loadingNamesModelsNotReady() async throws {
        let chatMissing = try #require(
            await missingModelDetail {
                try await LlamaCppRuntime().load(status: status(ready: [.fileSearch, .voiceInput]))
            }
        )
        let nothingChosen = try #require(
            await missingModelDetail { try await LlamaCppRuntime().load(status: status(ready: [])) }
        )

        #expect(chatMissing.contains(UIStrings.modelChatCapability))
        #expect(chatMissing.contains(UIStrings.modelFileSearchCapability) == false)
        #expect(chatMissing.contains(UIStrings.modelVoiceCapability) == false)
        #expect(chatMissing.contains(MissingModelTestConstants.settingsLocation))
        for kind in LocalModelCapabilityKind.allCases {
            #expect(nothingChosen.contains(UIStrings.modelCapabilityTitle(kind)))
        }
        #expect(nothingChosen.contains(MissingModelTestConstants.settingsLocation))
    }

    @Test("voice input names its model and points to Settings › Models")
    internal func voiceInputNamesItsModel() async throws {
        let voice = LocalVoiceService()

        let detail = try #require(await missingModelDetail { _ = try await voice.startRecording() })

        #expect(detail.contains(UIStrings.modelVoiceCapability))
        #expect(detail.contains(MissingModelTestConstants.settingsLocation))
        #expect(VoiceConstants.missingTokenizer.contains(UIStrings.modelVoiceCapability))
        #expect(VoiceConstants.missingTokenizer.contains(MissingModelTestConstants.settingsLocation))
    }

    @Test("no missing-model message keeps the earlier offline-package wording")
    internal func retiresEarlierWording() {
        let messages = [
            InferenceConstants.missingChatModel,
            InferenceConstants.missingEmbeddingModel,
            VoiceConstants.missingSpeechModel,
            VoiceConstants.missingTokenizer,
            UIStrings.missingModelDetail(LocalModelCapabilityKind.allCases)
        ]

        for message in messages {
            for retired in MissingModelTestConstants.retiredWording {
                #expect(message.localizedCaseInsensitiveContains(retired) == false)
            }
        }
    }
}
