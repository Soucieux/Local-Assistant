import Foundation

/// Recording, transcription, and speech-output constants.
enum VoiceConstants {
    static let recordingPrefix = "voice-query-"
    static let recordingExtension = "caf"
    static let recordingDirectory = "Voice"
    static let transcriptionSeparator = " "
    static let missingRecording = "No push-to-talk recording is active."
    static let missingSpeechModel = "The bundled speech model is not installed."
    static let speechInitializationFailure = "The local speech model could not be loaded."

    /// Adds a local framework diagnostic to a safe voice prefix.
    /// - Parameter detail: Local framework error detail.
    /// - Returns: Combined diagnostic string.
    internal static func initializationMessage(detail: String) -> String {
        speechInitializationFailure + AppConstants.Text.space + detail
    }
}
