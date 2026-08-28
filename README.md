# Local Assistant

> A private macOS assistant for local conversation, file search, and reminder knowledge.

Local Assistant runs on one Mac and keeps its main application offline. It can:

- answer ordinary questions with an embedded local model;
- search only folders the user authorizes;
- understand text, Office files, PDFs, and text recognized inside images (OCR);
- accept typed or spoken requests; and
- answer reminder questions from a local copy of the CloudBase reminder list.

OpenClaw is optional and remains outside the app:

- Reminder reads stay local.
- Reminder changes require an in-conversation confirmation.
- Other OpenClaw tasks require the user to say `OpenClaw` or `Open Claw`.
- Authorized requests use Agent-to-Agent (A2A) v1.0 through a separate Connector that starts only
  when needed and exits after the request.
- Only the exact submitted message is sent; files, reminder rows, and conversation history are not attached.

## Quick start

Use the installed application for normal work. The source-build section is only for developers preparing an offline release.

### Use the installed application

1. Open **Local Assistant**.
2. In **Settings**, choose **Add Folder** and select what the app may read.
3. Type a request, click to speak, or hold Space to talk.
4. Review the answer and result cards. Files open only after an explicit action.
5. Use **History** for earlier conversations and results.

### OpenClaw connector setup

Open **Settings → OpenClaw Connection → Open Setup**. The guide opens the matching
`OpenClaw Connector.app` and walks through five steps.

What is required:

- the server address and port already used for Secure Shell (SSH) login;
- an administrator account that can open the OpenClaw server terminal;
- the Connector public key and server ZIP created on the Mac; and
- the server host key and two secret access tokens printed by the server installer.

No Python, Git, VPN, public Gateway, or permanent tunnel is required on the Mac.

#### Connector step 1 — Identify the existing SSH server

- Enter the server name or numeric IP address used for SSH administration.
- Enter the SSH port, normally `22`.
- Confirm the same address and port work in the existing administrator login.

#### Connector step 2 — Create both server files

- Choose **Create Key and Save Public Key…**.
- Choose **Create Server Setup ZIP…**.
- Save both files in the same folder.

The private key stays on the Mac. The ZIP contains no credentials or application source.

#### Connector step 3 — Transfer both files and run setup

Transfer both files to the OpenClaw owner's home folder. Then run these commands on the OpenClaw
server as the account that owns OpenClaw:

```bash
cd "$HOME"
unzip -o "OpenClaw Server Setup.zip"
cd "OpenClaw Server Setup"
./setup-server.sh "$HOME/local-assistant-connector.pub"
```

The installer:

- keeps OpenClaw reachable only from the server itself;
- installs the reminder snapshot and A2A routes;
- creates a restricted connection account with no shell access; and
- prints **SERVER SETUP COMPLETE** when verification succeeds.

#### Connector step 4 — Enter the completed server values

After **SERVER SETUP COMPLETE**, copy these printed values into the Connector:

- the complete SSH host-key line printed by the installer, which identifies the server;
- the reminder bridge token, which permits read-only snapshots; and
- the OpenClaw operator token, which permits A2A requests.

The Connector fills the restricted username automatically.

#### Connector step 5 — Save and verify

- Enter the server values and two tokens.
- Choose **Save and Verify Connector**.
- Wait for the success message above the button.
- Close the Connector manually.

Verification checks the reminder snapshot and A2A service description through one temporary
encrypted SSH connection. The connection closes after the check.

#### Finish in Local Assistant — enable and refresh

- Return to **Settings** and enable **OpenClaw connection**.
- Choose a two-, four-, or eight-hour reminder refresh schedule.
- Select **Refresh Now** once.

The Connector also runs briefly when a request is queued, after wake when a refresh was missed,
and after a confirmed reminder change. A failed refresh keeps the last complete local snapshot.

### Keyboard shortcut

Press **Control–Option–Space** (`⌃⌥Space`) while the app is running to bring its window
forward. Closing the window keeps the shortcut available; quitting the app disables it.

### Example requests

