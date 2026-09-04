import AppKit
import Foundation
import UniformTypeIdentifiers

/// Exact companion release discovered at one bounded application location.
private struct ConnectorAppRelease: Equatable {
    let version: String
    let build: String

    var displayName: String {
        ReminderStrings.connectorReleaseDisplayName(version: version, build: build)
    }
}

/// Best compatible companion plus any installed-version recovery notice.
private struct ConnectorAppResolution {
    let url: URL?
    let availability: OpenClawConnectorAppAvailability
    let issue: String?
}

extension AppModel {
    /// Stores explicit connector opt-in and starts or stops automatic snapshot refreshes.
    /// - Parameter isEnabled: New user-selected connector state.
    internal func setReminderConnectorEnabled(_ isEnabled: Bool) {
        reminderConnectorEnabled = isEnabled
        UserDefaults.standard.set(
            isEnabled,
            forKey: ReminderConstants.Preferences.connectorEnabledKey
        )
        reminderSyncState = isEnabled ? .idle : .disabled
        restartReminderSyncLoop()
        restartConnectorHealthMonitor()
        guard isEnabled else { return }
        Task { [weak self] in
            await self?.syncReminders(presentErrors: false)
        }
    }

    /// Stores the user-selected automatic sync interval for launchd catch-up runs.
    /// - Parameter minutes: One allowlisted multi-hour interval from Settings.
    internal func setReminderSyncInterval(_ minutes: Int) {
        guard ReminderConstants.Preferences.allowedSyncIntervalMinutes.contains(minutes) else {
            return
        }
        reminderSyncIntervalMinutes = minutes
        UserDefaults.standard.set(
            minutes,
            forKey: ReminderConstants.Preferences.syncIntervalMinutesKey
        )
        restartReminderSyncLoop()
        Task { [weak self] in
            await self?.refreshReminderSnapshotIfStale()
        }
    }

    /// Fetches one complete CloudBase snapshot through the opt-in connector.
    /// - Parameter presentErrors: Whether a user-visible failure should be presented.
    internal func syncReminders(presentErrors: Bool = true) async {
        guard reminderSyncState != .syncing else { return }
        do {
            try await performReminderSync()
        } catch {
            if presentErrors {
                await presentConversationError(error)
                showAssistant()
            }
        }
    }

    /// Refreshes whether the connector is installed, nearby, or on a mounted disk image.
    internal func refreshOpenClawConnectorAppAvailability() {
        let resolution = connectorAppResolution()
        openClawConnectorAppAvailability = resolution.availability
        openClawConnectorAppIssue = resolution.issue
    }

    /// Opens the detected connector or lets the user locate one when it is unavailable.
    internal func openOpenClawConnectorApp() {
        let resolution = connectorAppResolution()
        guard let url = resolution.url else {
            locateOpenClawConnectorApp()
            return
        }
        if let issue = incompatibleRunningConnectorIssue() {
            openClawConnectorAppAvailability = .incompatible
            openClawConnectorAppIssue = issue
            handle(LocalAssistantError.connector(issue))
            return
        }
        guard NSWorkspace.shared.open(url) else {
            handle(LocalAssistantError.connector(ReminderStrings.connectorAppOpenFailed))
            return
        }
        openClawConnectorAppAvailability = resolution.availability
        openClawConnectorAppIssue = resolution.issue
    }

    /// Prevents Launch Services from reactivating an already-running older copy.
    /// - Returns: Recovery guidance when a mismatched Connector is running, otherwise `nil`.
    private func incompatibleRunningConnectorIssue() -> String? {
        guard let expected = connectorRelease(for: Bundle.main) else { return nil }
        return NSRunningApplication.runningApplications(
            withBundleIdentifier: ReminderConstants.Identity.connectorSetupBundleIdentifier
        ).compactMap(\.bundleURL).compactMap { connectorRelease(at: $0) }.first(where: {
            $0 != expected
        }).map {
            ReminderStrings.connectorRunningVersionMismatch(
                running: $0.displayName,
                expected: expected.displayName
            )
        }
    }

