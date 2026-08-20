import Foundation

/// Snapshot of an in-progress voice capture, safe to publish to the interface.
///
/// The interface never sees WhisperKit types. It receives audio levels for the waveform and
/// the text recognized so far, split into the part the model has settled on and the part it
/// is still revising.
struct VoiceCaptureState: Sendable, Equatable {
    /// Stage of the capture the interface should present.
    enum Phase: Sendable, Equatable {
        /// The speech model is still loading, so no audio is being captured yet.
        case preparing
        /// The microphone is open and audio is being recognized.
        case listening
    }

    let phase: Phase

    /// Recent relative audio levels, oldest first, each between zero and one.
    let levels: [Float]

    /// Text the model has settled on and will not revise.
    let confirmedText: String

    /// Text the model is still revising as more audio arrives.
    let tentativeText: String

    /// State shown while the speech model loads before capture begins.
    static let preparing = VoiceCaptureState(
        phase: .preparing,
        levels: [],
        confirmedText: AppConstants.Text.empty,
        tentativeText: AppConstants.Text.empty
    )

    /// Everything recognized so far, in reading order.
    var transcript: String {
        [confirmedText, tentativeText]
            .filter { $0.isEmpty == false }
            .joined(separator: VoiceConstants.transcriptionSeparator)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether any speech has been recognized yet.
    var hasTranscript: Bool {
        transcript.isEmpty == false
    }

    /// Whether the most recent audio is quiet enough to count as a pause.
    ///
    /// Levels arrive as relative energies, so the threshold compares against recent loudness
    /// rather than an absolute sound pressure.
    var isSilent: Bool {
        guard let loudest = levels.suffix(VoiceConstants.silenceSampleCount).max() else {
            return false
        }
        return loudest < VoiceConstants.silenceEnergyThreshold
    }
}
