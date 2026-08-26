import Foundation

/// User-visible reminder-cache and OpenClaw connector copy.
enum ReminderStrings {
    static let ownerLocalAssistant = "CloudBase only"
    static let ownerOpenClaw = "OpenClaw managed"
    static let ownerUnknown = "CloudBase"
    static let undated = "No date"
    static let openClawSettingsTitle = "OpenClaw Connection"
    static let openClawSettingsDetail =
        "Manage on-demand OpenClaw requests and complete reminder-snapshot refreshes."
    static let enableConnector = "Enable OpenClaw connection"
    static let connectorPrivacyDetail =
        "Local Assistant has no network access. A separate one-shot connector opens a restricted SSH tunnel only for a queued request, closes it, and exits."
    static let connectorHealthTitle = "Connection status"
    static let connectorOff = "Off"
    static let connectorOffDetail =
        "OpenClaw requests and automatic reminder refreshes are disabled."
    static let connectorChecking = "Checking"
    static let connectorCheckingDetail =
        "Reading the separate connector's private local status file."
    static let connectorNotDetected = "Not configured"
    static let connectorNotDetectedDetail =
        "No connector result was found. Open the setup guide to prepare the restricted SSH access."
    static let connectorUpdateRequired = "Update required"
    static let connectorUpdateRequiredDetail =
        "The installed Connector runtime is older than this Local Assistant release. Open OpenClaw Connector and choose Update and Verify Existing Connector."
    static let connectorRunning = "Connecting"
    static let connectorRunningDetail =
        "The one-shot connector is opening its temporary SSH tunnel for a queued request."
    static let connectorRunningUnreachable = "Connection failed"
    static let connectorRunningUnreachableDetail =
        "The connector process is active, but its restricted SSH tunnel or OpenClaw request failed."
    static let connectorReady = "Ready"
    static let connectorReadyDetail =
        "Connector setup is verified and the last request succeeded. No SSH tunnel remains open between requests."
    static let connectorNeedsAttention = "Last connection failed"
    static let connectorNeedsAttentionDetail =
        "Connector setup remains verified, but the latest request failed. The last complete reminder cache is preserved and may be outdated."
    static let openSetup = "Open Setup"
    static let reviewSetup = "Review Setup"
    static let refreshNow = "Refresh Now"
    static let refreshingNow = "Refreshing…"
    static let cachedSnapshotOutdated =
        "The latest refresh failed. Reminder answers still use the last complete local snapshot, which may be outdated."
    static let setupScreenTitle = "OpenClaw Setup"
    static let setupScreenDetail =
        "Connection status and the three remaining actions. Detailed setup stays inside the matching Connector app."
    static let backToSettings = "Back to Settings"
    static let setupPrivacyTitle = "The privacy boundary stays intact"
    static let setupPrivacyDetail =
        "OpenClaw stays on server loopback at 127.0.0.1:23116. Local Assistant never opens a socket. The separate Connector uses the Mac's built-in SSH client only while handling a request; no VPN app, public Gateway, public HTTPS endpoint, or continuous tunnel is required."
    static let troubleshootingTitle = "Questions and fixes"
    static let localSetupConnectorTitle = "1. Complete setup in OpenClaw Connector"
    static let localSetupConnectorBullets = [
        "Open only the Connector from the same Local Assistant release. Version and build must match exactly.",
        "The Connector creates both server files, shows the server commands, stores both tokens in Keychain, and verifies the restricted tunnel.",
        "When Save and Verify succeeds, server and Connector setup are complete. The Connector closes automatically."
    ]
    static let localSetupEnableTitle = "2. Enable the connection"
    static let localSetupEnableBullets = [
        "Return to Settings and turn on Enable OpenClaw connection.",
        "Choose how often the hidden reminder snapshot should refresh. No tunnel remains open while waiting."
    ]
    static let localSetupRefreshTitle = "3. Confirm the first reminder refresh"
    static let localSetupRefreshBullets = [
        "Choose Refresh Now in Settings after the Connector has verified successfully.",
        "A successful complete snapshot updates the private reminder cache and RAG index. A failed refresh never erases the last successful snapshot."
    ]
    static let refreshAfterVerifyQuestion =
        "Q: Save and Verify passed, but Refresh Now later failed. Is setup incomplete?"
    static let refreshAfterVerifyAnswer = [
        "No. A verified Connector means the server installation, SSH key, host key, and tokens were accepted.",
        "The later message describes a synchronization failure only. Retry Refresh Now; do not rerun server setup unless the Connector itself can no longer verify.",
        "The previous complete reminder cache remains available and is marked as potentially outdated until a refresh succeeds."
    ]