| Request | Expected behavior |
|---|---|
| `Hello` | Gives a local conversational answer without file cards. |
| `What is a PDF?` | Answers from the local model without searching files. |
| `Show me PDFs` | Shows only indexed PDF cards without repeating their names or paths in the answer. |
| `Find the automotive consulting PDF` | Filters to PDFs, then finds the most relevant topic match. |
| `Which PDF?` | Requests a topic, filename, folder, or date instead of guessing. |
| `Find the latest budget spreadsheet` | Filters to spreadsheets, then combines word, meaning, and date matches. |
| `Find my school files` | Finds the School folder and shows relevant items inside it. |
| `What reminders are due tomorrow?` | Uses the latest local reminder snapshot, including deadline and meaning matches. |
| `Create a reminder to renew the permit tomorrow at 09:00` | Asks for confirmation, then sends only that exact submitted request to OpenClaw. |
| `Delete the permit reminder` | Asks for confirmation before sending the exact request; saying OpenClaw is not required for a clear reminder change. |
| `OpenClaw, delete the permit reminder` | Still asks for confirmation because every reminder change is confirmation-gated. |
| `OpenClaw, add this to CloudBase only` | Lets OpenClaw apply the explicit CloudBase-only instruction instead of its normal paired reminder behavior. |
| `OpenClaw, summarize today's weather plan` | Sends the exact non-reminder request to OpenClaw through A2A. |

## How local RAG works

RAG means **Retrieval-Augmented Generation**. The app first finds relevant local evidence, then
gives only that evidence to the local language model for the answer.

```text
Your question
   ├─→ FTS5 finds matching words
   └─→ sqlite-vec finds similar meaning
              ↓
       combined local evidence
              ↓
       local model writes the answer
```

The pieces have separate jobs:

- **Embedding model:** converts text into a list of numbers called a vector.
- **Vector:** a numerical representation of the text's meaning.
- **FTS5:** SQLite's full-text search for matching words and phrases.
- **sqlite-vec:** stores and compares vectors to find text with similar meaning.
- **RAG:** retrieves the best evidence and supplies it to the local model.

Files and reminders use this same local pattern. Reminder deadlines also contribute to ranking.
OpenClaw is not contacted for RAG questions.

The app stores its index in relational SQLite tables. The SQLite engine is part of the app, but
the user's `assistant.sqlite3` data file is created separately inside the private app sandbox.

---

### Build and install from source

<details>
<summary>Developer: show offline build and installation steps</summary>

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

</details>

## Release notes

### Current release status

The current source release is **v4.9 (build 49)**. The application, Connector, documentation, and
release package are complete. Live multilingual voice review, full disconnected runtime
observation, and visual screen inspection remain manual checks.

<details>
<summary>Detailed build, test, privacy, and release evidence</summary>

