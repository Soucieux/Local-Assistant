# Architecture

## Runtime boundary

Local Assistant has two separate runtime boundaries.

**Offline application**

- Runs the interface, local models, file search, OCR, voice, SQLite, and reminder RAG.
- Reads only user-authorized folders.
- Has no network entitlement, web view, server, telemetry, or updater.

**Optional OpenClaw Connector**

```text
Local Assistant → owner-only spool → one-shot Connector → pinned SSH tunnel
                                                        ├─→ A2A v1.0
                                                        │   Agent Card + SendMessage
                                                        │   → OpenClaw agent and tools
                                                        └─→ read-only reminder snapshot
                                                            → CloudBase reminders
```

- **Reminder lane:** fetches a complete read-only snapshot with its own token.
- **A2A lane:** handles every delegated OpenClaw conversation and every confirmed reminder
  change. It validates the Agent Card, then sends the exact message with JSON-RPC `SendMessage`.
- Every tunnel closes after its request.
- Files, reminder rows, the database, and conversation history are never attached.

<details>
<summary>Detailed runtime and data flow</summary>

Local Assistant's trusted core is one sandboxed macOS application process. It has no HTTP server, localhost service, database daemon, cloud API client, updater, telemetry client, web view, network client entitlement, or network server entitlement. An optional, separately installed companion app packages the Python and LangGraph connector runtime outside the Local Assistant bundle and outside this core trust boundary. The app communicates with that process only through a bounded owner-only file spool after the user enables the connector in Settings.

```text
User-selected folders
read-only security-scoped bookmarks
                │
       native macOS FSEvents
  while the app process is running
                │
                ▼
       Read-only scanner
                │
     ┌──────────┴──────────┐
     ▼                     ▼
Metadata and hashes   Local extraction
                      Text / Office XML
                      PDFKit / Vision OCR
     │                     │
     └──────────┬──────────┘
                ▼
       Source-aligned chunks
                │
                ▼
 Qwen3 Embedding via llama.cpp
                │
                ▼
Private embedded SQLite database
relational + FTS5 + sqlite-vec
                │
     ┌──────────┴──────────┐
     ▼                     ▼
Filename/path/FTS5     Vector neighbors
     └──────────┬──────────┘
                ▼
       Hybrid score fusion
                │
                ▼
 Ranked absolute paths and excerpts
                │
                ▼
    Qwen3 chat via llama.cpp
                │
                ▼
 Grounded answer + actionable matches
```

The reminder and OpenClaw path is deliberately separate:

```text
Sandboxed Local Assistant
        │ bounded schema-v1 JSON files
        ▼
Owner-only Connector/{Requests,Processing,Responses}
        │
        ▼
Separately packaged connector (Python + LangGraph + SQLite checkpoints)
        │ one pinned, on-demand SSH local-forwarding tunnel
        │ server destination fixed at 127.0.0.1:23116
        ├──────── read-only snapshot lane ────────┐
        │     dedicated Keychain token            ▼
        │     calendarPolicy="never"     OpenClaw reminder plugin
        │                                         │ complete list only
        │                                         ▼
        │                                CloudBase getReminderItems
        │
        └──────── authorized agent lane ──────────┐
              separate Keychain token             ▼
              exact submitted message      OpenClaw agent + its tools
```

The agent lane accepts either a non-reminder message with standalone `OpenClaw` or `Open Claw`, or a clear reminder mutation that Local Assistant records as explicitly confirmed by the user. Reminder reads never enter this lane. Every reminder create, update, complete, reschedule, or remove request becomes a conversational assistant turn that repeats the exact pending request. The embedded local LLM classifies the user's reply as confirm, decline, or unclear; only the exact confirm label authorizes transmission. No separate confirmation dialog is used. After confirmation, the connector sends the exact submitted message, a typed authorization, and a stable conversation identifier. It does not receive cached reminder rows, file-search content, conversation history, the SQLite database, arbitrary files, email, Feishu data, or any credential from the app. OpenClaw then applies its own reminder rules: its normal dated-reminder behavior may update CloudBase and iCloud Calendar, while an explicit CloudBase-only instruction limits the operation there.