    static let openInstalledConnectorApp = "Open Installed Connector"
    static let openNearbyConnectorApp = "Open Connector App"
    static let openDiskImageConnectorApp = "Open Connector from Disk Image"
    static let locateConnectorApp = "Locate Connector App…"
    static let checkingConnectorApp = "Checking for Connector…"
    static let connectorAppMissing =
        "The selected app is not OpenClaw Connector. Open the Local Assistant release disk image, then select OpenClaw Connector.app or copy it into Applications."
    static let connectorAppOpenFailed =
        "macOS could not open OpenClaw Connector.app. Recopy it from the same release package and try again."
    static let connectorAppVersionMismatch =
        "That Connector does not match this Local Assistant version. Choose the Connector from the same release disk image."
    /// Explains how to replace an older Applications copy.
    /// - Parameters:
    ///   - installed: Version and build currently in Applications.
    ///   - expected: Version and build required by Local Assistant.
    /// - Returns: Recovery guidance for the installed mismatch.
    internal static func connectorInstalledVersionMismatch(installed: String, expected: String) -> String {
        "Applications contains Connector \(installed), but this app requires \(expected). Open the matching Connector from this release, then replace the older Applications copy when convenient."
    }
    /// Explains that no discovered Connector matches the current release.
    /// - Parameters:
    ///   - found: Version and build of one discovered Connector.
    ///   - expected: Version and build required by Local Assistant.
    /// - Returns: Recovery guidance for locating the matching release.
    internal static func connectorNoCompatibleVersion(found: String, expected: String) -> String {
        "Found Connector \(found), but this app requires \(expected). Open the matching release disk image and choose its Connector."
    }
    /// Prevents an older running copy from being reactivated by Launch Services.
    /// - Parameters:
    ///   - running: Version and build of the active Connector.
    ///   - expected: Version and build required by Local Assistant.
    /// - Returns: Guidance to quit and replace the active mismatch.
    internal static func connectorRunningVersionMismatch(running: String, expected: String) -> String {
        "Connector \(running) is already running, but this app requires \(expected). Quit the older Connector, replace its Applications copy from this release, then open it again."
    }
    static let connectorAppLocateTitle = "Locate OpenClaw Connector"
    static let connectorAppLocateMessage =
        "Select OpenClaw Connector.app in Applications or an opened Local Assistant release disk image."
    static let connectorAppLocatePrompt = "Open Connector"
    static let connectorAgentDetail =
        "Ask about reminders naturally. Read-only questions stay local. Before adding, changing, completing, or removing a reminder, the assistant repeats the exact request in the conversation and waits for your yes or no reply."
    static let syncInterval = "Refresh hidden reminder knowledge"
    static let connectorNotEnabled =
        "Enable the OpenClaw connector in Settings before using OpenClaw or refreshing reminders."
    static let connectorTimedOut =
        "The one-shot OpenClaw connector did not answer. Review its SSH setup and try again."
    static let incompleteSnapshot =
        "The connector response was incomplete, so the previous local reminder knowledge was kept."
    static let calendarBoundaryViolation =
        "The reminder snapshot response did not prove that Calendar was untouched. The previous local cache was kept."
    static let reminderNotFound =
        "I could not find a matching reminder in the latest local snapshot."
    static let noReminderMatches = "No reminders matched that request."
    static let invalidReminderRoute =
        "I could not safely interpret that reminder question. Please restate which reminder or deadline you mean."
    static let noTag = "No tag"
    static let overdue = "Overdue"
    static let dueToday = "Today"
    static let dueTomorrow = "Tomorrow"
    static let upcoming = "Upcoming"
    static let linkIncluded = "Link included"
    static let reminderConfirmationDetail =
        "I will send only this exact request. I will not attach cached reminders, files, or conversation history."
    static let reminderConfirmationUnclear =
        "I still need a clear instruction. You can say continue, proceed, send it, or cancel."
    static let reminderConfirmationDeclined =
        "Okay. I did not send that reminder request to OpenClaw."
    static let connectorRuntimeUpdateConversation =
        "I have not sent the reminder request yet. The installed Connector runtime needs to be updated first. Open OpenClaw Connector, choose Update and Verify Existing Connector, then return here and tell me to continue."

