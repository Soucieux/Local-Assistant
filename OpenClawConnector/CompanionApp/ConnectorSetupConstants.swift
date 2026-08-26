import Foundation

/// Fixed identities, paths, commands, and user-facing Connector copy.
enum ConnectorSetupConstants {
    enum Identity {
        static let appName = "OpenClaw Connector"
        static let bundleIdentifier = "com.soucieux.LocalAssistant.OpenClawConnectorSetup"
        static let launchAgentIdentifier = "com.soucieux.LocalAssistant.OpenClawConnector"
        static let localAssistantBundleIdentifier = "com.soucieux.LocalAssistant"
        static let applicationSupportDirectory = "LocalAssistantConnector"
        static let runtimeDirectory = "Runtime"
        static let temporaryRuntimeDirectory = "Runtime.installing"
        static let previousRuntimeDirectory = "Runtime.previous"
        static let launchAgentsDirectory = "LaunchAgents"
        static let launchAgentFilename = "com.soucieux.LocalAssistant.OpenClawConnector.plist"
        static let embeddedRuntimeDirectory = "ConnectorRuntime"
        static let embeddedServerSetupDirectory = "OpenClaw Server Setup"
        static let serverSetupZIPFilename = "OpenClaw Server Setup.zip"
        static let connectorExecutable = "local-assistant-connector"
        static let connectorRunArgument = "once"
        static let connectorSetupArgument = "setup-stdin"
        static let connectorReconfigureArgument = "reconfigure-stdin"
        static let connectorVerifyArgument = "verify"
        static let connectorSetupStateArgument = "setup-state"
        static let connectorForgetArgument = "forget"
        static let sshDirectory = "ssh"
        static let sshPrivateKeyFilename = "id_ed25519"
        static let sshPublicKeyFilename = "id_ed25519.pub"
        static let exportedPublicKeyFilename = "local-assistant-connector.pub"
        static let restrictedSSHUser = "local-assistant-tunnel"
        static let localAssistantSpoolRelativePath =
            "Data/Library/Application Support/LocalAssistant/Connector"
        static let libraryApplicationSupportPath = "Library/Application Support"
        static let libraryContainersPath = "Library/Containers"
        static let pendingSpoolDirectories = ["Requests", "Processing", "Responses"]
    }

    enum Configuration {
        static let sshHostKey = "sshHost"
        static let sshPortKey = "sshPort"
        static let sshUserKey = "sshUser"
        static let sshHostPublicKeyKey = "sshHostKey"
        static let spoolKey = "spoolDirectory"
        static let reminderTokenKey = "reminderToken"
        static let agentTokenKey = "agentToken"
        static let ownerDirectoryPermissions = 0o700
        static let ownerFilePermissions = 0o600
        static let verificationExitAuthentication: Int32 = 10
        static let verificationExitUnreachable: Int32 = 11
        static let verificationExitSnapshot: Int32 = 12
        static let verificationExitA2A: Int32 = 13
        static let maximumVerificationErrorBytes = 1_024
        static let maximumSetupStateBytes = 4_096
        static let automaticCloseDelayNanoseconds: UInt64 = 1_500_000_000
        static let defaultSSHPort = "22"
        static let minimumSSHPort = 1
        static let maximumSSHPort = 65_535
        static let sshKeygenExecutable = "/usr/bin/ssh-keygen"
        static let archiveExecutable = "/usr/bin/ditto"
        static let sshKeyType = "ed25519"
        static let sshKeyComment = "local-assistant-connector"
        static let publicKeyPrefix = "ssh-ed25519 "
    }

