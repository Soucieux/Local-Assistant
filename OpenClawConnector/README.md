# OpenClaw Connector

This optional networked companion is installed and run separately from `Local Assistant.app`. The
normal release packages its Python runtime and LangGraph dependencies inside
`OpenClaw Connector.app`; an installed-app user does not need Python, Git, a source checkout, a VPN,
or another networking app. The Connector cannot read Local Assistant's authorized files, search
results, or conversation database.

Local Assistant and the Connector exchange schema-validated tasks through an owner-only local file
spool. For each queued task, the Connector starts the Mac's built-in SSH client, opens one
encrypted local-forwarding tunnel to the server's loopback-only OpenClaw Gateway, performs the
request, closes the tunnel, and exits. There is no continuously running tunnel or networking app.

The Connector has two narrow lanes:

- `cloudbase-reminders` accepts only an unconfirmed complete-list snapshot with
  `calendarPolicy: "never"`. It calls the read-only OpenClaw plugin and requires the response to
  assert `calendarChanged: false`.
- `openclaw-agent` requires one typed authorization. An explicit non-reminder OpenClaw request must
  contain standalone `OpenClaw` or `Open Claw`. A clear reminder create, update, complete,
  reschedule, or remove request instead carries Local Assistant's recorded user confirmation and
  does not need to name OpenClaw. It calls OpenClaw's standard agent endpoint and does not attach
  reminder rows, files, indexed text, or conversation history.

Both lanes use the same pinned SSH server identity and separate credentials in macOS Keychain. The
non-secret configuration contains the SSH host, SSH port, fixed restricted username, spool path,
and bounded timeout. The private SSH key remains owner-only in Connector Application Support. It
is never exported, added to the server ZIP, or placed in a command argument.

The v4.6 build 46 application packages unchanged Connector runtime v1.7.0. The runtime publishes a non-secret
contract version in its local status so Local Assistant can stop an incompatible request before it
reaches an older installed runtime. The runtime rejects an agent task
unless its authorization is either an explicit standalone OpenClaw invocation or a confirmed
reminder mutation. In both cases the submitted message remains exact and no hidden context is
added.

The Python package uses Hatchling 1.27.0 as its pinned build backend. This avoids the vulnerable
setuptools build path reported for versions below the unavailable patched release while preserving
editable development installs and the packaged standalone runtime.

## Normal installed-app setup

Open Local Assistant, then choose **Settings → OpenClaw Connection → Open Setup**. Local Assistant
opens only a Connector whose marketing version and build number match exactly. If Applications
contains an older copy, Local Assistant opens the matching copy from the current release image and
explains that the older Applications copy should be replaced.

The Connector first checks for an existing installation. This check returns only the saved server
address, SSH port, public host key, and yes/no credential-presence flags. It never loads either
token into the Swift interface. A complete existing installation therefore opens a short
**Update and Verify Existing Connector** screen: the packaged runtime is replaced, the existing
SSH key, settings, and Keychain tokens are reused, a real snapshot is verified, and the one-shot
job is restarted without requiring any value again.

A first installation, incomplete repair, or explicit settings review uses five action-only steps.
Definitions, security details, transfer alternatives, and recovery remain collapsed under their
owning step:

1. Enter only the server address and SSH port from the existing administrator SSH login. The
   address has no username, scheme, path, or OpenClaw port.
2. Choose **Create Key and Save Public Key…**, then **Create Server Setup ZIP…**. Both actions are
   explicit and user-controlled; nothing is uploaded automatically.
3. Transfer both files to the OpenClaw owner's home folder and run the four commands shown in the
   Connector. The optional SCP template is unnecessary when the files are already on the server.
   The installer keeps OpenClaw on
   `127.0.0.1:23116`, installs the bridge, and creates a non-root `local-assistant-tunnel` account
   restricted to local forwarding to that exact destination. It grants no shell, PTY, X11,
   SSH-agent forwarding, remote forwarding, or alternative destination.
4. Continue only after `SERVER SETUP COMPLETE`, then paste the printed SSH host key, reminder bridge
   token, and operator token into the Connector. The restricted username is filled automatically.
   Existing Keychain tokens remain hidden; **Replace Saved Credentials** reveals two empty fields
   only when replacement is intentional.
5. Choose **Save and Verify Connector**. New tokens travel to the packaged runtime through bounded
   standard input, enter macOS Keychain, and are immediately cleared from the Swift fields before
   remote verification. After verification succeeds and the Connector closes, enable the
   connection in Local Assistant, choose the two-, four-, or eight-hour schedule, and use
   **Refresh Now** once.

Verification performs a real complete read-only snapshot through a temporary tunnel. A green
confirmation appears only after Calendar-unchanged proof passes; the tunnel closes and the setup
app then closes automatically.

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
read-only reminder snapshot plugin. The second reaches OpenClaw's full agent endpoint and carries
OpenClaw's normal tool authority. Neither credential is written to configuration, the spool, a
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
