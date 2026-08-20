import Foundation
@preconcurrency import WhisperKit

/// Streams microphone audio through a bundled offline Core ML model and publishes live text.
///
/// Audio is never written to disk. Samples pass from the microphone into the speech model in
/// memory, so a recording cannot outlive the request that produced it.
actor LocalVoiceService {
    private var whisperKit: WhisperKit?
    private var loadTask: Task<Void, Error>?
    private var modelURL: URL?
    private var transcriber: AudioStreamTranscriber?
    private var captureTask: Task<Void, Never>?
    private var updates: AsyncStream<VoiceCaptureState>.Continuation?
    private var latest: VoiceCaptureState = .preparing
    private var lastVoiceActivityAt: Date?

    /// Stores the verified local model location without loading it during app startup.
    /// - Parameter modelURL: Bundled Core ML model directory.
    internal func configure(modelURL: URL?) {
        self.modelURL = modelURL
        removeLegacyRecordings()
    }

    /// Starts loading the configured model without waiting for it to finish.
    private func beginLoadingModel() {
        guard whisperKit == nil, loadTask == nil, let modelURL else { return }
        loadTask = Task { try await self.load(modelURL: modelURL) }
    }

    /// Loads the configured WhisperKit model with downloads disabled.
    /// - Parameter modelURL: Verified local Core ML model directory.
    /// - Throws: A local voice error when loading fails.
    private func load(modelURL: URL) async throws {
        guard whisperKit == nil else { return }
        do {
            let config = WhisperKitConfig(
                modelFolder: modelURL.path,
                verbose: false,
                logLevel: .none,
                prewarm: true,
                load: true,
                download: false,
                useBackgroundDownloadSession: false
            )
            whisperKit = try await WhisperKit(config)
        } catch {
            throw LocalAssistantError.voice(
                VoiceConstants.initializationMessage(detail: error.localizedDescription)
            )
        }
    }

    /// Returns the speech model, awaiting a load that began when recording started.
    /// - Returns: Loaded offline transcription runtime.
    /// - Throws: A local voice or model error when the model cannot be loaded.
    private func loadedModel() async throws -> WhisperKit {
        if let whisperKit { return whisperKit }
        beginLoadingModel()
        guard let pendingLoad = loadTask else {
            throw LocalAssistantError.modelMissing(VoiceConstants.missingSpeechModel)
        }
        defer { loadTask = nil }
        try await pendingLoad.value
        guard let whisperKit else {
            throw LocalAssistantError.modelMissing(VoiceConstants.missingSpeechModel)
        }
        return whisperKit
    }

    /// Begins capture and returns live audio levels and recognized text.
    ///
    /// The stream finishes when the speaker pauses long enough to end the recording, when
    /// capture is stopped explicitly, or when capture cannot start.
    /// - Returns: Capture states in order, beginning with the preparing state.
    /// - Throws: A local model error when no speech model is installed.
    internal func startRecording() async throws -> AsyncStream<VoiceCaptureState> {
        guard captureTask == nil else {
            throw LocalAssistantError.voice(VoiceConstants.missingRecording)
        }
        guard modelURL != nil else {
            throw LocalAssistantError.modelMissing(VoiceConstants.missingSpeechModel)
        }
        let (stream, continuation) = AsyncStream<VoiceCaptureState>.makeStream()
        updates = continuation
        latest = .preparing
        lastVoiceActivityAt = nil
        continuation.yield(.preparing)
        beginLoadingModel()
        captureTask = Task { await self.runCapture() }
        return stream
    }

    /// Loads the model, then streams microphone audio until capture stops.
    ///
    /// The speech model must be loaded before samples can be recognized, so the interface
    /// shows a preparing state rather than opening the microphone and discarding the audio
    /// that arrives before the model is ready.
    private func runCapture() async {
        do {
            let whisperKit = try await loadedModel()
            guard let tokenizer = whisperKit.tokenizer else {
                throw LocalAssistantError.modelMissing(VoiceConstants.missingTokenizer)
            }
            let streamTranscriber = AudioStreamTranscriber(
                audioEncoder: whisperKit.audioEncoder,
                featureExtractor: whisperKit.featureExtractor,
                segmentSeeker: whisperKit.segmentSeeker,
                textDecoder: whisperKit.textDecoder,
                tokenizer: tokenizer,
                audioProcessor: whisperKit.audioProcessor,
                decodingOptions: Self.streamingOptions,
                stateChangeCallback: { [weak self] _, updated in
                    let snapshot = Self.snapshot(from: updated)
                    Task { await self?.apply(snapshot) }
                }
            )
            transcriber = streamTranscriber
            try await streamTranscriber.startStreamTranscription()
        } catch {
            updates?.yield(latest)
        }
        updates?.finish()
    }

    /// Converts one library state into an interface-facing snapshot.
    ///
    /// The conversion runs where the library reports its state, so its non-Sendable type is
    /// never passed between isolation domains.
    /// - Parameter state: Latest streaming transcription state.
    /// - Returns: A value the interface can hold.
    private nonisolated static func snapshot(
        from state: AudioStreamTranscriber.State
    ) -> VoiceCaptureState {
        let confirmed = state.confirmedSegments
            .map(\.text)
            .joined(separator: VoiceConstants.transcriptionSeparator)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let current = state.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tentative = current == VoiceConstants.libraryWaitingPlaceholder
            ? AppConstants.Text.empty
            : current
        return VoiceCaptureState(
            phase: .listening,
            levels: Array(state.bufferEnergy.suffix(VoiceConstants.displayedLevelCount)),
            confirmedText: confirmed,
            tentativeText: tentative
        )
    }

    /// Publishes one capture snapshot and ends the recording after a long enough pause.
    /// - Parameter snapshot: Snapshot converted from the latest library state.
    private func apply(_ snapshot: VoiceCaptureState) {
        latest = snapshot
        updates?.yield(snapshot)
        endCaptureIfSpeakerStopped(snapshot)
    }

    /// Ends the recording once the speaker has been quiet for the configured pause.
    ///
    /// Silence before any speech is ignored, so a slow start never ends the recording before
    /// the speaker has said anything.
    /// - Parameter snapshot: Latest published capture state.
    private func endCaptureIfSpeakerStopped(_ snapshot: VoiceCaptureState) {
        guard snapshot.hasTranscript else { return }
        guard snapshot.isSilent else {
            lastVoiceActivityAt = Date()
            return
        }
        guard let since = lastVoiceActivityAt else {
            lastVoiceActivityAt = Date()
            return
        }
        guard Date().timeIntervalSince(since) >= VoiceConstants.silenceTimeout else { return }
        guard let transcriber else { return }
        Task { await transcriber.stopStreamTranscription() }
    }

    /// Stops capture and returns everything recognized during it.
    /// - Returns: Normalized local transcription.
    /// - Throws: A local voice error when no capture is active.
    internal func stopAndTranscribe() async throws -> String {
        guard let captureTask else {
            throw LocalAssistantError.voice(VoiceConstants.missingRecording)
        }
        await transcriber?.stopStreamTranscription()
        await captureTask.value
        let transcript = latest.transcript
        self.captureTask = nil
        transcriber = nil
        updates = nil
        latest = .preparing
        lastVoiceActivityAt = nil
        return transcript
    }

    /// Stops capture and releases the offline speech runtime before application termination.
    internal func shutdown() async {
        loadTask?.cancel()
        loadTask = nil
        await transcriber?.stopStreamTranscription()
        captureTask?.cancel()
        captureTask = nil
        transcriber = nil
        updates?.finish()
        updates = nil
        latest = .preparing
        lastVoiceActivityAt = nil
        whisperKit = nil
        modelURL = nil
    }

    /// Removes recordings written by earlier versions that stored audio on disk.
    ///
    /// Streaming keeps audio in memory, so the directory is no longer created or used, and a
    /// file left by a previous version is deleted rather than retained.
    private func removeLegacyRecordings() {
        guard let baseURL = try? AppDirectories.applicationSupport() else { return }
        let directory = baseURL.appendingPathComponent(
            VoiceConstants.recordingDirectory,
            isDirectory: true
        )
        try? FileManager.default.removeItem(at: directory)
    }

    /// Decoding options used for continuous recognition.
    ///
    /// Timestamps stay enabled because segment seeking uses them to decide which text is
    /// settled and which is still being revised.
    private static let streamingOptions = DecodingOptions(
        verbose: false,
        task: .transcribe,
        language: nil,
        usePrefillPrompt: true,
        detectLanguage: true,
        skipSpecialTokens: true,
        withoutTimestamps: false,
        wordTimestamps: false
    )
}