Selected source files are never modified, and their security-scoped bookmarks remain read-only. Persistent application data stays in the private sandbox container. Local Assistant has no user-selected write entitlement. The separate Connector owns the user-approved ZIP and public-key destinations and is not embedded in or granted entitlements through the app. Its setup application installs the packaged runtime, writes the non-secret SSH configuration, stores credentials in Keychain, pins the server host key, and registers a one-shot per-user launchd job. On later releases, its bundled runtime returns only the public server values and yes/no credential-presence flags, so the Swift interface can update and verify an existing installation without retrieving either Keychain token. That discovery uses a bounded macOS Keychain metadata query with no password-output option; a missing item, unavailable command, or timeout becomes `false` instead of blocking startup. New tokens are accepted only through explicit replacement, transferred to the runtime through bounded standard input, and cleared from the Swift fields immediately after Keychain handoff. A queued request launches the job immediately; calendar checks support the chosen multi-hour reminder schedule and a missed check after wake. Every run closes its tunnel and exits.

</details>

## Conversation and search routing

Typed and transcribed requests are classified locally. The result is one of five paths:

- **Conversation:** answer with the embedded model.
- **Clarification:** ask one short question instead of guessing.
- **File search:** apply normalized terms and hard file-type filters to the private index.
- **Reminder read:** query the local reminder cache and RAG index.
- **Reminder change:** repeat the exact request and wait for confirmation.

The app invokes OpenClaw only when:

- the user confirms a reminder change; or
- a non-reminder request explicitly contains `OpenClaw` or `Open Claw`.

The routing pass sees recent local conversation but no file excerpts or reminder rows.

## Trust zones

### External read-only zone

Folders enter scope only through `NSOpenPanel`. `ReadOnlyAuthorizationService` creates app-scoped security bookmarks with read-only access. `SecurityScopedAccess` activates a bookmark only while the app needs it.

The scanner:

- does not follow symbolic links;
- skips hidden paths and package descendants;
- excludes configured system, cache, dependency, and build directories, matching the real system and cache locations by absolute path because a sandboxed process cannot identify them by name alone;
- excludes credential-like extensions before content extraction; and
- treats unreadable items as skipped rather than bypassing macOS controls.

`Open File` and `Reveal in Finder` are explicit user actions. Immediately before either handoff, the app resolves current symlink targets and rejects a target outside the active authorized root. It then hands the resolved URL to macOS; any external application operates under its own permissions.

### Private writable zone

The app creates owner-only content below:

```text
~/Library/Containers/com.soucieux.LocalAssistant/Data/Library/Application Support/LocalAssistant/
├── Connector/
│   ├── Requests/
│   ├── Processing/
│   └── Responses/
├── Index/assistant.sqlite3
└── Models/
```

The spool contains bounded task and response JSON only. It contains no token, remote origin, model credential, or unrestricted application state. The connector keeps only the validated non-secret SSH server address, port, restricted username, and public pinned host key in its own Application Support directory; the reminder-snapshot and full-operator tokens remain in separate macOS Keychain entries. Its owner-only LangGraph checkpoint database retains only connector workflow state and the task envelope. An agent task can therefore retain the exact submitted message and typed authorization, but never reminder rows, file-index content, or app conversation history. Confirmed Connector cleanup deletes those exact Keychain entries and the Connector directory while preserving the Local Assistant database, including the last committed reminder cache and RAG index.

SQLite WAL and shared-memory files may sit beside the database. Microphone audio is never written to disk: samples pass from the microphone into the speech model in memory, so a recording cannot outlive the request that produced it. A `Voice` directory left by a version that did store recordings is deleted at startup.

Revoking a root deletes its stored bookmark record and dependent private index rows. It does not alter the selected source folder. Indexing run and monitoring-event history remains in the private database until its rolling 30-day expiry or an explicit Clear Activity action.

### Network-denied zone

`LocalAssistant.entitlements` has App Sandbox enabled and contains neither `com.apple.security.network.client` nor `com.apple.security.network.server`. That entitlement set is what the operating system enforces, and it denies every outbound connection regardless of what the process attempts.

Connected preparation is confined to repository scripts run outside the app. The runtime never invokes those scripts. Enabling the connector does not change the app executable, entitlements, or linkage; the external connector is the only component allowed to open SSH and carry authenticated loopback Gateway requests inside that tunnel.

Configuration alone is not treated as sufficient. WhisperKit is configured with `download: false` and `useBackgroundDownloadSession: false`, and two capabilities are removed from the vendored source rather than switched off:

- its model-hub client started an `NWPathMonitor` whenever it was constructed, which observes network state before any request is made; and
- its tokenizer loader downloaded a missing tokenizer from a public model host, which is reached whenever the installed model folder lacks one.

Both are removed. Offline mode is unconditional and a caller cannot re-enable downloading; a missing tokenizer raises a reinstall instruction. The tokenizer ships inside the verified model package and is found in the installed model folder, so no cache directory outside the sandbox is consulted.