    /// Presents a Finder-backed app picker when automatic discovery finds no connector.
    private func locateOpenClawConnectorApp() {
        let panel = NSOpenPanel()
        panel.title = ReminderStrings.connectorAppLocateTitle
        panel.message = ReminderStrings.connectorAppLocateMessage
        panel.prompt = ReminderStrings.connectorAppLocatePrompt
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.isOpenClawConnectorApp(url) else {
                    self.handle(
                        LocalAssistantError.connector(ReminderStrings.connectorAppMissing)
                    )
                    return
                }
                guard self.isCompatibleOpenClawConnectorApp(url) else {
                    self.handle(
                        LocalAssistantError.connector(
                            ReminderStrings.connectorAppVersionMismatch
                        )
                    )
                    return
                }
                if let issue = self.incompatibleRunningConnectorIssue() {
                    self.openClawConnectorAppAvailability = .incompatible
                    self.openClawConnectorAppIssue = issue
                    self.handle(LocalAssistantError.connector(issue))
                    return
                }
                guard NSWorkspace.shared.open(url) else {
                    self.handle(
                        LocalAssistantError.connector(ReminderStrings.connectorAppOpenFailed)
                    )
                    return
                }
                self.openClawConnectorAppAvailability = self.connectorAvailability(for: url)
                self.openClawConnectorAppIssue = nil
            }
        }
    }

    /// Resolves the best available connector copy without searching unrelated user files.
    /// - Returns: Launchable URL and its user-visible location, or nil when unavailable.
    private func connectorAppResolution() -> ConnectorAppResolution {
        let fileManager = FileManager.default
        let applicationsURL = URL(
            fileURLWithPath: ReminderConstants.Identity.applicationsDirectory,
            isDirectory: true
        )
        let installedURL = applicationsURL.appendingPathComponent(
            ReminderConstants.Identity.connectorSetupAppFilename,
            isDirectory: true
        )
        let nearbyURL = Bundle.main.bundleURL.deletingLastPathComponent()
            .appendingPathComponent(
                ReminderConstants.Identity.connectorSetupAppFilename,
                isDirectory: true
            )
        var candidates: [(url: URL, availability: OpenClawConnectorAppAvailability)] = [
            (installedURL, .installed),
            (nearbyURL, connectorAvailability(for: nearbyURL))
        ]
        if let registeredURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: ReminderConstants.Identity.connectorSetupBundleIdentifier
        ) {
            candidates.append((registeredURL, connectorAvailability(for: registeredURL)))
        }

        let volumesURL = URL(
            fileURLWithPath: ReminderConstants.Identity.mountedVolumesDirectory,
            isDirectory: true
        )
        let volumes = (try? fileManager.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for volume in volumes {
            candidates.append((volume.appendingPathComponent(
                ReminderConstants.Identity.connectorSetupAppFilename,
                isDirectory: true
            ), .diskImage))
        }

        var seenPaths: Set<String> = []
        let available = candidates.filter {
            seenPaths.insert($0.url.standardizedFileURL.path).inserted
                && isOpenClawConnectorApp($0.url)
        }
        guard let expected = connectorRelease(for: Bundle.main) else {
            return ConnectorAppResolution(url: nil, availability: .missing, issue: nil)
        }
        let installedRelease = isOpenClawConnectorApp(installedURL)
            ? connectorRelease(at: installedURL)
            : nil
        if let match = available.first(where: {
            connectorRelease(at: $0.url) == expected
        }) {
            let issue = installedRelease.flatMap { installed in
                installed == expected
                    ? nil
                    : ReminderStrings.connectorInstalledVersionMismatch(
                        installed: installed.displayName,
                        expected: expected.displayName
                    )
            } ?? nil
            return ConnectorAppResolution(
                url: match.url,
                availability: match.availability,
                issue: issue
            )
        }
        let issue = available.compactMap { connectorRelease(at: $0.url) }.first.map {
            ReminderStrings.connectorNoCompatibleVersion(
                found: $0.displayName,
                expected: expected.displayName
            )
        }
        return ConnectorAppResolution(
            url: nil,
            availability: issue == nil ? .missing : .incompatible,
            issue: issue
        )
    }

    /// Confirms one application bundle has the connector's exact bundle identity.
    /// - Parameter url: Candidate application bundle.
    /// - Returns: Whether the candidate is the shipped connector setup app.
    private func isOpenClawConnectorApp(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let bundle = Bundle(url: url) else {
            return false
        }
        return bundle.bundleIdentifier
            == ReminderConstants.Identity.connectorSetupBundleIdentifier
    }

    /// Requires the Connector to match this Local Assistant release exactly.
    /// - Parameter url: Candidate Connector application bundle.
    /// - Returns: `true` when its version and build match this release.
    private func isCompatibleOpenClawConnectorApp(_ url: URL) -> Bool {
        guard let expected = connectorRelease(for: Bundle.main),
              let candidate = connectorRelease(at: url) else {
            return false
        }
        return candidate == expected
    }

    /// Reads one app bundle's marketing version and build number.
    /// - Parameter url: Location of a candidate Connector bundle.
    /// - Returns: That bundle's release identity, or `nil` when it cannot be read.
    private func connectorRelease(at url: URL) -> ConnectorAppRelease? {
        guard let bundle = Bundle(url: url) else { return nil }
        return connectorRelease(for: bundle)
    }

    /// Reads release identity without relying on an app's filename.
    /// - Parameter bundle: Loaded application bundle.
    /// - Returns: Marketing version and build number, or `nil` when either is absent.
    private func connectorRelease(for bundle: Bundle) -> ConnectorAppRelease? {
        guard let version = bundle.object(
            forInfoDictionaryKey: AppConstants.Identity.bundleShortVersionKey
        ) as? String,
        let build = bundle.object(
            forInfoDictionaryKey: AppConstants.Identity.bundleVersionKey
        ) as? String,
        version.isEmpty == false,
        build.isEmpty == false else {
            return nil
        }
        return ConnectorAppRelease(version: version, build: build)
    }

    /// Classifies a verified connector URL for the setup button label.
    /// - Parameter url: Verified connector application bundle.
    /// - Returns: User-visible launch location.
    private func connectorAvailability(
        for url: URL
    ) -> OpenClawConnectorAppAvailability {
        let path = url.standardizedFileURL.path
        let mountedPrefix = ReminderConstants.Identity.mountedVolumesDirectory
            + FileConstants.pathSeparator
        let applicationsPrefix = ReminderConstants.Identity.applicationsDirectory
            + FileConstants.pathSeparator
        if path.hasPrefix(mountedPrefix) {
            return .diskImage
        }
        if path.hasPrefix(applicationsPrefix) {
            return .installed
        }
        return .nearby
    }

    /// Adds one assistant answer to visible and private conversation history.
    /// - Parameter text: Safe assistant or Connector text.
    /// - Throws: A local database error when the message cannot be saved.
    internal func appendAssistantMessage(_ text: String) async throws {
        let message = ChatMessage(
            id: UUID(),
            role: .assistant,
            text: text,
            createdAt: Date(),
            citations: [],
            fileMatches: [],
            reminderMatches: []
        )
        try await services.database.insertChatMessage(message)
        messages.append(message)
        currentResponse = message
    }

    /// Adds one connector-originated answer through the shared assistant-message path.
    /// - Parameter text: OpenClaw's answer to the authorized user request.
    /// - Throws: A local database error when the message cannot be saved.
    internal func appendConnectorMessage(_ text: String) async throws {
        try await appendAssistantMessage(text)
    }

    /// Replaces hidden reminder knowledge only after a successful complete snapshot.
    /// - Throws: A connector or local database error when the snapshot cannot be replaced.
    internal func performReminderSync() async throws {
        reminderSyncState = .syncing
        do {
            try await services.reminders.sync(
                connectorEnabled: reminderConnectorEnabled
            )
            lastReminderSyncAt = try await services.reminders.lastSuccessfulSync()
            reminderSyncState = .idle
        } catch {
            reminderSyncState = reminderConnectorEnabled ? .failed : .disabled
            throw error
        }
    }

    /// Refreshes at launch only when the hidden snapshot is absent or older than its interval.
    internal func refreshReminderSnapshotIfStale() async {
        guard reminderConnectorEnabled else { return }
        let maximumAge = TimeInterval(reminderSyncIntervalMinutes * 60)
        guard let lastReminderSyncAt,
              Date().timeIntervalSince(lastReminderSyncAt) < maximumAge else {
            await syncReminders(presentErrors: false)
            return
        }
    }

    /// Publishes the current schedule for the one-shot launchd connector job.
    internal func restartReminderSyncLoop() {
        reminderSyncTask?.cancel()
        let enabled = reminderConnectorEnabled
        let interval = reminderSyncIntervalMinutes
        reminderSyncTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.services.reminderSpool.updateSchedule(
                    enabled: enabled,
                    intervalMinutes: interval
                )
            } catch {
                guard Task.isCancelled == false else { return }
                self.reminderSyncState = enabled ? .failed : .disabled
            }
        }
    }

    /// Applies one completed scheduled snapshot without contacting OpenClaw from this process.
    private func consumeScheduledReminderSnapshotIfAvailable() async {
        guard reminderConnectorEnabled, reminderSyncState != .syncing else { return }
        do {
            guard try await services.reminders.consumeScheduledSnapshot() else { return }
            lastReminderSyncAt = try await services.reminders.lastSuccessfulSync()
            reminderSyncState = .idle
        } catch {
            reminderSyncState = .failed
        }
    }

    /// Starts or stops the one-second local heartbeat monitor for the enabled ability.
    internal func restartConnectorHealthMonitor() {
        connectorHealthTask?.cancel()
        connectorHealthTask = nil
        guard reminderConnectorEnabled else {
            openClawConnectorHealth = .off
            return
        }
        openClawConnectorHealth = .checking
        connectorHealthTask = Task { [weak self] in
            guard let self else { return }
            while Task.isCancelled == false {
                await self.consumeScheduledReminderSnapshotIfAvailable()
                let health = await self.services.reminderSpool.connectorHealth()
                guard Task.isCancelled == false else { return }
                self.openClawConnectorHealth = health
                do {
                    try await Task.sleep(
                        nanoseconds: ReminderConstants.Connector.healthPollNanoseconds
                    )
                } catch {
                    return
                }
            }
        }
    }
}