    enum LaunchAgent {
        static let labelKey = "Label"
        static let argumentsKey = "ProgramArguments"
        static let runAtLoadKey = "RunAtLoad"
        static let watchPathsKey = "WatchPaths"
        static let startCalendarIntervalKey = "StartCalendarInterval"
        static let hourKey = "Hour"
        static let processTypeKey = "ProcessType"
        static let processTypeValue = "Background"
        static let standardOutputKey = "StandardOutPath"
        static let standardErrorKey = "StandardErrorPath"
        static let nullDevice = "/dev/null"
        static let executable = "/bin/launchctl"
        static let domainPrefix = "gui/"
        static let bootstrap = "bootstrap"
        static let bootout = "bootout"
    }

    enum Symbol {
        static let privacy = "lock.shield.fill"
        static let server = "server.rack"
        static let files = "shippingbox.fill"
        static let terminal = "terminal.fill"
        static let credentials = "key.fill"
        static let verification = "checkmark.shield.fill"
        static let success = "checkmark.circle.fill"
        static let failure = "exclamationmark.triangle.fill"
        static let saved = "key.viewfinder"
        static let settings = "slider.horizontal.3"
        static let remove = "trash.fill"
        static let question = "questionmark.circle.fill"
        static let loading = "arrow.triangle.2.circlepath"
        static let back = "chevron.left"
    }

    enum Text {
        static let empty = ""
        static let title = "Connect to OpenClaw"
        static let subtitle = "Connect Local Assistant to your existing OpenClaw server."
        static let privacyNote =
            "No VPN or public OpenClaw port is needed. The Connector opens SSH only when work is requested."
        static let loadingTitle = "Checking this Mac"
        static let loadingBody = "Looking for an existing Connector setup…"
        static let serverBadge = "ON THIS MAC"
        static let remoteBadge = "ON THE OPENCLAW SERVER"

        static let existingTitle = "Existing Connector found"
        static let existingBody =
            "Your saved connection can be reused. This release needs one server update for A2A."
        static let serverSettingsReady = "Server settings ready"
        static let sshIdentityReady = "Connector SSH key ready"
        static let credentialsReady = "Credentials saved in Keychain"
        static let updateExisting = "Update and Verify Existing Connector"
        static let updateWorking = "Updating and verifying…"
        static let updateReady =
            "Connector updated and verified. This window will close automatically."
        static let reviewSettings = "Review Connection / Update Server"
        static let returnToExisting = "Back to Existing Connector"
        static let replaceCredentials = "Replace Saved Credentials"
        static let removeConnector = "Remove Connector Data…"
        static let removeTitle = "Remove all Connector data?"
        static let removeMessage =
            "This removes the Connector runtime, SSH key, settings, pending requests, and its two Keychain entries. Local Assistant and its reminder cache stay on this Mac."
        static let removeConfirm = "Remove Connector Data"
        static let removeCancel = "Cancel"
        static let removeWorking = "Removing Connector data…"
        static let removeComplete = "Connector data removed. You can start a new setup."
        static let repairTitle = "Finish the existing setup"
        static let repairBody =
            "Some Connector data was found. Complete the missing steps below."

        static let connectionTitle = "Enter the server address"
        static let connectionBullets = [
            "Enter the address used to open the OpenClaw server.",
            "Enter its SSH port. The usual port is 22."
        ]
        static let sshHostLabel = "OpenClaw server address"
        static let sshHostPlaceholder = "Public IP address or DNS name"
        static let sshPortLabel = "SSH port"
        static let addressHelpTitle = "Where do I find these values?"
        static let addressHelp = [
            "Use the same address and port that already open the server from your Mac.",
            "Enter the address only. Do not include a username, ssh://, or a web address.",
            "The Connector later uses its own restricted account automatically."
        ]