`Vendor/` is regenerated from pinned revisions and is not tracked in Git, so a modification made only there would disappear on the next checkout. The modified files are stored under `Patches/WhisperKit/` with the dependency revision they apply to. `Scripts/apply_offline_patches.py` refuses to run against a different pinned revision, restores the stored files, and then verifies that the required marker is present and that the removed constructs are absent from the resulting source. `Scripts/prepare_dependencies.py` invokes it after every checkout, so preparation fails rather than silently producing a network-capable build.

`Scripts/audit_offline_boundary.sh` closes the loop on the built product: it requires the sandbox, microphone, bookmark, and user-selected read-only entitlements, rejects every other entitlement, and inspects the application executable and every bundled executable for a linked networking library or an imported network symbol. The separate Connector owns its user-approved exports, so Local Assistant needs no write entitlement. Linkage is the strongest static signal available, because a binary that never links networking code cannot open a connection whatever unreachable source may still say.

## Persistence and retrieval

**Embedded SQLite** means the SQLite engine is linked into the app and runs in the same process.
The user's data is not baked into the application bundle; it is created as the private
`assistant.sqlite3` file inside the app's sandbox.

This is a **relational database**, not a document database. It uses tables, rows, columns, keys,
and transactions. Search extensions add full-text and vector indexes without changing that model.

The database provides:

- relational tables for authorized roots, indexed items, chunks, chat history, and activity;
- FTS5 indexes for names, paths, and extracted text;
- sqlite-vec indexes for 1,024-dimensional embeddings; and
- reminder snapshot rows, reminder search indexes, and last-sync metadata.

SQLite extension loading is not enabled. sqlite-vec is compiled into the application and registered on the existing connection.

CloudBase exposes neither an `updatedAt > lastSync` feed nor deletion tombstones. Reminder synchronization therefore always requests the complete owner-scoped list. The cache is reconciled inside one SQLite transaction only after the connector reports `status:"completed"`, `success:true`, a complete decodable array, unique valid identifiers, valid fields, and `calendarChanged:false`. A timeout, partial list, malformed row, failed embedding, or failed database write leaves the prior complete cache intact. Missing identifiers in a successful snapshot are deletions; no remote tombstone is needed.

Every cached reminder is read-only in Local Assistant regardless of ownership markers. The cache is not exposed as a browser or management screen. It is refreshed at launch when stale, on manual request, after a successful confirmed reminder mutation, and by the selected multi-hour launchd schedule. A scheduled result waits locally when the application is closed and is transactionally consumed at the next launch. The read-only plugin rejects exact reads and every create, update, or delete shape.

The database schema still contains selected prototype-era tables so an upgrade does not need a destructive migration. The current interface does not present collections, saved searches, aliases, file relationships, summaries, duplicates, or versions, and no runtime path reads them. Retrieval previously queried the empty alias table on every search, which cost a round trip and could never contribute to a score; the table is retained, the query is not.

### Ranking

`HybridRetrievalService` combines:

- exact and partial filename matches;
- path matches;
- FTS5 keyword rank;
- semantic vector distance;
- hard indexed file-type matches;
- modification recency; and
- reciprocal-rank fusion across retrieval channels.

Type-constrained metadata and full-text candidates are filtered before candidate limits are applied. Vector retrieval expands nearest-neighbor batches until it has enough eligible types or has inspected every vector, so another file type cannot hide a valid constrained result. Vector neighbors below the minimum relevance floor do not enter fusion. The simplified interface always uses smart hybrid retrieval and shows absolute paths, deterministic match explanations, and a confidence-aware **Top match** or **Possible match** label. A rank is not proof that a file is the user's intended result.

`ReminderRetrievalService` applies the same local-first principle to reminder text, date, time, tag, and link fields. It combines exact identifier/text matches, FTS5 rank, local Qwen embeddings, reciprocal-rank fusion, and explicit temporal intent such as today, tomorrow, an ISO date, or overdue. Retrieved reminder fields enter a separate bounded grounding prompt, so questions are answered locally while supporting reminder cards remain available in the conversation and History.

## Grounding and generation

Conversation history is not replayed to the model verbatim. When an answer duplicates visible card metadata it is replaced by a generated acknowledgement, and that acknowledgement is stored as the assistant's message. Feeding it back as recent conversation presents the app's own output as something the model said, which the model then imitates: after a few such turns it answers every request with that sentence and routes nothing to retrieval. `boundedHistory` therefore substitutes a bracketed note for a generated acknowledgement, keeping the fact that results were shown without supplying a sentence to copy. Only text the model or the user actually wrote is replayed.

