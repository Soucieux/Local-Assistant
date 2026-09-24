import Foundation

/// Fixed identities, paths, commands, and user-facing Connector copy.
internal enum ConnectorSetupConstants {
    internal enum Identity {
        internal static let appName = "OpenClaw Connector"
        internal static let bundleIdentifier = "com.soucieux.LocalAssistant.OpenClawConnectorSetup"
        internal static let launchAgentIdentifier = "com.soucieux.LocalAssistant.OpenClawConnector"
        internal static let localAssistantBundleIdentifier = "com.soucieux.LocalAssistant"
        internal static let applicationSupportDirectory = "LocalAssistantConnector"
        internal static let runtimeDirectory = "Runtime"
        internal static let temporaryRuntimeDirectory = "Runtime.installing"
        internal static let previousRuntimeDirectory = "Runtime.previous"
        internal static let launchAgentsDirectory = "Library/LaunchAgents"
        internal static let legacyLaunchAgentsDirectory = "LaunchAgents"
        internal static let launchAgentFilename = "com.soucieux.LocalAssistant.OpenClawConnector.plist"
        internal static let embeddedRuntimeDirectory = "ConnectorRuntime"
        internal static let embeddedServerSetupDirectory = "OpenClaw Server Setup"
        internal static let serverSetupZIPFilename = "OpenClaw Server Setup.zip"
        internal static let connectorExecutable = "local-assistant-connector"
        internal static let connectorRunArgument = "once"
        internal static let connectorSetupArgument = "setup-stdin"
        internal static let connectorReconfigureArgument = "reconfigure-stdin"
        internal static let connectorVerifyArgument = "verify"
        internal static let connectorSetupStateArgument = "setup-state"
        internal static let connectorForgetArgument = "forget"
        internal static let sshDirectory = "ssh"
        internal static let sshPrivateKeyFilename = "id_ed25519"
        internal static let sshPublicKeyFilename = "id_ed25519.pub"
        internal static let exportedPublicKeyFilename = "local-assistant-connector.pub"
        internal static let restrictedSSHUser = "local-assistant-tunnel"
        internal static let localAssistantSpoolRelativePath =
            "Data/Library/Application Support/LocalAssistant/Connector"
        internal static let libraryApplicationSupportPath = "Library/Application Support"
        internal static let libraryContainersPath = "Library/Containers"
        internal static let requestsDirectory = "Requests"
        internal static let processingDirectory = "Processing"
        internal static let responsesDirectory = "Responses"
        internal static let pendingSpoolDirectories = [
            requestsDirectory,
            processingDirectory,
            responsesDirectory
        ]
    }

    /// Exact `ERROR_*` values the connector runtime writes to standard error.
    /// Source of truth: `src/local_assistant_connector/constants.py`.
    internal enum RuntimeError {
        internal static let sshHostKeyMismatch = "the pinned SSH host key does not match the server"
        internal static let sshPublicKeyRejected = "the server rejected the Connector public key"
        internal static let sshHostUnresolved = "the SSH server address could not be resolved"
        internal static let sshConnectionRefused = "the SSH server refused the connection"
        internal static let sshConnectionTimeout = "the SSH server connection timed out"
        internal static let sshNetworkUnreachable = "the SSH server is unreachable from this Mac"
        internal static let tunnelUnreachable = "the restricted SSH tunnel could not reach OpenClaw"
    }

    internal enum Configuration {
        internal static let sshHostKey = "sshHost"
        internal static let sshPortKey = "sshPort"
        internal static let sshUserKey = "sshUser"
        internal static let sshHostPublicKeyKey = "sshHostKey"
        internal static let spoolKey = "spoolDirectory"
        internal static let reminderTokenKey = "reminderToken"
        internal static let agentTokenKey = "agentToken"
        internal static let ownerDirectoryPermissions = 0o700
        internal static let ownerFilePermissions = 0o600
        internal static let verificationExitAuthentication: Int32 = 10
        internal static let verificationExitUnreachable: Int32 = 11
        internal static let verificationExitSnapshot: Int32 = 12
        internal static let verificationExitA2A: Int32 = 13
        internal static let maximumVerificationErrorBytes = 1_024
        internal static let maximumSetupStateBytes = 4_096
        internal static let defaultSSHPort = "22"
        internal static let minimumSSHPort = 1
        internal static let maximumSSHPort = 65_535
        internal static let sshHostAllowedCharacters =
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._:-"
        internal static let sshOptionPrefix = "-"
        internal static let sshKeygenExecutable = "/usr/bin/ssh-keygen"
        internal static let archiveExecutable = "/usr/bin/ditto"
        internal static let sshKeyType = "ed25519"
        internal static let sshKeyComment = "local-assistant-connector"
        internal static let publicKeyPrefix = "ssh-ed25519 "
        internal static let sshHostKeyFieldCount = 2
        internal static let sshHostKeyMinimumBytes = 32
        internal static let groupAndOtherPermissionMask = 0o077
    }

