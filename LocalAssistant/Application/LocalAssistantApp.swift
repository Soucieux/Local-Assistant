import AppKit
import SwiftUI

/// Native macOS entry point for the local-only assistant.
@main
struct LocalAssistantApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate
    @State private var model = AppModel()

    /// Declares one normal assistant window and a minimal command menu.
    var body: some Scene {
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
                    let version = Bundle.main.object(
                        forInfoDictionaryKey: AppConstants.Identity.bundleShortVersionKey
                    ) as? String ?? AppConstants.Identity.fallbackVersion
                    NSApp.orderFrontStandardAboutPanel(
                        options: [.version: UIStrings.displayVersion(version)]
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