`GroundedPromptBuilder` sends only a bounded set of local ranked paths and excerpts plus a bounded recent local conversation to Qwen. Before insertion, it neutralizes Qwen chat-control markers in every untrusted question, history message, path, and excerpt. The prompt requires evidence-based responses, treats excerpts as data rather than instructions, and requires an admission when the index lacks enough evidence.

Qwen3-4B and Qwen3-Embedding run through statically linked llama.cpp in the same process. Generated reasoning blocks are removed from visible output. Search results remain independently actionable even if generated prose is imperfect.

Chat history is persisted in the private SQLite database. The current interface has no private-session mode.

## Indexing lifecycle

1. Resolve a stored bookmark and begin its read-only security scope.
2. Enumerate metadata without following symbolic links.
3. Compare path, size, date, type, and metadata hashes with the prior snapshot.
4. Skip unchanged items.
5. Hash changed regular files.
6. Extract supported content locally.
7. Split content into overlapping, source-aligned passages.
8. Check each passage against the embedding model's actual token capacity.
9. Recursively subdivide oversized passages before calling llama.cpp.
10. Embed passages sequentially to bound memory use.
11. Replace each file and its FTS/vector rows in a SQLite transaction.
12. Prune items absent from a successfully completed snapshot.
13. Record final per-file states and run counts in private activity history.
14. Release the indexing security scope.

Manual actions, launch-time catch-up, and debounced native folder events enter one coalescing queue. Only one root indexes at a time. A second event for an active root schedules one follow-up pass instead of starting overlapping work. Each process-lifetime FSEvents stream retains its own read-only security scope and stops when the folder is paused, revoked, or the application quits.

Pausing an active run cancels between traversal, extraction, embedding, and save boundaries. A paused run does not prune missing items or advance the root's last-indexed timestamp. The current file returns to its waiting label, automatic updates for that root are paused, and the next explicit resume schedules a catch-up pass. Runs interrupted by process termination are recorded as stopped at the next launch and any transient file labels are restored to waiting states.

The token-capacity check and recursive subdivision prevent a passage larger than the native llama.cpp batch/context limit from reaching `llama_decode`, which was the cause of the newly added-folder crash in 0.1.0.

If content extraction fails, metadata can remain searchable by name or path. A semantic model failure stops semantic indexing rather than silently marking an incomplete vector index as successful.

An extractable file saved without a content hash after an earlier extraction failure is retried on the next scan even when its metadata is unchanged. Existing index rows under a temporarily unreadable path are retained rather than mistaken for deleted files.

`ExtractionConstants.extractionVersion` identifies the behavior of the extraction pipeline and is folded into every file's metadata hash. Raising it changes each stored fingerprint, so a correction that changes the text produced for an unchanged file re-extracts already-indexed files once instead of leaving them on superseded results. It needs no schema migration because the fingerprint is already stored per file.

## Voice lifecycle

Whisper is not loaded during normal application startup. Recognition is continuous: audio is
recognized while it is spoken rather than recorded and transcribed afterwards.

1. The user presses the microphone.
2. `LocalVoiceService` confirms an installed model is present and returns a stream of capture
   states, beginning with a preparing state.
3. The already installed `openai_whisper-small` model loads. Continuous recognition needs the
   model before samples can be interpreted, so the interface shows that it is preparing rather
   than opening the microphone and discarding audio it cannot yet recognize.
4. `AudioStreamTranscriber` streams microphone samples through the loaded model. Each update
   carries relative audio levels and the text recognized so far.
5. The composer replaces the text field with a waveform drawn from those levels, and the
   conversation shows the recognized words as they arrive.
6. Recognition revises its most recent words as more audio arrives, so settled and unsettled
   text are published separately and rendered differently.
7. The recording ends when the speaker pauses for the configured interval, or immediately when
   the control is pressed. A pause before any speech never ends the recording.
8. The transcription is submitted to the same local retrieval flow as typed input.

Library state is converted to an app value where the library reports it, so a non-Sendable type
never crosses an isolation boundary. The library writes an English placeholder into its own
partial text before speech arrives; that placeholder is filtered rather than displayed.

Settings reports voice input as unavailable when the installed model folder lacks its tokenizer files, rather than reporting readiness that fails at first use.

There is no speech-output or cloud transcription path in the current release.

## Application and shortcut lifecycle

