import Foundation
import llama

/// Owns non-Sendable llama.cpp pointers whose lifetime is confined to one runtime actor.
private final class LlamaResources: @unchecked Sendable {
    var chatModel: OpaquePointer?
    var chatContext: OpaquePointer?
    var embeddingModel: OpaquePointer?
    var embeddingContext: OpaquePointer?
    var backendInitialized = false

    deinit {
        release()
    }

    /// Releases every native resource before llama.cpp's process-global Metal teardown runs.
    internal func release() {
        if let chatContext {
            llama_synchronize(chatContext)
            llama_free(chatContext)
            self.chatContext = nil
        }
        if let chatModel {
            llama_model_free(chatModel)
            self.chatModel = nil
        }
        if let embeddingContext {
            llama_synchronize(embeddingContext)
            llama_free(embeddingContext)
            self.embeddingContext = nil
        }
        if let embeddingModel {
            llama_model_free(embeddingModel)
            self.embeddingModel = nil
        }
        if backendInitialized {
            llama_backend_free()
            backendInitialized = false
        }
    }
}

/// Owns embedded llama.cpp models and performs all chat and embedding inference in process.
actor LlamaCppRuntime {
    private let resources = LlamaResources()

    /// Loads both verified Qwen models once for the current process.
    /// - Parameter status: Integrity-checked local model paths.
    /// - Throws: A local inference error when a model or context cannot be created.
    internal func load(status: LocalModelStatus) throws {
        guard resources.chatContext == nil, resources.embeddingContext == nil else { return }
        guard status.state == .ready,
              let chatURL = status.chatURL,
              let embeddingURL = status.embeddingURL else {
            throw LocalAssistantError.modelMissing(UIStrings.offlineSetupRequired)
        }
        if resources.backendInitialized == false {
            llama_backend_init()
            resources.backendInitialized = true
        }

        let loadedChat = try loadModel(url: chatURL, embeddings: false)
        resources.chatModel = loadedChat.model
        resources.chatContext = loadedChat.context

        do {
            let loadedEmbedding = try loadModel(url: embeddingURL, embeddings: true)
            resources.embeddingModel = loadedEmbedding.model
            resources.embeddingContext = loadedEmbedding.context
        } catch {
            if let chatContext = resources.chatContext { llama_free(chatContext) }
            if let chatModel = resources.chatModel { llama_model_free(chatModel) }
            resources.chatContext = nil
            resources.chatModel = nil
            throw error
        }
    }

    /// Releases contexts, models, and the backend before normal application termination.
    internal func shutdown() {
        resources.release()
    }

    /// Generates a local completion from an already-grounded prompt.
    /// - Parameter prompt: Prompt containing bounded local evidence.
    /// - Returns: Decoded assistant text.
    /// - Throws: A local inference error when evaluation fails.
    internal func generate(prompt: String) throws -> String {
        guard let model = resources.chatModel, let context = resources.chatContext else {
            throw LocalAssistantError.modelMissing(InferenceConstants.missingChatModel)
        }
        guard let vocab = llama_model_get_vocab(model) else {
            throw LocalAssistantError.inference(InferenceConstants.vocabularyFailure)
        }
        let tokens = try tokenize(
            text: prompt,
            vocab: vocab,
            addSpecial: true,
            parseSpecial: true
        )
        let maximumPromptTokens = Int(llama_n_ctx(context)) - AppConstants.Chat.maximumOutputTokens
        guard tokens.count <= maximumPromptTokens else {
            throw LocalAssistantError.inference(InferenceConstants.promptTooLong)
        }

        llama_memory_clear(llama_get_memory(context), true)
        var processed = 0
        var lastBatchTokenCount: Int32 = 0
        while processed < tokens.count {
            let upper = min(processed + Int(InferenceConstants.batchTokenCount), tokens.count)
            var batch = llama_batch_init(Int32(upper - processed), 0, 1)
            defer { llama_batch_free(batch) }
            clear(batch: &batch)
            for index in processed..<upper {
                add(
                    token: tokens[index],
                    position: Int32(index),
                    logits: index == tokens.count - 1,
                    batch: &batch
                )
            }
            guard llama_decode(context, batch) == 0 else {
                throw LocalAssistantError.inference(InferenceConstants.decodeFailure)
            }
            lastBatchTokenCount = batch.n_tokens
            processed = upper
        }

        let samplerParameters = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(samplerParameters) else {
            throw LocalAssistantError.inference(InferenceConstants.decodeFailure)
        }
        defer { llama_sampler_free(sampler) }
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(InferenceConstants.samplingTemperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(InferenceConstants.samplingSeed))

        var outputBytes: [CChar] = []
        var position = Int32(tokens.count)
        var sampleIndex = lastBatchTokenCount - 1
        for _ in 0..<AppConstants.Chat.maximumOutputTokens {
            let token = llama_sampler_sample(sampler, context, sampleIndex)
            if llama_vocab_is_eog(vocab, token) { break }
            outputBytes.append(contentsOf: tokenPiece(token: token, vocab: vocab))

            var batch = llama_batch_init(1, 0, 1)
            defer { llama_batch_free(batch) }
            clear(batch: &batch)
            add(token: token, position: position, logits: true, batch: &batch)
            guard llama_decode(context, batch) == 0 else {
                throw LocalAssistantError.inference(InferenceConstants.decodeFailure)
            }
            position += 1
            sampleIndex = 0
        }
        return String(decoding: outputBytes.map(UInt8.init(bitPattern:)), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Produces a normalized local embedding for query or document text.
    /// - Parameter text: Prefixed text expected by the embedding model.
    /// - Returns: Unit-length float vector.
    /// - Throws: A local inference error when evaluation or pooling fails.
    internal func embed(text: String) throws -> [Float] {
        guard let model = resources.embeddingModel, let context = resources.embeddingContext else {
            throw LocalAssistantError.modelMissing(InferenceConstants.missingEmbeddingModel)
        }
        guard let vocab = llama_model_get_vocab(model) else {
            throw LocalAssistantError.inference(InferenceConstants.vocabularyFailure)
        }
        let tokens = try tokenize(
            text: text,
            vocab: vocab,
            addSpecial: true,
            parseSpecial: false
        )
        guard tokens.count <= embeddingInputCapacity(context: context) else {
            throw LocalAssistantError.inference(InferenceConstants.promptTooLong)
        }
        llama_memory_clear(llama_get_memory(context), true)
        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer { llama_batch_free(batch) }
        clear(batch: &batch)
        for (index, token) in tokens.enumerated() {
            add(token: token, position: Int32(index), logits: true, batch: &batch)
        }
        guard llama_decode(context, batch) == 0,
              let pointer = llama_get_embeddings_seq(context, InferenceConstants.sequenceID) else {
            throw LocalAssistantError.inference(InferenceConstants.embeddingFailure)
        }
        let dimensionCount = Int(llama_model_n_embd_out(model))
        guard dimensionCount == AppConstants.Indexing.embeddingDimensions else {
            throw LocalAssistantError.inference(InferenceConstants.embeddingFailure)
        }
        let raw = Array(UnsafeBufferPointer(start: pointer, count: dimensionCount))
        let norm = sqrt(raw.reduce(Float.zero) { $0 + ($1 * $1) })
        guard norm > 0 else { throw LocalAssistantError.inference(InferenceConstants.embeddingFailure) }
        return raw.map { $0 / norm }
    }

    /// Reports whether text fits in one safe embedding batch.
    /// - Parameter text: Prefixed text expected by the embedding model.
    /// - Returns: `true` when native decoding can accept the full token sequence.
    /// - Throws: A local model or tokenization error.
    internal func canEmbed(text: String) throws -> Bool {
        guard let model = resources.embeddingModel, let context = resources.embeddingContext else {
            throw LocalAssistantError.modelMissing(InferenceConstants.missingEmbeddingModel)
        }
        guard let vocab = llama_model_get_vocab(model) else {
            throw LocalAssistantError.inference(InferenceConstants.vocabularyFailure)
        }
        let tokens = try tokenize(
            text: text,
            vocab: vocab,
            addSpecial: true,
            parseSpecial: false
        )
        return tokens.count <= embeddingInputCapacity(context: context)
    }

    /// Loads one model and configures a Metal-capable local context.
    /// - Parameters:
    ///   - url: Verified GGUF file URL.
    ///   - embeddings: Whether the context returns pooled embeddings.
    /// - Returns: Model and context pointers owned by this actor.
    /// - Throws: A local inference error when loading fails.
    private func loadModel(url: URL, embeddings: Bool) throws -> (model: OpaquePointer, context: OpaquePointer) {
        var modelParameters = llama_model_default_params()
        modelParameters.n_gpu_layers = InferenceConstants.gpuLayerCount
        guard let model = llama_model_load_from_file(url.path, modelParameters) else {
            throw LocalAssistantError.inference(InferenceConstants.modelLoadFailure)
        }

        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = embeddings
            ? InferenceConstants.embeddingContextTokenLimit
            : UInt32(AppConstants.Chat.contextTokenLimit)
        contextParameters.n_batch = embeddings
            ? InferenceConstants.embeddingContextTokenLimit
            : InferenceConstants.batchTokenCount
        contextParameters.n_ubatch = embeddings
            ? InferenceConstants.embeddingContextTokenLimit
            : InferenceConstants.batchTokenCount
        let threads = max(
            InferenceConstants.defaultThreadFloor,
            min(
                InferenceConstants.defaultThreadCeiling,
                ProcessInfo.processInfo.processorCount - InferenceConstants.reservedProcessorCount
            )
        )
        contextParameters.n_threads = Int32(threads)
        contextParameters.n_threads_batch = Int32(threads)
        contextParameters.embeddings = embeddings
        if embeddings { contextParameters.pooling_type = LLAMA_POOLING_TYPE_LAST }
        guard let context = llama_init_from_model(model, contextParameters) else {
            llama_model_free(model)
            throw LocalAssistantError.inference(InferenceConstants.contextLoadFailure)
        }
        return (model, context)
    }

    /// Returns the strictest native capacity governing one embedding decode.
    /// - Parameter context: Loaded embedding context.
    /// - Returns: Maximum tokens accepted without triggering a native assertion.
    private func embeddingInputCapacity(context: OpaquePointer) -> Int {
        Int(min(llama_n_ctx(context), min(llama_n_batch(context), llama_n_ubatch(context))))
    }

    /// Converts UTF-8 text to model tokens.
    /// - Parameters:
    ///   - text: Input text.
    ///   - vocab: Model vocabulary pointer.
    ///   - addSpecial: Whether model special tokens should be added.
    ///   - parseSpecial: Whether textual control markers should resolve to special-token identifiers.
    /// - Returns: Token identifiers.
    /// - Throws: A local inference error when tokenization fails.
    private func tokenize(
        text: String,
        vocab: OpaquePointer,
        addSpecial: Bool,
        parseSpecial: Bool
    ) throws -> [llama_token] {
        let capacity = text.utf8.count + (addSpecial ? 2 : 0) + 1
        var tokens = [llama_token](repeating: 0, count: capacity)
        let count = llama_tokenize(
            vocab,
            text,
            Int32(text.utf8.count),
            &tokens,
            Int32(capacity),
            addSpecial,
            parseSpecial
        )
        guard count >= 0 else { throw LocalAssistantError.inference(InferenceConstants.tokenizationFailure) }
        return Array(tokens.prefix(Int(count)))
    }

    /// Clears a llama batch for reuse.
    /// - Parameter batch: Batch whose logical token count should become zero.
    private func clear(batch: inout llama_batch) {
        batch.n_tokens = 0
    }

    /// Adds one token to a single-sequence llama batch.
    /// - Parameters:
    ///   - token: Token identifier.
    ///   - position: Absolute context position.
    ///   - logits: Whether logits are required for this token.
    ///   - batch: Mutable llama batch.
    private func add(token: llama_token, position: llama_pos, logits: Bool, batch: inout llama_batch) {
        let index = Int(batch.n_tokens)
        batch.token[index] = token
        batch.pos[index] = position
        batch.n_seq_id[index] = Int32(InferenceConstants.sequenceCount)
        batch.seq_id[index]?[0] = InferenceConstants.sequenceID
        batch.logits[index] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    /// Converts one generated token to raw UTF-8 bytes.
    /// - Parameters:
    ///   - token: Generated token identifier.
    ///   - vocab: Model vocabulary pointer.
    /// - Returns: Piece bytes without a null terminator.
    private func tokenPiece(token: llama_token, vocab: OpaquePointer) -> [CChar] {
        var buffer = [CChar](repeating: 0, count: Int(InferenceConstants.initialPieceCapacity))
        var count = llama_token_to_piece(
            vocab,
            token,
            &buffer,
            InferenceConstants.initialPieceCapacity,
            0,
            false
        )
        if count < 0 {
            buffer = [CChar](repeating: 0, count: Int(-count))
            count = llama_token_to_piece(vocab, token, &buffer, -count, 0, false)
        }
        guard count > 0 else { return [] }
        return Array(buffer.prefix(Int(count)))
    }
}
