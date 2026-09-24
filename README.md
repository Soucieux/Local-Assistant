# Local Assistant

![Platform](https://img.shields.io/badge/Platform-macOS%2015%2B-blue) ![Swift](https://img.shields.io/badge/Swift-6.0-orange) ![Release](https://img.shields.io/badge/Release-v5.6%20build%2056-brightgreen) ![Main app](https://img.shields.io/badge/Main%20app-Offline-9f9f9f)

<!-- project-control:section=overview -->
## Overview

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
- Only the exact submitted message is sent; files, reminder rows, and conversation history are not
  attached.

## Quick start

Use the installed application for normal work. The source-build section is only for developers preparing an offline release.

### Use the installed application

1. Open **Local Assistant**.
2. In **Settings**, choose **Add Folder** and select what the app may read.
3. Type a request, click to speak, or hold Space to talk.
4. Review the answer and result cards. Files open only after an explicit action.
5. Use **History** for earlier conversations and results.

### OpenClaw connector setup

Open **Settings → OpenClaw Connection → Open Setup**. The guide opens the matching `OpenClaw Connector.app` and walks through five steps.

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

Transfer both files to the OpenClaw owner's home folder. Then run these commands on the OpenClaw server as the account that owns OpenClaw:

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

Verification checks the reminder snapshot and A2A service description through one temporary encrypted SSH connection. The connection closes after the check.

#### Finish in Local Assistant — enable and refresh

- Return to **Settings** and enable **OpenClaw connection**.
- Choose a two-, four-, or eight-hour reminder refresh schedule.
- Select **Refresh Now** once.

- The Connector also runs briefly when a request is queued, after wake when a refresh was missed, and after a confirmed reminder change.
- A failed refresh keeps the last complete local snapshot.

### Keyboard shortcut

Press **Control–Option–Space** (`⌃⌥Space`) while the app is running to bring its window forward. Closing the window keeps the shortcut available; quitting the app disables it.

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

## Capabilities

### Conversation

| Capability | Availability | Notes |
|---|---|---|
| Local conversation | Available | Runs through an embedded model in the application process. |
| Current command presentation | Available in v1.7 | Shows only the active request, processing state, latest centered response, and latest responsive file findings on the main screen. |
| Retained conversation History | Available in v1.7 | Preserves the established chronological message and result-card layout in a separate in-window screen, including the current launch. |
| Intent-aware routing | Available | Selects conversation, clarification, or constrained file search. |
| Card-aware answers | Available | Summarizes results without duplicating filenames, paths, or source lists already shown in cards. |
| Styled conversation text | Available in v0.8 | Distinguishes each sender and renders lightweight local emphasis, inline code, and list markers. |
| Automatic conversation scrolling | Available | Follows new messages, results, and completed answers while respecting reduced motion. |
| Message timestamps | Available | Uses local time for today and an abbreviated local date and time for older messages. |
| Clear conversation history | Available | Removes saved messages and cards after confirmation. |

### Finding files

| Capability | Availability | Notes |
|---|---|---|
| Hard file-type filtering | Available in v0.9 source; hardened in v2.2 | Supports folders, PDFs, documents, spreadsheets, presentations, images, code, text, and archives. Only types explicitly requested by the user become constraints. |
| Hybrid retrieval | Folder-aware in v2.3 | Combines filename, path, folder hierarchy, keyword, text-semantic, recency, and reciprocal-rank signals. Semantic ranking operates on extracted text, OCR, and generated local folder context rather than raw visual pixels. |
| Folder-aware retrieval | Available in v2.3 | Indexes authorized roots and descendant folders, then uses a strong folder match to scope and explain contained results. |
| Explainable result cards | Available; evidence-backed in v2.2 | Shows file type, confidence, path, explicit actions, and the concrete filename, path, keyword passage, or semantic passage that qualified the result. |
| Durable result cards | Available | Restores saved cards with conversation history after relaunch. |

### Authorized folders and indexing

| Capability | Availability | Notes |
|---|---|---|
| Read-only folder selection | Available | Uses macOS security-scoped bookmarks. |
| Folder revocation | Available | Removes authorization and dependent private index records. |
| Manual incremental indexing | Available | Updates one or several authorized folders sequentially. |
| Continuous folder updates | Available in v1.0 source | Uses native macOS folder events while the application is running and performs a catch-up scan at launch. |
| Indexing progress and pause | Available in v1.0 source | Shows per-folder counts and percentage progress and safely pauses the active run without pruning unfinished index data. |
| Index activity | Available in v1.0 source | Retains automatic, manual, startup, and file-level results locally for 30 days, including history for revoked folders. |
| PDF and image OCR | Available | Uses PDFKit and Apple Vision. |

### Speaking and shortcuts

| Capability | Availability | Notes |
|---|---|---|
| Local voice input | Available in v1.7 | Updates the bottom command control with recognized words while speaking and ends on a pause or an explicit stop. |
| Global quick-call shortcut | Available | Uses fixed `⌃⌥Space` while the application process is running. |

### Deliberately not included

| Capability | Availability | Notes |
|---|---|---|
| Speech output | Not included | No text-to-speech surface is included in the current interface. |
| Feishu bridge | Not implemented | Reserved for a separately approved future network boundary. |
| Runtime web access | Prohibited | The application has no browser, download route, or network entitlement. |
## Build from source

<details>
<summary>Developer: show offline build and installation steps</summary>

> **Offline boundary:** Downloads occur only during preparation on a trusted connected Mac. The destination Mac remains disconnected, and the installed application never downloads dependencies or models at runtime.

- The source repository intentionally excludes `Vendor`, generated application bundles, model files, and offline-kit contents.
- The preparation workflow recreates these artifacts from pinned manifests before the project is transferred to the offline destination.

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

3. Wait for dependency checkout, pinned connector-runtime preparation, native-library compilation,
   model verification, and Swift package resolution to finish.

**Result:** The script recreates `Vendor` from pinned revisions and creates the transferable package under `outputs/LocalAssistant-OfflineKit`.

- If the speech model is downloaded manually, preserve the complete `openai_whisper-small` directory structure, including the `tokenizer.json` and `tokenizer_config.json` files recorded in `Config/ModelManifest.json`.
- The application has no route to fetch a missing tokenizer.

#### Step 3 — Transfer and disconnect

1. Copy the complete prepared project and offline package to trusted physical media.
2. Transfer them to the destination Mac.
3. Disable Wi-Fi, Ethernet, VPNs, and other network interfaces before continuing.

- Keep the destination disconnected throughout application installation, building, and static privacy auditing.
- The optional connector cannot be exercised until the Mac later has an approved private route to the OpenClaw server; enabling that separate route does not give `Local Assistant.app` network access.

#### Step 4 — Install the verified model assets

From the transferred project root, run:

```zsh
./outputs/LocalAssistant-OfflineKit/install_offline_assets.sh
```

- **Result:** Verified local models are installed inside the application sandbox.
- The installer refuses to overwrite an existing model or checksum manifest; verify or move the existing asset before retrying.

#### Step 5 — Build the Release application

Build only from the prepared local dependencies:

```zsh
./Scripts/build_offline.sh
```

- **Result:** The Release application is built under `DerivedData/Build/Products/Release` without automatic package resolution.
- The project root receives `Local Assistant.app`, the separately packaged `OpenClaw Connector.app`, and `Local Assistant Release.dmg`, which contains both applications.
- The server deployment payload is embedded only in the Connector, and the user creates `OpenClaw Server Setup.zip` from that app only when needed.

- A successful build removes the prior generated application and release artifacts first and deletes the entire `DerivedData` build cache once the new copies are verified, so the project root holds only the latest release set.

#### Step 6 — Audit the offline boundary

Run the static boundary audit against the Release application:

```zsh
./Scripts/audit_offline_boundary.sh "./Local Assistant.app"
```

- The audit requires exactly the approved App Sandbox, microphone, application-scoped bookmark, and user-selected read-only entitlements, and rejects every unexpected entitlement.
- Local Assistant has no user-selected write entitlement because ZIP and public-key export belong to the separate Connector.

- The audit then inspects the application executable and every bundled executable and fails if any of them links a networking library or imports a network symbol, because a binary that never links networking code cannot open a connection whatever its source might still say.
- It also inspects packaged resources for network-related implementation text.

- The audit reports, rather than rejects, an unreachable service hostname still compiled into the binary.
- A string literal in unreachable code proves nothing either way; the entitlement set is what the operating system enforces.

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

- `-derivedDataPath` keeps the test host beside the offline build.
- Without it the run writes a second application bundle into Xcode's own build directory, where it can be launched by mistake in place of the current one.

Tests run only against the Debug configuration. The Release application built in Step 5 keeps its hardened runtime and sandbox unchanged and does not include the test bundle.

#### Step 7 — Launch and authorize a folder

1. Open the Release application.
2. In **Settings**, choose **Add Folder** and select only the folder the assistant should read.
3. Return to the assistant after indexing finishes.

- Revoking a folder removes its bookmark and dependent private index records without changing the source folder.
- Saved result cards remain in history but become unavailable when their source authorization no longer exists.
- Indexing activity remains available for its normal 30-day retention period.

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
├── Models/
├── model-assets.sha256
└── model-verification.json
```

- Microphone audio is never written to disk.
- Speech is recognized from memory while it is spoken, then the complete in-memory utterance receives one final multilingual transcription pass before it is sent.
- No recording file exists to retain or clean up.

SQLite may create `-wal` and `-shm` files beside the database. Conversation history remains local until it is cleared through the application or its container is removed.

- While the application process is running, native macOS folder events schedule incremental updates; reopening the application performs a catch-up scan.
- Quitting stops folder monitoring completely.

- Local Assistant itself has no login item, background helper, localhost service, or runtime network route.
- The optional separate Connector installs a one-shot per-user launchd job that wakes only for queued work or schedule checks, closes every SSH tunnel, and exits.

</details>

## Supported content

| Content | Local processing |
|---|---|
| Plain text and common source files | Text extraction and chunking |
| PDF | PDFKit extraction; Vision OCR for image-only pages |
| PNG, JPEG, HEIC, TIFF, BMP, and GIF | Apple Vision OCR; labels and visible text become searchable, but visual objects and chart shapes are not captioned. |
| DOCX | Visible Open XML text |
| XLSX | Visible worksheet and shared-string XML text |
| PPTX | Visible slide XML text |
| Pages | OCR from an available local preview |
| Folders | Name, relative path, direct-child context, local embedding, and descendant scoping |
| Other files | Name, path, type, and metadata search |

- Complex formulas, charts, comments, embedded objects, encrypted files, and proprietary Pages IWA bodies are not fully reconstructed.
- The scanner does not follow symbolic links and skips hidden paths, credential-like files, package descendants, common caches, and build directories.

<!-- project-control:section=workflows -->
## How local RAG works

RAG means **Retrieval-Augmented Generation**. The app first finds relevant local evidence, then gives only that evidence to the local language model for the answer.

```text
Answer a question
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

Files and reminders use this same local pattern. Reminder deadlines also contribute to ranking. OpenClaw is not contacted for RAG questions.

The app stores its index in relational SQLite tables. The SQLite engine is part of the app, but the user's `assistant.sqlite3` data file is created separately inside the private app sandbox.

---

<!-- project-control:section=architecture -->
## Local architecture

### AI & Intelligence

| Technology or concept | Use in this project |
|---|---|
| Retrieval-Augmented Generation (RAG) | Finds local evidence before answering. HybridRetrievalService combines keyword, vector, filename, path, and recency signals. GroundedAssistantService supplies bounded, cited passages. |
| Embeddings | Numerical vectors represent queries and document passages so similar meanings can be retrieved through LocalEmbeddingService. |
| Qwen3-4B Q4_K_M | The local chat and intent-classification model; generates answers without a hosted service. |
| Qwen3-Embedding-0.6B Q8_0 | The local embedding model used for document indexing and query retrieval. |
| llama.cpp | Statically linked inference engine that runs both GGUF models inside the application. |
| GGUF | The packaged file format for the chat and embedding model weights. |
| Whisper Small | The local speech-recognition model, stored as openai_whisper-small Core ML assets. |
| WhisperKit | Runs the packaged speech-recognition model and its tokenizer. |
| Core ML | Apple's model format/runtime used by the speech assets. |
| Optical character recognition (OCR) | Extracts readable text from images before local indexing. |
| Apple Vision | Performs image text recognition for OCR. |

### Frontend & Presentation

| Technology or concept | Use in this project |
|---|---|
| SwiftUI | Builds the native conversation, History, Activity, and Settings interfaces. |
| AppKit | Supplies macOS application/window integration and explicit open/reveal actions. |

### Backend & Application Logic

| Technology or concept | Use in this project |
|---|---|
| Swift | Native Swift services and typed request routes orchestrate the app; no LangChain or LangGraph dependency. |
| Foundation | Supplies file, text, date, and structured-data APIs used by native services. |
| Indexing | IndexingService extracts content, splits it into passages, and generates embeddings; complete reminder snapshots enter the same private knowledge index. |
| CoreServices | FolderMonitorService uses filesystem events to detect changes for incremental indexing. |
| PDFKit | Extracts PDF text and provides PDF handling alongside image OCR. |
| ZIPFoundation | Reads bounded Office-document archive content during extraction. |

### Data & Storage

| Technology or concept | Use in this project |
|---|---|
| SQLite | Embedded relational storage for metadata, monitoring preferences, history, and local reminder snapshots; not a database server. |
| SQLite FTS5 | Keyword/full-text retrieval over indexed text. |
| sqlite-vec | Statically linked vector retrieval over stored embeddings. |

### Integrations & Security

| Technology or concept | Use in this project |
|---|---|
| Security-scoped bookmarks | Persist permission to authorized folders; the scanner keeps source access read-only. |
| App Sandbox | Enforces the main app's offline and filesystem permission boundary. |
| Agent-to-Agent (A2A) | The separate one-shot OpenClaw Connector sends explicitly authorized agent requests using A2A v1.0. |
| SSH | The Connector's temporary encrypted tunnel; networking never moves into the main app. |

<!-- project-control:section=models -->
### Models and shared storage

**Shared model storage:** Local Assistant uses the shared **AI-Models library in the Mac's Documents folder**, rather than maintaining separate project-owned model copies.

| Model used by this project | Path within the shared library |
| --- | --- |
| Chat: Qwen3-4B Q4_K_M | `gguf/Qwen3-4B-Q4_K_M.gguf` |
| File search: Qwen3-Embedding-0.6B Q8_0 | `gguf/Qwen3-Embedding-0.6B-Q8_0.gguf` |
| Speech: Whisper Small and its tokenizer | `whisper/openai_whisper-small/` |

- The shared library's README records **Local Assistant** as a consumer of all three models and owns their exact revision, storage and change-history records.
- Project settings, indexes and installation-specific verification records stay in the app's private storage.

On the current Mac, the app's existing sandbox filenames are **hard links to these shared files**: both locations name the same stored data, without duplicate model copies.

- No additional terminal, service, SSD or app setting is needed.
- The offline installer does not create this sharing arrangement automatically; check the links after reinstalling or replacing models.
- This storage arrangement does not change the app's sandbox or offline runtime boundary.

SQLite is an in-process library rather than a database server. See [ARCHITECTURE.md](ARCHITECTURE.md) for trust zones, the indexing lifecycle, and detailed design decisions.
## Architecture and project structure

- The category-grouped Local architecture tables above list each technology, concept, and model on its own row.
- Backend & Application Logic means on-device services here, not a network server.
- The 2026-08-31 architecture update also added stable README section mappings for Project Control, keeping models and RAG visible in Architecture.
- The later v5.2 reconciliation changes release metadata and documentation only; application behavior and model storage remain unchanged.

<!-- project-control:section=workflows -->
### Request flow

Every request is classified locally:

```text
Conversation
embedded model
  ↓
local answer

File request
private index
  ↓
grounded answer and result cards

Reminder read
local reminder cache/RAG
  ↓
answer or reminder cards

Reminder change
local confirmation
  ↓
one-shot Connector
  ↓
A2A
  ↓
OpenClaw

Other OpenClaw task
explicit OpenClaw wording
  ↓
one-shot Connector
  ↓
A2A
  ↓
OpenClaw
```

### How A2A is used

A2A v1.0 is the Connector's standard protocol for OpenClaw agent work:

- It discovers and validates OpenClaw's Agent Card.
- It sends every delegated conversation with the standard A2A `SendMessage` operation.
- It carries confirmed reminder changes and explicit non-reminder OpenClaw requests.
- It preserves a stable conversation context without attaching local files or history.

Reminder snapshot synchronization does not use A2A. It remains a separate complete, read-only route with its own credential.

Only bounded evidence reaches the local grounding pass. Indexed content is treated as data, never as an instruction.

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
│   ├── Reminders/                # Reminder cache, retrieval, and spool handoff
│   ├── Inference/                # Routing, prompts, llama.cpp, and grounding
│   ├── Voice/                    # Recording and local transcription
│   ├── Features/                 # Assistant, activity history, result cards, and Settings
│   ├── Security/                 # Private application-container directories
│   ├── Resources/                # Icon, property list, and sandbox entitlements
│   └── VendorBridge/             # Static native-library bridges
├── LocalAssistantTests/          # Automated tests for routing, retrieval, and exclusions
├── OpenClawConnector/            # Connector companion app, runtime, and its tests
├── Patches/                      # Offline modifications applied to pinned dependencies
├── Scripts/                      # Preparation, installation, build, audit, and patch tools
├── Vendor/                       # Recreated pinned dependencies; excluded from Git
└── outputs/                      # Generated offline transfer kit; excluded from Git
```

</details>

## Boundaries and limitations

### Privacy and security boundaries

These boundaries are product requirements rather than optional settings:

- **No application network access.** The signed application must not have network client or server
  entitlements.
- **No runtime downloads.** Required models and frameworks must already exist on the destination
  Mac. Dependency code that could download or observe the network is removed from the vendored
  source and the removal is verified during preparation, so the guarantee does not rest on a
  configuration flag.
- **Read-only source access.** Folder bookmarks are application-scoped and request read-only access.
- **Explicit authorization.** The application can read only folders selected through the macOS
  folder picker and allowed by the operating system.
- **Revocable access.** Revoking a folder removes its bookmark and dependent private index records
  without changing the source folder.
- **Private writes only.** The database, model assets, conversation history, and temporary voice
  recordings remain inside the application sandbox.
- **No source-file mutation.** The application does not create, edit, rename, move, or delete files
  in authorized folders.
- **Explicit external actions.** A result opens or appears in Finder only after the corresponding
  button is pressed, after its current symlink-resolved target is confirmed inside the authorized
  root.

macOS remains the final authority. A bookmark cannot bypass system permissions, encryption, Data Vault protections, or an unavailable external drive.

### Current limitations

- Every searchable root must be selected explicitly; the application cannot silently read the whole
  disk.
- Search quality depends on successful extraction and indexing.
- Semantic search currently embeds extracted text, not image pixels. An unlabeled chart or
  photograph with no useful OCR or surrounding text cannot be identified reliably by its visual
  appearance alone.
- Chat and semantic search require verified local model assets.
- Voice input requires the complete local speech model and macOS microphone permission.
- Office and Pages extraction is intentionally best-effort.
- Automatic refresh runs only while the application process is running; quitting stops every folder
  watcher until the next launch-time catch-up scan.
- The global shortcut is fixed and works only while the application process is running.
- Built-in conversational knowledge may be incomplete; file-specific answers remain bounded by
  displayed evidence.
- The only optional network boundary is the separately packaged OpenClaw connector. Local Assistant
  has no direct Feishu, CloudBase, calendar, email, or general internet client.

For a physically offline installation:

1. Prepare and verify all assets on a trusted connected Mac.
2. Transfer them using trusted media.
3. Disconnect the destination Mac.
4. Install and use Local Assistant without enabling OpenClaw.

The optional Connector requires an approved route to the OpenClaw server.

## Troubleshooting

### Why does Settings say a feature is not installed or damaged?

Open **Settings → Models**:

- **Not installed:** install the verified offline model package.
- **Damaged:** reinstall the package because a model file failed its integrity check.

The app cannot download a replacement itself.

### Why is an authorized folder unavailable?

Its bookmark may be stale, its volume may be disconnected, or macOS may be denying access. Revoke the folder in Settings, then select it again through the macOS folder picker.

### Why can a saved result card no longer open its file?

- The file may have moved, been deleted, fallen out of the current index, or belonged to a revoked folder.
- Update the relevant index or authorize its folder again.
- The application deliberately refuses to open a stale saved path.

### Why does a file have no searchable text?

The file may be unsupported, encrypted, excluded, too large, or may have failed extraction. It can still be discoverable by name, path, type, or metadata.

### How can broad search results be narrowed?

Include a topic, filename fragment, folder, date, or file type. A singular underspecified request should produce a follow-up question instead of an arbitrary result.

### What should I do if indexing fails?

- Confirm that the folder remains readable and File search is ready in Settings, then choose **Update Index**.
- Preserve any macOS crash report together with the triggering folder and file type.

### Why are automatic updates paused or unavailable?

- Choose **Resume Automatic Updates** for the folder in Settings.
- If monitoring remains unavailable, confirm that the folder or external volume is present and readable, then revoke and authorize it again if its macOS bookmark is stale.

### Why is the quick-call shortcut unavailable?

Another application may already own `⌃⌥Space`. Quit or reconfigure the conflicting application, then relaunch Local Assistant.

### Why does voice input not start?

- Confirm that macOS microphone permission is allowed.
- Confirm that **Settings → Models** reports Voice input as ready.
- If it is unavailable, reinstall the verified offline model package.

The first transcription may wait briefly while the local speech model loads.

### Why does offline package resolution fail?

Return to the connected preparation phase and rerun `prepare_offline_bundle.sh`. Do not temporarily enable networking on the disconnected destination to let Xcode resolve a missing package.

<!-- project-control:section=release -->
## Current release

**v5.7 (build 57)**. [Release details and delivery evidence](#openclaw-kit-shared-config).

To identify an application bundle, read `CFBundleShortVersionString` in its `Info.plist`.

## Design reference

[ARCHITECTURE.md](ARCHITECTURE.md) explains system design, data flow, and privacy boundaries.

<!-- project-control:section=ignore -->
## Contributing

For source changes, follow the [Local Assistant contribution guide](CONTRIBUTING.md).

<!-- project-control:section=history -->
## Change history

**Change-history numbering:** This project uses marketing versions and integer build numbers.
Follow the [version and build policy](CONTRIBUTING.md#version-and-build-policy).

One record per change; complete details and evidence are below. Older work dates and Git checkpoints remain labelled when they differ.

**Historical status:** Each record describes its own delivery checkpoint. Later records supersede older pending work or recovery locations; historical checks are not new validation.

| Record | Date | Highlights | Details |
|---|---|---|---|
| v5.7 / build 57 | 2026-09-23 | <ul><li><strong>Server kit:</strong> Ships the shared configuration the reminder bridge imports, so installing the kit onto an older server no longer fails at import.</li><li><strong>Setup:</strong> Carries bridge v1.5.1, whose installer names a missing CloudBase endpoint up front instead of timing out.</li></ul> | [Full record](#openclaw-kit-shared-config) |
| v5.6 / build 56 | 2026-09-21 | <ul><li><strong>Identity:</strong> A private conversation core now connects visibly to local documents, voice input, and reminders.</li><li><strong>Delivery:</strong> The matching main app and Connector, plus the clean-Mac disk image, were rebuilt and validated.</li></ul> | [Full record](#private-local-capabilities-icon) |
| Documentation | 2026-09-21 | <ul><li><strong>Contributor guide:</strong> The two llama.cpp links now address upstream, because the prepared vendor tree is not part of the repository and neither link resolved for a reader of it.</li><li><strong>Label:</strong> The second link now names the upstream agent instruction document it actually opens.</li></ul> | [Full record](#upstream-llama-cpp-links) |
| v5.5 / build 55 | 2026-09-20 | <ul><li><strong>Server kit:</strong> Ships the shared runtime_support package that the reminder bridge and the store manager import, so installing the kit no longer leaves the bridge unable to import.</li><li><strong>Release:</strong> Signed applications and a rebuilt disk image replace the v5.4 artifacts at the project root.</li></ul> | [Full record](#openclaw-kit-runtime-support) |
| Documentation | 2026-09-13 | <ul><li><strong>License:</strong> Added the approved Soucieux proprietary-software notice.</li></ul> | [Full record](#soucieux-proprietary-license) |
| Documentation | 2026-09-11 | <ul><li><strong>Contributing:</strong> Added a standalone project guide that works in both the canonical workspace and the public subtree mirror.</li><li><strong>Links:</strong> Removed README dependencies on parent-only repository files.</li><li><strong>Repository:</strong> Added a feature-first public GitHub description for new users.</li></ul> | [Full record](#public-contributor-guide) |
| Documentation | 2026-09-06 | <ul><li><strong>Structure:</strong> User guide first; one history table.</li><li><strong>Rules:</strong> Scoped contributor guidance under AGENTS.</li></ul> | [Full record](#readme-organization) |
| Maintenance | 2026-09-06 | <ul><li><strong>Change:</strong> Reorganized long paragraphs and table cells without dropping details.</li></ul> | [Full record](#change-1) |
| Documentation | 2026-09-06 | <ul><li><strong>Change:</strong> Moved complete project descriptions, register details, and repository-origin history into this README.</li></ul> | [Full record](#change-2) |
| v5.4 / build 54 | 2026-09-05 | <ul><li><strong>Change:</strong> Reused statements and atomic activity writes.</li></ul> | [Full record](#change-3) |
| Documentation | 2026-09-04 | <ul><li><strong>Change:</strong> Merged the version index and the dated maintenance history into one change-history table using the repository's required first-column labels.</li></ul> | [Full record](#change-4) |
| v5.3 / build 53 | 2026-09-04 | <ul><li><strong>Change:</strong> Connector launchd reliability and shared code.</li></ul> | [Full record](#change-5) |
| Documentation | 2026-09-02 | <ul><li><strong>Change:</strong> Linked Local Assistant's version-and-build declaration to the centralized repository policy and removed duplicated generic numbering rules.</li></ul> | [Full record](#change-6) |
| v5.2 / build 52 | 2026-08-31 | <ul><li><strong>Change:</strong> Release-history reconciliation.</li></ul> | [Full record](#change-7) |
| v5.1 / build 51 | 2026-08-31 | <ul><li><strong>Change:</strong> Explicit architecture inventory and README mappings.</li></ul> | [Full record](#change-8) |
| v5.0 / build 50 | 2026-08-29 | <ul><li><strong>Change:</strong> Final deterministic ordering and indexing cleanup.</li></ul> | [Full record](#change-9) |
| v4.9 / build 49 | 2026-08-28 | <ul><li><strong>Change:</strong> Deterministic retrieval and connector resilience.</li></ul> | [Full record](#change-10) |
| v4.8 / build 48 | 2026-08-26 | <ul><li><strong>Change:</strong> Responsive setup and consistent result cards.</li></ul> | [Full record](#change-11) |
| v4.7 / build 47 | 2026-08-26 | <ul><li><strong>Change:</strong> Private A2A connection to OpenClaw.</li></ul> | [Full record](#change-12) |
| v4.6 / build 46 | 2026-08-26 | <ul><li><strong>Change:</strong> Responsive native Markdown responses.</li></ul> | [Full record](#change-13) |
| v4.5 / build 45 | 2026-08-26 | <ul><li><strong>Change:</strong> Natural confirmation, centered processing, and dependency security.</li></ul> | [Full record](#change-14) |
| v4.4 / build 44 | 2026-08-26 | <ul><li><strong>Change:</strong> Conversational reminder confirmation and runtime compatibility.</li></ul> | [Full record](#change-15) |
| v4.3 / build 43 | 2026-08-26 | <ul><li><strong>Change:</strong> Natural reminder routing and responsive result cards.</li></ul> | [Full record](#change-16) |
| v4.2 / build 42 | 2026-08-26 | <ul><li><strong>Change:</strong> Content-height Local Assistant setup cards.</li></ul> | [Full record](#change-17) |
| v4.1 / build 41 | 2026-08-26 | <ul><li><strong>Change:</strong> Unified connection review and content-height setup cards.</li></ul> | [Full record](#change-18) |
| v4.0 / build 40 | 2026-08-26 | <ul><li><strong>Change:</strong> Credential-safe Connector updates and cleanup.</li></ul> | [Full record](#change-19) |
| v3.9 / build 39 | 2026-08-26 | <ul><li><strong>Change:</strong> Reliable connector setup, refresh, and lifecycle.</li></ul> | [Full record](#change-20) |
| v3.8 / build 38 | 2026-08-26 | <ul><li><strong>Change:</strong> On-demand restricted SSH transport.</li></ul> | [Full record](#change-21) |
| v3.7 / build 37 | 2026-08-26 | <ul><li><strong>Change:</strong> Complete private Tailscale connection setup.</li></ul> | [Full record](#change-22) |
| v3.6 / build 36 | 2026-08-26 | <ul><li><strong>Change:</strong> User-created server ZIP and corrected setup packaging.</li></ul> | [Full record](#change-23) |
| v3.5 / build 35 | 2026-08-26 | <ul><li><strong>Change:</strong> Unambiguous clean-device OpenClaw setup.</li></ul> | [Full record](#change-24) |
| v3.4 / build 34 | 2026-08-26 | <ul><li><strong>Change:</strong> Live OpenClaw status and in-app setup.</li></ul> | [Full record](#change-25) |
| v3.3 / build 33 | 2026-08-26 | <ul><li><strong>Change:</strong> Hidden reminder knowledge and explicit OpenClaw actions.</li></ul> | [Full record](#change-26) |
| v3.2 / build 32 | 2026-08-26 | <ul><li><strong>Change:</strong> Private reminder RAG and an opt-in OpenClaw connector.</li></ul> | [Full record](#change-27) |
| Maintenance | 2026-08-23 | <ul><li><strong>Change:</strong> Removed the stale hard-coded version fallback so bundle metadata remains authoritative and unavailable metadata is reported explicitly.</li></ul> | [Full record](#change-85) |

<details>
<summary>Full records for this table</summary>

<a id="openclaw-kit-shared-config"></a>

### v5.7 / build 57

- **Recorded date:** 2026-09-23.
- **Server kit:** The OpenClaw server setup kit now ships the shared `config.py` and `config.sh`
  beside the reminder bridge and store manager that import them. On a server whose workspace was
  older than that configuration, the previous kit installed the bridge without it, so the bridge
  failed at import and setup stopped with only a readiness timeout.
- **Setup:** The kit now carries Local Assistant bridge v1.5.1. Its installer checks for a CloudBase
  endpoint before it changes anything and says how to supply one. The bridge cannot serve a
  reminder request without an endpoint, and the earlier installer reported that only as a timeout.
- **Guard:** `OpenClawConnector/tests/test_server_kit.py` fails whenever a file the kit ships
  imports a module the kit leaves out. A standalone checkout cannot build the kit, so it skips them.
- **Release alignment:** Local Assistant and OpenClaw Connector both advance to v5.7/build 57. Only
  the Connector's embedded server kit changed; the main application's behavior is unchanged.

**Evidence and delivery status**

The full macOS test suite passed, 146 test cases, and all 43 Connector tests passed. The offline
Release build produced the signed v5.7/build 57 main application, the matching signed Connector,
and `Local Assistant Release.dmg`. Both bundles passed strict deep signature verification, the main
app passed the offline-boundary audit, and the disk image checksum is valid. The Connector's
embedded kit was confirmed to carry `config.py`, `config.sh` and the v1.5.1 installer, each
identical to its source. The rebuilt deliverables are at the project root; publication was not
requested. The source and this record are committed together.

[Back to change history](#change-history)

<a id="private-local-capabilities-icon"></a>

### v5.6 / build 56

- **Recorded date:** 2026-09-21.
- **Identity:** The application icon now depicts a private conversation core linked by a local-only
  teal ring to documents, voice input, and reminders. Those are the app's actual local capabilities,
  rather than a generic assistant mark.
- **Source:** The complete macOS asset catalog was regenerated from the approved transparent master
  at every standard and Retina size from 16 through 1024 pixels.
- **Release alignment:** Local Assistant and OpenClaw Connector both advance to v5.6/build 56. The
  Connector keeps its separate existing artwork; only its version moves so the two applications
  remain an accepted pair.
- **Scope:** No assistant, retrieval, reminder, voice, storage, Connector, or privacy behavior
  changed.

**Evidence and delivery status**

The full macOS test suite passed. The offline Release build produced the signed v5.6/build 56 main
application, the matching signed Connector, and `Local Assistant Release.dmg`. Both bundles passed
strict deep signature verification, the main app passed the offline-boundary audit, the disk image
checksum is valid, and the packaged 256-pixel icon representation matches the source catalog pixels.
The rebuilt deliverables are at the project root; publication was not requested.

[Back to change history](#change-history)

<a id="upstream-llama-cpp-links"></a>

### Documentation

- **Recorded date:** 2026-09-21.
- The contributor guide's two links into `Vendor/llama.cpp` now address upstream's
  [contribution guide](https://github.com/ggml-org/llama.cpp/blob/master/CONTRIBUTING.md) and
  [agent instructions](https://github.com/ggml-org/llama.cpp/blob/master/AGENTS.md).
- The prepared `Vendor` tree is recreated from pinned revisions and is not part of the repository,
  so both links resolved for no reader of the public repository. Only a checkout that had already
  run the preparation script could follow them.
- The second label also named the wrong destination. The preserved file is upstream's agent
  instruction document under a local name, kept that way so no nested instruction file sits in a
  project folder. The label now names what it opens, and the sentence still records that the
  prepared tree holds it as `CONTRIBUTOR_GUIDANCE.md`.
- The links address `master` rather than the pinned revision, because a contributor changing the
  prepared source should follow upstream's current contribution rules.

**Evidence and delivery status**

Documentation only. Both upstream documents were retrieved and their headings match the preserved
copies: `Contributors` for the contribution guide and `Instructions for llama.cpp` for the agent
instructions. The repository link check now reports that all links in 31 documents resolve and name
their destination, where it previously reported these two as broken; the README layout and retention
checks pass. No source, build, application version or build number changed.

[Back to change history](#change-history)

<a id="openclaw-kit-runtime-support"></a>

### v5.5 / build 55

- **Recorded date:** 2026-09-20.

- The server setup kit now ships `runtime_support`, the shared Python package that the typed reminder bridge and the reminder store manager both import, and the installer places it beside them in the workspace.
- Before this, the kit shipped both callers without their package. Both import `runtime_support.strict_json`, so installing the kit onto a workspace provisioned before that module existed left the bridge unable to import at all, and the setup's own snapshot test then timed out against a Gateway that was healthy, reporting the wrong cause.
- The installer places the shared package before its callers, so a failure leaves the workspace on its previous self-consistent pair rather than a new caller over an older package. Each install keeps the directory it replaces under a `.before-local-assistant-setup` name for rollback, and the two package installs now share one helper instead of repeating the same sequence twice.
- Existing users create and run a fresh server setup ZIP once for this to reach a server.

**Evidence and delivery status**

Source change only. A kit built from this source was confirmed to carry the package, and every import the kit's bridge and store manager make resolved from the installed set alone; removing the package again reproduced the original `ModuleNotFoundError`.

The clean offline Release build produced signed v5.5/build 55 applications and a rebuilt disk image that replace the v5.4 artifacts at the project root. Both bundles pass a strict deep signature check and keep the project's ad-hoc signature; the main application also carries the hardened runtime, which the Connector's build does not request; the signed-app offline-boundary audit passes with only the four expected entitlements and no network entitlement; and the disk image verifies its checksum and mounts with both applications at v5.5/build 55. The shipped Connector carries the corrected kit: its embedded setup payload contains the nine-module `runtime_support` package and the installer that places it before its callers.

146 macOS test cases and all 40 Connector tests pass against this source; the Debug test cache was removed afterwards so the project root holds only the delivered build.

Not established by this build: the applications were not launched, so runtime behaviour is unverified, and the signature is ad-hoc with the hardened runtime rather than Developer ID, so the artifacts are not notarized for distribution beyond this Mac. The source was uncommitted at delivery and is recorded in `5035744`.

[Back to change history](#change-history)

<a id="soucieux-proprietary-license"></a>

### Documentation

- **Recorded date:** 2026-09-13.
- Added the approved Soucieux proprietary-software notice, reserving rights in original project
  materials while retaining third-party license and attribution requirements.
- Documentation only; application behavior, v5.4/build 54, artifacts, deployment, and publication
  status are unchanged.

[Back to change history](#change-history)

<a id="public-contributor-guide"></a>

### Public contributor guide — 2026-09-11

- Added `CONTRIBUTING.md` with Local Assistant's public project boundaries, focused change checks,
  and version/build policy.
- Changed every README policy link to a path inside this project, so the canonical private subtree
  and standalone public repository can keep identical files without broken parent links.
- Kept the canonical workspace's root instructions and scoped internal procedures authoritative for
  private repository workflow; no private governance file was copied into the public subtree.
- Set the public GitHub repository description to a newcomer-friendly summary that highlights
  offline privacy, local chat, read-only file search, OCR, voice input, hybrid RAG, reminder
  knowledge, and the optional isolated Connector. Confirmed the saved value through GitHub's
  repository API.
- **Status:** Documentation only. Application behavior, v5.4/build 54 source metadata, signed
  artifacts, installed applications, model storage, and deployment state are unchanged.

[Back to change history](#change-history)

<a id="readme-organization"></a>

### README organization — 2026-09-06

- **Structure:** Put purpose, capabilities, setup, architecture, and workflows before history.
- **History:** Merge matching repository-origin records into the owning change; preserve unique detail, evidence, and older links.
- **Ownership:** Keep user documentation here; route scoped contributor rules through root AGENTS.
- **Status:** Documentation changes only; initially delivered uncommitted and recorded in `07fa894`. Existing application versions, artifacts, and deployment state are unchanged.

[Back to change history](#change-history)

<a id="change-1"></a>
<a id="readability-maintenance"></a>

### Documentation readability

- **Recorded date:** 2026-09-06.

- Reorganized long paragraphs and table cells without dropping details; consolidated imported history tables into indexes linked to complete readable records.
- Preserved existing destinations and README section mappings.
- Documentation only; no application or release artifact changed.

**Evidence and delivery status**

Local documentation changes; initially delivered uncommitted and recorded in this documentation commit.

[Back to change history](#change-history)

<a id="change-2"></a>

### Documentation

- **Recorded date:** 2026-09-06.

- Moved complete project descriptions, register details, and repository-origin history into this README; retained existing content, dates, release/build identifiers, Git evidence, and app-content mappings.
- Project guardrails now load through the root instructions only for this project.
- This is documentation maintenance; no application code, build, release, or deployment changed.

**Evidence and delivery status**

Local documentation update; initially delivered uncommitted and recorded in `07fa894`

[Back to change history](#change-history)

<a id="change-3"></a>

### v5.4 / build 54

- **Recorded date:** 2026-09-05.

- Released v5.4/build 54 after closing the efficiency and naming items the v5.3 review left open.
- The private index reuses its prepared SQL statements, a re-indexed file rebinds one delete statement for all of its vectors, and each removed file's activity row now commits with its parent run summary.

The signed v5.4/build 54 applications and disk image replace the v5.2 artifacts at the project root.

- Released v5.4/build 54, closing the efficiency and naming items the v5.3 byte-to-byte review left open.
- The private index now reuses its prepared SQL statements instead of preparing and discarding one per operation, so a scan stops reparsing the same statement once per file and a reminder sync stops doing it five times per reminder;

returned statements have their bindings cleared so a cached insert cannot pin the last embedding blob, and every cached statement is finalized when the connection closes.

- The cache holds only the 46 fixed statements: SQL whose placeholder count follows the query is prepared per call, because caching it by text would add a permanent entry for every distinct width.

- A re-indexed file now rebinds one delete statement for all of its vectors, each removed file's activity row commits together with the parent run summary it advances, and a monitoring burst's events commit together, so an interrupted run cannot leave those records disagreeing.

- Renamed `activityOrderingNudgeSeconds` to `activityOrderingNudgesPerSecond` because it is a divisor producing microsecond offsets, and moved the bullet glyph to the shared text constants now that a Settings view reuses it.

- The per-file run-summary write for unchanged files was deliberately kept, because that write is what keeps an interrupted run's counts accurate. 146 macOS test cases and all 40 Connector tests pass;

- the three added statement-reuse cases were each confirmed to fail when the reuse code is deliberately broken.
- The clean offline Release build produced signed v5.4/build 54 applications and a rebuilt disk image that replace the v5.2 artifacts at the project root;

- both bundles pass a strict deep signature check, the signed-app offline-boundary audit passes with only the four expected entitlements and no network entitlement, and the disk image verifies its checksum and mounts with both applications at v5.4/build 54.

- This is the first build carrying the v5.3 launchd correction.
- Both applications are now installed on this Mac and the Connector's existing-setup update re-registered the background job at `~/Library/LaunchAgents`, removing the superseded home-folder copy, so launchd loads it from the corrected path and the scheduled reminder refresh runs again.

A full re-read of both project READMEs after that install also corrected a stale `v5.3 (build 53)` release declaration in the Connector README that no changed hunk covered.

- Reuses prepared SQL statements across calls. Every read and write on the private index used to
  prepare a statement and discard it, so SQLite reparsed and recompiled the same SQL once per file
  during a scan and five times per reminder during a sync. Statements are now checked out of a
  per-connection cache and returned when the operation finishes.
- Clears a returned statement's bindings, so a cached insert does not keep the last embedding blob
  alive, and finalizes every cached statement when the connection closes.
- Bounds that cache to the 46 statements whose SQL is fixed. SQL whose placeholder count follows the
  query — a search's token list, a batch of identifiers, a set of item kinds — is prepared per call
  and finalized, because caching it by text would leave a permanent entry for every distinct width
  the app ever sees.

Those statements run once per user query, not once per file.
- Rebinds one delete statement for every vector belonging to a re-indexed file. A document deletes
  one vector per extracted passage, and each of those deletions previously checked out its own
  statement.
- Commits a removed file's activity row together with the parent run summary it advances. The two
  rows describe the same completed item, so a run that stops mid-scan can no longer show the file
  recorded in one and not counted in the other. It also halves that step's durable writes.
- Appends a monitoring burst's events in one commit, so retained history never shows a scheduled
  update without the detected change that triggered it.
- Renames `activityOrderingNudgeSeconds` to `activityOrderingNudgesPerSecond`. It is used as a
  divisor that produces microsecond offsets, so the previous suffix named the wrong unit.
- Moves the bullet glyph to the shared text constants. A Settings view began reusing it, and it was
  scoped under the Markdown constants that only the response parser and renderer own.
- Leaves the per-file run-summary write in place for unchanged files. That write is what keeps an
  interrupted run's counts accurate, and reusing its statement already removes the repeated work.
- Advances Local Assistant and OpenClaw Connector to v5.4 build 54. No Connector source changed; its
  bundle version tracks the project release.
- Passed all 146 macOS test cases and all 40 Connector tests. The three added statement-reuse cases
  were each confirmed to fail when the reuse code is deliberately broken.
- Passed the clean offline Release build, strict deep signature checks on both bundles, the
  signed-app offline-boundary audit, and disk-image checksum and mount validation. This is the first
  build to carry the v5.3 launchd correction. Both applications are now installed on this Mac, and
  the Connector's existing-setup update re-registered the background job at the corrected path, so
  that correction is in effect here.

- The current release is **v5.4 (build 54)**.
- The private index now reuses its prepared SQL statements instead of preparing and discarding one for every operation, so a scan or a reminder sync stops re-parsing the same statement once per file.

- The release also commits a removed file's activity row together with its parent run summary, and a monitoring burst's events together, so a run interrupted mid-scan cannot leave those records disagreeing.

The project root now holds the signed v5.4 build 54 applications and disk image, which replace the v5.2 artifacts and are the first build to carry the v5.3 launchd correction.

Both applications are installed on this Mac and the Connector's existing-setup update has re-registered the background job, so that correction is now in effect here.

<details>
<summary>Detailed build, test, privacy, and release evidence</summary>

- **Source implementation:** **v5.4 status:** Complete; **Meaning:** Local Assistant and OpenClaw Connector advance to v5.4/build 54. Connector runtime v1.9.0, server bridge v1.4.0, and runtime contract v3 are unchanged because no wire contract changed, and no Connector source changed in this release.

- **Documentation:** **v5.4 status:** Complete; **Meaning:** Records v5.4/build 54 here and in the repository README, including the signed build, the installed-Mac launch-agent verification, and the checks that were not repeated.

- **Release build:** **v5.4 status:** Complete; **Meaning:** The clean offline Release build produced `Local Assistant.app` and `OpenClaw Connector.app` at v5.4/build 54 with a rebuilt disk image, replacing the v5.2 artifacts at the project root. Both bundles pass a strict deep signature check, and the `DerivedData` cache was removed so the project root is the only place the build exists.

- **Automated tests:** **v5.4 status:** Complete; **Meaning:** 146 macOS test cases and all 40 Connector tests pass on this source. The three added cases cover statement reuse and were each confirmed to fail when the reuse code is deliberately broken.

- **Static privacy audit:** **v5.4 status:** Complete; **Meaning:** The offline-boundary audit passes against the signed v5.4 application. It carries exactly four entitlements — sandbox, audio input, app-scope bookmarks, and user-selected read-only — with no network entitlement and no reachable network code path.

- **Interface inspection:** **v5.4 status:** Complete; **Meaning:** No copy, layout, or visual styling changed in this release, and the installed v5.4 application's screens were inspected after the upgrade.

- **Formal verification:** **v5.4 status:** Partial; **Meaning:** The corrected launchd registration is verified on this Mac. The installed v5.4/build 54 Connector wrote `com.soucieux.LocalAssistant.OpenClawConnector.plist` to `~/Library/LaunchAgents` with owner-only permissions, removed the superseded `~/LaunchAgents` copy, and launchd reports the job loaded from that path with its scheduled spawn armed and a zero exit code. The disconnected acceptance run over the signed application was carried out separately; runtime socket inspection is still not part of this record.

- **Release artifact integrity:** **v5.4 status:** Complete; **Meaning:** `Local Assistant Release.dmg` verifies its checksum, mounts, and carries both applications at v5.4/build 54 beside the `Applications` link.

</details>

- **Status:** Released v5.4/build 54 after the private index moved to reused prepared statements and
  paired activity writes; the signed applications and disk image at the project root replace the
  v5.2 artifacts and are the first build carrying the v5.3 launchd correction, which is now
  installed and re-registered at the corrected launch-agent path on this Mac.

**Evidence and delivery status**

This v5.4/build 54 commit

[Back to change history](#change-history)

<a id="change-4"></a>

### Documentation

- **Recorded date:** 2026-09-04.

- Merged the version index and the dated maintenance history into one change-history table using the repository's required first-column labels: the exact version and build for an operation that changed them, `Maintenance` or `Documentation` otherwise.

- Build numbers were taken only from each release's own notes, so 20 rows carry one and 33 keep the version alone rather than a number derived from the numbering formula.
- No source, version, build, or artifact changed.

- Merged Local Assistant's version index and dated maintenance history into one change-history table following the repository's first-column convention.
- Build numbers were sourced from each release's own notes, so 20 rows carry a build and 33 keep the version alone rather than a derived number.
- No source, version, build, or artifact changed.

**Evidence and delivery status**

This documentation commit

[Back to change history](#change-history)

<a id="change-5"></a>

### v5.3 / build 53

- **Recorded date:** 2026-09-04.

- Released v5.3/build 53 after a byte-to-byte review of all 184 project files.
- Corrected the Connector launchd registration path and its failed-update restart, shared the inert Markdown parser and the temporary test database fixture, and named the remaining inline literals.
- No signed build was produced, so the project root retains the v5.2 artifacts.

- Released v5.3/build 53 after a byte-to-byte review of all 184 project files.
- Corrected the Connector launchd registration path, which placed the one-shot job outside `~/Library/LaunchAgents` so macOS stopped loading it after a logout, and restored that job when an update or re-verification fails.

- Shared the inert Markdown parser and the temporary test database fixture, and named the remaining inline literals.
- No signed build was produced; the project root retains the v5.2 applications and disk image.

- Registers the Connector's one-shot launchd job in `~/Library/LaunchAgents` instead of a
  `LaunchAgents` folder directly inside the home folder. Only the former is loaded automatically at
  login, so the job stopped running after a logout and its scheduled reminder refresh went silent
  until setup was opened again.
- Unloads that job by launchd service target rather than by property-list path, so an existing
  installation registered at the superseded location is stopped and its stale file removed before
  the corrected one is registered. Without this an update would fail to bootstrap a duplicate label.
- Restarts the installed job when an update or re-verification fails. Both flows stop the job before
  replacing the runtime, so a transient server failure previously left a working Connector unloaded.
  The job is restored only when an installed runtime is actually present.
- Shares one inert inline-Markdown parser between the assistant document and the user bubble. The
  two copies were byte-identical, and both must strip link destinations from untrusted text.
- Shares one temporary database fixture across the reminder and folder-indexing tests, replacing
  five duplicated set-up blocks and removing the helper and constant they needed.
- Names the remaining inline literals: the Connector host-key field count and minimum length, the
  owner-only permission mask, the launchd schedule hours, the file-transfer template tokens, the
  reminder-definition token count, and one bullet glyph.
- Completes the missing documentation blocks and access modifiers, corrects one misspelled test
  name, and restores the separations that made a file overview read as a type's own documentation.
- Advances Local Assistant and OpenClaw Connector to v5.3 build 53. Connector runtime v1.9.0, server
  bridge v1.4.0, and runtime contract v3 are unchanged because no wire contract changed.
- Passed all 143 macOS test cases and all 40 Connector tests, plus a standalone Connector type
  check. No signed release build was produced for this checkpoint.

**Evidence and delivery status**

This v5.3/build 53 commit

[Back to change history](#change-history)

<a id="change-6"></a>

### Documentation

- **Recorded date:** 2026-09-02.

- Linked Local Assistant's version-and-build declaration to the centralized repository policy and removed duplicated generic numbering rules.
- Application behavior, metadata, artifacts, and release numbers are unchanged.

**Evidence and delivery status**

This documentation commit

[Back to change history](#change-history)

<a id="change-7"></a>

### v5.2 / build 52

- **Recorded date:** 2026-08-31.

- Released v5.2/build 52 while reconciling the complete v0.1–v5.2 release index with retained Git records and preserving the historical v3.10/build-40 alias.
- Prepared the root-only development-guardrail consolidation separately and retained upstream llama.cpp guidance as CONTRIBUTOR_GUIDANCE.md.
- Application behavior, shared models, and deployed setup are unchanged.

- Released v5.2/build 52 while reconciling all 52 documented releases and assigning explicit versions to three previously date-only Local Assistant change batches.
- Application behavior, shared models, and deployed setup are unchanged.

- Assigns explicit releases to the three Local Assistant change batches that were previously
  displayed only by date in Project Control.
- Records the August 29 batch as v5.0/build 50 and the architecture batch as v5.1/build 51.
- Reconciles the complete version index through v5.2/build 52 while preserving the historical
  v3.10/build-40 alias.
- Leaves application behavior, model storage, Connector runtime v1.9.0, server bridge v1.4.0, and
  runtime contract v3 unchanged.

The current source release is **v5.2 (build 52)**. In the current release:

- ordinary conversation, file search, voice, and reminder reads stay local;
- confirmed reminder changes use the one-shot Connector;
- other delegated tasks require the user to say `OpenClaw`;
- every delegated agent message uses authenticated A2A v1.0 over a temporary encrypted server
  connection (SSH); and
- the local index uses relational SQLite, with the engine inside the app and the data file in its
  private sandbox.

**Evidence and delivery status**

This v5.2/build 52 documentation commit

v5.2 release-history commit

[Back to change history](#change-history)

<a id="change-8"></a>

### v5.1 / build 51

- **Recorded date:** 2026-08-31.

Released v5.1/build 51 with category-grouped architecture coverage, one technology or concept per row, and stable README section mappings.

Released v5.1/build 51 with a one-item-per-row architecture inventory and stable app section mapping; native runtime and model storage are unchanged.

Grouped the complete architecture inventory into AI, frontend, on-device logic, storage, and integration tables. App code, model storage, and v4.9/build 49 are unchanged.

- Expanded the architecture table with native Swift orchestration, model roles, RAG, indexing/monitoring, file access, reminder knowledge, and the separate Connector.
- Clarified that LangChain/LangGraph are not dependencies.
- Documentation only; v4.9/build 49 and model storage are unchanged.

- Groups the Local Assistant architecture by responsibility while keeping each technology, concept,
  and model on its own row.
- Defines RAG, embeddings, the embedded models, SQLite, FTS5, sqlite-vec, A2A, and SSH in the
  project-specific context where each is used.
- Adds stable README section mappings for Project Control without changing runtime behavior.
- Advances Local Assistant and OpenClaw Connector to v5.1/build 51. Connector runtime v1.9.0, server
  bridge v1.4.0, and runtime contract v3 remain unchanged.

**Evidence and delivery status**

`475ce69`, `539e14b`

Historical work record

[Back to change history](#change-history)

<a id="change-9"></a>

### v5.0 / build 50

- **Recorded date:** 2026-08-29.

- Released v5.0/build 50 after closing the remaining sort-order and indexing issues, naming remaining literals, sharing reminder-card formatting, correcting the historical v0.8 record, and rebuilding the disk image.

- Released v5.0/build 50 after applying the remaining sort-tie and indexing corrections, centralizing literals and reminder-card formatting, correcting the v0.8 historical description, and rebuilding the disk image.

- Breaks the remaining activity, search, and reminder sort ties with stable identifiers.
- Removes an unreachable indexing-worker respawn branch.
- Moves the remaining reminder, inference, and Connector literals into their existing constants.
- Shares one reminder timing formatter between the compact and full reminder cards.
- Corrects the historical v0.8 evidence and records the reconstructed release artifact.
- Advances Local Assistant and OpenClaw Connector to v5.0/build 50. Connector runtime v1.9.0, server
  bridge v1.4.0, and runtime contract v3 remain unchanged.

**Evidence and delivery status**

`3f1b433`, `dcc3bd3`, `77bbd16`, `2ea8810`, `1803626`, `3c36fdf`

[Back to change history](#change-history)

<a id="change-10"></a>

### v4.9 / build 49

- **Recorded date:** 2026-08-28.

- Advanced Local Assistant and OpenClaw Connector to v4.9 build 49 and Connector runtime v1.9.0;
  server bridge v1.4.0 and runtime contract v3 are unchanged.

- Gave ranked file results and folder-scope matches a total order; both previously sorted a
  dictionary by one score key, so equally scored files could differ between launches for the same
  request.

- Skipped an unparseable connector claim filename instead of raising out of service start-up, which
  previously stopped every later connector run; added a focused test that fails without the fix.

- Replaced the eight exact connector error strings matched as bare literals across both apps with
  named constants citing <code>constants.py</code>.

- Routed reminder retrieval explanations, schedule-document keys, the JSON suffix, and the POSIX
  locale identifier through the existing constant files.

- Removed 34 unreferenced Swift constants and nine Connector constants orphaned when A2A replaced
  the chat-completions transport.

- Added explicit access modifiers to 57 test declarations and one runtime method, and aligned the
  single outlier extension with the house convention.

- Named the five remaining retrieval calibration numbers, removing a latent divergence where the
  exact-name weight was assigned in one method and compared as a literal in another.

- Completed 64 documentation blocks so every function in the project carries the parameter and
  return documentation the standards require.

- Held the security-scoped read session across the Finder reveal and open calls with
  <code>withExtendedLifetime</code>, reusing the idiom already present in
  <code>FolderMonitorService</code>.

- Removed an unreachable respawn block at the end of <code>drainIndexingQueue</code>; its condition
  negated both of the loop's exit conditions with no suspension point between them, so it could
  never run.

- Collapsed duplicate branches in connector claim recovery, removed redundant enum-case bindings,
  and cleared blank-line residue from the removed design-token group.

- Split the two Connector files over the 800-line limit into
  <code>ConnectorSetupModel+Runtime.swift</code> and
  <code>ConnectorSetupView+Components.swift</code>; every first-party Swift file is now inside the
  limit.

- Put the indexing pipeline under test by depending on a new <code>DocumentEmbedding</code> protocol
  instead of the concrete embedding service, which previously required multi-gigabyte models to
  construct; added seven end-to-end run tests, each confirmed to fail against a deliberate
  regression.

- Split the resulting 245-line <code>IndexingService.index</code> into an error boundary plus named
  passes, reducing it to 47 lines with no function in the folder over 50; moved the record and
  progress builders to <code>IndexingService+Records.swift</code> to stay inside the file-size
  limit.

- Stopped re-reading every indexed row per run in <code>pruneItems</code>, which re-derived a stale
  list the scan pass had already computed.

- Committed a run's opening per-file classifications in one transaction instead of one durable write
  per file, which dominated the start of a large scan.

- Bounded decompressed ZIP entries in the Office and Pages extractors; the plain-text path already
  capped file size, but both archive paths accumulated an entry into memory with no limit.

- Derived the two vector-table widths in the SQL schema from the embedding-dimension constant rather
  than restating <code>1024</code>, so the schema cannot silently disagree with the dimension the
  code enforces.

- Named the remaining bare numbers in logic code, including the FSEvents coalescing latency, the
  connector spool read-chunk size, and the connector's authentication HTTP statuses.

- Passed all 137 macOS tests (up from 128), all 40 Connector tests with their 10 subtests, the clean
  offline release build, strict signature and version checks, the offline-boundary audit, disk-image
  verification, a launched-application smoke check with a clean index integrity result, and
  frozen-runtime source verification.

- Interface inspection was completed by the maintainer directly; automated capture stayed
  unavailable because macOS withheld screen-capture permission, and no permission boundary was
  widened. No user-facing copy, layout, or referenced design token changed. Git reconciliation:
  Advanced Local Assistant to v4.9/build 49 and Connector runtime v1.9.0: testable indexing, bounded
  archive expansion, deterministic retrieval, safer connector spool recovery, split setup files, and
  completed constants/documentation.

- Gives ranked file results and folder-scope matches a total order. Both previously sorted a
  dictionary by one score key, so equally scored files could differ between launches for the same
  request, and folder scoping could restrict results differently each time.
- Skips a connector claim filename the runtime cannot parse instead of raising out of service
  start-up, which previously stopped every later connector run until the file was removed by hand. A
  new focused test covers the recovery and fails without the fix.
- Replaces the eight exact connector error strings that the app and Connector matched as bare
  literals with named constants citing `constants.py` as their source of truth.
- Routes reminder retrieval explanations, the schedule-document keys, the JSON suffix, and the POSIX
  locale identifier through the existing constant files.
- Removes 34 unreferenced Swift constants, the emptied `DesignTokens.Shadow` group, and nine
  Connector constants orphaned when A2A replaced the chat-completions transport.
- Adds explicit access modifiers to 57 test declarations and one runtime method, and aligns the
  single outlier extension with the house convention.
- Names the five remaining retrieval calibration numbers. The exact-name and name-contains weights
  sat inline beside three sibling constants, and `explanation` compared against the same literal
  `addMetadata` assigned, so the two could silently diverge; one constant now drives both.
- Completes 64 documentation blocks on helpers across the reminder services, the spool service, the
  Connector model and setup view, app directories, the reminder database extension, grounded
  inference, indexing activity, and six test helpers, so every function in the project now carries
  the parameter and return documentation the standards require.
- Holds the security-scoped read session across the Finder reveal and open calls with
  `withExtendedLifetime`, reusing the idiom already used in `FolderMonitorService`, instead of a
  trailing `_ = resolved.access` the optimizer is free to discard.
- Removes an unreachable respawn block at the end of `drainIndexingQueue`. Its condition negated
  both of the loop's exit conditions with no suspension point in between, so on a `@MainActor` model
  it could never be true; the preceding `indexingWorker = nil` is what lets the next request start a
  fresh worker.
- Collapses two identical branches in the connector's claim recovery, removes redundant `case .x(_)`
  bindings in three switches, and clears the blank-line residue left by the removed
  `DesignTokens.Shadow` group.
- Splits the two Connector files that exceeded the 800-line limit into
  `ConnectorSetupModel+Runtime.swift` and `ConnectorSetupView+Components.swift`, following the
  existing `AssistantDatabase+*` and `SettingsView+*` pattern. Every first-party Swift file is now
  inside the limit, with 744 lines the largest.
- Advances Local Assistant and OpenClaw Connector to v4.9 build 49 and Connector runtime v1.9.0.
  Server bridge v1.4.0 and runtime contract v3 are unchanged because no wire contract changed.
- Puts the indexing pipeline under test by depending on a new `DocumentEmbedding` protocol instead
  of the concrete embedding service. `IndexingService` previously required a `LlamaCppRuntime` with
  multi-gigabyte models loaded, so no focused test could construct it and its 245-line `index` could
  not be split safely.

Seven end-to-end run tests now cover the first scan, unchanged and modified files, removal, a
  recoverable per-file failure, a fatal model failure, and oversized-passage splitting; each was
  confirmed to fail against a deliberate regression before being relied on.
- Splits that 245-line `index` into an error boundary plus named passes — `startingRun`,
  `performRun`, `beginRun`, `recordUnchangedFile`, `indexChangedFile`, `announceFileStart`,
  `recordSkippedFile`, and `finishInterruptedRun` — and collapses the two identical skip-handling
  branches into one. `index` is now 47 lines and no function in the folder exceeds 50. The record
  and progress builders moved to `IndexingService+Records.swift` so the file stays inside the
  800-line limit.
- Stops re-reading every indexed row for a folder on each run. `pruneItems` re-derived a stale list
  the run had already computed in its scan pass; it now takes that list directly.
- Commits a run's opening per-file classifications in one transaction instead of one durable write
  per file, which dominated the start of a large scan.
- Bounds decompressed ZIP entries in the Office and Pages extractors. The plain-text path already
  capped file size, but both archive paths accumulated an entry into memory with no limit, so a
  small container declaring an enormous entry could exhaust memory.
- Derives the two vector-table widths in the SQL schema from `embeddingDimensions` rather than
  restating `1024`, so the schema cannot silently disagree with the dimension the code enforces.
- Names the remaining bare numbers in logic code: the FSEvents coalescing latency, the connector
  spool read-chunk size, the recency decay day, the activity ordering nudge, the startup detail
  width, and the connector's authentication HTTP statuses, which sat inline beside an already named
  retryable set.
- Discards the `NSWorkspace.open` result explicitly so the `withExtendedLifetime` reveal fix no
  longer emits an unused-result warning.
- Passed all 137 macOS tests (up from 128) and all 40 Connector tests with their 10 subtests, the
  clean offline release build, strict project-root and mounted signature and version checks, the
  offline-boundary audit, disk-image verification, and a maintainer-run inspection of the built
  screens.

**Evidence and delivery status**

`66ae195` (2026-08-28)

Version-index record in `66ae195`; related date-group work: `4a4e598`, `8f3ed7c`, `1ededcb`, `6674a0b`, `f8da2e1`, `3ac61a3`, `3781759`, `66ae195`

[Back to change history](#change-history)

<a id="change-11"></a>

### v4.8 / build 48

- **Recorded date:** 2026-08-26.

- Advanced Local Assistant and OpenClaw Connector to v4.8 build 48 while retaining Connector runtime
  v1.8.0 and server bridge v1.4.0.

- Made required setup buttons equally prominent, expanded Mac/server location labels into full-width
  banners, and reflowed wide setup cards into instruction and action regions with one-column
  fallback.

- Kept the Connector open after save or update verification and retained a clear result immediately
  above the owning button.

- Reordered OpenClaw Settings around enablement, health, schedule plus Refresh Now, setup
  maintenance, and optional request behavior with readable explanation text.

- Reused the richer History file/folder card presentation on the main command screen and removed the
  duplicate weaker card implementation.

- Reworked all maintained Local Assistant documentation for beginners: expanded acronyms, added a
  plain RAG/FTS5/sqlite-vec flow, labeled A2A directly in the architecture, explained relational
  embedded SQLite, and collapsed developer-only internals.

- Passed 128 macOS tests, all 39 Connector tests, all 12 OpenClaw plugin tests, all 5 typed
  reminder-bridge tests, the clean release build, strict source/installed/mounted signature and
  version checks, the offline-boundary audit, responsive installed-screen inspection, and disk-image
  verification.

Git reconciliation: Committed the reminder/Connector and responsive-interface sequence documented
  as v3.2–v4.8: private reminder knowledge, one-shot SSH Connector, setup/recovery, conversational
  confirmation, native Markdown, A2A, and responsive settings/results. The old v3.10/build-40 label
  was normalized to v4.0 in the later index; this is one historical release, not two.

- Simplifies the README and architecture guide around local routing, reminder RAG, the one-shot SSH
  boundary, and A2A delegation.
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
- Passed all 128 macOS tests, all 39 Connector tests, all 12 OpenClaw plugin tests, and all 5 typed
  reminder-bridge tests. The clean release build, installed and mounted version and signature
  checks, offline-boundary audit, responsive installed-screen inspection, and disk-image
  verification also passed.

**Evidence and delivery status**

Version-index record in `0efc623` (2026-08-26); related date-group work in `dfb5057`, `5da7990`, `6185970`, `ea58bc9`, `d2cb05a`, `d8893f3`, `e0f1095`, `28640c9`, `6adfdab`, `b69e98a`, `ee7fe4f`, `f893a3f`, `ed3df06`, `77f5965`, `4061edc`, `8239dd6`, `b5a046a`, `65c4630`, `1962569`, `2f2228d`, `cbc2fc9`, `a06a422`, `4075c43`, `0efc623`, `421dac9`, `38c0de6`, `06b0ca2`

[Back to change history](#change-history)

<a id="change-12"></a>

### v4.7 / build 47

- **Recorded date:** 2026-08-26.

- Advanced Local Assistant and OpenClaw Connector to v4.7 build 47 and Connector runtime v1.8.0.

- Replaced direct Chat Completions transport with authenticated A2A v1.0 Agent Card discovery and
  text-only JSON-RPC <code>SendMessage</code>.

- Preserved exact-message disclosure, stable conversation identity, the separate read-only reminder
  route, and the network-free Local Assistant boundary.

- Updated in-app setup to require one fresh server ZIP for existing installations and to diagnose a
  missing A2A bridge directly.

- Passed 128 macOS tests, all 39 Connector tests, all 12 bridge tests, the clean offline build,
  strict project-root/installed/disk-image signature and version checks, the privacy audit,
  installed setup-screen inspection, and DMG verification.

- Replaces the Connector's direct Chat Completions transport with A2A v1.0 Agent Card discovery and
  JSON-RPC `SendMessage` while preserving the exact submitted text and stable conversation identity.
- Adds two Gateway-authenticated loopback routes to server bridge v1.4.0. The existing dedicated
  reminder snapshot route and Calendar-unchanged proof remain separate and unchanged.
- Keeps Local Assistant offline, keeps OpenClaw on `127.0.0.1:23116`, and opens only the existing
  one-request restricted SSH tunnel. No VPN, public Gateway, public HTTPS origin, or permanent
  tunnel is added.
- Advances Local Assistant and OpenClaw Connector to v4.7 build 47, Connector runtime v1.8.0, and
  runtime contract v3. Existing users create and run a fresh server setup ZIP once before verifying
  the updated Connector.

**Evidence and delivery status**

`1962569` (2026-08-26)

Version-index record in `1962569`

[Back to change history](#change-history)

<a id="change-13"></a>

### v4.6 / build 46

- **Recorded date:** 2026-08-26.

- Advanced Local Assistant and OpenClaw Connector to v4.6 build 46 while retaining Connector runtime
  v1.7.0 and server bridge v1.3.0.

- Replaced the fixed-width current answer and constrained assistant History content with response
  documents that expand continuously with the live app window.

- Added a native selectable block-Markdown parser and SwiftUI presentation for headings, paragraphs,
  emphasis, lists, quotations, fenced code, dividers, and real styled pipe tables.

- Kept links inert and added no WebView, network entitlement, or Connector transport change.

- Passed five focused parser cases, the clean offline release build, signed-bundle privacy audit,
  project-root and installed version/signature checks, restored and expanded installed response
  inspection, and mounted-disk-image verification.

- Expands the current answer and retained assistant History content with the live app window instead
  of keeping the old fixed-width answer column.
- Presents common block Markdown as native SwiftUI headings, paragraphs, emphasis, lists,
  quotations, fenced code, dividers, and real table cells. OpenClaw pipe tables no longer appear as
  raw `|` and `---` text.
- Keeps response links inert and adds no WebView or network presentation dependency, preserving the
  Local Assistant privacy boundary.
- Advances Local Assistant and OpenClaw Connector to v4.6 build 46. Connector runtime v1.7.0 and
  OpenClaw server bridge v1.3.0 remain unchanged because neither transport contract changed.
- Passed five focused parser cases, the clean release build, source/installed/mounted version and
  signature checks, the signed-bundle privacy audit, installed restored/expanded response
  inspection, and disk-image verification.

**Evidence and delivery status**

`8239dd6` (2026-08-26)

Version-index record in `8239dd6`

[Back to change history](#change-history)

<a id="change-14"></a>

### v4.5 / build 45

- **Recorded date:** 2026-08-26.

- Advanced Local Assistant and OpenClaw Connector to v4.5 build 45 and Connector runtime package
  v1.7.0.

- Accepted clear natural confirmation instructions such as continue, proceed, go ahead, send it, or
  cancel without requiring the literal words yes or no, while leaving ambiguous or changed requests
  pending.

- Centered the processing label and progress bar in the available assistant workspace instead of the
  top of the result scroller.

- Replaced the Connector package's vulnerable setuptools build backend with pinned Hatchling 1.27.0
  while retaining editable installs and standalone runtime packaging.

- Passed 40 focused macOS routing tests, all 36 Connector tests, a zero-vulnerability QWeather
  package audit, the clean offline build, strict source/installed/disk-image signature checks, the
  privacy audit, installed processing-state inspection, mounted disk-image validation, and a real
  Connector connection check.

- Accepts clear standalone instructions such as continue, proceed, go ahead, send it, do it, okay,
  sure, or cancel without requiring the literal words yes or no. The embedded local LLM remains the
  interpreter for other natural replies, while ambiguous or changed requests stay pending.
- Centers the processing label and progress bar in the full available assistant workspace instead of
  placing them near the top of the result scroller.
- Replaces the Connector package's vulnerable setuptools build backend with pinned Hatchling 1.27.0
  because the patched setuptools release identified by the alert is not available from the package
  index. Editable installs and standalone packaging remain supported.
- Advances Local Assistant and OpenClaw Connector to v4.5 build 45 and the Connector runtime package
  to v1.7.0. The OpenClaw server bridge remains v1.3.0 because its read-only snapshot contract did
  not change.
- Focused confirmation, dependency, packaging, release, installed-interface, and disk-image results
  are recorded in the release-status table after they run.

**Evidence and delivery status**

`ed3df06` (2026-08-26)

Version-index record in `ed3df06`

[Back to change history](#change-history)

<a id="change-15"></a>

### v4.4 / build 44

- **Recorded date:** 2026-08-26.

- Advanced Local Assistant and OpenClaw Connector to v4.4 build 44 and Connector runtime package
  v1.6.0.

- Replaced the reminder-change confirmation dialog with an assistant turn that repeats the exact
  pending request and uses the embedded local LLM to interpret the user's yes-or-no reply.

- Moved reminder cancellation, unclear replies, Connector recovery guidance, and request failures
  into the assistant conversation while retaining failed changes for retry.

- Added a non-secret Connector runtime contract marker and a fresh pre-send check, preventing the
  older-runtime mismatch that returned <code>connector request is invalid</code>.

- Retained the network-free Local Assistant boundary, exact-request disclosure, one-shot restricted
  SSH tunnel, hidden complete-snapshot reminder RAG, and unchanged v1.3 server bridge.

- Passed 36 Connector tests, a clean 47-test focused macOS run, all 122 complete macOS test cases
  before an Xcode post-result teardown stall, the offline release build, signature and privacy
  checks, installed-app inspection, mounted disk-image validation, and a real read-only reminder
  refresh reporting Ready.

- Replaces the reminder-mutation confirmation alert with an assistant conversation turn that repeats
  the exact pending request and asks for a yes-or-no reply.
- Uses the embedded local LLM to classify that reply as confirm, decline, or unclear. Only the exact
  confirmation result authorizes the pending request; unclear replies keep it pending and ask again.
- Presents reminder-request failures, cancellation, and recovery guidance as assistant messages
  instead of separate dialogs. A failed mutation remains pending so the user can retry without
  reconstructing it.
- Adds a non-secret Connector runtime contract version to the owner-only status file. Local
  Assistant reads it again at confirmation time and directs an older runtime to **Update and Verify
  Existing Connector** before any incompatible request is published.
- Advances Local Assistant and OpenClaw Connector to v4.4 build 44 and the Connector runtime package
  to v1.6.0. The OpenClaw server bridge remains v1.3.0 because its read-only snapshot contract did
  not change.
- Focused confirmation and runtime-contract tests, Connector regression tests, release building,
  installed-flow inspection, and disk-image validation are recorded in the release-status table.

**Evidence and delivery status**

`ed3df06` (2026-08-26)

Version-index record in `ed3df06`

[Back to change history](#change-history)

<a id="change-16"></a>

### v4.3 / build 43

- **Recorded date:** 2026-08-26.

- Advanced Local Assistant and OpenClaw Connector to v4.3 build 43 and Connector runtime package
  v1.5.0.

- Recognized clear reminder and to-do language without requiring the word OpenClaw; read-only
  reminder requests stay in the complete local cache and RAG index.

- Required explicit confirmation for every reminder create, update, complete, reschedule, or remove
  request before only its exact text and typed authorization enter the Connector.

- Removed the complete-list presentation cap, summarized current and retained reminder history
  instead of repeating item prose, and rendered every cached item as an equal-height icon, urgency,
  and tag-styled card.

- Made reminder and file/folder cards change columns live with the window width, and expanded
  applicable Settings, Activity, History, and setup layouts without fixed whole-screen or lower
  gaps.

- Restored automatic submission after about two seconds of silence in both voice modes while
  preserving earlier Hold Space release.

- Passed focused macOS and Connector regression tests, the clean offline release build,
  signed-bundle privacy and identity checks, compact and expanded installed-screen inspection, and
  mounted disk-image validation.

- Recognizes clear reminder and to-do phrasing without requiring the user to say OpenClaw. Read-only
  list and question requests use the complete local reminder cache and RAG index without
  confirmation or Connector access.
- Requires explicit confirmation for every reminder create, update, complete, reschedule, or remove
  request, including requests that name OpenClaw. After confirmation, only the exact submitted text
  and its typed authorization enter the Connector.
- Returns every cached reminder for an all-reminders request without a presentation cap, keeps both
  current and retained History prose concise, groups cards by tag with one heading per group, and
  shows one reminder per equal-height styled card with a semantic icon, urgency, date/time, and an
  optional link indicator.
- Makes reminder cards, file/folder findings, Settings, Activity, History, and other applicable
  collections adapt their columns and available space live as the window changes size, without fixed
  whole-screen margins or unnecessary lower gaps.
- Restores automatic submission after about two seconds of silence in both voice modes while
  preserving immediate Hold Space release.
- Advances Local Assistant and OpenClaw Connector to v4.3 build 43 and the Connector runtime package
  to v1.5.0. The OpenClaw server bridge remains v1.3.0 because its read-only snapshot contract did
  not change.
- Focused tests, release building, signed-artifact checks, privacy audit, installed-screen
  inspection, and disk-image validation are recorded in the release-status table after they run.

**Evidence and delivery status**

`ed3df06` (2026-08-26)

Version-index record in `ed3df06`

[Back to change history](#change-history)

<a id="change-17"></a>

### v4.2 / build 42

- **Recorded date:** 2026-08-26.

- Advanced Local Assistant and OpenClaw Connector to v4.2 build 42.

- Removed the fixed 184-point minimum height from the actual Local Assistant three-step OpenClaw
  guide.

- Made Steps 2 and 3 end after their visible content while retaining equal widths and consistent
  padding.

- Added an exact-screen verification guardrail for screenshot-reported layout defects.

- Passed the complete Local Assistant macOS test target, all 35 Connector tests, the clean offline
  Release build, strict source and installed signatures, the privacy audit, exact installed-screen
  visual inspection, and mounted disk-image validation.

- Removed the fixed 184-point minimum height from the shared card used by Local Assistant's
  three-step OpenClaw guide.
- Made Steps 2 and 3 end after their visible text and controls while retaining equal widths,
  consistent padding, and the existing card surface.
- Removed the now-unused setup-card minimum-height design token.
- Added a project guardrail requiring screenshot-reported layout defects to be verified in the exact
  installed application and screen shown, not in a visually similar companion screen.
- Advanced Local Assistant and OpenClaw Connector to v4.2 build 42 so the release package continues
  to contain matching applications.
- Passed the complete Local Assistant macOS test target, all 35 Connector tests, the clean offline
  Release build, strict source and installed-bundle signature checks, the signed-app privacy audit,
  exact installed-screen visual inspection, and mounted disk-image validation.

**Evidence and delivery status**

`ed3df06` (2026-08-26)

Version-index record in `ed3df06`

[Back to change history](#change-history)

<a id="change-18"></a>

### v4.1 / build 41

- **Recorded date:** 2026-08-26.

- Advanced Local Assistant and OpenClaw Connector source versions to v4.1 build 41.

- Replaced the two equivalent overview routes with one full-width connection-review action and kept
  credential replacement inside Step 4.

- Made the Connector setup cards content-height so its Steps 2 and 3 no longer retain excess lower
  whitespace.

- Changed existing-install discovery to a bounded metadata-only Keychain query, preventing startup
  from waiting on credential-value access while never returning a token.

- Added a release guard that rejects mismatched Local Assistant and Connector versions.

- Defined minor versions as 0 through 9 and corrected the preceding v3.10 release record to v4.0
  while preserving its original build-40 bundle label.

- Passed focused Keychain/setup tests, the clean offline Release build, strict source and installed
  signatures, the privacy audit, installed-app visual inspection, and mounted disk-image validation.

- Replaced the duplicate **Review Connection Settings** and **Replace Saved Credentials** overview
  routes with one full-width **Review Connection** action.
- Kept **Replace Saved Credentials** inside Step 4 beside the saved Keychain status, so credential
  changes begin only where the two secure fields belong.
- Removed the Connector layout rail from card measurement and made every Connector setup card
  content-height, eliminating excess lower whitespace in its Steps 2 and 3 while retaining equal
  widths and semantic colors.
- Replaced setup discovery's credential-value read with a bounded macOS Keychain metadata query.
  Startup receives only presence booleans, cannot wait indefinitely for Keychain metadata, and still
  loads a token only when an authenticated request actually needs it.
- Advanced Local Assistant and OpenClaw Connector to v4.1 build 41.
- Defined marketing-version minor numbers as `0` through `9`, with `vN.9` followed by `v(N+1).0`;
  the build number remains a separate increasing integer.
- Added a release-package guard that stops the build when Local Assistant and OpenClaw Connector
  versions or build numbers differ.
- Passed the 6 focused Keychain and existing-setup tests, clean offline Release build, strict source
  and installed-bundle signature checks, signed-app privacy audit, installed-app visual inspection,
  and mounted disk-image validation.

**Evidence and delivery status**

`ed3df06` (2026-08-26)

Version-index record in `ed3df06`

[Back to change history](#change-history)

<a id="change-19"></a>

### v4.0 / build 40

- **Recorded date:** 2026-08-26.

- Corrected the historical build-40 release label from v3.10 to v4.0; the original applications and
  Git history remain stamped <code>3.10</code>.

- Advanced the Connector runtime package to v1.4.0.

- Added credential-free discovery of an existing installation using only reusable public settings
  and yes/no Keychain-presence flags.

- Added no-reentry runtime update and verification, explicit replacement through empty secure
  fields, and confirmed exact Connector cleanup that preserves Local Assistant and its committed
  reminder cache.

- Reworked the Connector into a light semantic-color setup workbench and shortened the five primary
  steps for first-time users while keeping definitions and recovery in step-owned
  question-and-answer disclosures.

- Kept the app target network-free and retained the one-request pinned SSH tunnel, loopback-only
  Gateway, complete-snapshot reminder cache, and hidden local reminder RAG.

- Passed the complete Local Assistant Xcode test target, 44 Connector and bridge tests, the clean
  offline Release build, strict signature checks, the signed-app privacy audit, installed-app visual
  inspection, and mounted disk-image validation.

- This is the corrected historical release label for build 40.
- The original build-40 applications were stamped `3.10`; that immutable bundle metadata and the existing Git history are not rewritten.

- Added credential-free discovery of an existing Connector installation. The Swift app receives only
  reusable public server values and yes/no Keychain-presence flags; it never retrieves or displays
  saved tokens.
- Added **Update and Verify Existing Connector**, which installs the current packaged runtime,
  reuses the saved SSH identity, configuration, and Keychain tokens, verifies a real complete
  snapshot, and restarts the one-shot job without asking the user to repeat setup.
- Separated **Replace Saved Credentials** from public settings review. New tokens enter through
  empty secure fields, move to Keychain through bounded standard input, and are cleared from Swift
  immediately after secure handoff even if later verification fails.
- Added confirmed **Remove Connector Data**, which deletes the exact Connector runtime, identity,
  settings, checkpoint, launch job, pending spool lanes, and two Keychain entries while preserving
  Local Assistant and its committed reminder cache and RAG index.
- Replaced the dense Connector form with a light-only semantic-color workbench: blue identifies
  server values, cyan identifies generated files, orange identifies server actions, teal identifies
  credentials and privacy, green identifies verification, and red is reserved for destructive
  cleanup.
- Rewrote every primary step for a first-time user who knows only how to open Mac Terminal and the
  server terminal. Required actions and completion cues remain visible; definitions, security
  details, alternatives, internal port details, and Q&A recovery remain collapsed under the step
  that owns them.
- Corrected the release record to v4.0 build 40 and retained Connector runtime package v1.4.0. The
  original applications remain stamped `3.10`, and the OpenClaw reminder bridge remains v1.3.0
  because its server contract did not change.
- Passed the complete Local Assistant Xcode test target, all 32 Connector tests, all 7 OpenClaw
  plugin tests, all 5 typed reminder-bridge tests, the clean offline Release build, strict
  bundle-signature checks, the signed-app privacy audit, installed-app visual inspection, and
  mounted disk-image validation.

**Evidence and delivery status**

`ed3df06` (2026-08-26)

Historical work record

[Back to change history](#change-history)

<a id="change-20"></a>

### v3.9 / build 39

- **Recorded dates:** 2026-08-26; 2026-08-25.
- **Date provenance:** Change history: 2026-08-26; Repository history records: 2026-08-25. Different source dates are retained; they are not newly established release dates.

- Advanced Local Assistant and OpenClaw Connector to v3.9 build 39 and connector package v1.3.0.

- Fixed OpenSSH parsing of the pinned host-key file inside the standard macOS Application Support
  path.

- Canonicalized Swift UUID casing before forwarding and response comparison, eliminating the false
  <code>connector could not complete the request</code> result after valid reminder snapshots.

- Moved public-key and server-ZIP creation into OpenClaw Connector and restored Local Assistant's
  user-selected-files entitlement to read-only.

- Added exact Connector version/build selection, visible startup progress, Dock-visible Connector
  behavior, and current-screen restoration when Local Assistant reopens from the Dock.

- Simplified setup into three Local Assistant completion cards and five bullet-first Connector steps
  with safe, specific SSH diagnostics.

- Fixed the standard macOS `Application Support` SSH host-key path so OpenSSH receives it as one
  pinned file rather than splitting it at the space.
- Canonicalized Swift-generated UUIDs before forwarding and comparison, preventing valid complete
  reminder snapshots from being replaced by the generic `connector could not complete the request`
  response.
- Added regression coverage at the workflow, service, and SSH-command boundaries.
- Moved public-key and server-ZIP creation into the standalone Connector, which now embeds the
  generic server kit and owns every user-approved export. Local Assistant returned to a read-only
  user-selected-files entitlement.
- Replaced the overwhelming Local Assistant procedure with three short completion cards and a
  five-step bullet-first Connector flow that distinguishes existing server access, two generated
  files, server commands, printed values, and local verification.
- Added bounded server-route readiness retries and service diagnostics so a normal Gateway restart
  no longer races the installer snapshot check.
- Added allowlisted SSH failure reasons for host-key mismatch, rejected public key, unresolved
  address, refused connection, timeout, and unreachable network without exposing raw SSH output or
  credentials.
- Required exact marketing-version and build-number matching before Local Assistant opens a
  Connector, with recovery wording when Applications contains an older copy.
- Added visible startup progress, preserved the current screen when reopening from the Dock, kept
  the global shortcut's assistant behavior, and made the Connector a normal Dock-visible
  application.
- Advanced Local Assistant and OpenClaw Connector to v3.9 build 39 and the bridge/connector packages
  to v1.3.0.

**Evidence and delivery status**

`ea58bc9` (2026-08-26)

Version-index record in `ea58bc9`

[Back to change history](#change-history)

<a id="change-21"></a>

### v3.8 / build 38

- **Recorded dates:** 2026-08-26; 2026-08-25.
- **Date provenance:** Change history: 2026-08-26; Repository history records: 2026-08-25. Different source dates are retained; they are not newly established release dates.

- Advanced Local Assistant and OpenClaw Connector to v3.8 build 38 and connector package v1.2.0.

- Replaced Tailscale and private HTTPS ingress with a pinned, on-demand SSH tunnel opened only by
  the separate Connector for one request.

- Added user-controlled Ed25519 key generation and public-key export; the private key stays
  owner-only on the Mac and never enters the generic server ZIP.

- Added a one-shot launchd workflow for queued work and due two-, four-, or eight-hour reminder
  checks, including missed-check handling after wake.

- Added scheduled complete-snapshot handoff and transactional cache/RAG replacement; failures
  preserve the last complete local knowledge and mark it potentially outdated.

- Rewrote the seven full-width setup cards and collapsed Q&A troubleshooting around existing SSH
  access, two-file transfer, loopback-only server setup, host-key pinning, and restricted-account
  failures.

- Replaced Tailscale and the private HTTPS origin with an on-demand encrypted SSH tunnel opened by
  the separate Connector only for one request.
- Kept OpenClaw fixed to server loopback `127.0.0.1:23116`; no public Gateway port, HTTPS endpoint,
  VPN app, or continuously running tunnel is required.
- Added user-controlled Connector key generation. Only `local-assistant-connector.pub` is exported;
  the owner-only private key stays on the Mac and never enters the server ZIP or a command argument.
- Reworked the rerunnable server installer to create a non-root, no-shell `local-assistant-tunnel`
  account restricted to local forwarding to the exact Gateway destination, with PTY, X11, agent
  forwarding, remote forwarding, and all other destinations denied.
- Added strict Ed25519 host-key pinning and SSH configuration rollback when `sshd` validation fails.
- Replaced the persistent connector process with a one-shot launchd job. Queued app work launches it
  immediately; calendar checks support two-, four-, and eight-hour reminder schedules and a missed
  check after wake.
- Added scheduled snapshot handoff: the Connector fetches a complete snapshot, exits, and leaves the
  newest result in the owner-only spool until Local Assistant validates, embeds, and transactionally
  replaces the cache and RAG index.
- Preserved the prior complete cache on every fetch, validation, embedding, or database failure and
  visibly marks reminder knowledge as potentially outdated. Missing IDs in a successful complete
  snapshot are deleted locally without `updatedAt` fields or tombstones.
- Rewrote the seven-step in-app guide and its collapsed Q&A troubleshooting around the real SSH
  flow, clean-device assumptions, public-key and ZIP transfer, server-owner boundary, host-key
  verification, one-shot scheduling, and stale-cache behavior.
- Advanced Local Assistant and OpenClaw Connector to v3.8 build 38 and the bridge/connector packages
  to v1.2.0.

**Evidence and delivery status**

`ea58bc9` (2026-08-26)

Version-index record in `ea58bc9`

[Back to change history](#change-history)

<a id="change-22"></a>
<a id="v37--complete-private-tailscale-connection-setup"></a>

### v3.7 / build 37

- **Recorded date:** 2026-08-26.

- Git index record, not an independently established release date: [Complete private Tailscale connection setup](#v37--complete-private-tailscale-connection-setup).
- Preserves the documented intermediate release; no separate commit/build is invented.

- Added a browser-specific prerequisite section that separates new Tailscale accounts from existing
  accounts and explains that sign-up uses an external identity provider, not the CLI-only OpenClaw
  server.
- Added execute-as-is Linux commands that install Tailscale only when missing, print a one-time
  authorization URL when required, and confirm the server has joined the intended tailnet.
- Added a separate OpenClaw token-authentication check and private Tailscale Serve command block
  that keeps the Gateway on loopback and identifies the exact `https://…ts.net` origin required by
  the connector.
- Distinguished the one-time authorization URL, private HTTPS origin, WebSocket addresses, and API
  paths so the wrong value cannot be pasted into the server installer or connector.
- Added separate Mac instructions for new and existing Tailscale installations, including the
  same-account requirement, macOS network-extension approval, and server-visibility check.
- Added buttons for the official Tailscale account, Linux installation, and macOS installation
  pages. Local Assistant only opens those pages in the default browser and receives no account or
  sign-in information.
- Preserved concise bullet groups, aligned full-width cards, distinct browser/server/Mac locations,
  in-card command copy actions, and the network-denied Local Assistant boundary.
- Advanced Local Assistant and OpenClaw Connector to v3.7 build 37.
- Rebuilt the signed release apps and clean-Mac disk image, passed 17 connector tests and 7 bridge
  tests, passed the offline-boundary and packaging checks, and visually inspected the guide and
  connector at normal and minimum sizes under both system appearances.

**Evidence and delivery status**

`ea58bc9` (2026-08-26)

`ea58bc9`

[Back to change history](#change-history)

<a id="change-23"></a>

### v3.6 / build 36

- **Recorded dates:** 2026-08-26; 2026-08-25.
- **Date provenance:** Change history: 2026-08-26; Repository history records: 2026-08-25. Different source dates are retained; they are not newly established release dates.

- Released v3.6 build 36 as a checksum-valid clean-Mac disk image containing the network-denied app
  and separately networked connector app.

- Moved server ZIP creation into an explicit in-app save action: the user chooses the destination,
  nothing is downloaded, no credentials are included, and the DMG no longer contains an
  automatically generated ZIP.

- Replaced the labelled **WHERE**, **DO THIS**, and **EXPECT** rows with concise bullet steps while
  retaining separate OpenClaw-server and local-companion sections; command blocks and app-opening
  actions now remain inside their owning cards.

- Aligned every setup surface to the same content width and added a declared, generated icon to the
  standalone connector application.

- Removed the Reminder Center, direct CloudBase CRUD proposals, confirmation sheet, and local
  reminder notifications so the cache remains hidden read-only knowledge.

- Kept Local Assistant network-free while consolidating all external traffic into the separate
  LangGraph connector with exact origins, Keychain credentials, and independent
  snapshot-versus-agent validation.

- Passed 110 Local Assistant test cases, 17 connector tests, and 7 OpenClaw bridge tests with no
  failures or skips.

- Passed built-app inspection for the setup guide and connector at normal and minimum sizes in Light
  and Dark appearances; documented that the home-screen navigation labels shorten at the 680-point
  minimum width.

- Passed the clean Release compilation, signed-bundle offline audit, connector signature and icon
  checks, embedded-payload check, and disk-image checksum.

- Replaced the automatically generated server ZIP with a **Create Server Setup ZIP…** action inside
  Local Assistant. The user chooses the destination, and the app explains that it packages versioned
  server runtime files locally without downloading content or adding credentials.
- Kept **Set up the OpenClaw server** and **Set up the local companion** as the two location
  boundaries. Every setup card now uses concise bullet points, every card fills the same content
  width, the server commands and copy action remain inside server step 2, and **Open Connector App**
  remains inside the connector-configuration card.
- Reduced the disk image to the two standalone Mac applications. Required server installer and
  bridge files are embedded in Local Assistant and enter the exported ZIP only after the user
  requests it; development tests and documentation are excluded from that payload.
- Added a distinct generated icon to `OpenClaw Connector.app` and declared it in the connector
  bundle metadata.
- Preserved the app's network-denied sandbox while adding user-selected write access solely for the
  ZIP destination; authorized source-folder bookmarks remain read-only.
- Corrected post-payload signing so the final Local Assistant bundle retains its explicit sandbox
  entitlements, then rebuilt and checksum-validated the v3.6 build 36 release DMG.

**Evidence and delivery status**

`ea58bc9` (2026-08-26)

Historical work record

[Back to change history](#change-history)

<a id="change-24"></a>
<a id="v35--unambiguous-clean-device-openclaw-setup"></a>

### v3.5 / build 35

- **Recorded date:** 2026-08-26.

- Git index record, not an independently established release date: [Unambiguous clean-device OpenClaw setup](#v35--unambiguous-clean-device-openclaw-setup).
- Preserves the documented intermediate release; no separate commit/build is invented.

- Replaced the conceptual four-step guide with separate **ON THE OPENCLAW SERVER** and **ON THIS
  MAC** sections. Every command states its execution location, whether it runs unchanged, and
  whether a prompt expects input.
- Normalized all six step cards to the same width and minimum height, with aligned **WHERE**, **DO
  THIS**, and **EXPECT** rows instead of dense instruction paragraphs.
- Added `OpenClaw Server Setup.zip`, whose interactive server installer installs and verifies the
  read-only bridge, enables the agent endpoint, restarts OpenClaw, and prints the three values
  needed on the Mac without asking the user to edit a file.
- Added a separately packaged `OpenClaw Connector.app` containing its own Python and LangGraph
  runtime. It detects the local spool, saves configuration and Keychain credentials through the
  packaged connector, and starts a per-user background service without requiring Python, Git,
  Terminal, or project source on the user's Mac.
- Added a complete release disk image containing both applications and the server setup kit, while
  keeping all network access outside `Local Assistant.app`.
- Advanced the application to v3.5 build 35.

**Evidence and delivery status**

`ea58bc9` (2026-08-26)

`ea58bc9`

[Back to change history](#change-history)

<a id="change-25"></a>
<a id="v34--live-openclaw-status-and-in-app-setup"></a>

### v3.4 / build 34

- **Recorded date:** 2026-08-26.

- Git index record, not an independently established release date: [Live OpenClaw status and in-app setup](#v34--live-openclaw-status-and-in-app-setup).
- Preserves the documented intermediate release; no separate commit/build is invented.

- Added a live **Connection status** summary to the OpenClaw Settings section. While the
  user-controlled ability is enabled, Local Assistant checks the connector's bounded, non-secret
  local heartbeat once per second and reports Off, Checking, Not detected, Running but not yet
  verified, Ready, or Needs attention.
- Added a same-window **OpenClaw Setup** guide opened from Settings, with plain-language
  preparation, installation, secure configuration, start, recovery, and privacy steps. The
  installation-specific spool path can be copied there, and optional source-install commands remain
  collapsed until requested.
- Kept the privacy boundary unchanged: Local Assistant has no network entitlement, never reads the
  OpenClaw origin or Keychain credentials, and stops both automatic reminder refreshes and heartbeat
  monitoring when the connection ability is disabled.
- Advanced the application to v3.4 build 34.

**Evidence and delivery status**

`ea58bc9` (2026-08-26)

`ea58bc9`

[Back to change history](#change-history)

<a id="change-26"></a>
<a id="v33--hidden-reminder-knowledge-and-explicit-openclaw-actions"></a>

### v3.3 / build 33
- **Recorded date:** 2026-08-26.

- Git index record, not an independently established release date: [Hidden reminder knowledge and explicit OpenClaw actions](#v33--hidden-reminder-knowledge-and-explicit-openclaw-actions).
- Preserves the documented intermediate release; no separate commit/build is invented.

- Removed the Reminder Center, Local Assistant reminder CRUD proposals, confirmation sheet, and
  macOS reminder notifications. Every cached reminder is now hidden, read-only local knowledge.
- Clarified Privacy with the sole external OpenClaw path, moved every connector control into a
  distinct **OpenClaw Connection** section directly below it, and added visible setup state with a
  portable connector guide.
- Added local reminder-grounded generation so the assistant can answer questions from retrieved
  CloudBase records instead of only showing matches.
- Added a deterministic standalone `OpenClaw` / `Open Claw` gate before local inference. Matching
  requests go immediately to OpenClaw with only the exact submitted text and a stable conversation
  identifier.
- Reduced the reminder bridge to complete-list snapshots and made both the Swift service and
  LangGraph connector reject every read-by-ID and mutation shape.
- Consolidated connector traffic onto one exact OpenClaw origin while retaining separate Keychain
  credentials for snapshot reads and full-operator agent requests.
- Changed automatic refresh choices to two, four, or eight hours, with a four-hour default, stale
  launch catch-up, and a refresh after each successful OpenClaw response.

**Evidence and delivery status**

`ea58bc9` (2026-08-26)

`ea58bc9`

[Back to change history](#change-history)

<a id="change-27"></a>

### v3.2 / build 32
- **Recorded dates:** 2026-08-26; 2026-08-23.
- **Date provenance:** Change history: 2026-08-26; Repository history records: 2026-08-23. Different source dates are retained; they are not newly established release dates.

- Added complete CloudBase reminder snapshots, transactional local caching,
  exact/FTS/vector/temporal reminder RAG, and ownership-aware Reminder Center and History cards.

- Added confirmation-gated CloudBase-only create, update, and delete operations, stable create
  idempotency, compare-and-set updates, and exact plus one-day-early local alerts only for Local
  Assistant-owned reminders.

- Kept the sandboxed app network-free and added an opt-in separate LangGraph connector with exact
  HTTPS origins, separate Keychain credentials, bounded owner-only no-follow spool IPC, complete
  outbound disclosure, and an independently disabled OpenClaw agent lane. Git reconciliation:
  Refreshed release audit assumptions without a new application version.

- Added a complete-snapshot CloudBase reminder cache because the remote rows have no incremental
  timestamp or deletion tombstone. A malformed, partial, timed-out, or unembeddable snapshot never
  replaces the previous complete cache.
- Added local exact, FTS5, Qwen embedding, reciprocal-rank, and temporal reminder retrieval, with
  reminder cards retained in conversation History.
- Added a Reminder Center with Upcoming, Overdue, and All views, explicit ownership labels,
  automatic sync while the app is open, and exact plus one-day-early local alerts only for Local
  Assistant-owned rows.
- Added confirmation-gated CloudBase-only create, update, and delete operations. Creates carry a
  stable idempotency key, updates carry compare-and-set fields, and all mutations reject
  OpenClaw-managed and legacy/unknown rows.
- Added a separate Python connector using LangGraph and durable SQLite checkpoints, exact HTTPS
  origins, separate Keychain credentials, bounded owner-only spool files, and reminder versus
  full-operator lanes. Both lanes are disabled until explicitly configured; the app itself retains
  no network entitlement.
- Added an OpenClaw plugin route that accepts only the narrow schema-v1 reminder contract, always
  requires `calendarPolicy:"never"`, invokes a fixed bridge command, and never accepts a calendar
  identifier.

**Evidence and delivery status**

`ea58bc9` (2026-08-26)

Retrospective work record; retained source in `dfb5057`, `5da7990`, `ea58bc9` (2026-08-26)

[Back to change history](#change-history)

<a id="change-85"></a>

### Removed the stale hard-coded version fallback so bundle metadata remains authoritative and unavailable metadata is reported explicitly

- **Recorded date:** 2026-08-23.

<ul><li>Removed the stale hard-coded version fallback so bundle metadata remains authoritative and unavailable metadata is reported explicitly.</li><li>Aligned indexing decision regression checks with the current content-indexing policy names and wording.</li><li>Made the documented release gates reusable across versions and corrected the offline-boundary command to audit the built root application.</li></ul>

**Evidence and delivery status**

`ccc028d`

[Back to change history](#change-history)

</details>

### Earlier history

Older records are archived by period, newest first. Each archive keeps the same table
and full records; the count after a link is how many records it holds.

- **Months** — [August 2026](history/2026-08.md) (35)

---

<!-- project-control:section=ignore -->
## 🔒 License

**PROPRIETARY SOFTWARE — ALL RIGHTS RESERVED**

Copyright © 2024–2026 Soucieux. All rights reserved.

The original source code, documentation, and other original materials in this repository are proprietary and are not open-source software.

Except where applicable law expressly permits otherwise, no permission is granted to copy, modify, publish, distribute, sublicense, sell, deploy, or create derivative works from these materials, in whole or in part, without prior written authorization from the copyright owner.

Access to this repository does not grant a license. Third-party software and materials remain subject to their respective license terms.

*This private project is not open for external contributions.*
