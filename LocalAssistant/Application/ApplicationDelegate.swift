import AppKit

/// Owns process-lifetime shortcut registration for the normal macOS application.
@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private weak var model: AppModel?
    private var shortcutService: GlobalShortcutService?
    private var terminationIsPending = false

    /// Connects shared app state and installs the fixed global quick-call shortcut once.
    /// - Parameter model: Main local assistant presentation state.
    internal func connect(model: AppModel) {
        self.model = model
        guard shortcutService == nil else { return }
        let service = GlobalShortcutService { [weak self] in
            self?.presentQuickCall()
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
        restoreMainWindow()
        return true
    }

    /// Defers termination until native model and monitoring resources are released safely.
    /// - Parameter sender: Application requesting normal termination.
    /// - Returns: A deferred reply while orderly local-runtime shutdown completes.
    internal func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        guard terminationIsPending == false else { return .terminateLater }
        terminationIsPending = true
        let model = self.model
        Task { @MainActor [weak self] in
            await model?.shutdown()
            self?.shortcutService?.unregister()
            self?.shortcutService = nil
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    /// Releases the registered system hotkey when the application actually quits.
    /// - Parameter notification: Termination notification from AppKit.
    internal func applicationWillTerminate(_ notification: Notification) {
        shortcutService?.unregister()
    }

    /// Restores the existing window without changing its current destination.
    private func restoreMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.deminiaturize(nil)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    /// Opens the assistant composer for the explicit global quick-call shortcut.
    private func presentQuickCall() {
        restoreMainWindow()
        model?.showAssistant()
    }

    /// Returns the singleton main window that hosts both assistant destinations.
    ///
    /// The scene identifier is matched instead of the visible title, which SwiftUI is free
    /// to change as the window presents a different destination.
    private var mainWindow: NSWindow? {
        NSApp.windows.first {
            $0.identifier?.rawValue == AppConstants.Identity.mainWindowIdentifier
        }
    }
}