        static let filesTitle = "Create the setup files"
        static let filesBullets = [
            "Save the Connector public key.",
            "Create a fresh server setup ZIP for this release.",
            "Keep both files in the same folder."
        ]
        static let createPublicKey = "Create Key and Save Public Key…"
        static let publicKeyReady = "Public key saved"
        static let existingPublicKeyReady = "Connector key already exists on this Mac"
        static let publicKeySaveTitle = "Save Connector Public Key"
        static let publicKeySaveMessage = "Choose a folder for the two server files."
        static let publicKeySavePrompt = "Save Public Key"
        static let keyGenerationFailed = "The Connector key could not be created."
        static let keyPairIncomplete =
            "The Connector key is incomplete. Remove Connector data, then start again."
        static let createServerSetupZIP = "Create Server Setup ZIP…"
        static let serverSetupReady = "Server setup ZIP created"
        static let serverSetupSaveTitle = "Create OpenClaw Server Setup ZIP"
        static let serverSetupSaveMessage = "Save the ZIP beside the public key."
        static let serverSetupSavePrompt = "Create ZIP"
        static let serverSetupMissing =
            "The server setup files are missing from this Connector app."
        static let serverSetupFailed = "The server setup ZIP could not be created."
        static let filesHelpTitle = "What leaves this Mac?"
        static let filesHelp = [
            "The public key and setup ZIP are safe to transfer to your server.",
            "The private key remains in this Mac user's private Library folder.",
            "The ZIP contains packaged setup files, not this app's source code."
        ]

        static let transferTitle = "Run setup on the server"
        static let transferBullets = [
            "Place both files in the OpenClaw owner's home folder.",
            "Run the four commands below in the server terminal.",
            "Continue when SERVER SETUP COMPLETE appears. This also enables private A2A."
        ]
        static let serverCommands =
            "cd \"$HOME\"\nunzip -o \"OpenClaw Server Setup.zip\"\ncd \"OpenClaw Server Setup\"\n./setup-server.sh \"$HOME/local-assistant-connector.pub\""
        static let copyServerCommands = "Copy Server Commands"
        static let transferHelpTitle = "Need to transfer the files with Mac Terminal?"
        static let transferHelp = [
            "Run the command below on this Mac from the folder containing both files.",
            "Replace only SERVER_USER. Use the Linux account that owns OpenClaw."
        ]
        static let transferCommandTemplate =
            "scp -P SSH_PORT \"OpenClaw Server Setup.zip\" \"local-assistant-connector.pub\" SERVER_USER@SERVER_ADDRESS:~/"
        static let copyTransferCommand = "Copy File Transfer Command"
        static let serverSetupQuestion = "The server setup stops before completion."
        static let serverSetupAnswers = [
            "Confirm the OpenClaw Gateway is running, then run the same four commands again.",
            "If the Gateway was still starting, wait a moment before retrying.",
            "Create a new ZIP from this Connector if the files came from an older release."
        ]

        static let resultsTitle = "Add the server values"
        static let resultsBullets = [
            "Copy the host key printed by the completed setup.",
            "Copy the reminder bridge token.",
            "Copy the OpenClaw A2A / operator token."
        ]
        static let sshHostKeyLabel = "Server SSH host key"
        static let sshHostKeyPlaceholder = "ssh-ed25519 AAAA…"
        static let restrictedUserLabel = "Connector account"
        static let restrictedUserSummary = "Used automatically. It cannot open a shell."
        static let reminderTokenLabel = "Reminder bridge token"
        static let agentTokenLabel = "OpenClaw A2A / operator token"
        static let savedCredential = "Saved in macOS Keychain"
        static let credentialHelpTitle = "Where do these values come from?"
        static let credentialHelp = [
            "The server setup prints all three values after SERVER SETUP COMPLETE.",
            "Paste each value into its matching field. Do not run a token as a command.",
            "Tokens are saved in macOS Keychain and cleared from this window."
        ]
        static let restrictedAccountQuestion = "What is the Connector account?"
        static let restrictedAccountAnswers = [
            "The server setup creates local-assistant-tunnel automatically.",
            "It can forward only to OpenClaw on the same server.",
            "It cannot open a shell, PTY, agent forward, X11 session, or remote forward."
        ]

