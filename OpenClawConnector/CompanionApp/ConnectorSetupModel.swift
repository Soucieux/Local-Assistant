import AppKit
import Combine
import Darwin
import Foundation

/// Top-level presentation selected after credential-free local discovery.
enum ConnectorSetupMode {
    case loading
    case existing
    case setup
}

/// Non-secret setup facts returned by the bundled Connector runtime.
struct ExistingConnectorState: Decodable, Sendable {
    let hasExistingData: Bool
    let configured: Bool
    let sshHost: String
    let sshPort: Int
    let sshHostKey: String
    let sshIdentityReady: Bool
    let reminderTokenSaved: Bool
    let agentTokenSaved: Bool
    let readyForUpgrade: Bool
}

/// Owns local-only connector configuration, Keychain handoff, and background startup.
@MainActor
final class ConnectorSetupModel: ObservableObject {
    @Published var sshHost = ConnectorSetupConstants.Text.empty
    @Published var sshPort = ConnectorSetupConstants.Configuration.defaultSSHPort
    @Published var sshHostKey = ConnectorSetupConstants.Text.empty
    @Published var reminderToken = ConnectorSetupConstants.Text.empty
    @Published var agentToken = ConnectorSetupConstants.Text.empty
    @Published private(set) var mode = ConnectorSetupMode.loading
    @Published private(set) var existingState: ExistingConnectorState?
    @Published private(set) var statusMessage = ConnectorSetupConstants.Text.empty
    @Published private(set) var statusTone = ConnectorSetupStatusTone.neutral
    @Published private(set) var showsVerificationStatus = false
    @Published private(set) var isBusy = false
    @Published private(set) var publicKeyWasExported = false
    @Published private(set) var serverSetupWasExported = false
    @Published private(set) var isReplacingCredentials = false

    let spoolPath: String
    private var didLoadExistingState = false

    /// Creates setup state and resolves the installed app's private spool path.
    internal init() {
        spoolPath = Self.localAssistantSpoolURL().path
    }

    /// Reports whether both credentials remain saved without retrieving either value.
    internal var credentialsAreSaved: Bool {
        existingState?.reminderTokenSaved == true
            && existingState?.agentTokenSaved == true
    }

    /// Reports whether the two secure fields are required for this save.
    internal var shouldEnterCredentials: Bool {
        isReplacingCredentials || credentialsAreSaved == false
    }

    /// Reports whether setup is reviewing a previously complete installation.
    internal var isReviewingExistingSetup: Bool {
        existingState?.readyForUpgrade == true && mode == .setup
    }

    /// Returns the optional transfer command with public endpoint values filled in.
    internal var transferCommand: String {
        let host = sshHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = sshPort.trimmingCharacters(in: .whitespacesAndNewlines)
        let addressToken = ConnectorSetupConstants.Text.transferAddressToken
        let portToken = ConnectorSetupConstants.Text.transferPortToken
        return ConnectorSetupConstants.Text.transferCommandTemplate
            .replacingOccurrences(
                of: addressToken,
                with: host.isEmpty ? addressToken : host
            )
            .replacingOccurrences(of: portToken, with: port.isEmpty ? portToken : port)
    }

    /// Loads reusable public values and Keychain-presence flags from the bundled runtime.
    internal func loadExistingSetup() async {
        guard didLoadExistingState == false else { return }
        didLoadExistingState = true
        isBusy = true
        do {
            let state = try await Task.detached(priority: .userInitiated) {
                try Self.readExistingSetupState()
            }.value
            applyExistingState(state)
            mode = state.readyForUpgrade ? .existing : .setup
        } catch {
            mode = .setup
            statusMessage = ConnectorSetupConstants.Text.setupStateFailed
            statusTone = .failure
        }
        isBusy = false
    }

    /// Opens the full setup flow with reusable public values already filled in.
    internal func reviewExistingSettings() {
        guard isBusy == false else { return }
        clearStatus()
        isReplacingCredentials = false
        mode = .setup
    }