    /// Returns the concise title for one observed connector health state.
    /// - Parameter health: Current local connector health.
    /// - Returns: User-facing state title.
    internal static func connectorHealthTitle(_ health: OpenClawConnectorHealth) -> String {
        switch health {
        case .off: return connectorOff
        case .checking: return connectorChecking
        case .notDetected: return connectorNotDetected
        case .updateRequired: return connectorUpdateRequired
        case .runningUnverified: return connectorRunning
        case .runningUnreachable: return connectorRunningUnreachable
        case .ready: return connectorReady
        case .needsAttention: return connectorNeedsAttention
        }
    }

    /// Returns recovery-oriented detail for one observed connector health state.
    /// - Parameter health: Current local connector health.
    /// - Returns: User-facing state explanation.
    internal static func connectorHealthDetail(_ health: OpenClawConnectorHealth) -> String {
        switch health {
        case .off: return connectorOffDetail
        case .checking: return connectorCheckingDetail
        case .notDetected: return connectorNotDetectedDetail
        case .updateRequired: return connectorUpdateRequiredDetail
        case .runningUnverified: return connectorRunningDetail
        case .runningUnreachable: return connectorRunningUnreachableDetail
        case .ready: return connectorReadyDetail
        case .needsAttention: return connectorNeedsAttentionDetail
        }
    }

    /// Returns the setup action that matches the detected connector location.
    /// - Parameter availability: Current connector discovery result.
    /// - Returns: User-facing button title.
    internal static func connectorAppActionTitle(
        _ availability: OpenClawConnectorAppAvailability
    ) -> String {
        switch availability {
        case .checking: return checkingConnectorApp
        case .installed: return openInstalledConnectorApp
        case .nearby: return openNearbyConnectorApp
        case .diskImage: return openDiskImageConnectorApp
        case .incompatible: return locateConnectorApp
        case .missing: return locateConnectorApp
        }
    }

    /// Formats one connector synchronization interval.
    /// - Parameter minutes: Selected launchd-backed synchronization interval.
    /// - Returns: A concise picker label.
    internal static func syncInterval(minutes: Int) -> String {
        let hours = minutes / 60
        return hours == 1 ? "Every hour" : "Every \(hours) hours"
    }

    /// Formats a reminder count.
    /// - Parameter count: Visible reminder-result count.
    /// - Returns: Singular or plural reminder count.
    internal static func reminderCount(_ count: Int) -> String {
        count == 1 ? "1 reminder" : "\(count) reminders"
    }

    /// Summarizes a tag-grouped reminder collection without repeating card content.
    /// - Parameters:
    ///   - count: Number of reminder cards shown.
    ///   - groupCount: Number of visible tag sections.
    /// - Returns: Concise card-only result acknowledgement.
    internal static func reminderListSummary(count: Int, groupCount: Int) -> String {
        let reminderText = reminderCount(count)
        let groupText = groupCount == 1 ? "1 tag group" : "\(groupCount) tag groups"
        return "\(reminderText) across \(groupText) are shown below."
    }

    /// Builds the assistant's conversational double-confirmation turn.
    /// - Parameters:
    ///   - kind: Reminder operation inferred by the local model.
    ///   - request: Exact user wording that would cross the Connector boundary.
    /// - Returns: A clear conversational question that repeats the exact pending request.
    internal static func mutationConfirmationMessage(
        kind: ReminderMutationKind,
        request: String
    ) -> String {
        let action: String
        switch kind {
        case .create: action = "add"
        case .update: action = "update"
        case .remove: action = "remove"
        }
        return "Before I ask OpenClaw to \(action) a reminder, I need to confirm the exact request with you.\n\n“\(request)”\n\n\(reminderConfirmationDetail) Tell me to continue, proceed, send it, or cancel."
    }

    /// Turns a privacy-safe local failure into an assistant conversation message.
    /// - Parameter detail: Localized error text already approved for presentation.
    /// - Returns: Recovery-oriented wording without a modal alert.
    internal static func conversationalError(_ detail: String) -> String {
        if detail.localizedCaseInsensitiveContains("connector request is invalid") {
            return connectorRuntimeUpdateConversation
        }
        return "I could not complete that request. Nothing was changed. \(detail)"
    }
}
