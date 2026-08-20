import Foundation
import Testing

@testable import LocalAssistant

/// Covers the decisions that end a recording and the text the interface shows while capturing.
struct VoiceCaptureStateTests {
    /// Builds a capture state with the given levels and text.
    /// - Parameters:
    ///   - levels: Relative audio levels, oldest first.
    ///   - confirmed: Text the model has settled on.
    ///   - tentative: Text the model is still revising.
    /// - Returns: A listening capture state.
    private func state(
        levels: [Float] = [],
        confirmed: String = "",
        tentative: String = ""
    ) -> VoiceCaptureState {
        VoiceCaptureState(
            phase: .listening,
            levels: levels,
            confirmedText: confirmed,
            tentativeText: tentative
        )
    }

    @Test("joins settled and revising text in reading order")
    func joinsTranscriptParts() {
        #expect(state(confirmed: "open the", tentative: "budget file").transcript == "open the budget file")
    }

    @Test("omits the separator when only one part is present")
    func omitsSeparatorForSinglePart() {
        #expect(state(confirmed: "open the").transcript == "open the")
        #expect(state(tentative: "budget file").transcript == "budget file")
    }

    @Test("reports no transcript before any speech is recognized")
    func reportsEmptyTranscript() {
        #expect(state().hasTranscript == false)
        #expect(state(confirmed: "   ").hasTranscript == false)
    }

    @Test("treats quiet recent audio as a pause")
    func detectsSilence() {
        let quiet = Array(repeating: Float(0.001), count: VoiceConstants.silenceSampleCount)
        #expect(state(levels: quiet).isSilent)
    }

    @Test("does not treat audible recent audio as a pause")
    func detectsSpeech() {
        var levels = Array(repeating: Float(0.001), count: VoiceConstants.silenceSampleCount)
        levels.append(0.9)
        #expect(state(levels: levels).isSilent == false)
    }

    @Test("ignores loud audio older than the inspected window")
    func ignoresOlderLoudAudio() {
        var levels: [Float] = [0.9]
        levels += Array(repeating: Float(0.001), count: VoiceConstants.silenceSampleCount)
        #expect(state(levels: levels).isSilent)
    }

    @Test("reports no pause before any audio has arrived")
    func reportsNoSilenceWithoutLevels() {
        #expect(state().isSilent == false)
        #expect(VoiceCaptureState.preparing.isSilent == false)
    }

    @Test("starts in the preparing phase with nothing recognized")
    func preparingStateIsEmpty() {
        #expect(VoiceCaptureState.preparing.phase == .preparing)
        #expect(VoiceCaptureState.preparing.hasTranscript == false)
        #expect(VoiceCaptureState.preparing.levels.isEmpty)
    }
}
