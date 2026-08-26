import AppKit
import SwiftUI

/// Separate, non-sandboxed setup application for the networked connector process.
@main
struct OpenClawConnectorApp: App {
    /// Makes the setup companion a normal visible Dock application.
    internal init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    /// Presents the one local connector setup window.
    var body: some Scene {
        WindowGroup(ConnectorSetupConstants.Identity.appName) {
            ConnectorSetupView()
        }
        .windowResizability(.contentSize)
    }
}
