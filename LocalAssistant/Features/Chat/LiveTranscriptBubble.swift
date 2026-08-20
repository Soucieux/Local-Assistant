import SwiftUI

/// Shows what the microphone is capturing before the request is sent.
///
/// The speech model revises its most recent words as more audio arrives, so settled text is
/// shown plainly and text still being revised is dimmed. Nothing here is saved; the message
/// is written to history only once the recording is committed.
struct LiveTranscriptBubble: View {
    let capture: VoiceCaptureState

    var body: some View {
        HStack {
            Spacer(minLength: DesignTokens.Spacing.xLarge)
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxSmall) {
                Text(UIStrings.voiceCapturing)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignTokens.Color.voice)

                if capture.hasTranscript {
                    transcript
                } else {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.large)
            .padding(.vertical, DesignTokens.Spacing.medium)
            .frame(maxWidth: DesignTokens.Message.maximumWidth, alignment: .trailing)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                    .fill(DesignTokens.Color.voiceSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                    .stroke(DesignTokens.Color.voice.opacity(borderOpacity), lineWidth: 1)
            )
        }
        .accessibilityElement(children: .combine)
    }

    /// Settled words followed by the words still being revised.
    private var transcript: Text {
        Text(capture.confirmedText)
            .foregroundStyle(.primary)
            + Text(spacer)
            + Text(capture.tentativeText)
            .foregroundStyle(.secondary)
    }

    /// Separator inserted only when both settled and tentative text are present.
    private var spacer: String {
        capture.confirmedText.isEmpty || capture.tentativeText.isEmpty
            ? AppConstants.Text.empty
            : VoiceConstants.transcriptionSeparator
    }

    /// Guidance shown before any speech has been recognized.
    private var placeholder: String {
        capture.phase == .preparing ? UIStrings.voicePreparing : UIStrings.voiceListening
    }

    /// Border emphasis, softened while the model is still loading.
    private var borderOpacity: Double {
        capture.phase == .preparing ? DesignTokens.Waveform.restingOpacity : 1
    }
}
