# Local Assistant

> A private macOS assistant for conversation, evidence-backed file search, and local reminder intelligence, with no network access in the application process.

Local Assistant is designed for one person and one Mac. Open the application normally or press **Control–Option–Space**, then type or speak through its focused light command surface. Voice input can use a click followed by automatic sending after a pause, or hold-to-talk with the Space bar. The main screen presents only the current request, response, and file findings; the complete retained conversation remains available from **History**. It can answer ordinary questions, retain recent conversational context for follow-up requests, ask for clarification when a file request is ambiguous, and search only the folders explicitly authorized through macOS.

Conversation, retrieval, text embeddings, speech recognition, OCR, and data storage all run inside the sandboxed application. Semantic search compares plain-language requests with text extracted from files, including OCR text from images and image-only PDF pages. Authorized roots and descendant folders are also indexed with local context, so a request such as “files for school” can use the matching folder as the scope even when individual files do not contain the word “school.” Search answers stay concise while reusable result modules present item identity, matching evidence, and explicit Open or Reveal actions. The application runtime does not depend on a local server, a cloud service, telemetry, or an updater.

An optional, separately installed OpenClaw connector exchanges schema-validated tasks through an owner-only local file spool. The app keeps complete CloudBase reminder snapshots as hidden local knowledge and answers reminder questions with exact, lexical, semantic, and deadline-aware retrieval. It never shows a reminder-management screen, changes CloudBase itself, or schedules reminder notifications. A typed or spoken request is sent to OpenClaw only when it explicitly contains standalone `OpenClaw` or `Open Claw`; only that submitted text is sent. The app bundle still has no networking entitlement, and the connector's scoped credentials remain in separate macOS Keychain entries.

## Quick start

Choose the path that matches what you need. If Local Assistant is already installed, begin with the first path. The source-build path is for preparing a new installation without giving the finished application network access.

### Use the installed application

1. Open **Local Assistant**.
2. Open **Settings** and choose **Add Folder**.
3. Select only the folder the assistant should read.
4. Follow the folder's progress in Settings, or continue using the assistant while indexing runs in the background.
5. In **Voice input**, choose **Click to speak** or **Hold Space**, then return to the assistant and type or speak a request.
6. Review the centered answer and responsive findings before choosing **Open File**, **Open Folder**, or **Reveal in Finder**.
7. Open **History** to review the complete retained conversation, including the current session.

### OpenClaw connector setup

Local Assistant never opens a network connection. This connection uses two applications and the
Mac's built-in SSH client:

- `Local Assistant.app`, the sandboxed offline application;
- `OpenClaw Connector.app`, the only application component that contacts OpenClaw;
- a dedicated Connector SSH key and restricted server account that can forward only to
  `127.0.0.1:23116`.

`OpenClaw Connector.app` contains the versioned server-only deployment payload. It never writes that payload automatically. In the Connector, the user chooses **Create Server Setup ZIP…**, selects a save location, and receives `OpenClaw Server Setup.zip`. The ZIP is assembled locally, downloads nothing, and contains no credentials or application source.

The installed-app setup assumes the Mac has no Python, Git, source checkout, VPN, connector
configuration, or extra networking application. The OpenClaw host may remain completely CLI-only.
The user needs only the existing server address, SSH port, and administrator SSH access.

Open Local Assistant and choose **Settings → OpenClaw Connection → Open Setup**. Local Assistant
shows three short completion cards: open the matching Connector, enable the connection after it
verifies, and run the first refresh. The Connector owns the five actionable setup steps and keeps
less common recovery instructions in collapsed **Questions and fixes** disclosures.

#### Connector step 1 — Identify the existing SSH server

Record the server DNS name or IP address and SSH port already used for administration. Confirm the
administrator login works before continuing. Port `23116` must remain closed to the public and the
OpenClaw Gateway must not be bound to a public interface.

#### Connector step 2 — Create both server files

Open the exact Connector version selected by Local Assistant. Choose **Create Key and Save Public
Key…** and save `local-assistant-connector.pub`, then choose **Create Server Setup ZIP…** and save
the ZIP beside it. Only the public key is transferred; the owner-only private key stays in the
current Mac user's Connector Application Support directory. The ZIP contains only generic files
embedded in the Connector and is created only after the user chooses a destination.

#### Connector step 3 — Transfer both files and run setup

Transfer both unchanged files to the OpenClaw owner's home folder using the existing trusted SSH,
SFTP, Finder, or SCP method. The optional SCP template is only an alternative file-transfer method;
skip it when the files are already on the server. Run the following on the OpenClaw server as the
account that owns the working installation. The installer asks for administrator approval only
when it creates the restricted SSH account and configuration:

```bash
cd "$HOME"
unzip -o "OpenClaw Server Setup.zip"
cd "OpenClaw Server Setup"
./setup-server.sh "$HOME/local-assistant-connector.pub"
```

The installer keeps the Gateway on `127.0.0.1:23116`, disables OpenClaw's Tailscale mode, installs
the read-only reminder route, waits for that route to become ready, and verifies a complete
snapshot locally. It creates a non-root
`local-assistant-tunnel` account whose authorized key can perform local port forwarding only to
that exact loopback destination. Shell access, PTY, X11, SSH-agent forwarding, remote forwarding,
and every other destination are denied. A failed `sshd` validation restores the previous SSH
configuration. It is safe to rerun after a partial failure.

#### Connector step 4 — Enter the completed server values

Continue only after **SERVER SETUP COMPLETE**. Record the server's complete Ed25519 host-key line,
the reminder bridge token, and the OpenClaw operator token. The installer also prints the host-key
fingerprint for comparison through the already trusted administrator SSH session. The server
address and SSH port remain the values from step 1; the restricted username is always
`local-assistant-tunnel`.

#### Connector step 5 — Save and verify

Local Assistant searches Applications, beside its own app, macOS application registration, and the
root of a mounted release disk image. It launches only a Connector whose marketing version and
build number exactly match Local Assistant. When Applications contains an older copy, the setup
screen tells the user to replace it instead of silently opening it. If no matching copy is found, a
Finder-backed picker accepts only the matching Connector.

Enter the server address and SSH port, paste the complete host-key line and two tokens, then choose
**Save and Verify Connector**. The Connector pins that host key, opens one encrypted tunnel,
performs an authenticated complete read-only reminder snapshot, requires proof that Calendar was
unchanged, and closes the tunnel. On success, a green message appears above the button and the
setup app closes automatically. On failure, it stays open with an actionable message.

#### Finish in Local Assistant — enable and refresh

Return to Settings, enable **OpenClaw connection**, and select the two-, four-, or eight-hour
refresh interval. A per-user `launchd` job runs the Connector briefly when a request is queued and
at scheduled catch-up checks; the Connector opens its tunnel only when a snapshot is due. A missed
calendar interval is handled after the Mac wakes. The same one-shot path runs at Local Assistant
launch when stale, on **Refresh Now**, and after a successful explicit OpenClaw add, update, or
delete request.

Every successful complete snapshot transactionally replaces the local reminder cache and RAG
index. Rows missing from the new snapshot disappear, so remote `updatedAt` values and deletion
tombstones are unnecessary. A failed fetch or local validation leaves the last complete cache and
index untouched and marks reminder knowledge as potentially outdated. Reminder questions always
use that local cache; they never contact OpenClaw.

#### Advanced developer source setup

The commands in `OpenClawConnector/README.md` are for developers who deliberately cloned this repository. They are not part of installed-app setup. That reference labels every command that runs unchanged, every value that must be replaced, and confirms that the connector CLI creates its configuration automatically.

Once enabled, Local Assistant refreshes its hidden reminder snapshot at launch when stale, after a
successful OpenClaw response, on manual request, and through the selected macOS schedule.

Press **Control–Option–Space** (`⌃⌥Space`) while the application is running to bring its window forward and focus the composer. Closing the window keeps the shortcut available; quitting the application disables it.

#### Example requests

