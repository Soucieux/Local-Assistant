import AVFoundation
import Foundation
import WhisperKit

/// Records push-to-talk audio and transcribes it with a bundled offline Core ML model.
actor LocalVoiceService {
    private var whisperKit: WhisperKit?
    private var modelURL: URL?
    private var audioEngine: AVAudioEngine?
    private var recordingURL: URL?
    private var recordingBox: AudioRecordingBox?

    /// Stores the verified local model location without loading it during app startup.
    /// - Parameter modelURL: Bundled Core ML model directory.
    internal func configure(modelURL: URL?) {
        self.modelURL = modelURL
    }

    /// Loads the configured WhisperKit model with downloads disabled.
    /// - Throws: A local voice error when the model is missing or loading fails.
    private func prepare() async throws {
        guard whisperKit == nil else { return }
        guard let modelURL else {
            throw LocalAssistantError.modelMissing(VoiceConstants.missingSpeechModel)
        }
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

    /// Starts a new microphone recording inside the private app container.
    /// - Throws: A local voice or permission error when capture cannot start.
    internal func startRecording() async throws {
        guard audioEngine == nil else { return }
        try await prepare()
        var engineWithTap: AVAudioEngine?
        var pendingRecordingURL: URL?
        do {
            let directory = try voiceDirectory()
            try VoiceRecordingFiles.removeStaleRecordings(in: directory)
            let url = directory
                .appendingPathComponent(VoiceConstants.recordingPrefix + UUID().uuidString)
                .appendingPathExtension(VoiceConstants.recordingExtension)
            pendingRecordingURL = url
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
            try VoiceRecordingFiles.protectRecording(at: url)
            let box = AudioRecordingBox(file: audioFile)
            input.installTap(onBus: 0, bufferSize: 0, format: format) { buffer, _ in
                box.write(buffer)
            }
            engineWithTap = engine
            engine.prepare()
            try engine.start()
            audioEngine = engine
            recordingURL = url
            recordingBox = box
        } catch {
            engineWithTap?.inputNode.removeTap(onBus: 0)
            engineWithTap?.stop()
            VoiceRecordingFiles.removeRecordingIfPresent(at: pendingRecordingURL)
            throw LocalAssistantError.voice(error.localizedDescription)
        }
    }

    /// Stops the microphone and transcribes the private temporary recording.
    /// - Returns: Normalized local transcription.
    /// - Throws: A local voice error when no recording or model is available.
    internal func stopAndTranscribe() async throws -> String {
        guard let engine = audioEngine, let url = recordingURL else {
            throw LocalAssistantError.voice(VoiceConstants.missingRecording)
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioEngine = nil
        recordingBox = nil
        recordingURL = nil
        defer { VoiceRecordingFiles.removeRecordingIfPresent(at: url) }

        guard let whisperKit else {
            throw LocalAssistantError.modelMissing(VoiceConstants.missingSpeechModel)
        }
        do {
            let options = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: nil,
                usePrefillPrompt: false,
                detectLanguage: true,
                skipSpecialTokens: true,
                withoutTimestamps: true,
                wordTimestamps: false
            )
            let results = try await whisperKit.transcribe(audioPath: url.path, decodeOptions: options)
            return results
                .map(\.text)
                .joined(separator: VoiceConstants.transcriptionSeparator)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw LocalAssistantError.voice(error.localizedDescription)
        }
    }

    /// Stops capture and releases the offline speech runtime before application termination.
    internal func shutdown() {
        if let audioEngine {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        VoiceRecordingFiles.removeRecordingIfPresent(at: recordingURL)
        audioEngine = nil
        recordingURL = nil
        recordingBox = nil
        whisperKit = nil
        modelURL = nil
    }

    /// Creates an owner-only directory for ephemeral recordings.
    /// - Returns: Private voice directory URL.
    /// - Throws: A local permission error when creation fails.
    private func voiceDirectory() throws -> URL {
        let baseURL = try AppDirectories.applicationSupport()
        let directory = baseURL.appendingPathComponent(VoiceConstants.recordingDirectory, isDirectory: true)
        do {
            try VoiceRecordingFiles.prepareDirectory(directory)
            return directory
        } catch {
            throw LocalAssistantError.permission(error.localizedDescription)
        }
    }
}
