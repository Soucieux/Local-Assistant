import SwiftUI

/// Voice-first command surface that presents only the latest request and result.
struct AssistantCommandView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focusedTarget: CommandFocusTarget?
    @State private var spaceIsHeld = false

    /// Builds the command canvas, current response, findings, and movable input control.
    var body: some View {
        ZStack {
            CompanionCanvasBackground()

            VStack(spacing: 0) {
                header
                if model.isIndexing {
                    CommandIndexingStrip()
                }
                GeometryReader { proxy in
                    VStack(spacing: DesignTokens.Spacing.xLarge) {
                        if model.hasCurrentRequest {
                            currentOutput
                                .frame(maxHeight: .infinity)
                            commandInput
                                .frame(maxWidth: DesignTokens.Command.inputMaximumWidth)
                        } else {
                            commandInput
                                .frame(maxWidth: DesignTokens.Command.inputMaximumWidth)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.xLarge)
                    .padding(.top, DesignTokens.Spacing.large)
                    .padding(.bottom, DesignTokens.Spacing.xLarge)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: DesignTokens.Motion.commandRelocationDuration),
                        value: model.hasCurrentRequest
                    )
                }
            }
        }
        .focusable()
        .focused($focusedTarget, equals: .surface)
        .onKeyPress(
            .space,
            phases: [.down, .repeat, .up],
            action: handleSpaceKey
        )
        .onAppear { focusPreferredTarget() }
        .onChange(of: model.inputFocusRequest) { _, _ in
            focusPreferredTarget()
        }
        .onChange(of: model.voiceInputMode) { _, _ in
            focusPreferredTarget()
        }
        .onChange(of: scenePhase) { _, phase in
            endHeldCaptureWhenInactive(phase)
        }
        .onChange(of: model.queryText) { previousText, currentText in
            if previousText.isEmpty, currentText.isEmpty == false {
                model.prepareNewRequestPresentation()
            }
        }
    }

    /// Builds the app identity, local status, and in-window destinations.
    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Text(UIStrings.appName.uppercased())
                .font(.caption.monospaced().weight(.bold))
                .tracking(1.5)
                .lineLimit(1)

            Spacer(minLength: DesignTokens.Spacing.medium)

            Text(commandHeaderStatus)
                .font(.caption2.monospaced().weight(.medium))
                .tracking(1.1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: DesignTokens.Spacing.medium)

            HStack(spacing: DesignTokens.Spacing.small) {
                commandHeaderButton(
                    title: UIStrings.history,
                    systemImage: SystemImages.history,
                    action: model.showHistory
                )
                commandHeaderButton(
                    title: UIStrings.activity,
                    systemImage: SystemImages.activity,
                    action: model.showActivity
                )
                commandHeaderButton(
                    title: UIStrings.settings,
                    systemImage: SystemImages.settings,
                    action: model.showSettings
                )
            }
        }
        .foregroundStyle(DesignTokens.Color.commandInk)
        .padding(.horizontal, DesignTokens.Spacing.xLarge)
        .frame(height: DesignTokens.Command.headerHeight)
        .background(DesignTokens.Color.commandLightCanvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.Color.commandInk.opacity(0.68))
                .frame(height: 1)
                .padding(.horizontal, DesignTokens.Spacing.xLarge)
        }
    }

    /// Current local processing state presented in the center of the telemetry rail.
    private var commandHeaderStatus: String {
        if model.isIndexing { return UIStrings.commandIndexingStatus }
        return model.reminderConnectorEnabled
            ? UIStrings.commandConnectorStatus
            : UIStrings.commandLocalStatus
    }

    /// Creates one labeled navigation control for the command header.
    /// - Parameters:
    ///   - title: Visible and accessible action name.
    ///   - systemImage: SF Symbol identifying the destination.
    ///   - action: In-window navigation action.
    /// - Returns: A compact square-edged command control.
    private func commandHeaderButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title.uppercased(), systemImage: systemImage)
                .font(.caption2.monospaced().weight(.semibold))
                .tracking(0.8)
                .lineLimit(1)
        }
        .buttonStyle(CommandHeaderButtonStyle())
        .disabled(model.isListening || model.isBusy)
        .accessibilityLabel(title)
        .help(title)
    }

    /// Builds the latest processing state, response, and adaptive file findings.
    private var currentOutput: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xLarge) {
                if model.isBusy {
                    ProcessingIndicator()
                        .transition(.opacity)
                } else if let response = model.currentResponse {
                    CommandResponseView(message: response)
                        .transition(.opacity)
                    if response.fileMatches.isEmpty == false {
                        CommandFindingsGrid(results: response.fileMatches)
                            .transition(.opacity)
                    }
                    if response.reminderMatches.isEmpty == false {
                        CommandReminderFindingsGrid(results: response.reminderMatches)
                            .transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: DesignTokens.Command.contentMaximumWidth)
            .padding(.vertical, DesignTokens.Spacing.xxLarge)
            .frame(maxWidth: .infinity)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.responseTransitionDuration),
                value: model.isBusy
            )
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.responseTransitionDuration),
                value: model.currentResponse?.id
            )
        }
        .scrollIndicators(.hidden)
    }

    /// Builds the voice and text control in its centered or bottom position.
    private var commandInput: some View {
        @Bindable var model = model
        return VStack(spacing: DesignTokens.Spacing.small) {
            ZStack {
                if model.isListening {
                    Text(liveInputText)
                        .accessibilityLabel(liveInputText)
                } else {
                    if model.queryText.isEmpty {
                        Text(inputPrompt)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    TextField(AppConstants.Text.empty, text: $model.queryText, axis: .vertical)
                        .focused($focusedTarget, equals: .input)
                        .textFieldStyle(.plain)
                        .disabled(model.isBusy)
                        .onSubmit {
                            Task {
                                await model.submit()
                                focusPreferredTarget()
                            }
                        }
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                model.beginTextInput()
                                focusedTarget = .input
                            }
                        )
                }
            }
            .font(.system(size: 21, weight: .semibold, design: .monospaced))
            .textCase(.uppercase)
            .foregroundStyle(DesignTokens.Color.commandInk)
            .multilineTextAlignment(.center)
            .lineLimit(1...3)
            .frame(maxWidth: .infinity, minHeight: 32)

            Rectangle()
                .fill(DesignTokens.Color.commandInk)
                .frame(height: 2)

            Button {
                Task { await performCommandAction() }
            } label: {
                if reduceMotion {
                    CommandTriangle()
                        .fill(DesignTokens.Color.commandAccent)
                        .frame(
                            width: DesignTokens.Command.triangleWidth,
                            height: DesignTokens.Command.triangleHeight
                        )
                        .scaleEffect(voiceScale)
                } else {
                    PhaseAnimator([false, true]) { isDimmed in
                        CommandTriangle()
                            .fill(DesignTokens.Color.commandAccent)
                            .frame(
                                width: DesignTokens.Command.triangleWidth,
                                height: DesignTokens.Command.triangleHeight
                            )
                            .opacity(
                                trianglePulseIsActive && isDimmed
                                    ? DesignTokens.Motion.triangleDimOpacity
                                    : 1
                            )
                            .scaleEffect(voiceScale)
                    } animation: { _ in
                        .easeInOut(duration: DesignTokens.Motion.trianglePulseDuration)
                    }
                }
            }
            .buttonStyle(.plain)
            .buttonHoverFeedback(tint: DesignTokens.Color.commandAccent)
            .disabled(model.isBusy)
            .accessibilityLabel(commandActionLabel)
            .help(commandActionLabel)
            .animation(
                reduceMotion ? nil : .linear(duration: DesignTokens.Motion.waveformDuration),
                value: voiceScale
            )

            Text(inputSupportLabel)
                .font(.caption2.monospaced().weight(.medium))
                .tracking(1.0)
                .foregroundStyle(inputSupportColor)
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
    }

    /// Visible input text while speech recognition is revising the transcript.
    private var liveInputText: String {
        model.voiceCapture.hasTranscript
            ? model.voiceCapture.transcript
            : UIStrings.voiceListening
    }

    /// Prompt shown before the first request or while awaiting the next request.
    private var inputPrompt: String {
        model.hasCurrentRequest && model.isComposingRequest == false
            ? model.currentRequestText
            : UIStrings.commandPrompt
    }

    /// Compact system label beneath the command control for its current state.
    private var inputSupportLabel: String {
        if model.isListening { return UIStrings.commandListening }
        if model.isBusy { return UIStrings.commandProcessing }
        return model.voiceInputMode == .holdSpace
            ? UIStrings.commandHoldInputHelp
            : UIStrings.commandClickInputHelp
    }

    /// State-aware supporting color that does not carry meaning without text.
    private var inputSupportColor: Color {
        model.isListening || model.isBusy
            ? DesignTokens.Color.commandAccent
            : DesignTokens.Color.commandMutedInk
    }

    /// Accessible action label that follows voice, typed, and idle states.
    private var commandActionLabel: String {
        if model.isListening { return UIStrings.stopListening }
        if model.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return UIStrings.answerWithEvidence
        }
        return UIStrings.startListening
    }

    /// Audio-reactive scale for the red command indicator.
    private var voiceScale: CGFloat {
        let restingScale: CGFloat = 1
        guard model.isListening,
              let level = model.voiceCapture.levels
                  .suffix(DesignTokens.Waveform.indicatorSampleCount)
                  .max() else {
            return restingScale
        }
        let normalized = CGFloat(max(0, min(1, level)))
        return restingScale + normalized * DesignTokens.Waveform.indicatorScaleRange
    }

    /// Whether the stable phase loop should visibly brighten and dim the idle control.
    private var trianglePulseIsActive: Bool {
        model.isListening == false && model.isBusy == false
    }

    /// Sends typed text, stops active speech, or begins a new recording.
    private func performCommandAction() async {
        if model.isListening {
            await model.stopListening()
        } else if model.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            await model.submit()
        } else {
            await model.startListening()
        }
    }

    /// Moves focus to text entry or the command surface for the selected voice mode.
    private func focusPreferredTarget() {
        focusedTarget = model.voiceInputMode == .holdSpace ? .surface : .input
    }

    /// Ends an active capture when the application stops being frontmost.
    ///
    /// Hold-to-talk ends on the key release, and a release is not delivered once another
    /// application takes focus. Without this the microphone would stay open until the
    /// speaker noticed and stopped it by hand.
    /// - Parameter phase: Latest scene phase reported for this window.
    private func endHeldCaptureWhenInactive(_ phase: ScenePhase) {
        guard phase != .active else { return }
        spaceIsHeld = false
        guard model.isListening else { return }
        Task { await model.stopListening() }
    }

    /// Starts hold-to-talk on Space down and sends the finalized transcript on release.
    /// - Parameter press: Local key event delivered while the command surface has focus.
    /// - Returns: Whether this view consumed the event.
    private func handleSpaceKey(_ press: KeyPress) -> KeyPress.Result {
        let disallowedModifiers: EventModifiers = [.command, .control, .option, .shift]
        guard model.voiceInputMode == .holdSpace,
              focusedTarget != .input,
              press.modifiers.intersection(disallowedModifiers).isEmpty else {
            return .ignored
        }
        if press.phase.contains(.down) {
            guard spaceIsHeld == false else { return .handled }
            guard model.isBusy == false, model.isListening == false else { return .handled }
            spaceIsHeld = true
            Task {
                await model.startListening()
                if spaceIsHeld == false, model.isListening {
                    await model.stopListening()
                }
            }
            return .handled
        }
        if press.phase.contains(.repeat) {
            return .handled
        }
        if press.phase.contains(.up) {
            guard spaceIsHeld else { return .handled }
            spaceIsHeld = false
            Task {
                if model.isListening {
                    await model.stopListening()
                }
            }
            return .handled
        }
        return .ignored
    }
}

/// Keyboard focus destinations used to keep text entry and hold-to-talk independent.
private enum CommandFocusTarget: Hashable {
    case input
    case surface
}
