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
        return ConnectorSetupConstants.Text.transferCommandTemplate
            .replacingOccurrences(
                of: "SERVER_ADDRESS",
                with: host.isEmpty ? "SERVER_ADDRESS" : host
            )
            .replacingOccurrences(of: "SSH_PORT", with: port.isEmpty ? "SSH_PORT" : port)
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
            await closeAfterSuccess()
        } catch {
            showFailure(error)
            isBusy = false
        }
    }

    /// Validates, saves, starts, and verifies the connector without arguments containing secrets.
    internal func saveAndStart() {
        guard isBusy == false else { return }
        clearStatus()
        isBusy = true
        Task { [weak self] in
            await self?.performSetupAndVerification()
        }
    }

    /// Completes the local installation and closes only after a real snapshot succeeds.
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
            await closeAfterSuccess()
        } catch {
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
        isBusy = false
    }

    /// Removes the launch configuration and only pending Connector spool lanes.
    private func removeLaunchAgentAndPendingSpool() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: Self.launchAgentPlistURL())
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
    }

    /// Shows one user-safe failure without remote content or credentials.
    private func showFailure(_ error: Error) {
        statusMessage = ConnectorSetupConstants.Text.setupFailedPrefix
            + error.localizedDescription
        statusTone = .failure
    }

    /// Waits briefly so the successful confirmation is visible before closing.
    private func closeAfterSuccess() async {
        try? await Task.sleep(
            nanoseconds: ConnectorSetupConstants.Configuration.automaticCloseDelayNanoseconds
        )
        NSApplication.shared.terminate(nil)
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
        let decodedHostKey = fields.count == 2
            ? Data(base64Encoded: String(fields[1]))
            : nil
        guard fields.count == 2,
              String(fields[0]) == ConnectorSetupConstants.Configuration.publicKeyPrefix
                .trimmingCharacters(in: .whitespaces),
              let decodedHostKey,
              decodedHostKey.count >= 32 else {
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
              permissions.intValue & 0o077 == 0 else {
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
                    .appendingPathComponent("Requests", isDirectory: true).path
            ],
            ConnectorSetupConstants.LaunchAgent.startCalendarIntervalKey:
                stride(from: 0, to: 24, by: 2).map {
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
            arguments: [ConnectorSetupConstants.LaunchAgent.bootout, domain, plistURL.path]
        )
        guard Self.runLaunchctl(
            arguments: [ConnectorSetupConstants.LaunchAgent.bootstrap, domain, plistURL.path]
        ) == 0 else {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.launchFailed)
        }
    }

    /// Runs the packaged read-only verification command without exposing credentials.
    /// - Throws: A user-safe error matched to the failed connection stage.
    nonisolated private static func verifyRuntimeConnection() throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = runtimeExecutableURL()
        process.arguments = [ConnectorSetupConstants.Identity.connectorVerifyArgument]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ConnectorSetupError.message(
                ConnectorSetupConstants.Text.verificationFailed
            )
        }
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        switch process.terminationStatus {
        case 0:
            return
        case ConnectorSetupConstants.Configuration.verificationExitAuthentication:
            throw ConnectorSetupError.message(
                ConnectorSetupConstants.Text.verificationAuthenticationFailed
            )
        case ConnectorSetupConstants.Configuration.verificationExitUnreachable:
            throw ConnectorSetupError.message(
                verificationSSHMessage(from: errorData)
            )
        case ConnectorSetupConstants.Configuration.verificationExitSnapshot:
            throw ConnectorSetupError.message(
                ConnectorSetupConstants.Text.verificationSnapshotFailed
            )
        default:
            throw ConnectorSetupError.message(
                ConnectorSetupConstants.Text.verificationFailed
            )
        }
    }

    /// Accepts only known credential-free runtime errors and discards all other output.
    nonisolated private static func verificationSSHMessage(from data: Data) -> String {
        guard data.count <= ConnectorSetupConstants.Configuration.maximumVerificationErrorBytes,
              let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return ConnectorSetupConstants.Text.verificationUnreachable
        }
        let messages: [String: String] = [
            "the pinned SSH host key does not match the server":
                ConnectorSetupConstants.Text.sshHostKeyMismatch,
            "the server rejected the Connector public key":
                ConnectorSetupConstants.Text.sshPublicKeyRejected,
            "the SSH server address could not be resolved":
                ConnectorSetupConstants.Text.sshHostUnresolved,
            "the SSH server refused the connection":
                ConnectorSetupConstants.Text.sshConnectionRefused,
            "the SSH server connection timed out":
                ConnectorSetupConstants.Text.sshConnectionTimeout,
            "the SSH server is unreachable from this Mac":
                ConnectorSetupConstants.Text.sshNetworkUnreachable,
            "the restricted SSH tunnel could not reach OpenClaw":
                ConnectorSetupConstants.Text.verificationUnreachable
        ]
        return messages[raw] ?? ConnectorSetupConstants.Text.verificationUnreachable
    }

    /// Reads credential-free setup JSON from the runtime embedded in this app.
    /// - Returns: Existing local setup facts without Keychain values.
    /// - Throws: A safe error if the runtime or bounded JSON response is invalid.
    nonisolated private static func readExistingSetupState() throws -> ExistingConnectorState {
        let process = Process()
        let output = Pipe()
        process.executableURL = try bundledRuntimeExecutableURL()
        process.arguments = [ConnectorSetupConstants.Identity.connectorSetupStateArgument]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0,
              data.count <= ConnectorSetupConstants.Configuration.maximumSetupStateBytes else {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.setupStateFailed)
        }
        do {
            return try JSONDecoder().decode(ExistingConnectorState.self, from: data)
        } catch {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.setupStateFailed)
        }
    }

    /// Invokes exact Connector cleanup from the runtime embedded in this app.
    /// - Throws: A safe error when cleanup cannot complete.
    nonisolated private static func forgetRuntimeData() throws {
        let process = Process()
        process.executableURL = try bundledRuntimeExecutableURL()
        process.arguments = [ConnectorSetupConstants.Identity.connectorForgetArgument]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.removalFailed)
        }
    }

    /// Stops an existing connector service before replacing its runtime or credentials.
    private func stopExistingLaunchAgent() {
        let domain = ConnectorSetupConstants.LaunchAgent.domainPrefix + String(getuid())
        _ = Self.runLaunchctl(
            arguments: [
                ConnectorSetupConstants.LaunchAgent.bootout,
                domain,
                Self.launchAgentPlistURL().path
            ]
        )
    }

    /// Runs one bounded launchctl operation without a shell.
    /// - Parameter arguments: Exact launchctl arguments.
    /// - Returns: Process termination status.
    private static func runLaunchctl(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: ConnectorSetupConstants.LaunchAgent.executable
        )
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    /// Returns the Connector runtime directory embedded in this app.
    /// - Returns: Bundled runtime directory URL.
    /// - Throws: A safe error when release resources are incomplete.
    nonisolated private static func bundledRuntimeDirectoryURL() throws -> URL {
        guard let source = Bundle.main.resourceURL?.appendingPathComponent(
            ConnectorSetupConstants.Identity.embeddedRuntimeDirectory,
            isDirectory: true
        ), FileManager.default.fileExists(atPath: source.path) else {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.runtimeMissing)
        }
        return source
    }

    /// Returns the Connector executable embedded in this app.
    /// - Returns: Bundled executable used for discovery and cleanup.
    /// - Throws: A safe error when release resources are incomplete.
    nonisolated private static func bundledRuntimeExecutableURL() throws -> URL {
        let executable = try bundledRuntimeDirectoryURL().appendingPathComponent(
            ConnectorSetupConstants.Identity.connectorExecutable,
            isDirectory: false
        )
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ConnectorSetupError.message(ConnectorSetupConstants.Text.runtimeMissing)
        }
        return executable
    }

    /// Returns the connector's stable user Application Support directory.
    /// - Returns: Owner-local connector directory.
    nonisolated private static func connectorApplicationSupportURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                ConnectorSetupConstants.Identity.libraryApplicationSupportPath,
                isDirectory: true
            )
            .appendingPathComponent(
                ConnectorSetupConstants.Identity.applicationSupportDirectory,
                isDirectory: true
            )
    }

    /// Returns the stable installed connector runtime executable.
    /// - Returns: Executable URL used by setup and launchd.
    nonisolated private static func runtimeExecutableURL() -> URL {
        connectorApplicationSupportURL()
            .appendingPathComponent(
                ConnectorSetupConstants.Identity.runtimeDirectory,
                isDirectory: true
            )
            .appendingPathComponent(
                ConnectorSetupConstants.Identity.connectorExecutable,
                isDirectory: false
            )
    }

    /// Returns the private directory holding the dedicated forwarding identity.
    /// - Returns: Owner-local SSH directory.
    private static func sshDirectoryURL() -> URL {
        connectorApplicationSupportURL().appendingPathComponent(
            ConnectorSetupConstants.Identity.sshDirectory,
            isDirectory: true
        )
    }

    /// Returns the dedicated private-key path.
    /// - Returns: Owner-only Ed25519 private key URL.
    private static func sshPrivateKeyURL() -> URL {
        sshDirectoryURL().appendingPathComponent(
            ConnectorSetupConstants.Identity.sshPrivateKeyFilename,
            isDirectory: false
        )
    }

    /// Returns the shareable public-key path.
    /// - Returns: Ed25519 public key URL.
    private static func sshPublicKeyURL() -> URL {
        sshDirectoryURL().appendingPathComponent(
            ConnectorSetupConstants.Identity.sshPublicKeyFilename,
            isDirectory: false
        )
    }

    /// Returns the current user's LaunchAgents directory.
    /// - Returns: Stable per-user launchd configuration directory.
    private static func launchAgentsDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            ConnectorSetupConstants.Identity.launchAgentsDirectory,
            isDirectory: true
        )
    }

    /// Returns the connector's per-user LaunchAgent property-list path.
    /// - Returns: Stable launchd configuration URL.
    private static func launchAgentPlistURL() -> URL {
        launchAgentsDirectoryURL().appendingPathComponent(
            ConnectorSetupConstants.Identity.launchAgentFilename,
            isDirectory: false
        )
    }

    /// Returns the installed Local Assistant sandbox spool location.
    /// - Returns: Absolute expected spool directory.
    private static func localAssistantSpoolURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                ConnectorSetupConstants.Identity.libraryContainersPath,
                isDirectory: true
            )
            .appendingPathComponent(
                ConnectorSetupConstants.Identity.localAssistantBundleIdentifier,
                isDirectory: true
            )
            .appendingPathComponent(
                ConnectorSetupConstants.Identity.localAssistantSpoolRelativePath,
                isDirectory: true
            )
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
