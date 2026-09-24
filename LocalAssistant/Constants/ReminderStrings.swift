import Foundation

/// User-visible reminder-cache and OpenClaw connector copy.
internal enum ReminderStrings {
    internal static let ownerLocalAssistant = "CloudBase only"
    internal static let ownerOpenClaw = "OpenClaw managed"
    internal static let ownerUnknown = "CloudBase"
    internal static let undated = "No date"
    internal static let reminderTimingSeparator = " · "

    /// Formats one reminder card's stored date and optional start time.
    /// - Parameters:
    ///   - date: Stored calendar date, absent when the reminder is undated.
    ///   - startTime: Optional stored wall-clock start.
    /// - Returns: The shared timing label used by every reminder card.
    internal static func reminderTiming(date: String?, startTime: String?) -> String {
        let day = date ?? undated
        guard let startTime else { return day }
        return day + reminderTimingSeparator + startTime
    }
    internal static let openClawSettingsTitle = "OpenClaw Connection"
    internal static let openClawSettingsDetail =
        "Manage private OpenClaw requests and reminder refreshes."
    internal static let enableConnector = "Enable OpenClaw connection"
    internal static let connectorPrivacyDetail =
        "Local Assistant stays offline. The separate Connector opens SSH only while handling a request."
    internal static let connectorHealthTitle = "Connection status"
    internal static let connectorOff = "Off"
    internal static let connectorOffDetail =
        "OpenClaw requests and automatic reminder refreshes are disabled."
    internal static let connectorChecking = "Checking"
    internal static let connectorCheckingDetail =
        "Reading the separate connector's private local status file."
    internal static let connectorNotDetected = "Not configured"
    internal static let connectorNotDetectedDetail =
        "No connector result was found. Open the setup guide to prepare the restricted SSH access."
    internal static let connectorUpdateRequired = "Update required"
    internal static let connectorUpdateRequiredDetail =
        "The installed Connector runtime is older than this Local Assistant release. Open OpenClaw Connector and choose Update and Verify Existing Connector."
    internal static let connectorRunning = "Connecting"
    internal static let connectorRunningDetail =
        "The one-shot connector is opening its temporary SSH tunnel for a queued request."
    internal static let connectorRunningUnreachable = "Connection failed"
    internal static let connectorRunningUnreachableDetail =
        "The connector process is active, but its restricted SSH tunnel or OpenClaw request failed."
    internal static let connectorReady = "Ready"
    internal static let connectorReadyDetail =
        "Connector setup is verified and the last request succeeded. No SSH tunnel remains open between requests."
    internal static let connectorNeedsAttention = "Last connection failed"
    internal static let connectorNeedsAttentionDetail =
        "Connector setup remains verified, but the latest request failed. The last complete reminder cache is preserved and may be outdated."
    internal static let openSetup = "Open Setup"
    internal static let reviewSetup = "Review Setup"
    internal static let refreshNow = "Refresh Now"
    internal static let refreshingNow = "Refreshing…"
    internal static let cachedSnapshotOutdated =
        "The latest refresh failed. Reminder answers still use the last complete local snapshot, which may be outdated."
    internal static let setupScreenTitle = "OpenClaw Setup"
    internal static let setupScreenDetail =
        "Connection status and the three remaining actions. Detailed setup stays inside the matching Connector app."
    internal static let backToSettings = "Back to Settings"
    internal static let setupPrivacyTitle = "The privacy boundary stays intact"
    internal static let setupPrivacyBullets = [
        "Local Assistant stays offline.",
        "The Connector opens SSH only while handling a request.",
        "OpenClaw remains private on the server."
    ]
    internal static let setupPrivacyTechnicalTitle = "Technical privacy details"
    internal static let setupPrivacyTechnicalBullets = [
        "OpenClaw listens only on server loopback at 127.0.0.1:23116.",
        "No VPN app, public Gateway, public HTTPS endpoint, or continuous tunnel is used."
    ]
    internal static let troubleshootingTitle = "Questions and fixes"
    internal static let localSetupConnectorTitle = "1. Complete setup in OpenClaw Connector"
    internal static let localSetupConnectorBullets = [
        "Open the Connector from this Local Assistant release.",
        "Confirm that its version and build match Local Assistant.",
        "Create and transfer both server files.",
        "Run the server commands and enter the three returned values.",
        "Choose Save and Verify Connector. Close the window after it reports success."
    ]
    internal static let localSetupEnableTitle = "2. Enable the connection"
    internal static let localSetupEnableBullets = [
        "Return to Settings and turn on Enable OpenClaw connection.",
        "Choose how often reminder knowledge should refresh."
    ]
    internal static let localSetupRefreshTitle = "3. Confirm the first reminder refresh"
    internal static let localSetupRefreshBullets = [
        "Choose Refresh Now after the Connector verifies successfully.",
        "A successful refresh replaces the private reminder cache and RAG index.",
        "A failed refresh keeps the last successful snapshot."
    ]
    internal static let refreshAfterVerifyQuestion =
        "Q: Save and Verify passed, but Refresh Now later failed. Is setup incomplete?"
    internal static let refreshAfterVerifyAnswer = [
        "No. A verified Connector means the server installation, SSH key, host key, and tokens were accepted.",
        "The later message describes a synchronization failure only. Retry Refresh Now; do not rerun server setup unless the Connector itself can no longer verify.",
        "The previous complete reminder cache remains available and is marked as potentially outdated until a refresh succeeds."
    ]