| Request | Expected behavior |
|---|---|
| `Hello` | Gives a local conversational answer without file cards. |
| `What is a PDF?` | Answers from the local model without searching files. |
| `Show me PDFs` | Shows only indexed PDF cards without repeating their names or paths in the answer. |
| `Find the automotive consulting PDF` | Applies a PDF constraint and ranks the remaining topic terms. |
| `Which PDF?` | Requests a topic, filename, folder, or date instead of guessing. |
| `Find the latest budget spreadsheet` | Applies a spreadsheet constraint and hybrid relevance ranking. |
| `Find my school files` | Matches an indexed School folder, then promotes files and folders contained inside it. |
| `What reminders are due tomorrow?` | Searches the latest complete local CloudBase snapshot with temporal and semantic ranking. |
| `Create a reminder to renew the permit tomorrow at 09:00` | Stays local and explains that a change request must explicitly include OpenClaw. |
| `OpenClaw, delete the permit reminder` | Sends that exact submitted request to OpenClaw, with no cached reminder rows or file context attached. |
| `OpenClaw, add this to CloudBase only` | Lets OpenClaw apply the explicit CloudBase-only instruction instead of its normal paired reminder behavior. |

---

### Build and install from source

> **Offline boundary:** Downloads occur only during preparation on a trusted connected Mac. The destination Mac remains disconnected, and the installed application never downloads dependencies or models at runtime.

The source repository intentionally excludes `Vendor`, generated application bundles, model files, and offline-kit contents. The preparation workflow recreates these artifacts from pinned manifests before the project is transferred to the offline destination.

#### Step 1 — Check the requirements

| Requirement | Minimum |
|---|---|
| Hardware | Apple Silicon Mac |
| Operating system | macOS 15 or newer |
| Development tools | Xcode and Command Line Tools |
| Connector preparation | Python 3.10 or newer on the connected preparation Mac only |
| Free preparation space | Approximately 10 GB |

#### Step 2 — Prepare the offline package

1. Use a trusted Mac that is allowed to connect to the internet.
2. From the project root, run:

   ```zsh
   ./Scripts/prepare_offline_bundle.sh
   ```

3. Wait for dependency checkout, pinned connector-runtime preparation, native-library compilation, model verification, and Swift package resolution to finish.

**Result:** The script recreates `Vendor` from pinned revisions and creates the transferable package under `outputs/LocalAssistant-OfflineKit`.

If the speech model is downloaded manually, preserve the complete `openai_whisper-small` directory structure, including the `tokenizer.json` and `tokenizer_config.json` files recorded in `Config/ModelManifest.json`. The application has no route to fetch a missing tokenizer.

#### Step 3 — Transfer and disconnect

1. Copy the complete prepared project and offline package to trusted physical media.
2. Transfer them to the destination Mac.
3. Disable Wi-Fi, Ethernet, VPNs, and other network interfaces before continuing.

Keep the destination disconnected throughout application installation, building, and static privacy auditing. The optional connector cannot be exercised until the Mac later has an approved private route to the OpenClaw server; enabling that separate route does not give `Local Assistant.app` network access.

#### Step 4 — Install the verified model assets

From the transferred project root, run:

```zsh
./outputs/LocalAssistant-OfflineKit/install_offline_assets.sh
```

**Result:** Verified local models are installed inside the application sandbox. The installer refuses to overwrite an existing model or checksum manifest; verify or move the existing asset before retrying.

#### Step 5 — Build the Release application

Build only from the prepared local dependencies:

```zsh
./Scripts/build_offline.sh
```

**Result:** The Release application is built under `DerivedData/Build/Products/Release` without automatic package resolution. The project root receives `Local Assistant.app`, the separately packaged `OpenClaw Connector.app`, and `Local Assistant Release.dmg`, which contains both applications. The server deployment payload is embedded only in the Connector, and the user creates `OpenClaw Server Setup.zip` from that app only when needed.

A successful build removes the prior generated application and release artifacts first and deletes the entire `DerivedData` build cache once the new copies are verified, so the project root holds only the latest release set.

#### Step 6 — Audit the offline boundary

Run the static boundary audit against the Release application:

```zsh
./Scripts/audit_offline_boundary.sh "./Local Assistant.app"
```

The audit requires exactly the approved App Sandbox, microphone, application-scoped bookmark, and user-selected read-only entitlements, and rejects every unexpected entitlement. Local Assistant has no user-selected write entitlement because ZIP and public-key export belong to the separate Connector. The audit then inspects the application executable and every bundled executable and fails if any of them links a networking library or imports a network symbol, because a binary that never links networking code cannot open a connection whatever its source might still say. It also inspects packaged resources for network-related implementation text.

The audit reports, rather than rejects, an unreachable service hostname still compiled into the binary. A string literal in unreachable code proves nothing either way; the entitlement set is what the operating system enforces.

> Static inspection is not full runtime verification. Formal verification should also exercise the signed application with every network interface disabled, inspect runtime sockets, and test indexing, chat, OCR, voice, Open, Reveal, and Revoke against controlled fixtures.

#### Optional — run the automated tests

The test target builds and runs entirely from local sources and needs no network access:

```zsh
xcodebuild -project LocalAssistant.xcodeproj \
  -scheme LocalAssistant \
  -configuration Debug \
  -derivedDataPath DerivedData \
  -destination 'platform=macOS' test
```

`-derivedDataPath` keeps the test host beside the offline build. Without it the run writes a
second application bundle into Xcode's own build directory, where it can be launched by
mistake in place of the current one.

Tests run only against the Debug configuration. The Release application built in Step 5 keeps its hardened runtime and sandbox unchanged and does not include the test bundle.

#### Step 7 — Launch and authorize a folder

1. Open the Release application.
2. In **Settings**, choose **Add Folder** and select only the folder the assistant should read.
3. Return to the assistant after indexing finishes.

Revoking a folder removes its bookmark and dependent private index records without changing the source folder. Saved result cards remain in history but become unavailable when their source authorization no longer exists. Indexing activity remains available for its normal 30-day retention period.

Writable application data remains inside the macOS sandbox's Application Support directory:

```text
LocalAssistant/
├── Connector/
│   ├── schedule.json
│   ├── status.json
│   ├── Requests/
│   ├── Processing/
│   └── Responses/
│       └── scheduled-reminder-snapshot.json
├── Index/assistant.sqlite3
└── Models/
```

Microphone audio is never written to disk. Speech is recognized from memory while it is spoken, then the complete in-memory utterance receives one final multilingual transcription pass before it is sent. No recording file exists to retain or clean up.

SQLite may create `-wal` and `-shm` files beside the database. Conversation history remains local until it is cleared through the application or its container is removed. While the application process is running, native macOS folder events schedule incremental updates; reopening the application performs a catch-up scan. Quitting stops folder monitoring completely. Local Assistant itself has no login item, background helper, localhost service, or runtime network route. The optional separate Connector installs a one-shot per-user launchd job that wakes only for queued work or schedule checks, closes every SSH tunnel, and exits.

## Release notes

### Current release status

| Release area | v3.10 status | Meaning |
|---|---|---|
| Approved scope | Complete | Reminders are hidden read-only knowledge; every change goes through an explicitly named OpenClaw request, with no Local Assistant notifications or reminder-management screen. |
| Source implementation | Complete | The Connector detects complete existing installations without returning token values, provides no-reentry update and verification, separates intentional credential replacement, supports confirmed exact cleanup, and retains the five-step first-install path without giving Local Assistant network access. |
| Semantic capability audit | Complete | Reminder retrieval combines exact, lexical, vector, reciprocal-rank, and temporal evidence without changing the existing file-retrieval pipeline. |
| Debug compilation | In progress | Connector v3.10 type-checks cleanly; the full Debug application build remains part of the current release run. |
| Release build | Pending | The clean offline v3.10 build has not run yet. |
| Automated tests | In progress | All 32 Connector tests, all 7 OpenClaw plugin tests, and all 5 typed reminder-bridge tests pass; the focused Local Assistant tests remain part of the current release run. |
| Voice runtime testing | Pending manual check | Live multilingual speech, final transcription, silence sending, and hold-Space sending still require manual inspection. |
| Focused testing | Pending | Bundle signatures, embedded server payload, setup-state contract, cleanup boundary, and disk-image contents await the v3.10 build. |
| Disconnected runtime testing | Not run | The v3.10 application has not been exercised with every network interface disabled. |
| Static privacy audit | Pending | The v3.10 signed Local Assistant bundle has not been audited yet. |
| Interface inspection | Pending | The built v3.10 existing-install, first-install, replacement, cleanup, and error states still require visual inspection. |
| Code review | Not run | Code review remains a separate optional phase after implementation and local validation. |
| Formal verification | Not run | Runtime socket inspection and full disconnected acceptance remain separate. |
| Release artifact integrity | Pending | The v3.10 build 40 applications and release disk image have not been produced yet. |