The main assistant is a normal singleton SwiftUI `Window`. Closing it leaves the app process running. `GlobalShortcutService` registers `⌃⌥Space` with Carbon while the process is alive; the application delegate brings the main window forward and requests input focus.

The shortcut:

- does not require a helper or localhost service;
- is unavailable after the app is fully quit;
- is fixed rather than user-configurable in the current release; and
- reports registration failure in Settings if another process owns the combination.

Folder monitoring follows the same process lifetime. It uses no helper, daemon, login item, server, or network route. Closing the window keeps monitoring active because the application remains running; fully quitting stops every watcher. The next launch starts fresh streams and schedules catch-up indexing for each enabled root.

## Key design decisions

### Embedded libraries instead of local servers

llama.cpp, SQLite, and sqlite-vec are linked into the app. This avoids ports, daemon lifecycle, inter-process HTTP, server credentials, and another privacy boundary. Ollama and Chroma are not used.

### SQLite instead of MySQL or PostgreSQL

The product has one user, one process, and one private database file. A database server would add accounts, processes, ports, configuration, and upgrades without improving this local retrieval workflow.

### Direct Swift services in the trusted core

The in-app runtime flows are linear: scan, extract, embed, retrieve, ground, generate; and request-file, response-file, validate, reconcile. Direct actors and services make the trusted data path smaller and inspectable. LangGraph is used only by the optional external connector, where a durable checkpointed graph keeps the narrow reminder lane and the separately enabled full-operator lane explicit.

### WhisperKit instead of whisper.cpp

llama.cpp and whisper.cpp can expose overlapping ggml symbols in one native binary. WhisperKit uses Core ML for speech recognition and avoids that native-symbol collision. Its network-capable download paths are removed from the vendored source rather than only disabled by configuration, and the removal is re-applied and verified during preparation.

### OpenClaw connector remains separate

No Feishu integration exists in the application. Adding a network entitlement to this binary would break its privacy contract. The implemented connector follows the separate-process boundary: narrow file-spool IPC, a pinned restricted SSH tunnel opened only for one request, separate Keychain credentials, a read-only snapshot lane, and typed authorization for exact-message OpenClaw A2A. OpenClaw can continue using Feishu independently; this app neither reads nor processes those messages.

## Automated tests and interface previews

`LocalAssistantTests` is a native unit-test bundle that loads the application and exercises its pure decision logic: request routing, standalone OpenClaw detection, search-text escaping, passage offsets and overlap, card-aware answer formatting, scanner exclusions, reminder snapshot reconciliation, read-only ownership classification, and no-follow spool handling. Exclusion and spool tests operate on real files in a temporary directory — including an actual symbolic link, hidden file, credential extension, and symlinked connector response — so they test the resource values the runtime reads rather than a mock of them. They resolve the real account home through the user record, because the test host is sandboxed and its container home is not the path the policy excludes.

The bundle runs only against the Debug configuration. Loading a test bundle into a sandboxed, adhoc-signed host requires three settings that the Release application must not carry:

| Setting | Debug | Release | Reason |
|---|---|---|---|
| `ENABLE_TESTABILITY` | `YES` | `NO` | `@testable import` needs internal symbols. |
| `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` | `YES` | `NO` | Without `get-task-allow` the test runner cannot attach. |
| `ENABLE_HARDENED_RUNTIME` | `NO` | `YES` | Library validation rejects an adhoc-signed bundle inside an adhoc-signed host. |
| `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | `DEBUG` | unset | Keeps preview-only code out of the shipped binary. |

The Debug configuration therefore also carries `get-task-allow`, a test-manager lookup exception, and a read-only sandbox exception used by the test harness. Those widen the Debug sandbox and never ship: `Scripts/build_offline.sh` builds Release, and the boundary audit refuses a Debug build.

`SettingsModelStatusPreviews.swift` renders the model readiness states that a verified installation never reaches. Chat, file search, and voice input all report ready once the offline model package is installed, so reviewing the not-installed and damaged wording in a running app would mean deliberately removing or corrupting installed model files. The previews instead construct the presentation state directly and render each readiness state — including voice input missing only its tokenizer — in light and dark side by side at the minimum window size, which is what the interface-inspection gate asks for. The whole file sits inside `#if DEBUG`; the Release build defines no such condition, and the preview types are absent from the Release binary while present in the Debug binary.

## Release gates

For each release, distinguish these activities:

