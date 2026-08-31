# OpenClaw Connector

OpenClaw Connector is the only part of Local Assistant that can use the network. It is a separate
app with its own packaged runtime.

For each request, it:

1. reads one validated task from the owner-only spool;
2. opens a pinned SSH tunnel to the server's loopback-only Gateway;
3. completes the request; and
4. closes the tunnel and exits.

It has two lanes:

- **Reminder snapshot:** fetches a complete read-only CloudBase list and proves Calendar was not changed.
- **A2A agent:** validates OpenClaw's Agent Card and sends the exact authorized message with A2A v1.0 `SendMessage`.

A2A is the standard protocol for all delegated OpenClaw agent work, including explicit general
requests and confirmed reminder changes. The complete reminder snapshot uses the separate
read-only lane instead.

The Connector cannot read indexed files, result cards, or conversation history. Tokens stay in
macOS Keychain, and the private SSH key stays in Connector Application Support.

Current release components:

- Local Assistant and Connector: **v5.1 (build 51)**
- Connector runtime: **v1.8.0**
- OpenClaw server bridge: **v1.4.0**

## Terms used in setup

- **Connector:** the separate Mac app that is allowed to contact OpenClaw.
- **Spool:** the private folder used to exchange small request and response files with Local Assistant.
- **SSH:** Secure Shell, the encrypted remote-connection tool already included with macOS.
- **SSH tunnel:** a temporary encrypted path to OpenClaw's private server interface.
- **Public key:** the safe half of the Connector identity that is copied to the server.
- **Host key:** the server identity copied back to the Connector so it can reject an impostor.
- **Token:** a secret value that grants one specific type of OpenClaw access.
- **A2A:** Agent-to-Agent, the protocol used for every delegated OpenClaw agent request.
- **Agent Card:** the description the Connector checks before sending an A2A message.

## Normal installed-app setup

Open **Local Assistant → Settings → OpenClaw Connection → Open Setup**. Local Assistant opens
only a Connector with the same version and build.

For an existing installation:

- create and run a fresh server ZIP once for this release;
- choose **Update and Verify Existing Connector**; and
- reuse the saved SSH settings and Keychain credentials.

For a new setup:

1. Enter the server address and SSH port used for administration.
2. Create the public key and server ZIP. Save them together.
3. Transfer both files and run the four commands shown in the Connector.
4. After **SERVER SETUP COMPLETE**, paste the printed host key and two tokens.
5. Choose **Save and Verify Connector**, wait for success, then close the Connector manually.

Finish in Local Assistant:

- enable **OpenClaw connection**;
- choose the reminder refresh schedule; and
- select **Refresh Now** once.

<details>
<summary>Verification, scheduling, and cleanup details</summary>

Verification performs a real complete read-only snapshot and fetches the authenticated A2A v1.0
Agent Card through temporary tunnels. A green confirmation appears above the verification button
only after Calendar-unchanged proof and the exact loopback JSON-RPC interface both pass. The tunnel
closes, but the setup app remains open until the user closes it.

The setup workbench uses full-width location banners to distinguish Mac and server actions. Wide
cards place short instructions beside their fields or actions, while narrow windows return to one
ordered column. Required actions use filled semantic controls; supporting, update, and destructive
actions retain distinct bordered treatments.

The Connector maps common SSH failures to a specific safe cause—host-key mismatch, rejected public
key, unresolved address, refused connection, timeout, or unreachable network—without displaying raw
OpenSSH output. A successful setup followed by a later refresh failure does not mean setup must be
repeated: the last complete cache remains intact and the failed operation can be retried.

The installed per-user `launchd` job is one-shot. A queued app request launches it immediately,
and fixed calendar checks allow a missed interval to run after wake. The Connector reads the
non-secret schedule published by Local Assistant and contacts OpenClaw only when the chosen
interval is due. Its newest scheduled response waits in the spool until Local Assistant validates,
embeds, and transactionally commits it. A failed synchronization never replaces the last complete
cache or RAG index.

**Remove Connector Data…** requires confirmation. It stops and removes the one-shot job, deletes
the exact Connector Application Support directory (including the runtime, SSH identity,
configuration, and checkpoint), deletes the Connector's two exact Keychain entries, and clears
pending spool lanes. It does not delete Local Assistant, indexed files, conversation history, or
the last committed reminder cache and RAG index. Deleting either application bundle by itself does
not delete Keychain entries, which is why cleanup is an explicit in-app action.

</details>

<details>
<summary>Developer: source installation, configuration, and checks</summary>

The following sections are only for a developer who deliberately cloned the repository.

## Advanced source install

Python 3.10 or newer is required. Open Terminal in this `OpenClawConnector` source directory, then
run this block unchanged. Do not edit any file:

```zsh
python3 -m venv .venv
.venv/bin/python -m pip install --require-virtualenv -e .
```

The virtual environment is local build state and must not be committed.

## Advanced source configuration

First create the Connector key from the packaged setup app, or place an owner-only Ed25519 private
key at the path defined by the connector constants. Obtain the full Ed25519 server host-key line
from the server installer.

Local Assistant shows the exact spool path in Settings. Replace the example server address and the
quoted spool placeholder below; adjust port `22` only when the existing SSH service uses another
port. Run the command without editing a source or configuration file:

```zsh
.venv/bin/local-assistant-connector configure \
  --ssh-host openclaw.example.internal \
  --ssh-port 22 \
  --ssh-user local-assistant-tunnel \
  --spool "/absolute/path/shown/by/Local Assistant"

.venv/bin/local-assistant-connector set-ssh-host-key
.venv/bin/local-assistant-connector set-reminder-token
.venv/bin/local-assistant-connector set-agent-token
```

Each token command displays a non-echoing prompt. The first credential can reach only the
read-only reminder snapshot plugin. The second authenticates the private A2A route and its
delegated OpenClaw agent call and carries OpenClaw's normal tool authority. Neither credential is
written to configuration, the spool, a
command line, or the repository.

Run one queue pass with:

```zsh
.venv/bin/local-assistant-connector once
```

Use `status` to read the non-secret health document and `verify` to require one authenticated
complete reminder snapshot. `setup-state` prints reusable public values and credential-presence
booleans only. `forget` deletes the Connector's exact local data and two Keychain entries. The
source CLI deliberately has no persistent run command.

## Local checks

```zsh
.venv/bin/python -m unittest discover -s tests -p 'test_*.py'
```

The v4.8 release passed all 39 Connector tests, standalone Swift type checking, the clean packaged
runtime build, strict project-root, installed, and mounted signature checks, and responsive
installed-screen inspection at normal and full-screen widths. Its disk image contains no saved
server values or credentials; those remain outside the application bundle in Connector Application
Support and macOS Keychain.

</details>