### Version index

The table and notes below are the durable record of what each release contained. Only the
current project-root release set is retained; rebuilding never leaves a previous copy. Each
entry names what that release changed and links to its full notes.

| Version | What changed |
|---|---|
| v3.10 | [Credential-safe Connector updates and cleanup](#v310--credential-safe-connector-updates-and-cleanup) |
| v3.9 | [Reliable connector setup, refresh, and lifecycle](#v39--reliable-connector-setup-refresh-and-lifecycle) |
| v3.8 | [On-demand restricted SSH transport](#v38--on-demand-restricted-ssh-transport) |
| v3.7 | [Complete private Tailscale connection setup](#v37--complete-private-tailscale-connection-setup) |
| v3.6 | [User-created server ZIP and corrected setup packaging](#v36--user-created-server-zip-and-corrected-setup-packaging) |
| v3.5 | [Unambiguous clean-device OpenClaw setup](#v35--unambiguous-clean-device-openclaw-setup) |
| v3.4 | [Live OpenClaw status and in-app setup](#v34--live-openclaw-status-and-in-app-setup) |
| v3.3 | [Hidden reminder knowledge and explicit OpenClaw actions](#v33--hidden-reminder-knowledge-and-explicit-openclaw-actions) |
| v3.2 | [Private reminder RAG and an opt-in OpenClaw connector](#v32--private-reminder-rag-and-an-opt-in-openclaw-connector) |
| v3.1 | [Storage figures moved beside each button](#v31--storage-figures-moved-beside-each-button) |
| v3.0 | [Storage figures next to each reset action](#v30--storage-figures-next-to-each-reset-action) |
| v2.9 | [Bordered reset rows matching the folder-card style](#v29--bordered-reset-rows-matching-the-folder-card-style) |
| v2.8 | [Simplified reset rows and corrected model-removal placement](#v28--simplified-reset-rows-and-corrected-model-removal-placement) |
| v2.7 | [Reset controls integrated into their owning sections](#v27--reset-controls-integrated-into-their-owning-sections) |
| v2.6 | [On-demand model removal, search-index reset, and status check](#v26--on-demand-model-removal-search-index-reset-and-status-check) |
| v2.5 | [Complete folder hierarchy and precise folder-scoped results](#v25--complete-folder-hierarchy-and-precise-folder-scoped-results) |
| v2.4 | [Reliable type-only listings and idle command pulse](#v24--reliable-type-only-listings-and-idle-command-pulse) |
| v2.3 | [Folder-aware retrieval and coordinated interface motion](#v23--folder-aware-retrieval-and-coordinated-interface-motion) |
| v2.2 | [Evidence-backed result cards and honest visual-search limits](#v22--evidence-backed-result-cards-and-honest-visual-search-limits) |
| v2.1 | [Bounded vector search, visible button hover states, and clarified semantic-image limits](#v21--bounded-vector-search-visible-button-hover-states-and-clarified-semantic-image-limits) |
| v2.0 | [Selectable voice interactions, finalized speech, and conversational follow-ups](#v20--selectable-voice-interactions-finalized-speech-and-conversational-follow-ups) |
| v1.9 | [One light visual family across every screen](#v19--one-light-visual-family-across-every-screen) |
| v1.8 | [Light command interface with acquired-file modules](#v18--light-command-interface-with-acquired-file-modules) |
| v1.7 | [Current command presentation with complete conversation History](#v17--current-command-presentation-with-complete-conversation-history) |
| v1.6 | [Spoken words appear and send, and the routing marker stays hidden](#v16--spoken-words-appear-and-send-and-the-routing-marker-stays-hidden) |
| v1.5 | [Recordings end on a pause and send what was said](#v15--recordings-end-on-a-pause-and-send-what-was-said) |
| v1.4 | [Live waveform and on-screen speech, with no audio written to disk](#v14--live-waveform-and-on-screen-speech-with-no-audio-written-to-disk) |
| v1.3 | [The assistant stopped repeating its own result sentence](#v13--the-assistant-stopped-repeating-its-own-result-sentence) |
| v1.2 | [Vendored network code removed, with correctness fixes and automated tests](#v12--vendored-network-code-removed-with-correctness-fixes-and-automated-tests) |
| v1.1 | [Simpler indexing controls and a clean shutdown on quit](#v11--simpler-indexing-controls-and-a-clean-shutdown-on-quit) |
| v1.0 | [Continuous folder monitoring, pausable indexing, and 30-day activity](#v10--continuous-folder-monitoring-pausable-indexing-and-30-day-activity) |
| v0.9 | [Hard file-type filters, prompt safety, and tightened entitlements](#v09--hard-file-type-filters-prompt-safety-and-tightened-entitlements) |
| v0.8 | [Settings reordered, conversation text styled, and the README rewritten](#v08--settings-reordered-conversation-text-styled-and-the-readme-rewritten) |
| v0.7 | [Answers stopped repeating details already shown in the cards](#v07--answers-stopped-repeating-details-already-shown-in-the-cards) |
| v0.6 | [Plain-language model readiness and result cards that survive relaunch](#v06--plain-language-model-readiness-and-result-cards-that-survive-relaunch) |
| v0.5 | [Message timestamps, Clear Conversation, and shorter result cards](#v05--message-timestamps-clear-conversation-and-shorter-result-cards) |
| v0.4 | [Settings reorganized around status, folder access, and privacy](#v04--settings-reorganized-around-status-folder-access-and-privacy) |
| v0.3 | [Local routing between chat, clarification, and file search](#v03--local-routing-between-chat-clarification-and-file-search) |
| v0.2 | [Focused interface with crash-safe indexing and folder revocation](#v02--focused-interface-with-crash-safe-indexing-and-folder-revocation) |
| v0.1 | [First sandboxed assistant with local indexing, retrieval, and voice](#v01--first-sandboxed-assistant-with-local-indexing-retrieval-and-voice) |

To confirm which release an application is, read `CFBundleShortVersionString` from its
`Info.plist`. Every release increments it, so it identifies one release exactly.

### v3.10 — Credential-safe Connector updates and cleanup

- Added credential-free discovery of an existing Connector installation. The Swift app receives only reusable public server values and yes/no Keychain-presence flags; it never retrieves or displays saved tokens.
- Added **Update and Verify Existing Connector**, which installs the current packaged runtime, reuses the saved SSH identity, configuration, and Keychain tokens, verifies a real complete snapshot, and restarts the one-shot job without asking the user to repeat setup.
- Separated **Replace Saved Credentials** from public settings review. New tokens enter through empty secure fields, move to Keychain through bounded standard input, and are cleared from Swift immediately after secure handoff even if later verification fails.
- Added confirmed **Remove Connector Data**, which deletes the exact Connector runtime, identity, settings, checkpoint, launch job, pending spool lanes, and two Keychain entries while preserving Local Assistant and its committed reminder cache and RAG index.
- Replaced the dense Connector form with a light-only semantic-color workbench: blue identifies server values, cyan identifies generated files, orange identifies server actions, teal identifies credentials and privacy, green identifies verification, and red is reserved for destructive cleanup.
- Rewrote every primary step for a first-time user who knows only how to open Mac Terminal and the server terminal. Required actions and completion cues remain visible; definitions, security details, alternatives, internal port details, and Q&A recovery remain collapsed under the step that owns them.
- Advanced Local Assistant and OpenClaw Connector to v3.10 build 40 and the Connector runtime package to v1.4.0. The OpenClaw reminder bridge remains v1.3.0 because its server contract did not change.

### v3.9 — Reliable connector setup, refresh, and lifecycle

- Fixed the standard macOS `Application Support` SSH host-key path so OpenSSH receives it as one pinned file rather than splitting it at the space.
- Canonicalized Swift-generated UUIDs before forwarding and comparison, preventing valid complete reminder snapshots from being replaced by the generic `connector could not complete the request` response.
- Added regression coverage at the workflow, service, and SSH-command boundaries.
- Moved public-key and server-ZIP creation into the standalone Connector, which now embeds the generic server kit and owns every user-approved export. Local Assistant returned to a read-only user-selected-files entitlement.
- Replaced the overwhelming Local Assistant procedure with three short completion cards and a five-step bullet-first Connector flow that distinguishes existing server access, two generated files, server commands, printed values, and local verification.
- Added bounded server-route readiness retries and service diagnostics so a normal Gateway restart no longer races the installer snapshot check.
- Added allowlisted SSH failure reasons for host-key mismatch, rejected public key, unresolved address, refused connection, timeout, and unreachable network without exposing raw SSH output or credentials.
- Required exact marketing-version and build-number matching before Local Assistant opens a Connector, with recovery wording when Applications contains an older copy.
- Added visible startup progress, preserved the current screen when reopening from the Dock, kept the global shortcut's assistant behavior, and made the Connector a normal Dock-visible application.
- Advanced Local Assistant and OpenClaw Connector to v3.9 build 39 and the bridge/connector packages to v1.3.0.

### v3.8 — On-demand restricted SSH transport

- Replaced Tailscale and the private HTTPS origin with an on-demand encrypted SSH tunnel opened by the separate Connector only for one request.
- Kept OpenClaw fixed to server loopback `127.0.0.1:23116`; no public Gateway port, HTTPS endpoint, VPN app, or continuously running tunnel is required.
- Added user-controlled Connector key generation. Only `local-assistant-connector.pub` is exported; the owner-only private key stays on the Mac and never enters the server ZIP or a command argument.
- Reworked the rerunnable server installer to create a non-root, no-shell `local-assistant-tunnel` account restricted to local forwarding to the exact Gateway destination, with PTY, X11, agent forwarding, remote forwarding, and all other destinations denied.
- Added strict Ed25519 host-key pinning and SSH configuration rollback when `sshd` validation fails.
- Replaced the persistent connector process with a one-shot launchd job. Queued app work launches it immediately; calendar checks support two-, four-, and eight-hour reminder schedules and a missed check after wake.
- Added scheduled snapshot handoff: the Connector fetches a complete snapshot, exits, and leaves the newest result in the owner-only spool until Local Assistant validates, embeds, and transactionally replaces the cache and RAG index.
- Preserved the prior complete cache on every fetch, validation, embedding, or database failure and visibly marks reminder knowledge as potentially outdated. Missing IDs in a successful complete snapshot are deleted locally without `updatedAt` fields or tombstones.
- Rewrote the seven-step in-app guide and its collapsed Q&A troubleshooting around the real SSH flow, clean-device assumptions, public-key and ZIP transfer, server-owner boundary, host-key verification, one-shot scheduling, and stale-cache behavior.
- Advanced Local Assistant and OpenClaw Connector to v3.8 build 38 and the bridge/connector packages to v1.2.0.

### v3.7 — Complete private Tailscale connection setup

- Added a browser-specific prerequisite section that separates new Tailscale accounts from existing accounts and explains that sign-up uses an external identity provider, not the CLI-only OpenClaw server.
- Added execute-as-is Linux commands that install Tailscale only when missing, print a one-time authorization URL when required, and confirm the server has joined the intended tailnet.
- Added a separate OpenClaw token-authentication check and private Tailscale Serve command block that keeps the Gateway on loopback and identifies the exact `https://…ts.net` origin required by the connector.
- Distinguished the one-time authorization URL, private HTTPS origin, WebSocket addresses, and API paths so the wrong value cannot be pasted into the server installer or connector.
- Added separate Mac instructions for new and existing Tailscale installations, including the same-account requirement, macOS network-extension approval, and server-visibility check.
- Added buttons for the official Tailscale account, Linux installation, and macOS installation pages. Local Assistant only opens those pages in the default browser and receives no account or sign-in information.
- Preserved concise bullet groups, aligned full-width cards, distinct browser/server/Mac locations, in-card command copy actions, and the network-denied Local Assistant boundary.
- Advanced Local Assistant and OpenClaw Connector to v3.7 build 37.
- Rebuilt the signed release apps and clean-Mac disk image, passed 17 connector tests and 7 bridge tests, passed the offline-boundary and packaging checks, and visually inspected the guide and connector at normal and minimum sizes under both system appearances.

### v3.6 — User-created server ZIP and corrected setup packaging

- Replaced the automatically generated server ZIP with a **Create Server Setup ZIP…** action inside Local Assistant. The user chooses the destination, and the app explains that it packages versioned server runtime files locally without downloading content or adding credentials.
- Kept **Set up the OpenClaw server** and **Set up the local companion** as the two location boundaries. Every setup card now uses concise bullet points, every card fills the same content width, the server commands and copy action remain inside server step 2, and **Open Connector App** remains inside the connector-configuration card.
- Reduced the disk image to the two standalone Mac applications. Required server installer and bridge files are embedded in Local Assistant and enter the exported ZIP only after the user requests it; development tests and documentation are excluded from that payload.
- Added a distinct generated icon to `OpenClaw Connector.app` and declared it in the connector bundle metadata.
- Preserved the app's network-denied sandbox while adding user-selected write access solely for the ZIP destination; authorized source-folder bookmarks remain read-only.
- Corrected post-payload signing so the final Local Assistant bundle retains its explicit sandbox entitlements, then rebuilt and checksum-validated the v3.6 build 36 release DMG.

### v3.5 — Unambiguous clean-device OpenClaw setup

- Replaced the conceptual four-step guide with separate **ON THE OPENCLAW SERVER** and **ON THIS MAC** sections. Every command states its execution location, whether it runs unchanged, and whether a prompt expects input.
- Normalized all six step cards to the same width and minimum height, with aligned **WHERE**, **DO THIS**, and **EXPECT** rows instead of dense instruction paragraphs.
- Added `OpenClaw Server Setup.zip`, whose interactive server installer installs and verifies the read-only bridge, enables the agent endpoint, restarts OpenClaw, and prints the three values needed on the Mac without asking the user to edit a file.
- Added a separately packaged `OpenClaw Connector.app` containing its own Python and LangGraph runtime. It detects the local spool, saves configuration and Keychain credentials through the packaged connector, and starts a per-user background service without requiring Python, Git, Terminal, or project source on the user's Mac.
- Added a complete release disk image containing both applications and the server setup kit, while keeping all network access outside `Local Assistant.app`.
- Advanced the application to v3.5 build 35.

### v3.4 — Live OpenClaw status and in-app setup

- Added a live **Connection status** summary to the OpenClaw Settings section. While the user-controlled ability is enabled, Local Assistant checks the connector's bounded, non-secret local heartbeat once per second and reports Off, Checking, Not detected, Running but not yet verified, Ready, or Needs attention.
- Added a same-window **OpenClaw Setup** guide opened from Settings, with plain-language preparation, installation, secure configuration, start, recovery, and privacy steps. The installation-specific spool path can be copied there, and optional source-install commands remain collapsed until requested.
- Kept the privacy boundary unchanged: Local Assistant has no network entitlement, never reads the OpenClaw origin or Keychain credentials, and stops both automatic reminder refreshes and heartbeat monitoring when the connection ability is disabled.
- Advanced the application to v3.4 build 34.

### v3.3 — Hidden reminder knowledge and explicit OpenClaw actions

- Removed the Reminder Center, Local Assistant reminder CRUD proposals, confirmation sheet, and macOS reminder notifications. Every cached reminder is now hidden, read-only local knowledge.
- Clarified Privacy with the sole external OpenClaw path, moved every connector control into a distinct **OpenClaw Connection** section directly below it, and added visible setup state with a portable connector guide.
- Added local reminder-grounded generation so the assistant can answer questions from retrieved CloudBase records instead of only showing matches.
- Added a deterministic standalone `OpenClaw` / `Open Claw` gate before local inference. Matching requests go immediately to OpenClaw with only the exact submitted text and a stable conversation identifier.
- Reduced the reminder bridge to complete-list snapshots and made both the Swift service and LangGraph connector reject every read-by-ID and mutation shape.
- Consolidated connector traffic onto one exact OpenClaw origin while retaining separate Keychain credentials for snapshot reads and full-operator agent requests.
- Changed automatic refresh choices to two, four, or eight hours, with a four-hour default, stale launch catch-up, and a refresh after each successful OpenClaw response.

### v3.2 — Private reminder RAG and an opt-in OpenClaw connector

- Added a complete-snapshot CloudBase reminder cache because the remote rows have no incremental timestamp or deletion tombstone. A malformed, partial, timed-out, or unembeddable snapshot never replaces the previous complete cache.
- Added local exact, FTS5, Qwen embedding, reciprocal-rank, and temporal reminder retrieval, with reminder cards retained in conversation History.
- Added a Reminder Center with Upcoming, Overdue, and All views, explicit ownership labels, automatic sync while the app is open, and exact plus one-day-early local alerts only for Local Assistant-owned rows.
- Added confirmation-gated CloudBase-only create, update, and delete operations. Creates carry a stable idempotency key, updates carry compare-and-set fields, and all mutations reject OpenClaw-managed and legacy/unknown rows.
- Added a separate Python connector using LangGraph and durable SQLite checkpoints, exact HTTPS origins, separate Keychain credentials, bounded owner-only spool files, and reminder versus full-operator lanes. Both lanes are disabled until explicitly configured; the app itself retains no network entitlement.
- Added an OpenClaw plugin route that accepts only the narrow schema-v1 reminder contract, always requires `calendarPolicy:"never"`, invokes a fixed bridge command, and never accepts a calendar identifier.

### v3.1 — Storage figures moved beside each button

- Moved the model-storage figure off its own line and into the **Remove Downloaded Models** row, right beside the button, inside the same grey-filled box.
- Moved the index-storage figure off its own line and into the **Clear Search Index** row the same way; the indexed-file count keeps its own separate line above the row.

### v3.0 — Storage figures next to each reset action

- Added an index-storage figure next to the indexed-file count in Folder Access, showing the actual on-disk size of the search index (database, passages, and vectors) beside **Clear Search Index**.
- The existing model-storage figure now sits directly beside **Remove Downloaded Models** instead of near the launch-check row.
- Dropped the "#" symbol from the version badge in the Settings header; it now reads as plain text (e.g. "v3.0").

### v2.9 — Bordered reset rows matching the folder-card style

- Gave **Remove Downloaded Models** and **Clear Search Index** their own grey-filled, bordered row, matching the visual treatment already used for each authorized folder.
- Moved **Remove Downloaded Models** to sit directly under the model capability list as its own row, rather than as a fourth entry sharing that list's box.

### v2.8 — Simplified reset rows and corrected model-removal placement

- Moved **Remove Downloaded Models** into the model capability list itself, directly below Chat/File search/Voice input, instead of sitting apart near the bottom of the Models section.
- Dropped the inline explanation text under **Clear Search Index** and **Remove Downloaded Models**; each row is now an icon, name, and button, with the full effect still explained in the confirmation alert before anything is deleted.
- Fixed a left-alignment inconsistency that made Clear Search Index appear indented relative to the folder list above it.

### v2.7 — Reset controls integrated into their owning sections

- Moved **Remove Downloaded Models** into the Models section, next to the capability list and storage details it affects.
- Moved **Clear Search Index** (and the indexed-file count) into Folder Access, next to the folder list and indexing controls it affects, instead of sharing a block with model controls.
- Removed automatic previous-build retention from the offline build script; a rebuild now always leaves exactly one application at the project root.

### v2.6 — On-demand model removal, search-index reset, and status check

- Added **Check Now** to Settings, re-verifying installed models and re-counting indexed files on demand instead of only at launch.
- Added **Clear Search Index**, deleting every indexed file, passage, and vector, then immediately re-indexing every authorized folder. Folder access, monitoring preferences, and conversation history are untouched.
- Added **Remove Downloaded Models**, deleting every installed model file and its verification cache so a reinstall starts from a clean slate without deleting the application itself.
- Both destructive actions require confirmation and are disabled while indexing, a request, or voice capture is active.

### v2.5 — Complete folder hierarchy and precise folder-scoped results

- Published every scanned file and folder as searchable metadata before expensive extraction begins, while preserving previously indexed passages. Interrupted runs no longer leave later folders absent from the hierarchy.
- Processed folder context before file contents and made a literal folder name or path the retrieval boundary, preventing unrelated semantic candidates outside that folder from being presented as its contents.
- Recovered explicit file and folder requests when the local routing model returns only a generic results acknowledgement, avoiding a response that claims matches while showing no cards.
- Added the installed release number to the Settings header.

### v2.4 — Reliable type-only listings and idle command pulse

- Normalized broad requests such as “Any PDFs?” into type-only listings so conversational filler no longer becomes a false semantic-evidence requirement.
- Preserved meaningful topics in requests such as “PDFs about insurance” and kept the requested file type as a hard constraint.
- Replaced the state-changing triangle phase collection with one stable continuous loop and increased the bright-to-dim contrast while retaining a static full-red Reduce Motion presentation.

### v2.3 — Folder-aware retrieval and coordinated interface motion

- Indexed each authorized root and descendant folder as a first-class result with a bounded, locally embedded context derived from its name, relative path, and direct children.
- Added hierarchy-aware retrieval so a strongly matched folder promotes contained files and folders, while requested file types remain hard constraints within that scope.
- Prioritized exact folder and path evidence over unrelated document passages and explained scoped results with the folder that qualified them.
- Added folder-aware Open actions, response and screen crossfades, staggered result acquisition, and a slow idle pulse for the red command triangle. Reduce Motion keeps these states legible without movement.

### v2.2 — Evidence-backed result cards and honest visual-search limits

- Stopped a hard file-type constraint from qualifying otherwise unrelated files when a request also contains a topic or content description. A non-empty search now requires filename, path, keyword, or semantic evidence.
- Derived hard file-type filters from the user's own words instead of trusting a model-generated kind. Requests for files containing images no longer become an invented PDF or image-file constraint.
- Replaced generic content-search reasons with the strongest concrete evidence, including a bounded indexed passage for keyword and semantic matches and calibrated wording for uncertain semantic relations.
- Reported requests that require recognizing visual subjects or embedded images as unsupported by the current text-and-OCR index. This prevents false result cards while preserving the separately scoped path to local multimodal retrieval.

### v2.1 — Bounded vector search, visible button hover states, and clarified semantic-image limits

- Capped every sqlite-vec nearest-neighbor request at the embedded extension's 4,096-result limit and stopped adaptive file-type expansion at the same boundary, preventing large indexes from producing a 5,120-neighbor database error.
- Added restrained hover feedback to every custom in-window button while preserving disabled states, keyboard focus, stable layout, and reduced-motion behavior. Native macOS alert and menu buttons retain their system-provided pointer states.
- Confirmed that extracted passages are embedded with the local Qwen text model, stored in sqlite-vec, and combined with filename, path, keyword, type, and recency signals during ranking.
- Clarified that standalone images and image-only PDF pages contribute OCR text, not a visual embedding. A chart can be found from its labels, caption, or surrounding extracted text; recognizing an unlabeled histogram by shape requires a future local image-text model or image-captioning stage.

### v2.0 — Selectable voice interactions, finalized speech, and conversational follow-ups

- Added a persistent Voice input setting with **Click to speak** and **Hold Space** choices. Click mode sends after two seconds of silence; hold mode records while Space is held and sends on release without taking over the Space key during text editing.
- Kept live multilingual recognition for immediate feedback, then added one complete in-memory transcription pass before sending so the newest words and language decision are no longer limited to the last streaming hypothesis.
- Reframed recent history as actual user and assistant turns for the local Qwen model, bounded each retained message, and prioritized the newest turns so long older responses cannot remove the context needed by a follow-up.
- Cleared the previous displayed request when a new text or voice interaction begins while preserving a draft that is already being edited.

### v1.9 — One light visual family across every screen

- Extended the warm light canvas, restrained scan texture, graphite hierarchy, signal-red identity, and sharper surfaces from the command screen into History, Activity, file results, and Settings.
- Kept each destination purpose-specific: History remains a chronological conversation archive, Activity remains a filterable indexing ledger, and Settings retains every native control, status, confirmation, recovery path, and privacy explanation.
- Preserved natural capitalization in assistant responses and file explanations while reserving uppercase treatment for short telemetry and interface labels.
- Kept the application intentionally light-only, including when macOS uses Dark appearance.

### v1.8 — Light command interface with acquired-file modules

- Rebuilt the main screen around the approved light-only command design: a warm off-white canvas, restrained scan texture, compact local-status rail, black monospaced hierarchy, and signal-red command markers.
- Replaced rounded command cards and material controls with square-edged file modules, acquisition corners, section rules, and plain Open and Reveal actions. Main-screen modules omit absolute paths while retained History preserves the established record.
- Kept the idle prompt centered, moved the current request control to the bottom after interaction, and preserved live voice text, local processing state, responsive file wrapping, reduced-motion behavior, and the separate History screen.
- Restyled background indexing as a compact command strip without removing its percentage, folder state, Activity navigation, or safe Pause action.

### v1.7 — Current command presentation with complete conversation History

- Replaced the accumulating main chat with a voice-first command surface that starts centered and moves its live voice or text input to the bottom after the first request.
- Presents only the current processing state, latest response, and latest file findings on the main screen; beginning another request replaces that presentation instead of adding another bubble.
- Displays file findings in a centered adaptive grid with a restrained acquisition animation, while retaining explicit Open and Reveal actions and a reduced-motion fallback.
- Moved the established chronological message layout to an in-window History screen. It includes restored messages and new requests from the current launch, while reopening the application resets only the main command presentation.

### v1.6 — Spoken words appear and send, and the routing marker stays hidden

- Fixed spoken words never appearing and no request being sent. Recognized text for a short phrase arrives as unconfirmed segments, which the app ignored: it read only the confirmed list, which fills once a recording is long enough to exceed the confirmation window, and the in-progress text, which is cleared as soon as each chunk finishes.
- Fixed a routing instruction being shown as the assistant's answer. The model is asked for a doubled bracket marker and does not reliably reproduce the brackets, so a near miss was treated as ordinary conversation and the raw marker and payload were displayed. The marker is now matched by its token, whatever brackets surround it.
- Neutralized that token wherever untrusted text enters a prompt, so an answer already stored in history cannot teach the model to repeat it.

### v1.5 — Recordings end on a pause and send what was said

- Fixed a spoken request never being sent after the recording ended on its own. Finishing ran inside the task that following the recording had just cancelled, so the request was abandoned silently.
- Fixed the recording not ending after a pause. The level below which audio counted as quiet was far lower than a quiet room reports, so a pause was never recognized.
- Ended a recording on a pause in the audio rather than on recognized text. Recognition lags speech by about a second, so waiting for text delayed the stop or prevented it.
- Shortened the pause that ends a recording to two seconds.
- Reported a capture that fails instead of ending silently. A failed stream previously left the interface showing a recording that was no longer running, with no message and no error.
- Logged speech-library activity in Debug builds so a capture that produces no text can be diagnosed. Release builds stay silent.

### v1.4 — Live waveform and on-screen speech, with no audio written to disk

- Replaced the text field with a live waveform while the microphone is open, drawn from the audio levels the speech model reports rather than a decorative animation.
- Showed recognized words in the conversation as they are spoken, so it is clear what the app has captured and when to stop. Settled words are shown plainly and words still being revised are dimmed, because continuous recognition rewrites its most recent words as more audio arrives.
- Ended a recording automatically after a pause, while the microphone control still stops it immediately.
- Stopped writing microphone audio to disk. Speech is recognized from memory as it arrives, so no recording file is created, and any file left by an earlier version is deleted at startup.
- Added a preparing state shown before capture begins. Continuous recognition needs the speech model loaded first, so the interface says so instead of opening the microphone and discarding what it cannot yet recognize.

### v1.3 — The assistant stopped repeating its own result sentence

- Stopped the assistant repeating "I found N matches. They are shown below." for every request. When an answer duplicated card metadata, the app replaced it with that generated sentence, stored the sentence as the assistant's reply, and then showed it back to the model as recent conversation. After a few such turns the model reproduced the sentence as its own answer, so every later request returned the same text and no results.
- Replaced a generated acknowledgement with a bracketed note wherever conversation history enters a prompt, so the model keeps the context that results were shown without a sentence to imitate.

### v1.2 — Vendored network code removed, with correctness fixes and automated tests

**Offline boundary**

- Removed the network path monitor that the vendored speech dependency started whenever it constructed a model-hub client, so no code in the application observes network state.
- Removed that dependency's fallback that downloaded a missing speech tokenizer from the internet, and moved the tokenizer into the verified offline model package instead. A missing tokenizer now reports a reinstall instruction rather than attempting a connection.
- Stored both dependency modifications in the repository and re-applied and verified them during preparation, so refreshing a pinned checkout cannot silently restore the original network code.
- Extended the boundary audit to reject any executable in the bundle that links a networking library or imports a network symbol, in addition to the existing entitlement checks.
- Recorded the verified checksum and size of every added tokenizer file in the model manifest, and made the preparation download fail loudly on a timeout, a partial file, or a truncated file listing.

**Search and extraction accuracy**

- Made a multi-word file request match words individually instead of requiring the whole phrase to appear as one run of characters, so a request naming a topic and a folder can still find the file.
- Treated `%` and `_` typed in a request as ordinary characters rather than as database wildcards.
- Scaled an oversized photograph or scan down to the supported recognition size instead of rejecting it, so a high-resolution image is no longer indexed with no text at all.
- Added Simplified Chinese alongside English to text recognition.
- Kept the text of a PDF's readable pages when recognition fails on one page, instead of discarding the whole document's text.
- Detected the encoding of a plain-text file rather than assuming UTF-8, so a file saved in another encoding is no longer indexed as replacement characters.
- Excluded the real system and cache directories by absolute path, which a sandboxed application cannot identify by name alone.
- Stopped a concise answer from being replaced by a match count when a result's name was an ordinary word, such as a folder named `Documents`.

**Voice, models, and lifecycle**

- Fixed voice capture discarding the first seconds of speech: the microphone now opens immediately while the speech model loads alongside it.
- Fixed a recording being read back before macOS had finished writing it, which could truncate or empty a transcription.
- Separated **Not installed** from **Damaged** in Settings so a missing model package and a file that no longer matches its checksum no longer share one recovery instruction.
- Reported voice input as unavailable when its tokenizer is absent, instead of reporting it ready and failing at first use.
- Re-verified model checksums on a weekly schedule rather than at every launch, and closed the private database when the application quits.
- Added an extraction version to each file's fingerprint, so an extraction correction re-extracts already-indexed files once instead of leaving them on superseded text.

**Performance and cleanup**

- Replaced a repeated per-result database lookup with one batched read, and stopped semantic search from scanning the whole vector table when no vector can satisfy the requested file type.
- Made passage splitting cost time proportional to a document's length rather than to its length squared.
- Removed a retrieval lookup against an empty prototype table that ran on every search and could never affect a score.
- Added a native test target with 46 automated tests covering request routing, search-text escaping, passage offsets, card-aware answers, and scanner exclusions.
- Added previews for every model readiness state, so the not-installed and damaged wording can be reviewed in both appearances without removing or corrupting installed model files. They are excluded from the shipped application.

### v1.1 — Simpler indexing controls and a clean shutdown on quit

- Reworked file-state counts into compact metric tiles and consolidated each folder's automatic-update state and action into one control.
- Added a dedicated pause action for an active indexing run and redesigned activity-history filters as consistent Source, Folder, and Status fields.
- Anchored restored conversations at the newest message to prevent a visible top-to-bottom jump when returning to the assistant.
- Added orderly llama.cpp, Metal, voice, monitoring, and indexing teardown so a normal Quit no longer produces an unexpected-termination report.

### v1.0 — Continuous folder monitoring, pausable indexing, and 30-day activity

- Added pausable per-folder indexing with determinate progress, percentages, and clearly labeled new, modified, unchanged, removed, and skipped states.
- Added process-lifetime native macOS folder monitoring, debounced incremental updates, and launch-time catch-up scans without a daemon, login item, server, or runtime network access.
- Added a same-window Activity screen with run filters, automatic monitoring events, summary badges, expandable file details, and a rolling 30-day retention policy.
- Kept retained activity after folder revocation while continuing to remove the bookmark and dependent searchable index records.
- Added a background-indexing banner so silent automatic work remains visible without blocking conversation.

### v0.9 — Hard file-type filters, prompt safety, and tightened entitlements

- Applied requested file-type constraints inside metadata and full-text queries before candidate limits, and added adaptive vector-neighbor expansion so valid constrained semantic matches are not hidden behind other file types.
- Neutralized Qwen chat-control markers in questions, local history, paths, and excerpts before untrusted text enters a parsed chat template.
- Resolved current symlink targets before explicit Open or Reveal actions and rejected targets outside the authorized root.
- Made SQLite reads distinguish normal completion from execution failure, reject malformed required identifiers, and close a partially initialized database connection after setup failure.
- Removed duplicated presentation state, dead prototype APIs, unused constants, and duplicate indexed-item decoding while retaining compatible prototype-era database tables.
- Hardened temporary voice recordings with owner-only permissions, failed-start cleanup, and stale-recording cleanup before the next capture.
- Recorded unreadable traversal paths in indexing exclusions instead of silently continuing.
- Restricted Release signing to the four approved sandbox entitlements and made the static audit reject every unexpected entitlement.
- Hardened connected dependency archive extraction on older system Python versions while preserving safe in-repository symbolic links.

### v0.8 — Settings reordered, conversation text styled, and the README rewritten

- Reordered Settings around Privacy, Folder Access, Models, and Assistant Status.
- Updated the Settings introduction to follow the same information hierarchy.
- Added restrained sender labels and role-specific typography to user and assistant messages.
- Added local lightweight styling for emphasis, inline code, preserved paragraphs, and simple list markers without introducing a web-rendering surface.
- Consolidated the README into task-focused sections, converted troubleshooting to questions and answers, integrated related operational guidance, preserved the architecture diagrams, and removed machine-specific paths.
- Converted the project folder into a lean source checkout by excluding regenerated dependencies, model assets, offline packages, and built applications from Git.

#### Delivery evidence

- The isolated Debug build and clean offline Release build completed using pinned local dependencies.
- The clean-built and installed bundles report v0.8 with numeric build `8`.
- The clean-built and installed executables are byte-identical with SHA-256 `1deb2c96ea3f6da614cea02477e905ea9c2850f2e5dd4035057313b2432be8ea`.
- Deep signature validation and the static offline-boundary audit passed for the installed bundle.
- Focused source checks confirmed the requested Settings order, sender labels, local rich-text renderer, and absence of machine-specific paths in this README.
- The installed application launched successfully and remained running during the startup smoke check.
- Automated visual capture was unavailable because the current macOS environment did not grant accessibility or screen-recording permission; no permission boundary was widened to bypass that restriction.

### v0.7 — Answers stopped repeating details already shown in the cards

- Stopped grounded replies from repeating filenames, paths, source numbers, or file-by-file lists already presented in result cards.
- Added a deterministic local safeguard that replaces duplicated card metadata with a concise match count when necessary.
- Applied the same safeguard to restored conversation history while preserving reusable cards.
- Added project-hygiene rules and removed obsolete build caches, historical application bundles, Finder metadata, and download-state files while preserving installed offline models and dependency pins.

### v0.6 — Plain-language model readiness and result cards that survive relaunch

- Redesigned **Models** as a plain-language readiness summary for Chat and answers, File search, and Voice input.
- Added overall readiness, private model-storage usage, launch-check acknowledgement, and actionable recovery wording without exposing model filenames in the interface.
- Stored ranked result-card snapshots with their assistant messages and restored them after relaunch.
- Added migration for older citation-only messages when the cited item still exists in the current index.
- Revalidated saved-card actions against the current index, read-only folder authorization, path containment, and disk presence.
- Prevented result actions from collapsing into narrow vertical controls.
- Standardized human-facing release labels with a `v` prefix and aligned the project folder name with the application name.

### v0.5 — Message timestamps, Clear Conversation, and shorter result cards

- Added local timestamps below user and assistant messages.
- Added a confirmed Clear Conversation action in the assistant header and application menu.
- Limited history deletion to saved messages and current results; folders, permissions, models, index records, and source files remain unchanged.
- Reduced result-card height and replaced stacked ranking signals with one concise **Why it matches** explanation.

### v0.4 — Settings reorganized around status, folder access, and privacy

- Reorganized Settings around assistant status, shortcut availability, folder access, and one focused privacy statement.
- Styled Control, Option, and Space as separate accessible keycaps.
- Kept an individual **Update Index** action on every folder and showed **Update All Folders** only when multiple folders were authorized.
- Reduced repeated privacy wording while retaining read-only access and explicit revocation controls.

### v0.3 — Local routing between chat, clarification, and file search

- Added local routing between ordinary conversation, clarification, and structured file search.
- Made requested file types hard constraints instead of filename keywords.
- Added deterministic clarification for singular, underspecified file requests while retaining broad listing requests such as “Show me PDFs.”
- Added automatic bottom scrolling, corrected message alignment, a richer native visual system, in-window Settings, responsive result cards, and the selected blue folder-and-sparkle icon.

### v0.2 — Focused interface with crash-safe indexing and folder revocation

- Simplified the interface around conversation, file retrieval, voice input, shortcut access, and Settings.
- Added crash-safe sequential indexing, folder revocation, local conversation, and lazy local speech-model loading.

### v0.1 — First sandboxed assistant with local indexing, retrieval, and voice

- Established the sandboxed SwiftUI application, read-only folder authorization, local indexing, embedded inference, hybrid retrieval, OCR, and local voice foundation.

## Product reference

### Capabilities

| Capability | Availability | Notes |
|---|---|---|
| Local conversation | Available | Runs through an embedded model in the application process. |
| Current command presentation | Available in v1.7 | Shows only the active request, processing state, latest centered response, and latest responsive file findings on the main screen. |
| Retained conversation History | Available in v1.7 | Preserves the established chronological message and result-card layout in a separate in-window screen, including the current launch. |
| Intent-aware routing | Available | Selects conversation, clarification, or constrained file search. |
| Hard file-type filtering | Available in v0.9 source; hardened in v2.2 | Supports folders, PDFs, documents, spreadsheets, presentations, images, code, text, and archives. Only types explicitly requested by the user become constraints. |
| Hybrid retrieval | Folder-aware in v2.3 | Combines filename, path, folder hierarchy, keyword, text-semantic, recency, and reciprocal-rank signals. Semantic ranking operates on extracted text, OCR, and generated local folder context rather than raw visual pixels. |
| Folder-aware retrieval | Available in v2.3 | Indexes authorized roots and descendant folders, then uses a strong folder match to scope and explain contained results. |
| Explainable result cards | Available; evidence-backed in v2.2 | Shows file type, confidence, path, explicit actions, and the concrete filename, path, keyword passage, or semantic passage that qualified the result. |
| Durable result cards | Available | Restores saved cards with conversation history after relaunch. |
| Card-aware answers | Available | Summarizes results without duplicating filenames, paths, or source lists already shown in cards. |
| Styled conversation text | Available in v0.8 | Distinguishes each sender and renders lightweight local emphasis, inline code, and list markers. |
| Automatic conversation scrolling | Available | Follows new messages, results, and completed answers while respecting reduced motion. |
| Message timestamps | Available | Uses local time for today and an abbreviated local date and time for older messages. |
| Clear conversation history | Available | Removes saved messages and cards after confirmation. |
| Read-only folder selection | Available | Uses macOS security-scoped bookmarks. |
| Folder revocation | Available | Removes authorization and dependent private index records. |
| Manual incremental indexing | Available | Updates one or several authorized folders sequentially. |
| Continuous folder updates | Available in v1.0 source | Uses native macOS folder events while the application is running and performs a catch-up scan at launch. |
| Indexing progress and pause | Available in v1.0 source | Shows per-folder counts and percentage progress and safely pauses the active run without pruning unfinished index data. |
| Index activity | Available in v1.0 source | Retains automatic, manual, startup, and file-level results locally for 30 days, including history for revoked folders. |
| PDF and image OCR | Available | Uses PDFKit and Apple Vision. |
| Local voice input | Available in v1.7 | Updates the bottom command control with recognized words while speaking and ends on a pause or an explicit stop. |
| Global quick-call shortcut | Available | Uses fixed `⌃⌥Space` while the application process is running. |
| Speech output | Not included | No text-to-speech surface is included in the current interface. |
| Feishu bridge | Not implemented | Reserved for a separately approved future network boundary. |
| Runtime web access | Prohibited | The application has no browser, download route, or network entitlement. |

### Supported content

| Content | Local processing |
|---|---|
| Plain text and common source files | Text extraction and chunking |
| PDF | PDFKit extraction; Vision OCR for image-only pages |
| PNG, JPEG, HEIC, TIFF, BMP, and GIF | Apple Vision OCR; labels and visible text become searchable, but visual objects and chart shapes are not captioned |
| DOCX | Visible Open XML text |
| XLSX | Visible worksheet and shared-string XML text |
| PPTX | Visible slide XML text |
| Pages | OCR from an available local preview |
| Folders | Name, relative path, direct-child context, local embedding, and descendant scoping |
| Other files | Name, path, type, and metadata search |

Complex formulas, charts, comments, embedded objects, encrypted files, and proprietary Pages IWA bodies are not fully reconstructed. The scanner does not follow symbolic links and skips hidden paths, credential-like files, package descendants, common caches, and build directories.

### Local architecture

| Responsibility | Embedded component |
|---|---|
| Interface | SwiftUI |
| Chat and intent | Qwen3-4B Q4_K_M GGUF |
| Embeddings | Qwen3-Embedding-0.6B Q8_0 GGUF |
| Inference | Statically linked llama.cpp |
| Relational metadata, monitoring preferences, and history | Embedded SQLite |
| Keyword retrieval | SQLite FTS5 |
| Vector retrieval | Statically linked sqlite-vec |
| Speech recognition | WhisperKit with local `openai_whisper-small` Core ML assets |
| OCR | Apple Vision and PDFKit |

SQLite is an in-process library rather than a database server. See [ARCHITECTURE.md](ARCHITECTURE.md) for trust zones, the indexing lifecycle, and detailed design decisions.

## Architecture and project structure

### Request flow

```text
Typed or spoken request
          │
          ▼
 Local intent decision
   ┌──────┼──────────────┐
   ▼      ▼              ▼
 Chat  Clarification  Search plan
                         │
            normalized terms + file kinds
                         │
                         ▼
      filename/path + FTS5 + sqlite-vec
                         │
                         ▼
             constrained local ranking
                         │
                         ▼
         grounded answer + reusable cards
```

The first model pass decides whether to answer conversationally, ask for clarification, or search. A search plan then runs against the private index. For file-grounded answers, a second model pass receives only bounded ranked paths and excerpts. Indexed text is treated as untrusted evidence; chat-control markers are neutralized and the model is explicitly instructed not to follow instructions found in excerpts.

### Source layout

```text
Local Assistant/
├── Config/                       # Dependency, model, and privacy manifests
├── LocalAssistant.xcodeproj/     # Native project and numeric bundle metadata
├── LocalAssistant/
│   ├── Application/              # Lifecycle, state, shortcut, and service graph
│   ├── Constants/                # Shared interface and implementation copy
│   ├── DesignSystem/             # Layout, color, motion, and depth tokens
│   ├── Domain/                   # File, search, scoring, and conversation models
│   ├── FileAccess/               # Read-only bookmarks, scanning, and exclusions
│   ├── Extraction/               # Text, Office, PDF, Pages preview, and OCR
│   ├── Indexing/                 # Incremental extraction and embeddings
│   ├── Persistence/              # SQLite, FTS5, sqlite-vec, and conversation history
│   ├── Retrieval/                # Hard filters, hybrid ranking, and explanations
│   ├── Inference/                # Routing, prompts, llama.cpp, and grounding
│   ├── Voice/                    # Recording and local transcription
│   ├── Features/                 # Assistant, activity history, result cards, and Settings
│   ├── Security/                 # Private application-container directories
│   ├── Resources/                # Icon, property list, and sandbox entitlements
│   └── VendorBridge/             # Static native-library bridges
├── LocalAssistantTests/          # Automated tests for routing, retrieval, and exclusions
├── Patches/                      # Offline modifications applied to pinned dependencies
├── Scripts/                      # Preparation, installation, build, audit, and patch tools
├── Vendor/                       # Recreated pinned dependencies; excluded from Git
└── outputs/                      # Generated offline transfer kit; excluded from Git
```

## Troubleshooting

### Why does Settings say a feature is not installed or damaged?

Open **Settings → Models**. **Not installed** means the model files are absent, so install the verified offline model package. **Damaged** means a file no longer matches the checksum recorded at installation, so reinstall the package to replace it. Do not add runtime network access as a repair for either state.

### Why is an authorized folder unavailable?

Its bookmark may be stale, its volume may be disconnected, or macOS may be denying access. Revoke the folder in Settings, then select it again through the macOS folder picker.

### Why can a saved result card no longer open its file?

The file may have moved, been deleted, fallen out of the current index, or belonged to a revoked folder. Update the relevant index or authorize its folder again. The application deliberately refuses to open a stale saved path.

### Why does a file have no searchable text?

The file may be unsupported, encrypted, excluded, too large, or may have failed extraction. It can still be discoverable by name, path, type, or metadata.

### How can broad search results be narrowed?

Include a topic, filename fragment, folder, date, or file type. A singular underspecified request should produce a follow-up question instead of an arbitrary result.

### What should I do if indexing fails?

Confirm that the folder remains readable and File search is ready in Settings, then choose **Update Index**. Preserve any macOS crash report together with the triggering folder and file type.

### Why are automatic updates paused or unavailable?

Choose **Resume Automatic Updates** for the folder in Settings. If monitoring remains unavailable, confirm that the folder or external volume is present and readable, then revoke and authorize it again if its macOS bookmark is stale.

### Why is the quick-call shortcut unavailable?

Another application may already own `⌃⌥Space`. Quit or reconfigure the conflicting application, then relaunch Local Assistant.

### Why does voice input not start?

Confirm that microphone permission is allowed and that **Settings → Models** reports Voice input as ready. Voice input is reported unavailable when the `openai_whisper-small` directory is incomplete, including a missing `tokenizer.json` or `tokenizer_config.json`; reinstall the verified offline model package to restore it. Recording begins immediately, but the first transcription of a session waits for the speech model to finish loading.

### Why does offline package resolution fail?

Return to the connected preparation phase and rerun `prepare_offline_bundle.sh`. Do not temporarily enable networking on the disconnected destination to let Xcode resolve a missing package.

## Boundaries and limitations

### Privacy and security boundaries

These boundaries are product requirements rather than optional settings:

- **No application network access.** The signed application must not have network client or server entitlements.
- **No runtime downloads.** Required models and frameworks must already exist on the destination Mac. Dependency code that could download or observe the network is removed from the vendored source and the removal is verified during preparation, so the guarantee does not rest on a configuration flag.
- **Read-only source access.** Folder bookmarks are application-scoped and request read-only access.
- **Explicit authorization.** The application can read only folders selected through the macOS folder picker and allowed by the operating system.
- **Revocable access.** Revoking a folder removes its bookmark and dependent private index records without changing the source folder.
- **Private writes only.** The database, model assets, conversation history, and temporary voice recordings remain inside the application sandbox.
- **No source-file mutation.** The application does not create, edit, rename, move, or delete files in authorized folders.
- **Explicit external actions.** A result opens or appears in Finder only after the corresponding button is pressed, after its current symlink-resolved target is confirmed inside the authorized root.

macOS remains the final authority. A bookmark cannot bypass system permissions, encryption, Data Vault protections, or an unavailable external drive.

### Current limitations

- Every searchable root must be selected explicitly; the application cannot silently read the whole disk.
- Search quality depends on successful extraction and indexing.
- Semantic search currently embeds extracted text, not image pixels. An unlabeled chart or photograph with no useful OCR or surrounding text cannot be identified reliably by its visual appearance alone.
- Chat and semantic search require verified local model assets.
- Voice input requires the complete local speech model and macOS microphone permission.
- Office and Pages extraction is intentionally best-effort.
- Automatic refresh runs only while the application process is running; quitting stops every folder watcher until the next launch-time catch-up scan.
- The global shortcut is fixed and works only while the application process is running.
- Built-in conversational knowledge may be incomplete; file-specific answers remain bounded by displayed evidence.
- The only optional network boundary is the separately packaged OpenClaw connector. Local Assistant has no direct Feishu, CloudBase, calendar, email, or general internet client.

Preparation tools may use the internet on a trusted staging Mac, but they are not packaged or invoked by the runtime application. For an app-only physically offline deployment, prepare and verify all assets first, transfer them using trusted media, disconnect the destination Mac, and then install and use Local Assistant without enabling OpenClaw. The optional connector requires a separately approved private network route to the OpenClaw server.

## License

No project-level license has been assigned. Each dependency and model retains its own license and attribution requirements; review them before redistribution.
