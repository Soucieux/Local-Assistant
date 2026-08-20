import Foundation

/// Recording, transcription, and speech-output constants.
enum VoiceConstants {
    static let recordingDirectory = "Voice"
    static let transcriptionSeparator = " "
    static let missingRecording = "No push-to-talk recording is active."
    static let missingTokenizer = "The bundled speech tokenizer is not installed."

    /// Placeholder the speech library writes into its own partial text before any speech
    /// arrives. It is upstream English copy, so it is filtered rather than displayed.
    static let libraryWaitingPlaceholder = "Waiting for speech..."

    /// Number of recent level samples the waveform draws.
    static let displayedLevelCount = 48

    /// Recent level samples inspected when deciding whether the speaker has paused.
    static let silenceSampleCount = 12

    /// Relative energy below which recent audio counts as a pause.
    ///
    /// Levels arrive as energy relative to recent loudness, where a quiet room still reports
    /// well above zero. The speech library treats this same signal as silence below 0.3.
    static let silenceEnergyThreshold: Float = 0.3

    /// Seconds of continuous quiet after speech that ends a recording on its own.
    static let silenceTimeout: TimeInterval = 2
    static let missingSpeechModel = "The bundled speech model is not installed."
    static let speechInitializationFailure = "The local speech model could not be loaded."

    /// Adds a local framework diagnostic to a safe voice prefix.
    /// - Parameter detail: Local framework error detail.
    /// - Returns: Combined diagnostic string.
    internal static func initializationMessage(detail: String) -> String {
        speechInitializationFailure + AppConstants.Text.space + detail
    }
}
