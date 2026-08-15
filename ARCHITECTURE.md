# Architecture

## Runtime boundary

Local Assistant is one sandboxed macOS application process. It has no HTTP server, localhost service, database daemon, cloud API, updater, telemetry client, web view, network client entitlement, or network server entitlement.

```text
User-selected folders
read-only security-scoped bookmarks
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
- excludes configured system, cache, dependency, and build directories;
- excludes credential-like extensions before content extraction; and
- treats unreadable items as skipped rather than bypassing macOS controls.

`Open File` and `Reveal in Finder` are explicit user actions. Immediately before either handoff, the app resolves current symlink targets and rejects a target outside the active authorized root. It then hands the resolved URL to macOS; any external application operates under its own permissions.

### Private writable zone

The app creates owner-only content below:

```text
~/Library/Containers/com.soucieux.LocalAssistant/Data/Library/Application Support/LocalAssistant/
├── Index/assistant.sqlite3
├── Models/
└── Voice/
```

SQLite WAL and shared-memory files may sit beside the database. Voice files are uniquely named, owner-only, removed after transcription, cleaned up after a failed capture start, and removed as stale data before the next recording.

Revoking a root deletes its stored bookmark record and dependent private index rows. It does not alter the selected source folder.

### Network-denied zone

`LocalAssistant.entitlements` has App Sandbox enabled and contains neither `com.apple.security.network.client` nor `com.apple.security.network.server`.

Connected preparation is confined to repository scripts run outside the app. The runtime never invokes those scripts. WhisperKit is configured with `download: false` and `useBackgroundDownloadSession: false`.

## Persistence and retrieval

One embedded SQLite database provides:

1. relational storage for authorized roots, indexed items, chunks, and local chat history;
2. FTS5 indexing for names, paths, and extracted text; and
3. a statically registered sqlite-vec table for 1,024-dimensional float embeddings.

SQLite extension loading is not enabled. sqlite-vec is compiled into the application and registered on the existing connection.

The database schema still contains selected prototype-era tables so an upgrade does not need a destructive migration. The current interface does not present collections, saved searches, aliases, file relationships, summaries, duplicates, or versions.

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
13. Release the security scope.

The token-capacity check and recursive subdivision prevent a passage larger than the native llama.cpp batch/context limit from reaching `llama_decode`, which was the cause of the newly added-folder crash in 0.1.0.

If content extraction fails, metadata can remain searchable by name or path. A semantic model failure stops semantic indexing rather than silently marking an incomplete vector index as successful.

## Voice lifecycle

Whisper is not loaded during normal application startup.

1. The user presses the microphone.
2. `LocalVoiceService` loads the already installed `openai_whisper-small` model with downloads disabled.
3. macOS microphone capture writes a temporary CAF file under the private Voice directory.
4. The user presses the control again.
5. WhisperKit transcribes locally.
6. The temporary file is removed.
7. The transcription is submitted to the same local retrieval flow as typed input.

There is no speech-output or cloud transcription path in the current release.

## Application and shortcut lifecycle

The main assistant is a normal singleton SwiftUI `Window`. Closing it leaves the app process running. `GlobalShortcutService` registers `⌃⌥Space` with Carbon while the process is alive; the application delegate brings the main window forward and requests input focus.

The shortcut:

- does not require a helper or localhost service;
- is unavailable after the app is fully quit;
- is fixed rather than user-configurable in the current release; and
- reports registration failure in Settings if another process owns the combination.

## Key design decisions

### Embedded libraries instead of local servers

llama.cpp, SQLite, and sqlite-vec are linked into the app. This avoids ports, daemon lifecycle, inter-process HTTP, server credentials, and another privacy boundary. Ollama and Chroma are not used.

### SQLite instead of MySQL or PostgreSQL

The product has one user, one process, and one private database file. A database server would add accounts, processes, ports, configuration, and upgrades without improving this local retrieval workflow.

### Direct Swift services instead of LangChain or LangGraph

The runtime flow is linear: scan, extract, embed, retrieve, ground, generate. Direct actors and services make the trusted data path smaller and inspectable.

### WhisperKit instead of whisper.cpp

llama.cpp and whisper.cpp can expose overlapping ggml symbols in one native binary. WhisperKit uses Core ML for speech recognition and avoids that native-symbol collision. Its network-capable download paths are explicitly disabled in this app.

### Future Feishu bridge remains separate

No Feishu integration exists in the current release. Adding a network entitlement to this binary would break its privacy contract. A future bridge should be a separately signed, network-capable helper with narrow local IPC and an explicit preview/approval step for every outbound payload. It should receive only the exact user-approved text, never unrestricted file or index access.

## Release gates

For v0.9, distinguish these activities:

- **Build:** compile and link the Release application using resolved local dependencies.
- **Focused testing:** launch, index a controlled folder, retrieve files/folders, exercise explicit actions, revoke access, inspect voice initialization, and check for new crash reports.
- **Static privacy audit:** inspect signed entitlements and linked libraries and reject network capabilities.
- **Code review:** a separate authorized source-review phase.
- **Formal verification:** a separate authorized phase including offline runtime socket observation and broader format fixtures.

The v0.9 source implementation contains the exhaustive-pass corrections. Its focused native checks, offline Release build, deep signature validation, and static offline-boundary audit passed. The built signature contains exactly the four approved sandbox entitlements. The installed v0.8 bundle remains separate. Automated visual acceptance could not run because Computer Use was not approved for Local Assistant, and formal offline runtime verification remains an independent gate; the passing build and focused checks are not evidence that either incomplete gate has passed.
