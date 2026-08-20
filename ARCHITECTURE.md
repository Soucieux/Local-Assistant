# Architecture

## Runtime boundary

Local Assistant is one sandboxed macOS application process. It has no HTTP server, localhost service, database daemon, cloud API, updater, telemetry client, web view, network client entitlement, or network server entitlement.

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

Selected source files are never modified. The app's only writable area is its private sandbox container.

## Conversation and search routing

Every typed or locally transcribed request first enters the embedded Qwen chat model. That pass returns one of three outcomes:

1. a normal conversational reply;
2. a concise clarification question when searching would require a guess; or
3. a structured local search plan containing normalized topic terms and hard indexed-item kinds.

The routing pass receives recent local conversation but no file excerpts. Only a clear search plan can enter retrieval. The marker payload is parsed inside the process; recognized file types are enforced as filters rather than treated as keyword hints.

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
├── Index/assistant.sqlite3
└── Models/
```

SQLite WAL and shared-memory files may sit beside the database. Microphone audio is never written to disk: samples pass from the microphone into the speech model in memory, so a recording cannot outlive the request that produced it. A `Voice` directory left by a version that did store recordings is deleted at startup.

Revoking a root deletes its stored bookmark record and dependent private index rows. It does not alter the selected source folder. Indexing run and monitoring-event history remains in the private database until its rolling 30-day expiry or an explicit Clear Activity action.

### Network-denied zone

`LocalAssistant.entitlements` has App Sandbox enabled and contains neither `com.apple.security.network.client` nor `com.apple.security.network.server`. That entitlement set is what the operating system enforces, and it denies every outbound connection regardless of what the process attempts.

Connected preparation is confined to repository scripts run outside the app. The runtime never invokes those scripts.

Configuration alone is not treated as sufficient. WhisperKit is configured with `download: false` and `useBackgroundDownloadSession: false`, and two capabilities are removed from the vendored source rather than switched off:

- its model-hub client started an `NWPathMonitor` whenever it was constructed, which observes network state before any request is made; and
- its tokenizer loader downloaded a missing tokenizer from a public model host, which is reached whenever the installed model folder lacks one.

Both are removed. Offline mode is unconditional and a caller cannot re-enable downloading; a missing tokenizer raises a reinstall instruction. The tokenizer ships inside the verified model package and is found in the installed model folder, so no cache directory outside the sandbox is consulted.

`Vendor/` is regenerated from pinned revisions and is not tracked in Git, so a modification made only there would disappear on the next checkout. The modified files are stored under `Patches/WhisperKit/` with the dependency revision they apply to. `Scripts/apply_offline_patches.py` refuses to run against a different pinned revision, restores the stored files, and then verifies that the required marker is present and that the removed constructs are absent from the resulting source. `Scripts/prepare_dependencies.py` invokes it after every checkout, so preparation fails rather than silently producing a network-capable build.

`Scripts/audit_offline_boundary.sh` closes the loop on the built product: it rejects any unexpected entitlement, and inspects the application executable and every bundled executable for a linked networking library or an imported network symbol. Linkage is the strongest static signal available, because a binary that never links networking code cannot open a connection whatever unreachable source may still say.

## Persistence and retrieval

One embedded SQLite database provides:

1. relational storage for authorized roots, monitoring preferences, indexed items, chunks, local chat history, and 30-day indexing activity;
2. FTS5 indexing for names, paths, and extracted text; and
3. a statically registered sqlite-vec table for 1,024-dimensional float embeddings.

SQLite extension loading is not enabled. sqlite-vec is compiled into the application and registered on the existing connection.

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

### Direct Swift services instead of LangChain or LangGraph

The runtime flow is linear: scan, extract, embed, retrieve, ground, generate. Direct actors and services make the trusted data path smaller and inspectable.

### WhisperKit instead of whisper.cpp

llama.cpp and whisper.cpp can expose overlapping ggml symbols in one native binary. WhisperKit uses Core ML for speech recognition and avoids that native-symbol collision. Its network-capable download paths are removed from the vendored source rather than only disabled by configuration, and the removal is re-applied and verified during preparation.

### Future Feishu bridge remains separate

No Feishu integration exists in the current release. Adding a network entitlement to this binary would break its privacy contract. A future bridge should be a separately signed, network-capable helper with narrow local IPC and an explicit preview/approval step for every outbound payload. It should receive only the exact user-approved text, never unrestricted file or index access.

## Automated tests and interface previews

`LocalAssistantTests` is a native unit-test bundle that loads the application and exercises its pure decision logic: request routing, search-text escaping, passage offsets and overlap, card-aware answer formatting, and scanner exclusions. Exclusion tests operate on real files in a temporary directory — an actual symbolic link, an actual hidden file, an actual credential extension — so they test the resource values the scanner reads rather than a mock of them. They resolve the real account home through the user record, because the test host is sandboxed and its container home is not the path the policy excludes.

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

For v1.4, distinguish these activities:

- **Build:** compile and link the Release application using resolved local dependencies.
- **Automated tests:** run the `LocalAssistantTests` bundle against the Debug application.
- **Focused testing:** launch, index a controlled folder, retrieve files/folders, exercise explicit actions, revoke access, inspect voice initialization, and check for new crash reports.
- **Static privacy audit:** inspect signed entitlements and linked binaries and reject network capabilities.
- **Interface inspection:** review built-application screenshots in light and dark appearances at the smallest supported window size.
- **Code review:** a separate authorized source-review phase.
- **Formal verification:** a separate authorized phase including offline runtime socket observation and broader format fixtures.

The v1.2 source removes the vendored network monitor and tokenizer download, ships the tokenizer inside the verified model package, corrects extraction and retrieval accuracy, fixes voice capture and recording finalization, and adds an automated test bundle. The offline Release build, the static boundary audit, the automated tests, and focused indexing checks are recorded in the release-status table in README. Interface inspection was not repeated in this pass and remains open. Formal disconnected runtime verification and any installed bundle remain independent gates; a passing source build is not evidence that either gate has passed.