    internal enum LaunchAgent {
        internal static let labelKey = "Label"
        internal static let argumentsKey = "ProgramArguments"
        internal static let runAtLoadKey = "RunAtLoad"
        internal static let watchPathsKey = "WatchPaths"
        internal static let startCalendarIntervalKey = "StartCalendarInterval"
        internal static let hourKey = "Hour"
        internal static let processTypeKey = "ProcessType"
        internal static let processTypeValue = "Background"
        internal static let standardOutputKey = "StandardOutPath"
        internal static let standardErrorKey = "StandardErrorPath"
        internal static let nullDevice = "/dev/null"
        internal static let executable = "/bin/launchctl"
        internal static let domainPrefix = "gui/"
        internal static let serviceTargetSeparator = "/"
        internal static let bootstrap = "bootstrap"
        internal static let bootout = "bootout"
        internal static let scheduleFirstHour = 0
        internal static let scheduleHourLimit = 24
        internal static let scheduleHourInterval = 2
    }

    internal enum Symbol {
        internal static let privacy = "lock.shield.fill"
        internal static let server = "server.rack"
        internal static let files = "shippingbox.fill"
        internal static let terminal = "terminal.fill"
        internal static let credentials = "key.fill"
        internal static let verification = "checkmark.shield.fill"
        internal static let success = "checkmark.circle.fill"
        internal static let failure = "exclamationmark.triangle.fill"
        internal static let saved = "key.viewfinder"
        internal static let settings = "slider.horizontal.3"
        internal static let remove = "trash.fill"
        internal static let question = "questionmark.circle.fill"
        internal static let loading = "arrow.triangle.2.circlepath"
        internal static let back = "chevron.left"
        internal static let copy = "doc.on.doc"
    }

    internal enum Text {
        internal static let empty = ""
        internal static let title = "Connect to OpenClaw"
        internal static let subtitle = "Connect Local Assistant to your existing OpenClaw server."
        internal static let privacyNote =
            "No VPN or public OpenClaw port is needed. The Connector opens SSH only when work is requested."
        internal static let loadingTitle = "Checking this Mac"
        internal static let loadingBody = "Looking for an existing Connector setup…"
        internal static let serverBadge = "ON THIS MAC"
        internal static let remoteBadge = "ON THE OPENCLAW SERVER"

        internal static let existingTitle = "Existing Connector found"
        internal static let existingBody =
            "Your saved connection can be reused. If the server was set up from an older release, "
            + "create and run a fresh server setup ZIP first."
        internal static let serverSettingsReady = "Server settings ready"
        internal static let sshIdentityReady = "Connector SSH key ready"
        internal static let credentialsReady = "Credentials saved in Keychain"
        internal static let updateExisting = "Update and Verify Existing Connector"
        internal static let updateWorking = "Updating and verifying…"
        internal static let updateReady =
            "Connector updated and verified. You can close this window."
        internal static let reviewSettings = "Review Connection / Update Server"
        internal static let returnToExisting = "Back to Existing Connector"
        internal static let replaceCredentials = "Replace Saved Credentials"
        internal static let removeConnector = "Remove Connector Data…"
        internal static let removeTitle = "Remove all Connector data?"
        internal static let removeMessage =
            "This removes the Connector runtime, SSH key, settings, pending requests, and its two Keychain entries. Local Assistant and its reminder cache stay on this Mac."
        internal static let removeConfirm = "Remove Connector Data"
        internal static let removeCancel = "Cancel"
        internal static let removeWorking = "Removing Connector data…"
        internal static let removeComplete = "Connector data removed. You can start a new setup."
        internal static let repairTitle = "Finish the existing setup"
        internal static let repairBody =
            "Some Connector data was found. Complete the missing steps below."

        internal static let connectionTitle = "Enter the server address"
        internal static let connectionBullets = [
            "Enter the address used to open the OpenClaw server.",
            "Enter its SSH port. The usual port is 22."
        ]
        internal static let sshHostLabel = "OpenClaw server address"
        internal static let sshHostPlaceholder = "Public IP address or DNS name"
        internal static let sshPortLabel = "SSH port"
        internal static let addressHelpTitle = "Where do I find these values?"
        internal static let addressHelp = [
            "Use the same address and port that already open the server from your Mac.",
            "Enter the address only. Do not include a username, ssh://, or a web address.",
            "The Connector later uses its own restricted account automatically."
        ]