        static let localTitle = "Verify the connection"
        static let localBullets = [
            "Select Save and Verify Connector.",
            "Wait while the reminder route and A2A Agent Card are checked.",
            "Return to Local Assistant and enable OpenClaw."
        ]
        static let saveAndStart = "Save and Verify Connector"
        static let working = "Saving and verifying…"
        static let ready =
            "Connection verified. Setup is complete and this window will close automatically."
        static let troubleshootingTitle = "If verification does not pass"
        static let tunnelQuestion = "The Connector cannot open the SSH tunnel."
        static let tunnelAnswers = [
            "Confirm the address and port work from this Mac.",
            "Confirm server setup completed with the public key created on this Mac.",
            "Copy the current host key from the completed server setup."
        ]
        static let authenticationQuestion = "OpenClaw rejects a saved token."
        static let authenticationAnswers = [
            "Run the server setup again to print current values.",
            "Select Replace Saved Credentials and paste both new tokens."
        ]
        static let laterRefreshQuestion = "Verification passes, but a later refresh fails."
        static let laterRefreshAnswers = [
            "Do not repeat server setup for one later synchronization failure.",
            "Local Assistant keeps the last complete reminder cache.",
            "Retry Refresh Now after the server and network are available."
        ]
        static let a2aQuestion = "The Connector says the A2A Agent Card is missing."
        static let a2aAnswers = [
            "Create a new server setup ZIP from this Connector release.",
            "Transfer it to the server and run the four setup commands again.",
            "Return here and select Save and Verify Connector."
        ]
        static let advancedTitle = "Advanced details"
        static let advancedDetails = [
            "The Connector uses a one-shot SSH tunnel to server loopback port 23116.",
            "The tunnel closes after each request.",
            "Scheduled requests use the saved Keychain tokens without displaying them."
        ]

        static let sshHostRequired = "Enter the server address."
        static let sshHostInvalid = "Enter only a DNS name or IP address."
        static let sshPortInvalid = "Enter a port from 1 through 65535."
        static let sshHostKeyInvalid = "Paste the complete ssh-ed25519 host key."
        static let sshIdentityMissing = "Create the Connector public key first."
        static let reminderTokenRequired = "Enter the reminder bridge token."
        static let agentTokenRequired = "Enter the OpenClaw operator token."
        static let localAssistantMissing =
            "Open Local Assistant once, then return here and try again."
        static let runtimeMissing = "The Connector runtime is missing from this app."
        static let setupStateFailed =
            "The existing Connector setup could not be checked. You can review the setup below."
        static let setupFailedPrefix = "Setup could not finish: "
        static let launchFailed = "macOS could not start the Connector job."
        static let runtimeSetupFailed = "The Connector could not save the setup."
        static let removalFailed = "Connector data could not be removed."
        static let verificationAuthenticationFailed =
            "OpenClaw rejected a token. Replace both saved credentials and try again."
        static let verificationUnreachable =
            "The SSH tunnel could not open. Check the server address, port, public key, and host key."
        static let sshHostKeyMismatch =
            "The server host key changed. Copy the current host key from server setup."
        static let sshPublicKeyRejected =
            "The server rejected this Connector key. Recreate both setup files and rerun server setup."
        static let sshHostUnresolved =
            "The server address was not found. Use the address that works from this Mac."
        static let sshConnectionRefused =
            "The server refused SSH. Check that SSH is running and the port is correct."
        static let sshConnectionTimeout =
            "The server did not answer in time. Check the address, port, and firewall."
        static let sshNetworkUnreachable =
            "This Mac cannot reach the server. Check the network, address, and firewall."
        static let verificationSnapshotFailed =
            "OpenClaw did not return a complete reminder list. The previous cache was not changed."
        static let verificationA2AFailed =
            "OpenClaw does not have this release's A2A bridge. Create and run a fresh server setup ZIP, then verify again."
        static let verificationFailed =
            "The Connector could not complete verification. Open the matching help question below."
    }
}

/// Visual meaning of the Connector setup message.
enum ConnectorSetupStatusTone {
    case neutral
    case success
    case failure
}
