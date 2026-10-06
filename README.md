# Local Assistant

![Platform](https://img.shields.io/badge/Platform-macOS%2015%2B-blue) ![Swift](https://img.shields.io/badge/Swift-6.0-orange) ![Release](https://img.shields.io/badge/Release-v6.4%20build%2064-brightgreen) ![Main app](https://img.shields.io/badge/Main%20app-Offline-9f9f9f)

[Quick start](#quick-start) · [Architecture](#architecture) · [Change history](#change-history)

<!-- project-control:section=overview -->
## Overview

A private macOS assistant for local conversation, file search, and reminder knowledge.

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

<!-- project-control:section=overview -->
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

### Build from source

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

- **Result:** Verified local models are in the shared model library, and their checksum manifest is inside the application sandbox.
  - The library is `~/Documents/AI-Models` unless another folder is given as the script's argument.
  - A model the library already holds is left as it is; the app checks it against its pinned checksums.
- The installer refuses to overwrite an existing checksum manifest.
- Open Local Assistant, then choose that folder under **Settings → Models**.

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
├── model-assets.sha256
├── model-library.json
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

## Usage

### Supported content

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
## Workflow

### How local RAG works

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

<!-- project-control:section=ignore -->
### How A2A is used

A2A v1.0 is the Connector's standard protocol for OpenClaw agent work:

- It discovers and validates OpenClaw's Agent Card.
- It sends every delegated conversation with the standard A2A `SendMessage` operation.
- It carries confirmed reminder changes and explicit non-reminder OpenClaw requests.
- It preserves a stable conversation context without attaching local files or history.

Reminder snapshot synchronization does not use A2A. It remains a separate complete, read-only route with its own credential.

Only bounded evidence reaches the local grounding pass. Indexed content is treated as data, never as an instruction.

<!-- project-control:section=architecture -->
## Architecture

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
| Swift | Native Swift services and typed request routes orchestrate the app; the main app has no LangChain or LangGraph dependency. |
| CryptoKit | SHA-256 digests of file contents and of generated search context tell changed files from unchanged ones during incremental indexing, and derive stable identifiers from local paths without disclosing them. |
| Carbon HIToolbox | Registers the one system-wide quick-call shortcut that summons the assistant while the app runs. |
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
| LangGraph | The Connector's one-shot workflow is a LangGraph state graph in Python 3.10 or newer, checkpointed to a SQLite file through langgraph-checkpoint-sqlite. |
| keyring | Keeps the Connector's credentials in the macOS Keychain through the system keyring backend; they never enter the bundle or a file. |

### Build & Delivery

| Technology or concept | Use in this project |
|---|---|
| Xcode project | `LocalAssistant.xcodeproj` builds the sandboxed app with `xcodebuild`; `Config/` holds the dependency pins, model manifest and privacy boundary the scripts read. |
| Build scripts | `Scripts/` prepares the offline bundle and pinned dependencies, builds llama.cpp statically, packages the release, builds the Connector app and server kit, and audits a built app's offline boundary. |
| Swift Testing | `LocalAssistantTests` use the Swift Testing framework for routing, retrieval and exclusion checks. |
| unittest and hatchling | The Connector's tests run with Python's unittest; hatchling builds its wheel from `pyproject.toml`. |

- The category-grouped Architecture tables above list each technology, concept, and model on its own row.
- Backend & Application Logic means on-device services here, not a network server.
- The 2026-08-31 architecture update also added stable README section mappings for Project Control, keeping models and RAG visible in Architecture.
- The later v5.2 reconciliation changes release metadata and documentation only; application behavior and model storage remain unchanged.

## Project structure

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
├── ARCHITECTURE.md               # Trust zones, indexing lifecycle and design decisions
├── CONTRIBUTING.md               # Contribution and numbering rules for the public mirror
├── CHANGELOG.md                  # Complete change history
├── Vendor/                       # Recreated pinned dependencies; excluded from Git
└── outputs/                      # Generated offline transfer kit; excluded from Git
```

<!-- project-control:section=models -->
## Models

**Shared model storage:** Local Assistant uses the shared **AI-Models library in the Mac's Documents folder**, rather than maintaining separate project-owned model copies.

| Model used by this project | Path within the shared library |
| --- | --- |
| Chat: Qwen3-4B Q4_K_M | `gguf/Qwen3-4B-Q4_K_M.gguf` |
| File search: Qwen3-Embedding-0.6B Q8_0 | `gguf/Qwen3-Embedding-0.6B-Q8_0.gguf` |
| Speech: Whisper Small and its tokenizer | `whisper/openai_whisper-small/` |

- The shared library's README records **Local Assistant** as a consumer of all three models and owns their exact revision, storage and change-history records.
- Project settings, indexes and installation-specific verification records stay in the app's private storage.

The app keeps no model of its own. Under **Settings → Models**, **Choose Folder…** selects the model folder, and the app reads the three models there in place with read-only access.

- The folder follows the shared library's layout shown in the table, so the Mac library and the library on the external SSD are both valid choices.
- Settings shows the chosen folder, and says when none is chosen, when the folder can no longer be found, and when a model is missing from it or damaged.
- **Stop Using** forgets the choice; the app never changes or deletes anything in the folder.
  - A model that is already loaded stays in memory until the app is reopened.
- No additional terminal or service is needed.
- This storage arrangement does not change the app's sandbox or offline runtime boundary: the app reaches the folder only through the choice made in the picker.

SQLite is an in-process library rather than a database server. See [ARCHITECTURE.md](ARCHITECTURE.md) for trust zones, the indexing lifecycle, and detailed design decisions.

## Limits

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
- **Private writes only.** The database, model assets, and conversation history remain inside the
  application sandbox. Microphone audio is processed in memory and is never written to disk.
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

### Why does Settings say a model is not found or damaged?

Open **Settings → Models**:

- **Choose your model folder:** no folder is chosen yet; choose the AI-Models folder with **Choose Folder…**.
- **The model folder can't be found:** reconnect the drive it is on and choose **Check Now**, or choose the folder again.
- **Not found:** the folder lacks that model; add it by installing the verified offline model package, or choose another folder.
- **Damaged:** replace the file with a verified copy because it failed its integrity check.

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
- If it is unavailable, check the model folder there, then reinstall the verified offline model package if the model is missing.

The first transcription may wait briefly while the local speech model loads.

### Why does offline package resolution fail?

Return to the connected preparation phase and rerun `prepare_offline_bundle.sh`. Do not temporarily enable networking on the disconnected destination to let Xcode resolve a missing package.

<!-- project-control:section=release -->
## Current release

**v6.4 (build 64)**. [Release details and delivery evidence](CHANGELOG.md#v6-4-build-64).

To identify an application bundle, read `CFBundleShortVersionString` in its `Info.plist`.

## References

### Design reference

[ARCHITECTURE.md](ARCHITECTURE.md) explains system design, data flow, and privacy boundaries.

<!-- project-control:section=ignore -->
## Contributing

For source changes, follow the [Local Assistant contribution guide](CONTRIBUTING.md).

<!-- project-control:section=history -->
## Change history

**Change-history numbering:** This project uses marketing versions and integer build numbers.
Follow the [version and build policy](CONTRIBUTING.md#version-and-build-policy).

One record per change; complete details and evidence are in [CHANGELOG.md](CHANGELOG.md). Older work dates and Git checkpoints remain labelled when they differ.

**Historical status:** Each record describes its own delivery checkpoint. Later records supersede older pending work or recovery locations; historical checks are not new validation.

| Record | Date | Highlights | Details |
|---|---|---|---|
| Documentation | 2026-10-06 | <ul><li><strong>Layout:</strong> The line of section links under the title now holds three quick links, Quick start, Architecture and Change history, in place of one for every section; the outline of the whole README is the one GitHub, Obsidian and Project Control provide.</li></ul> | [Full record](CHANGELOG.md#three-quick-links) |
| Documentation | 2026-10-06 | <ul><li><strong>Audit:</strong> The Connector's Python stack, CryptoKit, the Carbon hotkey and a Build & Delivery table joined the architecture tables, and the structure tree lists the three root documents.</li></ul> | [Full record](CHANGELOG.md#readme-source-audit) |
| Documentation | 2026-10-06 | <ul><li><strong>History:</strong> The complete change history now lives in <code>CHANGELOG.md</code>, one entry per change with its summary, what changed, what was checked and how it was delivered; the README table keeps the newest ten rows and opens each entry from its Details cell.</li></ul> | [Full record](CHANGELOG.md#changelog) |
| Documentation | 2026-10-05 | <ul><li><strong>Alignment:</strong> Capabilities carries the overview marker; the architecture notes sit under Architecture, and the structure tree is no longer collapsed.</li></ul> | [Full record](CHANGELOG.md#readme-alignment) |
| Documentation | 2026-10-05 | <ul><li><strong>Structure:</strong> Sections follow the order and names every project README now shares, under a contents line; sections were renamed and moved, and no wording was removed.</li></ul> | [Full record](CHANGELOG.md#readme-skeleton) |
| v6.4 / build 64 | 2026-10-05 | <ul><li><strong>Models:</strong> The app keeps no model of its own; it reads the three models in place from a model folder chosen under Settings → Models.</li><li><strong>Settings:</strong> Models names the chosen folder and says when none is chosen, when it can no longer be found, and when a model is missing or damaged.</li><li><strong>Installer:</strong> The offline installer puts models into the shared library instead of the app's private storage.</li><li><strong>Evidence:</strong> 160 Swift and 43 Connector tests, the Release set's signatures, the offline-boundary audit and a launch passed; the owner then chose the model folder in the delivered app, which verified every model in it.</li></ul> | [Full record](CHANGELOG.md#v6-4-build-64) |
| Documentation | 2026-10-05 | <ul><li><strong>Readability:</strong> Long paragraphs, bullets and table cells are now short leads with sub-points, one fact each; no detail was removed.</li></ul> | [Full record](CHANGELOG.md#readme-structure) |
| v6.3 / build 63 | 2026-10-02 | <ul><li><strong>Server kit:</strong> The Connector's server setup kit carries Local Assistant bridge v1.5.6, whose store manager no longer needs a package the kit does not ship, and which reads the CloudBase token only from its own section.</li><li><strong>Checks:</strong> The kit check now also reads the Python the kit's shell scripts embed, which is where the missing package hid.</li><li><strong>Delivery:</strong> Signed v6.3 applications and a rebuilt disk image replace the v6.2 set at the project root.</li></ul> | [Full record](CHANGELOG.md#v6-3-build-63) |
| v6.2 / build 62 | 2026-10-02 | <ul><li><strong>Server kit:</strong> The Connector's server setup kit carries Local Assistant bridge v1.5.5, which reads the pending-report retry budget only under its current name.</li><li><strong>Delivery:</strong> Signed v6.2 applications and a rebuilt disk image replace the v6.1 set at the project root.</li></ul> | [Full record](CHANGELOG.md#v6-2-build-62) |
| v6.1 / build 61 | 2026-10-01 | <ul><li><strong>Server kit:</strong> The Connector's server setup kit carries Local Assistant bridge v1.5.4, whose installer checks for the SSH host key before changing anything and names an unreadable settings file instead of stopping with a traceback.</li><li><strong>Setup:</strong> Each readiness wait ends within 30 seconds, and a rejected operator token is named as the cause.</li><li><strong>Delivery:</strong> Signed v6.1 applications and a rebuilt disk image replace the v6.0 set at the project root.</li></ul> | [Full record](CHANGELOG.md#v6-1-build-61) |
---

<!-- project-control:section=ignore -->
## 🔒 License

**PROPRIETARY SOFTWARE — ALL RIGHTS RESERVED**

Copyright © 2024–2026 Soucieux. All rights reserved.

The original source code, documentation, and other original materials in this repository are proprietary and are not open-source software.

Except where applicable law expressly permits otherwise, no permission is granted to copy, modify, publish, distribute, sublicense, sell, deploy, or create derivative works from these materials, in whole or in part, without prior written authorization from the copyright owner.

Access to this repository does not grant a license. Third-party software and materials remain subject to their respective license terms.

*This private project is not open for external contributions.*