        internal static let filesTitle = "Create the setup files"
        internal static let filesBullets = [
            "Save the Connector public key.",
            "Create a fresh server setup ZIP for this release.",
            "Keep both files in the same folder."
        ]
        internal static let createPublicKey = "Create Key and Save Public Key…"
        internal static let publicKeyReady = "Public key saved"
        internal static let existingPublicKeyReady = "Connector key already exists on this Mac"
        internal static let publicKeySaveTitle = "Save Connector Public Key"
        internal static let publicKeySaveMessage = "Choose a folder for the two server files."
        internal static let publicKeySavePrompt = "Save Public Key"
        internal static let keyGenerationFailed = "The Connector key could not be created."
        internal static let keyPairIncomplete =
            "The Connector key is incomplete. Remove Connector data, then start again."
        internal static let createServerSetupZIP = "Create Server Setup ZIP…"
        internal static let serverSetupReady = "Server setup ZIP created"
        internal static let serverSetupSaveTitle = "Create OpenClaw Server Setup ZIP"
        internal static let serverSetupSaveMessage = "Save the ZIP beside the public key."
        internal static let serverSetupSavePrompt = "Create ZIP"
        internal static let serverSetupMissing =
            "The server setup files are missing from this Connector app."
        internal static let serverSetupFailed = "The server setup ZIP could not be created."
        internal static let filesHelpTitle = "What leaves this Mac?"
        internal static let filesHelp = [
            "Transfer both the public key and the setup ZIP to your server.",
            "The public key is a separate file. It is not inside the ZIP.",
            "The private key remains in this Mac user's private Library folder.",
            "The ZIP contains packaged setup files, not this app's source code."
        ]

        internal static let transferTitle = "Run setup on the server"
        internal static let transferBullets = [
            "Place the public key and ZIP in the OpenClaw owner's home folder.",
            "Run the four commands below in the server terminal.",
            "Continue when SERVER SETUP COMPLETE appears.",
            "This also enables private A2A."
        ]
        internal static let serverCommands =
            "cd \"$HOME\"\nunzip -o \"OpenClaw Server Setup.zip\"\ncd \"OpenClaw Server Setup\"\n./setup-server.sh \"$HOME/local-assistant-connector.pub\""
        internal static let copyServerCommands = "Copy Server Commands"
        internal static let transferHelpTitle = "Need to transfer the files with Mac Terminal?"
        internal static let transferHelp = [
            "Run the command below on this Mac from the folder containing both files.",
            "Replace only SERVER_USER. Use the Linux account that owns OpenClaw."
        ]
        internal static let transferCommandTemplate =
            "scp -P SSH_PORT \"OpenClaw Server Setup.zip\" \"local-assistant-connector.pub\" SERVER_USER@SERVER_ADDRESS:~/"
        internal static let transferAddressToken = "SERVER_ADDRESS"
        internal static let transferPortToken = "SSH_PORT"
        internal static let copyTransferCommand = "Copy File Transfer Command"
        internal static let serverSetupQuestion = "The server setup stops before completion."
        internal static let serverSetupAnswers = [
            "Confirm the OpenClaw Gateway is running, then run the same four commands again.",
            "If the Gateway was still starting, wait a moment before retrying.",
            "Create a new ZIP from this Connector if the files came from an older release."
        ]

        internal static let resultsTitle = "Add the server values"
        internal static let resultsBullets = [
            "Copy the host key printed by the completed setup.",
            "Copy the reminder bridge token.",
            "Copy the OpenClaw A2A / operator token."
        ]
        internal static let sshHostKeyLabel = "Server SSH host key"
        internal static let sshHostKeyPlaceholder = "ssh-ed25519 AAAA…"
        internal static let restrictedUserLabel = "Connector account"
        internal static let restrictedUserSummary = "Used automatically. It cannot open a shell."
        internal static let reminderTokenLabel = "Reminder bridge token"
        internal static let agentTokenLabel = "OpenClaw A2A / operator token"
        internal static let savedCredential = "Saved in macOS Keychain"
        internal static let credentialHelpTitle = "Where do these values come from?"
        internal static let credentialHelp = [
            "The server setup prints all three values after SERVER SETUP COMPLETE.",
            "Paste each value into its matching field. Do not run a token as a command.",
            "Tokens are saved in macOS Keychain and cleared from this window."
        ]
        internal static let restrictedAccountQuestion = "What is the Connector account?"
        internal static let restrictedAccountAnswers = [
            "The server setup creates local-assistant-tunnel automatically.",
            "It can forward only to OpenClaw on the same server.",
            "It cannot open a shell, PTY, agent forward, X11 session, or remote forward."
        ]