- **Build:** compile and link the Release application using resolved local dependencies.
- **Automated tests:** run the `LocalAssistantTests` bundle against the Debug application.
- **Focused testing:** launch, index a controlled folder, retrieve files/folders, exercise explicit actions, revoke access, inspect voice initialization, and check for new crash reports.
- **Static privacy audit:** inspect signed entitlements and linked binaries and reject network capabilities.
- **Interface inspection:** review built-application screenshots in light and dark appearances at the smallest supported window size.
- **Code review:** a separate authorized source-review phase.
- **Formal verification:** a separate authorized phase including offline runtime socket observation and broader format fixtures.

<details>
<summary>Recent implementation notes</summary>

The v4.7 Connector replaces its direct Chat Completions client contract with A2A v1.0. For each
authorized general-agent request it opens the existing restricted SSH tunnel, authenticates and
validates OpenClaw's Agent Card, and sends a text-only JSON-RPC `SendMessage` carrying a unique
message identifier and the stable conversation `contextId`. Server bridge v1.4.0 owns the Agent
Card and A2A route, rejects hidden fields, and delegates only the exact text to OpenClaw's existing
loopback agent endpoint. The read-only reminder snapshot route and its separate credential remain
unchanged. The adapter adds no public origin, permanent connection, VPN dependency, or network
entitlement to Local Assistant.

The v4.6 response surface parses bounded block Markdown into native SwiftUI components. Headings, paragraphs, emphasis, lists, quotations, fenced code, dividers, and pipe tables remain selectable without a WebView or active links. The current answer and retained assistant history expand with the live window width. Tables use equal-width native cells, a distinct header row, wrapped text, and horizontal scrolling only when the available width cannot keep every column readable. Presentation remains entirely inside the network-denied Local Assistant target.

The v4.5 source keeps complete CloudBase reminder snapshots as hidden read-only RAG knowledge. Natural reminder and to-do questions retrieve locally without confirmation or Connector access. Clear reminder mutations receive an in-conversation double confirmation: the assistant repeats the exact request, the embedded local LLM classifies the reply, and a bounded local phrase layer guarantees that clear standalone instructions such as continue, proceed, send it, or cancel do not require the literal words yes or no. Only a strict confirmation can add the typed authorization before the request enters the external Connector. Declines, unclear replies, stale-runtime guidance, and request failures remain assistant messages; no reminder-operation dialog is presented, and a failed mutation remains pending for retry. While a request is running, its processing label and progress bar occupy the center of the available assistant workspace rather than the top of the result scroller. The app reads the Connector's non-secret runtime contract before sending, so an older installed runtime is routed to Update and Verify instead of receiving an incompatible request. Standalone OpenClaw naming remains the gate for non-reminder agent requests. Complete reminder lists return all cached rows as concise, tag-grouped cards without duplicating their contents in prose. Reminder and file/folder grids change columns live with the window width, and applicable Settings, Activity, History, and setup surfaces use available space without fixed whole-screen margins or artificial lower gaps. Both voice modes submit after about two seconds of silence, while Hold Space release can submit sooner. Local Assistant still presents three short completion cards while the Connector owns the five actionable setup steps, uses the administrator SSH access the user already has, creates a dedicated key only on demand, and keeps OpenClaw on server loopback. A complete existing installation presents one connection-review route alongside update and verification; credential replacement remains inside Step 4 and reveals empty secure fields only on request. Existing-install discovery reuses public settings and the SSH identity, and obtains only bounded metadata-level Keychain presence results without returning token values to Swift. Confirmed cleanup removes only Connector state while preserving Local Assistant and its reminder cache. The server installer creates a non-root forwarding-only account constrained to `127.0.0.1:23116`, waits for the authenticated bridge route, and prints the host key and two scoped tokens only after a complete snapshot succeeds. The Connector embeds the credential-free server payload, pins the server host key, opens no tunnel between tasks, classifies common SSH failures without exposing raw diagnostics, and reports success before closing only after one authenticated complete snapshot proves the server route, reminder credential, and no-Calendar boundary. Local Assistant launches only an exactly matching Connector version, the release build rejects mismatched application versions, startup shows progress before controls become active, and the current screen survives a Dock reopen. Connector packaging uses pinned Hatchling rather than the vulnerable setuptools build path. launchd runs the Connector briefly for queued work and due schedule checks, including a missed check after wake. Build, static boundary audit, automated suites, and focused checks are recorded separately in the release-status table in README. Live speech recognition and formal disconnected runtime observation remain manual gates. No CloudBase function, VPN application, public Gateway, or continuous tunnel is deployed by the repository build.

</details>
