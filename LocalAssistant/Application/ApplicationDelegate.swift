import AppKit

/// Owns process-lifetime shortcut registration for the normal macOS application.
@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private weak var model: AppModel?
    private var shortcutService: GlobalShortcutService?

    /// Connects shared app state and installs the fixed global quick-call shortcut once.
    /// - Parameter model: Main local assistant presentation state.
    internal func connect(model: AppModel) {
        self.model = model
        guard shortcutService == nil else { return }
        let service = GlobalShortcutService { [weak self] in
            self?.presentAssistant()
        }
        let isAvailable = service.register()
        model.setShortcutAvailable(isAvailable)
        if isAvailable { shortcutService = service }
        mainWindow?.isReleasedWhenClosed = false
    }

    /// Keeps the process alive after its main window closes so the shortcut remains usable.
    /// - Parameter sender: Running application requesting close behavior.
    /// - Returns: Always `false` so closing the window does not quit the app.
    internal func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Restores the singleton assistant window when the running Dock app is reopened.
    /// - Parameters:
    ///   - sender: Running application receiving the reopen request.
    ///   - flag: Whether any application window is currently visible.
    /// - Returns: `true` after handling the reopen request.
    internal func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        presentAssistant()
        return true
    }

    /// Releases the registered system hotkey when the application actually quits.
    /// - Parameter notification: Termination notification from AppKit.
    internal func applicationWillTerminate(_ notification: Notification) {
        shortcutService?.unregister()
    }

    /// Brings the existing normal app window forward and focuses its query field.
    private func presentAssistant() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
        model?.showAssistant()
    }

    /// Returns the singleton main window that hosts both assistant destinations.
    private var mainWindow: NSWindow? {
        NSApp.windows.first { $0.title == UIStrings.appName }
    }
}