        internal static let localTitle = "Verify the connection"
        internal static let localBullets = [
            "Select Save and Verify Connector.",
            "Wait while the reminder route and A2A Agent Card are checked.",
            "Return to Local Assistant and enable OpenClaw."
        ]
        internal static let saveAndStart = "Save and Verify Connector"
        internal static let working = "Saving and verifying…"
        internal static let ready =
            "Connector verified and ready. You can close this window."
        internal static let troubleshootingTitle = "If verification does not pass"
        internal static let tunnelQuestion = "The Connector cannot open the SSH tunnel."
        internal static let tunnelAnswers = [
            "Confirm the address and port work from this Mac.",
            "Confirm server setup completed with the public key created on this Mac.",
            "Copy the current host key from the completed server setup."
        ]
        internal static let authenticationQuestion = "OpenClaw rejects a saved token."
        internal static let authenticationAnswers = [
            "Run the server setup again to print current values.",
            "Select Replace Saved Credentials and paste both new tokens."
        ]
        internal static let laterRefreshQuestion = "Verification passes, but a later refresh fails."
        internal static let laterRefreshAnswers = [
            "Do not repeat server setup for one later synchronization failure.",
            "Local Assistant keeps the last complete reminder cache.",
            "Retry Refresh Now after the server and network are available."
        ]
        internal static let a2aQuestion = "The Connector says the A2A Agent Card is missing."
        internal static let a2aAnswers = [
            "Create a new server setup ZIP from this Connector release.",
            "Transfer it to the server and run the four setup commands again.",
            "Return here and select Save and Verify Connector."
        ]
        internal static let advancedTitle = "Advanced details"
        internal static let advancedDetails = [
            "The Connector uses a one-shot SSH tunnel to server loopback port 23116.",
            "The tunnel closes after each request.",
            "Scheduled requests use the saved Keychain tokens without displaying them."
        ]

        internal static let sshHostRequired = "Enter the server address."
        internal static let sshHostInvalid = "Enter only a DNS name or IP address."
        internal static let sshPortInvalid = "Enter a port from 1 through 65535."
        internal static let sshHostKeyInvalid = "Paste the complete ssh-ed25519 host key."
        internal static let sshIdentityMissing = "Create the Connector public key first."
        internal static let reminderTokenRequired = "Enter the reminder bridge token."
        internal static let agentTokenRequired = "Enter the OpenClaw operator token."
        internal static let localAssistantMissing =
            "Open Local Assistant once, then return here and try again."
        internal static let runtimeMissing = "The Connector runtime is missing from this app."
        internal static let setupStateFailed =
            "The existing Connector setup could not be checked. You can review the setup below."
        internal static let setupFailedPrefix = "Setup could not finish: "
        internal static let launchFailed = "macOS could not start the Connector job."
        internal static let runtimeSetupFailed = "The Connector could not save the setup."
        internal static let removalFailed = "Connector data could not be removed."
        internal static let verificationAuthenticationFailed =
            "OpenClaw rejected a token. Replace both saved credentials and try again."
        internal static let verificationUnreachable =
            "The SSH tunnel could not open. Check the server address, port, public key, and host key."
        internal static let sshHostKeyMismatch =
            "The server host key changed. Copy the current host key from server setup."
        internal static let sshPublicKeyRejected =
            "The server rejected this Connector key. Recreate both setup files and rerun server setup."
        internal static let sshHostUnresolved =
            "The server address was not found. Use the address that works from this Mac."
        internal static let sshConnectionRefused =
            "The server refused SSH. Check that SSH is running and the port is correct."
        internal static let sshConnectionTimeout =
            "The server did not answer in time. Check the address, port, and firewall."
        internal static let sshNetworkUnreachable =
            "This Mac cannot reach the server. Check the network, address, and firewall."
        internal static let verificationSnapshotFailed =
            "OpenClaw did not return a complete reminder list. The previous cache was not changed."
        internal static let verificationA2AFailed =
            "OpenClaw does not have this release's A2A bridge. Create and run a fresh server setup ZIP, then verify again."
        internal static let verificationFailed =
            "The Connector could not complete verification. Open the matching help question below."
    }
}

/// Visual meaning of the Connector setup message.
internal enum ConnectorSetupStatusTone {
    case neutral
    case success
    case failure
}