| Release area | v4.9 status | Meaning |
|---|---|---|
| Approved scope | Complete | A repository-wide review pass corrected result-ordering determinism, connector start-up resilience, the cross-language error contract, constant centralization, dead code, access-modifier consistency, retrieval calibration constants, and documentation completeness. No user-facing copy or layout changed. |
| Source implementation | Complete | Ranked file results and folder-scope matches now use a total order instead of dictionary order. An unparseable connector claim filename is skipped rather than raising out of service start-up. The eight exact connector error strings are named constants citing `constants.py`. Connector runtime advances to v1.9.0; server bridge v1.4.0 and runtime contract v3 are unchanged because no wire contract changed. |
| Documentation | Complete | The release status, version index, and change log record v4.9 and separate the phases that ran from those that did not. |
| Debug compilation | Complete | Local Assistant and the standalone Connector compile at v4.9. A `private`-scope regression introduced during the pass was caught by this build and corrected to `fileprivate`. |
| Release build | Complete | The clean offline build produced signed v4.9 build 49 copies of Local Assistant and OpenClaw Connector plus the refreshed clean-Mac disk image. |
| Automated tests | Complete | The complete macOS target reports 137 tests passed, 0 failed, 0 skipped, up from 128 after nine were added for indexing runs and bounded archive extraction. Each new case was confirmed to fail against a deliberate regression before being relied on. All 40 Connector tests and their 10 subtests passed against this checkout's source. |
| Voice runtime testing | Pending manual check | Automated state tests cover silence submission in both modes; live multilingual recognition still requires manual inspection. |
| Focused testing | Complete | Project-root and mounted applications both report v4.9 build 49 and pass strict deep signature validation. The frozen Connector runtime was extracted from its PYZ archive and confirmed to carry this release's source: five constants added by the pass are present, nine removed constants are absent, and the recovery guard is in the packaged bytecode. |
| Disconnected runtime testing | Not run | The v4.9 application has not been exercised with every network interface disabled. |
| Static privacy audit | Complete | The project-root bundle passed the offline-boundary audit: the sandbox retains no network entitlement and the executable links no forbidden networking library. The audit reports `huggingface.co` as an unreachable compiled-in string with no reachable code path. |
| Runtime smoke check | Complete | The built v4.9 application launched from the project root, loaded its local models, opened the live index, and ran for over ninety seconds with no crash report. `pragma quick_check` on the index returned `ok` afterwards. |
| Interface inspection | Complete | The maintainer inspected the built v4.9 screens directly. Automated capture stayed unavailable because macOS withheld Screen Recording and Accessibility from the automation process, and no permission boundary was widened to work around that. |
| Code review | Complete | An exhaustive pass covered the project's complete first-party code through the reuse, simplification, efficiency, and architectural-placement lenses, the full style rule set, and the exposure audit. A follow-up round closed the two gaps the first round left: the efficiency lens, which found the duplicated stale-item read and the per-file commit at scan start, and end-to-end reading of the remaining files, which found the unbounded archive entries and the schema's restated embedding width. Mechanical rules were re-verified across all 113 Swift files afterwards: none over 800 lines, no missing access modifier, and no missing documentation block. |
| Known limitation | Resolved | The former limitation was `IndexingService.index` at 245 lines with no test coverage, because the service required a concrete `LlamaCppRuntime` and its multi-gigabyte models. Indexing now depends on a `DocumentEmbedding` protocol, seven end-to-end run tests cover the pipeline, and `index` is 47 lines. Fourteen functions elsewhere still exceed 50 lines; each was measured for branch count and nesting and none is a comparable outlier, so they are recorded rather than split. |
| Formal verification | Not run | Runtime socket inspection and full disconnected acceptance remain separate. |
| Release artifact integrity | Complete | The disk image mounts, contains only the two v4.9 build 49 applications plus the Applications link, both signatures validate deeply, and its SHA-256 is `f2dbf513662147191cc07a793f1cf59fda84890b8aa3436c8caa4a85e8f4ac87`. |

</details>

### Version index

<details>
<summary>Complete version history (v4.8 to v0.1)</summary>

The entries below preserve the full release record. They are collapsed so current setup and
architecture remain easy to scan.

The table and notes below are the durable record of what each release contained. Only the
current project-root release set is retained; rebuilding never leaves a previous copy. Each
entry names what that release changed and links to its full notes.

Marketing-version minor numbers run from `0` through `9`. After `vN.9`, the next
release is `v(N+1).0`; the separate integer build number continues increasing by one.

