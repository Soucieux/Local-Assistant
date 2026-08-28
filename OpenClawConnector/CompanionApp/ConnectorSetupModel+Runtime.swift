import Foundation

/// Packaged-runtime, launchd, and private-directory operations for Connector setup.
extension ConnectorSetupModel {
    /// Runs the packaged read-only verification command without exposing credentials.
    /// - Throws: A user-safe error matched to the failed connection stage.
    nonisolated internal static func verifyRuntimeConnection() throws {
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
        case ConnectorSetupConstants.Configuration.verificationExitA2A:
            throw ConnectorSetupError.message(
                ConnectorSetupConstants.Text.verificationA2AFailed
            )
        default:
            throw ConnectorSetupError.message(
                ConnectorSetupConstants.Text.verificationFailed
            )
        }
    }

    /// Accepts only known credential-free runtime errors and discards all other output.
    nonisolated internal static func verificationSSHMessage(from data: Data) -> String {
        guard data.count <= ConnectorSetupConstants.Configuration.maximumVerificationErrorBytes,
              let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return ConnectorSetupConstants.Text.verificationUnreachable
        }
        let messages: [String: String] = [
            ConnectorSetupConstants.RuntimeError.sshHostKeyMismatch:
                ConnectorSetupConstants.Text.sshHostKeyMismatch,
            ConnectorSetupConstants.RuntimeError.sshPublicKeyRejected:
                ConnectorSetupConstants.Text.sshPublicKeyRejected,
            ConnectorSetupConstants.RuntimeError.sshHostUnresolved:
                ConnectorSetupConstants.Text.sshHostUnresolved,
            ConnectorSetupConstants.RuntimeError.sshConnectionRefused:
                ConnectorSetupConstants.Text.sshConnectionRefused,
            ConnectorSetupConstants.RuntimeError.sshConnectionTimeout:
                ConnectorSetupConstants.Text.sshConnectionTimeout,
            ConnectorSetupConstants.RuntimeError.sshNetworkUnreachable:
                ConnectorSetupConstants.Text.sshNetworkUnreachable,
            ConnectorSetupConstants.RuntimeError.tunnelUnreachable:
                ConnectorSetupConstants.Text.verificationUnreachable
        ]
        return messages[raw] ?? ConnectorSetupConstants.Text.verificationUnreachable
    }

    /// Reads credential-free setup JSON from the runtime embedded in this app.
    /// - Returns: Existing local setup facts without Keychain values.
    /// - Throws: A safe error if the runtime or bounded JSON response is invalid.
    nonisolated internal static func readExistingSetupState() throws -> ExistingConnectorState {
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
    nonisolated internal static func forgetRuntimeData() throws {
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
    internal func stopExistingLaunchAgent() {
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
    internal static func runLaunchctl(arguments: [String]) -> Int32 {
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
    nonisolated internal static func bundledRuntimeDirectoryURL() throws -> URL {
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
    nonisolated internal static func bundledRuntimeExecutableURL() throws -> URL {
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
    nonisolated internal static func connectorApplicationSupportURL() -> URL {
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
    nonisolated internal static func runtimeExecutableURL() -> URL {
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
    internal static func sshDirectoryURL() -> URL {
        connectorApplicationSupportURL().appendingPathComponent(
            ConnectorSetupConstants.Identity.sshDirectory,
            isDirectory: true
        )
    }

    /// Returns the dedicated private-key path.
    /// - Returns: Owner-only Ed25519 private key URL.
    internal static func sshPrivateKeyURL() -> URL {
        sshDirectoryURL().appendingPathComponent(
            ConnectorSetupConstants.Identity.sshPrivateKeyFilename,
            isDirectory: false
        )
    }

    /// Returns the shareable public-key path.
    /// - Returns: Ed25519 public key URL.
    internal static func sshPublicKeyURL() -> URL {
        sshDirectoryURL().appendingPathComponent(
            ConnectorSetupConstants.Identity.sshPublicKeyFilename,
            isDirectory: false
        )
    }

    /// Returns the current user's LaunchAgents directory.
    /// - Returns: Stable per-user launchd configuration directory.
    internal static func launchAgentsDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            ConnectorSetupConstants.Identity.launchAgentsDirectory,
            isDirectory: true
        )
    }

    /// Returns the connector's per-user LaunchAgent property-list path.
    /// - Returns: Stable launchd configuration URL.
    internal static func launchAgentPlistURL() -> URL {
        launchAgentsDirectoryURL().appendingPathComponent(
            ConnectorSetupConstants.Identity.launchAgentFilename,
            isDirectory: false
        )
    }

    /// Returns the installed Local Assistant sandbox spool location.
    /// - Returns: Absolute expected spool directory.
    internal static func localAssistantSpoolURL() -> URL {
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
