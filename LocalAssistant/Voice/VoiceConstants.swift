import Foundation

/// Capture and transcription constants for local voice input.
internal enum VoiceConstants {
    internal static let recordingDirectory = "Voice"
    internal static let transcriptionSeparator = " "
    internal static let missingRecording = "No push-to-talk recording is active."
    internal static let missingTokenizer = "The bundled speech tokenizer is not installed."

    /// Placeholder the speech library writes into its own partial text before any speech
    /// arrives. It is upstream English copy, so it is filtered rather than displayed.
    internal static let libraryWaitingPlaceholder = "Waiting for speech..."

    /// Number of recent level samples the waveform draws.
    internal static let displayedLevelCount = 48

    /// Recent level samples inspected when deciding whether the speaker has paused.
    internal static let silenceSampleCount = 12

    /// Relative energy below which recent audio counts as a pause.
    ///
    /// Levels arrive as energy relative to recent loudness, where a quiet room still reports
    /// well above zero. The speech library treats this same signal as silence below 0.3.
    internal static let silenceEnergyThreshold: Float = 0.3

    /// Seconds of continuous quiet after speech that ends a recording on its own.
    internal static let silenceTimeout: TimeInterval = 2

    /// Longest a single capture may run before it ends itself.
    ///
    /// A pause ends a capture only after speech has been heard, and steady background noise
    /// never reads as a pause, so either case would otherwise leave the microphone open
    /// indefinitely. This bound applies in every mode, so no single failure keeps capture
    /// running.
    internal static let maximumCaptureSeconds: TimeInterval = 120
    internal static let missingSpeechModel = "The bundled speech model is not installed."
    internal static let speechInitializationFailure = "The local speech model could not be loaded."

    /// Adds a local framework diagnostic to a safe voice prefix.
    /// - Parameter detail: Local framework error detail.
    /// - Returns: Combined diagnostic string.
    internal static func initializationMessage(detail: String) -> String {
        speechInitializationFailure + AppConstants.Text.space + detail
    }
}
