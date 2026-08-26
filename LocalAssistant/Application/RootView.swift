import SwiftUI

/// Single-purpose assistant surface with privacy-safe error presentation.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Builds the assistant or Settings inside one main-window surface.
    var body: some View {
        @Bindable var model = model
        Group {
            if model.isStarting {
                startupView
            } else {
                switch model.activeScreen {
                case .assistant:
                    AssistantCommandView()
                case .history:
                    ConversationHistoryView()
                case .activity:
                    IndexActivityView()
                case .settings:
                    SettingsView()
                case .openClawSetup:
                    OpenClawSetupView()
                }
            }
        }
            .id(model.activeScreen)
            .transition(.opacity)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: DesignTokens.Motion.screenTransitionDuration),
                value: model.activeScreen
            )
            .preferredColorScheme(.light)
            .alert(
                UIStrings.errorTitle,
                isPresented: Binding(
                    get: { model.presentedError != nil },
                    set: { if $0 == false { model.dismissError() } }
                ),
                presenting: model.presentedError
            ) { _ in
                Button(UIStrings.done, role: .cancel) { model.dismissError() }
            } message: { error in
                Text(error.localizedDescription)
            }
            .alert(
                UIStrings.clearConversationTitle,
                isPresented: $model.conversationClearConfirmationIsPresented
            ) {
                Button(UIStrings.clearConversation, role: .destructive) {
                    Task { await model.confirmConversationClear() }
                }
                Button(UIStrings.cancel, role: .cancel) {
                    model.dismissConversationClearConfirmation()
                }
            } message: {
                Text(UIStrings.clearConversationMessage)
            }
            .alert(
                UIStrings.clearActivityTitle,
                isPresented: $model.activityClearConfirmationIsPresented
            ) {
                Button(UIStrings.clearActivity, role: .destructive) {
                    Task { await model.confirmActivityClear() }
                }
                Button(UIStrings.cancel, role: .cancel) {
                    model.dismissActivityClearConfirmation()
                }
            } message: {
                Text(UIStrings.clearActivityMessage)
            }
            .alert(
                UIStrings.clearSearchIndexTitle,
                isPresented: $model.searchIndexClearConfirmationIsPresented
            ) {
                Button(UIStrings.clearSearchIndex, role: .destructive) {
                    Task { await model.confirmSearchIndexClear() }
                }
                Button(UIStrings.cancel, role: .cancel) {
                    model.dismissSearchIndexClearConfirmation()
                }
            } message: {
                Text(UIStrings.clearSearchIndexMessage)
            }
            .alert(
                UIStrings.removeDownloadedModelsTitle,
                isPresented: $model.modelRemovalConfirmationIsPresented
            ) {
                Button(UIStrings.removeDownloadedModels, role: .destructive) {
                    Task { await model.confirmModelRemoval() }
                }
                Button(UIStrings.cancel, role: .cancel) {
                    model.dismissModelRemovalConfirmation()
                }
            } message: {
                Text(UIStrings.removeDownloadedModelsMessage)
            }
    }

    /// Explains why controls are unavailable while private local services open.
    private var startupView: some View {
        ZStack {
            CompanionCanvasBackground()
            VStack(spacing: DesignTokens.Spacing.large) {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel(UIStrings.startupTitle)
                Text(UIStrings.startupTitle)
                    .font(.title2.monospaced().weight(.semibold))
                Text(UIStrings.startupDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }
            .padding(DesignTokens.Spacing.xxLarge)
        }
    }
}
