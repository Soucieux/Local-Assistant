import SwiftUI

/// Draws live microphone levels as a symmetric bar meter.
///
/// The bars are the audio energies the speech model already reports, so the meter reflects
/// what the app is actually hearing rather than a decorative animation.
struct VoiceWaveformView: View {
    /// Recent relative levels, oldest first, each between zero and one.
    let levels: [Float]

    /// Whether the meter is waiting for the speech model instead of showing audio.
    let isPreparing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DesignTokens.Waveform.barSpacing) {
            ForEach(Array(displayedLevels.enumerated()), id: \.offset) { _, level in
                Capsule(style: .continuous)
                    .fill(DesignTokens.Color.voice)
                    .opacity(isPreparing ? DesignTokens.Waveform.restingOpacity : 1)
                    .frame(
                        width: DesignTokens.Waveform.barWidth,
                        height: barHeight(for: level)
                    )
            }
        }
        .frame(height: DesignTokens.Waveform.height)
        .frame(maxWidth: .infinity)
        .animation(motion, value: displayedLevels)
        .accessibilityElement()
        .accessibilityLabel(
            isPreparing ? UIStrings.voicePreparing : UIStrings.voiceListening
        )
    }

    /// Levels padded to a stable count so bars do not shift position as audio arrives.
    private var displayedLevels: [Float] {
        let count = VoiceConstants.displayedLevelCount
        guard levels.count < count else { return Array(levels.suffix(count)) }
        return Array(repeating: 0, count: count - levels.count) + levels
    }

    /// Scales one level into a drawable bar height.
    /// - Parameter level: Relative energy between zero and one.
    /// - Returns: Height between the resting and maximum bar heights.
    private func barHeight(for level: Float) -> CGFloat {
        let minimum = DesignTokens.Waveform.minimumBarHeight
        let maximum = DesignTokens.Waveform.maximumBarHeight
        let clamped = CGFloat(max(0, min(1, level)))
        return minimum + (maximum - minimum) * clamped
    }

    /// Animation applied to level changes, omitted when the reader prefers reduced motion.
    private var motion: Animation? {
        reduceMotion ? nil : .linear(duration: DesignTokens.Motion.waveformDuration)
    }
}
