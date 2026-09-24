import AppKit
import SwiftUI

/// Native macOS entry point for the local-only assistant.
@main
internal struct LocalAssistantApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate
    @State private var model = AppModel()

    /// Declares one normal assistant window and a minimal command menu.
    internal var body: some Scene {
        Window(UIStrings.appName, id: AppConstants.Identity.mainWindowIdentifier) {
            RootView()
                .environment(model)
                .frame(
                    minWidth: DesignTokens.Window.minimumWidth,
                    minHeight: DesignTokens.Window.minimumHeight
                )
                .task {
                    applicationDelegate.connect(model: model)
                    await model.start()
                }
        }
        .defaultSize(
            width: DesignTokens.Window.defaultWidth,
            height: DesignTokens.Window.defaultHeight
        )
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(UIStrings.about) {
                    NSApp.orderFrontStandardAboutPanel(
                        options: [.version: UIStrings.installedVersionLabel]
                    )
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button(UIStrings.settings) {
                    model.showSettings()
                }
                .keyboardShortcut(
                    ShortcutConstants.settingsKey,
                    modifiers: .command
                )
            }
            CommandGroup(after: .newItem) {
                Button(UIStrings.clearConversation) {
                    model.requestConversationClearConfirmation()
                }
                .disabled(
                    model.messages.isEmpty
                        || model.isBusy
                        || model.isListening
                )
            }
        }
    }
}