| Version | What changed |
|---|---|
| v4.9 | [Deterministic retrieval and connector resilience](#v49--deterministic-retrieval-and-connector-resilience) |
| v4.8 | [Responsive setup and consistent result cards](#v48--responsive-setup-and-consistent-result-cards) |
| v4.7 | [Private A2A connection to OpenClaw](#v47--private-a2a-connection-to-openclaw) |
| v4.6 | [Responsive native Markdown responses](#v46--responsive-native-markdown-responses) |
| v4.5 | [Natural confirmation, centered processing, and dependency security](#v45--natural-confirmation-centered-processing-and-dependency-security) |
| v4.4 | [Conversational reminder confirmation and runtime compatibility](#v44--conversational-reminder-confirmation-and-runtime-compatibility) |
| v4.3 | [Natural reminder routing and responsive result cards](#v43--natural-reminder-routing-and-responsive-result-cards) |
| v4.2 | [Content-height Local Assistant setup cards](#v42--content-height-local-assistant-setup-cards) |
| v4.1 | [Unified connection review and content-height setup cards](#v41--unified-connection-review-and-content-height-setup-cards) |
| v4.0 | [Credential-safe Connector updates and cleanup](#v40--credential-safe-connector-updates-and-cleanup) |
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

### v4.9 — Deterministic retrieval and connector resilience

- Gives ranked file results and folder-scope matches a total order. Both previously sorted a
  dictionary by one score key, so equally scored files could differ between launches for the
  same request, and folder scoping could restrict results differently each time.
- Skips a connector claim filename the runtime cannot parse instead of raising out of service
  start-up, which previously stopped every later connector run until the file was removed by
  hand. A new focused test covers the recovery and fails without the fix.
- Replaces the eight exact connector error strings that the app and Connector matched as bare
  literals with named constants citing `constants.py` as their source of truth.
- Routes reminder retrieval explanations, the schedule-document keys, the JSON suffix, and the
  POSIX locale identifier through the existing constant files.
- Removes 34 unreferenced Swift constants, the emptied `DesignTokens.Shadow` group, and nine
  Connector constants orphaned when A2A replaced the chat-completions transport.
- Adds explicit access modifiers to 57 test declarations and one runtime method, and aligns the
  single outlier extension with the house convention.
- Stops tracking the QWeather Ed25519 private-key path in the OpenClaw workspace and adds a
  committed example alongside it. No key material was ever committed.
- Names the five remaining retrieval calibration numbers. The exact-name and name-contains
  weights sat inline beside three sibling constants, and `explanation` compared against the same
  literal `addMetadata` assigned, so the two could silently diverge; one constant now drives both.
- Completes 64 documentation blocks on helpers across the reminder services, the spool service,
  the Connector model and setup view, app directories, the reminder database extension, grounded
  inference, indexing activity, and six test helpers, so every function in the project now carries
  the parameter and return documentation the standards require.
- Holds the security-scoped read session across the Finder reveal and open calls with
  `withExtendedLifetime`, reusing the idiom already used in `FolderMonitorService`, instead of
  a trailing `_ = resolved.access` the optimizer is free to discard.
- Collapses two identical branches in the connector's claim recovery, removes redundant
  `case .x(_)` bindings in three switches, and clears the blank-line residue left by the
  removed `DesignTokens.Shadow` group.
- Splits the two Connector files that exceeded the 800-line limit into
  `ConnectorSetupModel+Runtime.swift` and `ConnectorSetupView+Components.swift`, following the
  existing `AssistantDatabase+*` and `SettingsView+*` pattern. Every first-party Swift file is
  now inside the limit, with 744 lines the largest.
- Advances Local Assistant and OpenClaw Connector to v4.9 build 49 and Connector runtime v1.9.0.
  Server bridge v1.4.0 and runtime contract v3 are unchanged because no wire contract changed.
- Puts the indexing pipeline under test by depending on a new `DocumentEmbedding` protocol
  instead of the concrete embedding service. `IndexingService` previously required a
  `LlamaCppRuntime` with multi-gigabyte models loaded, so no focused test could construct it and
  its 245-line `index` could not be split safely. Seven end-to-end run tests now cover the first
  scan, unchanged and modified files, removal, a recoverable per-file failure, a fatal model
  failure, and oversized-passage splitting; each was confirmed to fail against a deliberate
  regression before being relied on.
- Splits that 245-line `index` into an error boundary plus named passes — `startingRun`,
  `performRun`, `beginRun`, `recordUnchangedFile`, `indexChangedFile`, `announceFileStart`,
  `recordSkippedFile`, and `finishInterruptedRun` — and collapses the two identical skip-handling
  branches into one. `index` is now 47 lines and no function in the folder exceeds 50. The record
  and progress builders moved to `IndexingService+Records.swift` so the file stays inside the
  800-line limit.
- Stops re-reading every indexed row for a folder on each run. `pruneItems` re-derived a stale
  list the run had already computed in its scan pass; it now takes that list directly.
- Commits a run's opening per-file classifications in one transaction instead of one durable
  write per file, which dominated the start of a large scan.
- Bounds decompressed ZIP entries in the Office and Pages extractors. The plain-text path already
  capped file size, but both archive paths accumulated an entry into memory with no limit, so a
  small container declaring an enormous entry could exhaust memory.
- Derives the two vector-table widths in the SQL schema from `embeddingDimensions` rather than
  restating `1024`, so the schema cannot silently disagree with the dimension the code enforces.
- Names the remaining bare numbers in logic code: the FSEvents coalescing latency, the connector
  spool read-chunk size, the recency decay day, the activity ordering nudge, the startup detail
  width, and the connector's authentication HTTP statuses, which sat inline beside an already
  named retryable set.
- Discards the `NSWorkspace.open` result explicitly so the `withExtendedLifetime` reveal fix no
  longer emits an unused-result warning.
- Passed all 137 macOS tests (up from 128) and all 40 Connector tests with their 10
  subtests, the clean offline release build, strict project-root and mounted signature and
  version checks, the offline-boundary audit, disk-image verification, and a maintainer-run
  inspection of the built screens.

### v4.8 — Responsive setup and consistent result cards

- Simplifies the README and architecture guide around local routing, reminder RAG, the one-shot
  SSH boundary, and A2A delegation.
- Labels A2A directly in the architecture flow and explains that embedded SQLite is relational,
  while the database file remains separate from the application bundle.
- Adds a beginner glossary and local RAG diagram, shortens troubleshooting, and collapses
  developer-only build, test, and implementation details.
- Gives every required Connector action a prominent full-width treatment and makes the public key
  and server ZIP equally recognizable as separate required files.
- Replaces compact Mac/server pills with full-width location banners and restructures wide setup
  cards into instructions beside actions, with help sections below and one-column fallback.
- Keeps the Connector open after both verification paths and leaves a clear success or failure
  message directly above the owning button until the user closes the window.
- Reorders OpenClaw Settings around enablement, health, schedule plus immediate refresh, setup
  maintenance, and optional request behavior. Explanations use readable callout text.
- Reuses the History file-and-folder result cards on the main command screen, preserving the
  adaptive grid while removing the weaker duplicate presentation.
- Advances Local Assistant and OpenClaw Connector to v4.8 build 48. Connector runtime v1.8.0 and
  server bridge v1.4.0 remain unchanged because no transport contract changed.
- Passed all 128 macOS tests, all 39 Connector tests, all 12 OpenClaw plugin tests, and all 5
  typed reminder-bridge tests. The clean release build, installed and mounted version and
  signature checks, offline-boundary audit, responsive installed-screen inspection, and disk-image
  verification also passed.

### v4.7 — Private A2A connection to OpenClaw

- Replaces the Connector's direct Chat Completions transport with A2A v1.0 Agent Card discovery
  and JSON-RPC `SendMessage` while preserving the exact submitted text and stable conversation
  identity.
- Adds two Gateway-authenticated loopback routes to server bridge v1.4.0. The existing dedicated
  reminder snapshot route and Calendar-unchanged proof remain separate and unchanged.
- Keeps Local Assistant offline, keeps OpenClaw on `127.0.0.1:23116`, and opens only the existing
  one-request restricted SSH tunnel. No VPN, public Gateway, public HTTPS origin, or permanent
  tunnel is added.
- Advances Local Assistant and OpenClaw Connector to v4.7 build 47, Connector runtime v1.8.0, and
  runtime contract v3. Existing users create and run a fresh server setup ZIP once before
  verifying the updated Connector.

### v4.6 — Responsive native Markdown responses

- Expands the current answer and retained assistant History content with the live app window instead of keeping the old fixed-width answer column.
- Presents common block Markdown as native SwiftUI headings, paragraphs, emphasis, lists, quotations, fenced code, dividers, and real table cells. OpenClaw pipe tables no longer appear as raw `|` and `---` text.
- Keeps response links inert and adds no WebView or network presentation dependency, preserving the Local Assistant privacy boundary.
- Advances Local Assistant and OpenClaw Connector to v4.6 build 46. Connector runtime v1.7.0 and OpenClaw server bridge v1.3.0 remain unchanged because neither transport contract changed.
- Passed five focused parser cases, the clean release build, source/installed/mounted version and signature checks, the signed-bundle privacy audit, installed restored/expanded response inspection, and disk-image verification.

### v4.5 — Natural confirmation, centered processing, and dependency security

- Accepts clear standalone instructions such as continue, proceed, go ahead, send it, do it, okay, sure, or cancel without requiring the literal words yes or no. The embedded local LLM remains the interpreter for other natural replies, while ambiguous or changed requests stay pending.
- Centers the processing label and progress bar in the full available assistant workspace instead of placing them near the top of the result scroller.
- Replaces the Connector package's vulnerable setuptools build backend with pinned Hatchling 1.27.0 because the patched setuptools release identified by the alert is not available from the package index. Editable installs and standalone packaging remain supported.
- Advances Local Assistant and OpenClaw Connector to v4.5 build 45 and the Connector runtime package to v1.7.0. The OpenClaw server bridge remains v1.3.0 because its read-only snapshot contract did not change.
- Focused confirmation, dependency, packaging, release, installed-interface, and disk-image results are recorded in the release-status table after they run.

### v4.4 — Conversational reminder confirmation and runtime compatibility

- Replaces the reminder-mutation confirmation alert with an assistant conversation turn that repeats the exact pending request and asks for a yes-or-no reply.
- Uses the embedded local LLM to classify that reply as confirm, decline, or unclear. Only the exact confirmation result authorizes the pending request; unclear replies keep it pending and ask again.
- Presents reminder-request failures, cancellation, and recovery guidance as assistant messages instead of separate dialogs. A failed mutation remains pending so the user can retry without reconstructing it.
- Adds a non-secret Connector runtime contract version to the owner-only status file. Local Assistant reads it again at confirmation time and directs an older runtime to **Update and Verify Existing Connector** before any incompatible request is published.
- Advances Local Assistant and OpenClaw Connector to v4.4 build 44 and the Connector runtime package to v1.6.0. The OpenClaw server bridge remains v1.3.0 because its read-only snapshot contract did not change.
- Focused confirmation and runtime-contract tests, Connector regression tests, release building, installed-flow inspection, and disk-image validation are recorded in the release-status table.

### v4.3 — Natural reminder routing and responsive result cards

- Recognizes clear reminder and to-do phrasing without requiring the user to say OpenClaw. Read-only list and question requests use the complete local reminder cache and RAG index without confirmation or Connector access.
- Requires explicit confirmation for every reminder create, update, complete, reschedule, or remove request, including requests that name OpenClaw. After confirmation, only the exact submitted text and its typed authorization enter the Connector.
- Returns every cached reminder for an all-reminders request without a presentation cap, keeps both current and retained History prose concise, groups cards by tag with one heading per group, and shows one reminder per equal-height styled card with a semantic icon, urgency, date/time, and an optional link indicator.
- Makes reminder cards, file/folder findings, Settings, Activity, History, and other applicable collections adapt their columns and available space live as the window changes size, without fixed whole-screen margins or unnecessary lower gaps.
- Restores automatic submission after about two seconds of silence in both voice modes while preserving immediate Hold Space release.
- Advances Local Assistant and OpenClaw Connector to v4.3 build 43 and the Connector runtime package to v1.5.0. The OpenClaw server bridge remains v1.3.0 because its read-only snapshot contract did not change.
- Focused tests, release building, signed-artifact checks, privacy audit, installed-screen inspection, and disk-image validation are recorded in the release-status table after they run.

### v4.2 — Content-height Local Assistant setup cards

- Removed the fixed 184-point minimum height from the shared card used by Local Assistant's three-step OpenClaw guide.
- Made Steps 2 and 3 end after their visible text and controls while retaining equal widths, consistent padding, and the existing card surface.
- Removed the now-unused setup-card minimum-height design token.
- Added a project guardrail requiring screenshot-reported layout defects to be verified in the exact installed application and screen shown, not in a visually similar companion screen.
- Advanced Local Assistant and OpenClaw Connector to v4.2 build 42 so the release package continues to contain matching applications.
- Passed the complete Local Assistant macOS test target, all 35 Connector tests, the clean offline Release build, strict source and installed-bundle signature checks, the signed-app privacy audit, exact installed-screen visual inspection, and mounted disk-image validation.

### v4.1 — Unified connection review and content-height setup cards

- Replaced the duplicate **Review Connection Settings** and **Replace Saved Credentials** overview routes with one full-width **Review Connection** action.
- Kept **Replace Saved Credentials** inside Step 4 beside the saved Keychain status, so credential changes begin only where the two secure fields belong.
- Removed the Connector layout rail from card measurement and made every Connector setup card content-height, eliminating excess lower whitespace in its Steps 2 and 3 while retaining equal widths and semantic colors.
- Replaced setup discovery's credential-value read with a bounded macOS Keychain metadata query. Startup receives only presence booleans, cannot wait indefinitely for Keychain metadata, and still loads a token only when an authenticated request actually needs it.
- Advanced Local Assistant and OpenClaw Connector to v4.1 build 41.
- Defined marketing-version minor numbers as `0` through `9`, with `vN.9` followed by `v(N+1).0`; the build number remains a separate increasing integer.
- Added a release-package guard that stops the build when Local Assistant and OpenClaw Connector versions or build numbers differ.
- Passed the 6 focused Keychain and existing-setup tests, clean offline Release build, strict source and installed-bundle signature checks, signed-app privacy audit, installed-app visual inspection, and mounted disk-image validation.

### v4.0 — Credential-safe Connector updates and cleanup

This is the corrected historical release label for build 40. The original build-40
applications were stamped `3.10`; that immutable bundle metadata and the existing Git
history are not rewritten.

- Added credential-free discovery of an existing Connector installation. The Swift app receives only reusable public server values and yes/no Keychain-presence flags; it never retrieves or displays saved tokens.
- Added **Update and Verify Existing Connector**, which installs the current packaged runtime, reuses the saved SSH identity, configuration, and Keychain tokens, verifies a real complete snapshot, and restarts the one-shot job without asking the user to repeat setup.
- Separated **Replace Saved Credentials** from public settings review. New tokens enter through empty secure fields, move to Keychain through bounded standard input, and are cleared from Swift immediately after secure handoff even if later verification fails.
- Added confirmed **Remove Connector Data**, which deletes the exact Connector runtime, identity, settings, checkpoint, launch job, pending spool lanes, and two Keychain entries while preserving Local Assistant and its committed reminder cache and RAG index.
- Replaced the dense Connector form with a light-only semantic-color workbench: blue identifies server values, cyan identifies generated files, orange identifies server actions, teal identifies credentials and privacy, green identifies verification, and red is reserved for destructive cleanup.
- Rewrote every primary step for a first-time user who knows only how to open Mac Terminal and the server terminal. Required actions and completion cues remain visible; definitions, security details, alternatives, internal port details, and Q&A recovery remain collapsed under the step that owns them.
- Corrected the release record to v4.0 build 40 and retained Connector runtime package v1.4.0. The original applications remain stamped `3.10`, and the OpenClaw reminder bridge remains v1.3.0 because its server contract did not change.
- Passed the complete Local Assistant Xcode test target, all 32 Connector tests, all 7 OpenClaw plugin tests, all 5 typed reminder-bridge tests, the clean offline Release build, strict bundle-signature checks, the signed-app privacy audit, installed-app visual inspection, and mounted disk-image validation.

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
- The clean-built and installed executables are byte-identical with SHA-256 `842ba0f9e02c3797f342a45703ba1055f0a5342521c1156b40d110fdaf1a6c3c`.
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

</details>

## Product reference

<details>
<summary>Detailed capability and file-format reference</summary>

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

</details>

## Architecture and project structure

### Request flow

Every request is classified locally:

- **Conversation:** embedded model → local answer.
- **File request:** private index → grounded answer and result cards.
- **Reminder read:** local reminder cache/RAG → answer or reminder cards.
- **Reminder change:** local confirmation → one-shot Connector → A2A → OpenClaw.
- **Other OpenClaw task:** explicit `OpenClaw` wording → one-shot Connector → A2A → OpenClaw.

### How A2A is used

A2A v1.0 is the Connector's standard protocol for OpenClaw agent work:

- It discovers and validates OpenClaw's Agent Card.
- It sends every delegated conversation with the standard A2A `SendMessage` operation.
- It carries confirmed reminder changes and explicit non-reminder OpenClaw requests.
- It preserves a stable conversation context without attaching local files or history.

Reminder snapshot synchronization does not use A2A. It remains a separate complete, read-only
route with its own credential.

Only bounded evidence reaches the local grounding pass. Indexed content is treated as data, never
as an instruction.

### Source layout

<details>
<summary>Source directory map</summary>

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

</details>

## Troubleshooting

### Why does Settings say a feature is not installed or damaged?

Open **Settings → Models**:

- **Not installed:** install the verified offline model package.
- **Damaged:** reinstall the package because a model file failed its integrity check.

The app cannot download a replacement itself.

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

- Confirm that macOS microphone permission is allowed.
- Confirm that **Settings → Models** reports Voice input as ready.
- If it is unavailable, reinstall the verified offline model package.

The first transcription may wait briefly while the local speech model loads.

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

For a physically offline installation:

1. Prepare and verify all assets on a trusted connected Mac.
2. Transfer them using trusted media.
3. Disconnect the destination Mac.
4. Install and use Local Assistant without enabling OpenClaw.

The optional Connector requires an approved route to the OpenClaw server.

## License

No project-level license has been assigned. Each dependency and model retains its own license and attribution requirements; review them before redistribution.