    internal static let openInstalledConnectorApp = "Open Installed Connector"
    internal static let openNearbyConnectorApp = "Open Connector App"
    internal static let openDiskImageConnectorApp = "Open Connector from Disk Image"
    internal static let locateConnectorApp = "Locate Connector App…"
    internal static let checkingConnectorApp = "Checking for Connector…"
    internal static let connectorAppMissing =
        "The selected app is not OpenClaw Connector. Open the Local Assistant release disk image, then select OpenClaw Connector.app or copy it into Applications."
    internal static let connectorAppOpenFailed =
        "macOS could not open OpenClaw Connector.app. Recopy it from the same release package and try again."
    internal static let connectorAppVersionMismatch =
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
    /// Names one companion release the way every setup message refers to it.
    /// - Parameters:
    ///   - version: Marketing version read from the bundle.
    ///   - build: Build number read from the bundle.
    /// - Returns: The shared release label.
    internal static func connectorReleaseDisplayName(version: String, build: String) -> String {
        "v\(version) (\(build))"
    }
    internal static let connectorAppLocateTitle = "Locate OpenClaw Connector"
    internal static let connectorAppLocateMessage =
        "Select OpenClaw Connector.app in Applications or an opened Local Assistant release disk image."
    internal static let connectorAppLocatePrompt = "Open Connector"
    internal static let connectorAgentDetail =
        "Read-only reminder questions use the local snapshot. Changes are sent only after you confirm the exact request in the conversation."
    internal static let syncInterval = "Refresh hidden reminder knowledge"
    internal static let syncIntervalDetail =
        "Choose the automatic schedule or refresh immediately."
    internal static let setupMaintenanceTitle = "Connector setup"
    internal static let setupMaintenanceDetail =
        "Review the saved connection, update its runtime, or replace credentials."
    internal static let connectorRequestBehaviorTitle = "How reminder requests work"
    internal static let connectorNotEnabled =
        "Enable the OpenClaw connector in Settings before using OpenClaw or refreshing reminders."
    internal static let connectorTimedOut =
        "The one-shot OpenClaw connector did not answer. Review its SSH setup and try again."
    internal static let incompleteSnapshot =
        "The connector response was incomplete, so the previous local reminder knowledge was kept."
    internal static let calendarBoundaryViolation =
        "The reminder snapshot response did not prove that Calendar was untouched. The previous local cache was kept."
    internal static let reminderNotFound =
        "I could not find a matching reminder in the latest local snapshot."
    internal static let noReminderMatches = "No reminders matched that request."
    internal static let invalidReminderRoute =
        "I could not safely interpret that reminder question. Please restate which reminder or deadline you mean."
    internal static let noTag = "No tag"
    internal static let overdue = "Overdue"
    internal static let dueToday = "Today"
    internal static let dueTomorrow = "Tomorrow"
    internal static let upcoming = "Upcoming"
    internal static let linkIncluded = "Link included"
    internal static let exactReminderMatch = "Exact reminder match"
    internal static let reminderTextMatch = "Reminder text match"
    internal static let reminderKeywordMatch = "Keyword and field match"
    internal static let reminderSemanticMatch = "Related reminder meaning"
    internal static let reminderFallbackMatch = "Local reminder match"
    internal static let overdueReminderMatch = "Overdue reminder"
    internal static let dueTodayReminderMatch = "Due today"
    internal static let dueTomorrowReminderMatch = "Due tomorrow"
    internal static let upcomingReminderMatch = "Upcoming reminder"
    internal static let reminderConfirmationDetail =
        "I will send only this exact request. I will not attach cached reminders, files, or conversation history."
    internal static let reminderConfirmationUnclear =
        "I still need a clear instruction. You can say continue, proceed, send it, or cancel."
    internal static let reminderConfirmationDeclined =
        "Okay. I did not send that reminder request to OpenClaw."
    internal static let connectorRuntimeUpdateConversation =
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
        if detail.localizedCaseInsensitiveContains(
            ReminderConstants.Connector.invalidRequestErrorDetail
        ) {
            return connectorRuntimeUpdateConversation
        }
        return "I could not complete that request. Nothing was changed. \(detail)"
    }
}