    /// Reveals empty credential fields for an explicit Keychain replacement.
    internal func beginCredentialReplacement() {
        guard isBusy == false else { return }
        reminderToken = ConnectorSetupConstants.Text.empty
        agentToken = ConnectorSetupConstants.Text.empty
        isReplacingCredentials = true
        mode = .setup
    }

    /// Returns from review without changing the existing Connector.
    internal func returnToExistingConnector() {
        guard existingState?.readyForUpgrade == true, isBusy == false else { return }
        reminderToken = ConnectorSetupConstants.Text.empty
        agentToken = ConnectorSetupConstants.Text.empty
        isReplacingCredentials = false
        clearStatus()
        mode = .existing
    }

    /// Creates the dedicated key if needed and lets the user save only its public half.
    internal func createAndExportPublicKey() {
        guard isBusy == false else { return }
        clearStatus()
        isBusy = true
        defer { isBusy = false }
        do {
            try prepareDedicatedSSHKey()
            let panel = NSSavePanel()
            panel.title = ConnectorSetupConstants.Text.publicKeySaveTitle
            panel.message = ConnectorSetupConstants.Text.publicKeySaveMessage
            panel.prompt = ConnectorSetupConstants.Text.publicKeySavePrompt
            panel.nameFieldStringValue = ConnectorSetupConstants.Identity
                .exportedPublicKeyFilename
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            guard panel.runModal() == .OK, let destination = panel.url else { return }
            let publicKey = try Data(contentsOf: Self.sshPublicKeyURL())
            try publicKey.write(to: destination, options: .atomic)
            publicKeyWasExported = true
            statusMessage = ConnectorSetupConstants.Text.publicKeyReady
            statusTone = .success
        } catch {
            showFailure(error)
        }
    }

    /// Creates the generic server setup ZIP only after the user chooses a destination.
    internal func createServerSetupZIP() {
        guard isBusy == false else { return }
        clearStatus()
        isBusy = true
        defer { isBusy = false }
        do {
            guard let source = Bundle.main.resourceURL?.appendingPathComponent(
                ConnectorSetupConstants.Identity.embeddedServerSetupDirectory,
                isDirectory: true
            ), FileManager.default.fileExists(atPath: source.path) else {
                throw ConnectorSetupError.message(
                    ConnectorSetupConstants.Text.serverSetupMissing
                )
            }
            let panel = NSSavePanel()
            panel.title = ConnectorSetupConstants.Text.serverSetupSaveTitle
            panel.message = ConnectorSetupConstants.Text.serverSetupSaveMessage
            panel.prompt = ConnectorSetupConstants.Text.serverSetupSavePrompt
            panel.nameFieldStringValue = ConnectorSetupConstants.Identity
                .serverSetupZIPFilename
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            guard panel.runModal() == .OK, let destination = panel.url else { return }
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            let process = Process()
            process.executableURL = URL(
                fileURLWithPath: ConnectorSetupConstants.Configuration.archiveExecutable
            )
            process.arguments = [
                "-c", "-k", "--sequesterRsrc", "--keepParent", source.path,
                destination.path
            ]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw ConnectorSetupError.message(
                    ConnectorSetupConstants.Text.serverSetupFailed
                )
            }
            serverSetupWasExported = true
            statusMessage = ConnectorSetupConstants.Text.serverSetupReady
            statusTone = .success
        } catch {
            showFailure(error)
        }
    }

    /// Copies the exact server command group without adding credentials.
    internal func copyServerCommands() {
        copyToPasteboard(ConnectorSetupConstants.Text.serverCommands)
    }

    /// Copies a file-transfer command filled only with the entered public endpoint.
    internal func copyTransferCommand() {
        copyToPasteboard(transferCommand)
    }

    /// Writes one non-secret command group to the macOS pasteboard.
    /// - Parameter value: Non-secret command text shown in the setup step.
    private func copyToPasteboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    /// Updates the packaged runtime while reusing all validated saved setup values.
    internal func updateExistingConnector() {
        guard isBusy == false, existingState?.readyForUpgrade == true else { return }
        clearStatus()
        isBusy = true
        Task { [weak self] in
            await self?.performExistingUpdate()
        }
    }

    /// Restarts the installed connector job after a failed update or re-verification.
    ///
    /// Both flows boot the job out before replacing the runtime, so returning early on a
    /// transient failure would otherwise stop every scheduled refresh until setup was
    /// opened again. The job is restored only when an installed runtime is present.
    private func restoreLaunchAgentIfInstalled() {
        guard FileManager.default.isExecutableFile(
            atPath: Self.runtimeExecutableURL().path
        ) else { return }
        try? installAndStartLaunchAgent()
    }

    /// Installs, verifies, and restarts without requesting credentials again.
    private func performExistingUpdate() async {
        do {
            try validateLocalAssistantSpool()
            try validateDedicatedSSHKey()
            stopExistingLaunchAgent()
            try installRuntime()
            try await Task.detached(priority: .userInitiated) {
                try Self.verifyRuntimeConnection()
            }.value
            try installAndStartLaunchAgent()
            statusMessage = ConnectorSetupConstants.Text.updateReady
            statusTone = .success
            isBusy = false
        } catch {
            restoreLaunchAgentIfInstalled()
            showFailure(error)
            isBusy = false
        }
    }

    /// Validates, saves, starts, and verifies the connector without arguments containing secrets.
    internal func saveAndStart() {
        guard isBusy == false else { return }
        clearStatus()
        showsVerificationStatus = true
        isBusy = true
        Task { [weak self] in
            await self?.performSetupAndVerification()
        }
    }

    /// Completes the local installation and leaves the verified result visible.
    private func performSetupAndVerification() async {
        do {
            let connection = try validatedConnection()
            try validateLocalAssistantSpool()
            try validateDedicatedSSHKey()
            stopExistingLaunchAgent()
            try installRuntime()
            try configureRuntime(connection: connection)
            try await Task.detached(priority: .userInitiated) {
                try Self.verifyRuntimeConnection()
            }.value
            try installAndStartLaunchAgent()
            statusMessage = ConnectorSetupConstants.Text.ready
            statusTone = .success
            isBusy = false
        } catch {
            restoreLaunchAgentIfInstalled()
            showFailure(error)
            isBusy = false
        }
    }

    /// Removes only Connector-owned local state after the view confirms the action.
    internal func removeConnectorData() {
        guard isBusy == false else { return }
        statusMessage = ConnectorSetupConstants.Text.removeWorking
        statusTone = .neutral
        isBusy = true
        stopExistingLaunchAgent()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.detached(priority: .userInitiated) {
                    try Self.forgetRuntimeData()
                }.value
                self.removeLaunchAgentAndPendingSpool()
                self.resetAfterRemoval()
            } catch {
                self.statusMessage = ConnectorSetupConstants.Text.removalFailed
                self.statusTone = .failure
                self.isBusy = false
            }
        }
    }

    /// Applies only credential-free values returned by setup discovery.
    /// - Parameter state: Reusable non-secret values and credential-presence flags.
    private func applyExistingState(_ state: ExistingConnectorState) {
        existingState = state
        sshHost = state.sshHost
        sshPort = String(state.sshPort)
        sshHostKey = state.sshHostKey
        publicKeyWasExported = false
        serverSetupWasExported = false
        isReplacingCredentials = false
    }

    /// Resets the workbench after exact Connector cleanup succeeds.
    private func resetAfterRemoval() {
        existingState = nil
        sshHost = ConnectorSetupConstants.Text.empty
        sshPort = ConnectorSetupConstants.Configuration.defaultSSHPort
        sshHostKey = ConnectorSetupConstants.Text.empty
        reminderToken = ConnectorSetupConstants.Text.empty
        agentToken = ConnectorSetupConstants.Text.empty
        publicKeyWasExported = false
        serverSetupWasExported = false
        isReplacingCredentials = false
        mode = .setup
        statusMessage = ConnectorSetupConstants.Text.removeComplete
        statusTone = .success
        showsVerificationStatus = false
        isBusy = false
    }

    /// Removes the launch configuration and only pending Connector spool lanes.
    private func removeLaunchAgentAndPendingSpool() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: Self.launchAgentPlistURL())
        try? fileManager.removeItem(at: Self.legacyLaunchAgentPlistURL())
        let spool = URL(fileURLWithPath: spoolPath, isDirectory: true)
        for directory in ConnectorSetupConstants.Identity.pendingSpoolDirectories {
            try? fileManager.removeItem(
                at: spool.appendingPathComponent(directory, isDirectory: true)
            )
        }
    }

    /// Clears the latest status before a new user action.
    private func clearStatus() {
        statusMessage = ConnectorSetupConstants.Text.empty
        statusTone = .neutral
        showsVerificationStatus = false
    }

    /// Shows one user-safe failure without remote content or credentials.
    /// - Parameter error: Failure whose description is already approved for display.
    private func showFailure(_ error: Error) {
        statusMessage = ConnectorSetupConstants.Text.setupFailedPrefix
            + error.localizedDescription
        statusTone = .failure
    }

    /// Returns the normalized SSH server values and pinned host key.
    /// - Returns: Validated host, port, and Ed25519 host-key line.
    /// - Throws: A readable validation error for unsupported input.
    private func validatedConnection() throws -> (host: String, port: Int, hostKey: String) {
        let host = sshHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard host.isEmpty == false else {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.sshHostRequired)
        }
        let disallowed = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: "/@?#")
        )
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._:-"
        )
        guard host.rangeOfCharacter(from: disallowed) == nil,
              host.hasPrefix("-") == false,
              host.contains("://") == false,
              host.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.sshHostInvalid)
        }
        let validPorts = ConnectorSetupConstants.Configuration.minimumSSHPort...ConnectorSetupConstants.Configuration.maximumSSHPort
        guard let port = Int(sshPort), validPorts.contains(port) else {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.sshPortInvalid)
        }
        let hostKey = sshHostKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = hostKey.split(whereSeparator: \.isWhitespace)
        let fieldCount = ConnectorSetupConstants.Configuration.sshHostKeyFieldCount
        let decodedHostKey = fields.count == fieldCount
            ? Data(base64Encoded: String(fields[1]))
            : nil
        guard fields.count == fieldCount,
              String(fields[0]) == ConnectorSetupConstants.Configuration.publicKeyPrefix
                .trimmingCharacters(in: .whitespaces),
              let decodedHostKey,
              decodedHostKey.count
                >= ConnectorSetupConstants.Configuration.sshHostKeyMinimumBytes else {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.sshHostKeyInvalid)
        }
        return (host, port, hostKey)
    }

    /// Generates one non-password Ed25519 keypair without invoking a shell.
    /// - Throws: A safe error when an incomplete identity exists or ssh-keygen fails.
    private func prepareDedicatedSSHKey() throws {
        let fileManager = FileManager.default
        let privateKey = Self.sshPrivateKeyURL()
        let publicKey = Self.sshPublicKeyURL()
        let privateExists = fileManager.fileExists(atPath: privateKey.path)
        let publicExists = fileManager.fileExists(atPath: publicKey.path)
        if privateExists || publicExists {
            guard privateExists && publicExists else {
                throw ConnectorSetupError.message(
                    ConnectorSetupConstants.Text.keyPairIncomplete
                )
            }
            try validateDedicatedSSHKey()
            return
        }
        try fileManager.createDirectory(
            at: Self.sshDirectoryURL(),
            withIntermediateDirectories: true,
            attributes: [
                .posixPermissions: ConnectorSetupConstants.Configuration
                    .ownerDirectoryPermissions
            ]
        )
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: ConnectorSetupConstants.Configuration.sshKeygenExecutable
        )
        process.arguments = [
            "-q", "-t", ConnectorSetupConstants.Configuration.sshKeyType,
            "-N", ConnectorSetupConstants.Text.empty,
            "-C", ConnectorSetupConstants.Configuration.sshKeyComment,
            "-f", privateKey.path
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ConnectorSetupError.message(
                ConnectorSetupConstants.Text.keyGenerationFailed
            )
        }
        try fileManager.setAttributes(
            [.posixPermissions: ConnectorSetupConstants.Configuration.ownerFilePermissions],
            ofItemAtPath: privateKey.path
        )
        try validateDedicatedSSHKey()
    }

    /// Requires a complete owner-only private key and its matching public file.
    /// - Throws: A safe error when the dedicated identity is absent or incomplete.
    private func validateDedicatedSSHKey() throws {
        let fileManager = FileManager.default
        let privateKey = Self.sshPrivateKeyURL()
        let publicKey = Self.sshPublicKeyURL()
        guard fileManager.fileExists(atPath: privateKey.path),
              fileManager.fileExists(atPath: publicKey.path),
              let attributes = try? fileManager.attributesOfItem(atPath: privateKey.path),
              let permissions = attributes[.posixPermissions] as? NSNumber,
              permissions.intValue
                & ConnectorSetupConstants.Configuration.groupAndOtherPermissionMask == 0 else {
            throw ConnectorSetupError.message(
                ConnectorSetupConstants.Text.sshIdentityMissing
            )
        }
    }

    /// Confirms Local Assistant has created its owner-only local spool.
    /// - Throws: A readable error when the app has not been opened yet.
    private func validateLocalAssistantSpool() throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: spoolPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ConnectorSetupError.message(
                ConnectorSetupConstants.Text.localAssistantMissing
            )
        }
    }

    /// Copies the bundled standalone runtime into stable user Application Support.
    /// - Throws: A filesystem error when the packaged runtime is absent or cannot be installed.
    private func installRuntime() throws {
        let source = try Self.bundledRuntimeDirectoryURL()
        let applicationSupport = Self.connectorApplicationSupportURL()
        let target = applicationSupport.appendingPathComponent(
            ConnectorSetupConstants.Identity.runtimeDirectory,
            isDirectory: true
        )
        let temporary = applicationSupport.appendingPathComponent(
            ConnectorSetupConstants.Identity.temporaryRuntimeDirectory,
            isDirectory: true
        )
        let previous = applicationSupport.appendingPathComponent(
            ConnectorSetupConstants.Identity.previousRuntimeDirectory,
            isDirectory: true
        )
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: applicationSupport,
            withIntermediateDirectories: true,
            attributes: [
                .posixPermissions: ConnectorSetupConstants.Configuration.ownerDirectoryPermissions
            ]
        )
        try? fileManager.removeItem(at: temporary)
        try? fileManager.removeItem(at: previous)
        try fileManager.copyItem(at: source, to: temporary)
        if fileManager.fileExists(atPath: target.path) {
            try fileManager.moveItem(at: target, to: previous)
        }
        do {
            try fileManager.moveItem(at: temporary, to: target)
            try? fileManager.removeItem(at: previous)
        } catch {
            try? fileManager.removeItem(at: temporary)
            if fileManager.fileExists(atPath: previous.path) {
                try? fileManager.moveItem(at: previous, to: target)
            }
            throw error
        }
    }

    /// Saves public values and, only when requested, new credentials through standard input.
    /// - Parameter connection: Validated SSH endpoint and pinned host key.
    /// - Throws: A readable error when validation or secure persistence fails.
    private func configureRuntime(
        connection: (host: String, port: Int, hostKey: String)
    ) throws {
        var document: [String: Any] = [
            ConnectorSetupConstants.Configuration.sshHostKey: connection.host,
            ConnectorSetupConstants.Configuration.sshPortKey: connection.port,
            ConnectorSetupConstants.Configuration.sshUserKey:
                ConnectorSetupConstants.Identity.restrictedSSHUser,
            ConnectorSetupConstants.Configuration.sshHostPublicKeyKey: connection.hostKey,
            ConnectorSetupConstants.Configuration.spoolKey: spoolPath
        ]
        let command: String
        if shouldEnterCredentials {
            let normalizedReminderToken = reminderToken.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let normalizedAgentToken = agentToken.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard normalizedReminderToken.isEmpty == false else {
                throw ConnectorSetupError.message(
                    ConnectorSetupConstants.Text.reminderTokenRequired
                )
            }
            guard normalizedAgentToken.isEmpty == false else {
                throw ConnectorSetupError.message(
                    ConnectorSetupConstants.Text.agentTokenRequired
                )
            }
            document[ConnectorSetupConstants.Configuration.reminderTokenKey] =
                normalizedReminderToken
            document[ConnectorSetupConstants.Configuration.agentTokenKey] =
                normalizedAgentToken
            command = ConnectorSetupConstants.Identity.connectorSetupArgument
        } else {
            command = ConnectorSetupConstants.Identity.connectorReconfigureArgument
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: document)
            let input = Pipe()
            let process = Process()
            process.executableURL = Self.runtimeExecutableURL()
            process.arguments = [command]
            process.standardInput = input
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            try input.fileHandleForWriting.write(contentsOf: data)
            try input.fileHandleForWriting.close()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw ConnectorSetupError.message(
                    ConnectorSetupConstants.Text.runtimeSetupFailed
                )
            }
            if command == ConnectorSetupConstants.Identity.connectorSetupArgument {
                reminderToken = ConnectorSetupConstants.Text.empty
                agentToken = ConnectorSetupConstants.Text.empty
            }
        } catch {
            if let setupError = error as? ConnectorSetupError {
                throw setupError
            }
            throw ConnectorSetupError.message(
                ConnectorSetupConstants.Text.runtimeSetupFailed
            )
        }
    }

    /// Installs and bootstraps the per-user LaunchAgent for the packaged runtime.
    /// - Throws: A readable error when launchd rejects the service.
    private func installAndStartLaunchAgent() throws {
        let launchAgents = Self.launchAgentsDirectoryURL()
        let plistURL = Self.launchAgentPlistURL()
        let executable = Self.runtimeExecutableURL()
        let document: [String: Any] = [
            ConnectorSetupConstants.LaunchAgent.labelKey:
                ConnectorSetupConstants.Identity.launchAgentIdentifier,
            ConnectorSetupConstants.LaunchAgent.argumentsKey: [
                executable.path,
                ConnectorSetupConstants.Identity.connectorRunArgument
            ],
            ConnectorSetupConstants.LaunchAgent.runAtLoadKey: false,
            ConnectorSetupConstants.LaunchAgent.watchPathsKey: [
                URL(fileURLWithPath: spoolPath, isDirectory: true)
                    .appendingPathComponent(
                        ConnectorSetupConstants.Identity.requestsDirectory,
                        isDirectory: true
                    ).path
            ],
            ConnectorSetupConstants.LaunchAgent.startCalendarIntervalKey:
                stride(
                    from: ConnectorSetupConstants.LaunchAgent.scheduleFirstHour,
                    to: ConnectorSetupConstants.LaunchAgent.scheduleHourLimit,
                    by: ConnectorSetupConstants.LaunchAgent.scheduleHourInterval
                ).map {
                    [ConnectorSetupConstants.LaunchAgent.hourKey: $0]
                },
            ConnectorSetupConstants.LaunchAgent.processTypeKey:
                ConnectorSetupConstants.LaunchAgent.processTypeValue,
            ConnectorSetupConstants.LaunchAgent.standardOutputKey:
                ConnectorSetupConstants.LaunchAgent.nullDevice,
            ConnectorSetupConstants.LaunchAgent.standardErrorKey:
                ConnectorSetupConstants.LaunchAgent.nullDevice
        ]
        try FileManager.default.createDirectory(
            at: launchAgents,
            withIntermediateDirectories: true
        )
        let data = try PropertyListSerialization.data(
            fromPropertyList: document,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: ConnectorSetupConstants.Configuration.ownerFilePermissions],
            ofItemAtPath: plistURL.path
        )
        let domain = ConnectorSetupConstants.LaunchAgent.domainPrefix + String(getuid())
        _ = Self.runLaunchctl(
            arguments: [
                ConnectorSetupConstants.LaunchAgent.bootout,
                Self.launchAgentServiceTarget()
            ]
        )
        guard Self.runLaunchctl(
            arguments: [ConnectorSetupConstants.LaunchAgent.bootstrap, domain, plistURL.path]
        ) == 0 else {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.launchFailed)
        }
    }

}

/// User-safe setup failure whose text contains no credential or remote response body.
enum ConnectorSetupError: LocalizedError, Sendable {
    case message(String)

    /// Returns the exact user-safe setup failure.
    internal var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}
