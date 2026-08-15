# Local Assistant

> A private macOS assistant for conversation and evidence-backed file search, with no runtime network access.

Local Assistant is designed for one person and one Mac. Open the application normally or press **Control–Option–Space**, then type or speak. It can answer ordinary questions, ask for clarification when a file request is ambiguous, and search only the folders explicitly authorized through macOS.

Conversation, retrieval, embeddings, speech recognition, OCR, and data storage all run inside the sandboxed application. Search answers stay concise while reusable result cards present paths, matching evidence, and explicit Open or Reveal actions. The runtime does not depend on a local server, a cloud service, telemetry, or an updater.

## Quick start

Choose the path that matches what you need. If Local Assistant is already installed, begin with the first path. The source-build path is for preparing a new installation without giving the finished application network access.

### Use the installed application

1. Open **Local Assistant**.
2. Open **Settings** and choose **Add Folder**.
3. Select only the folder the assistant should read.
4. Wait for local indexing to finish.
5. Return to the assistant and type or speak a request.
6. Review the answer and result cards before choosing **Open File** or **Reveal in Finder**.

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
| Free preparation space | Approximately 10 GB |

#### Step 2 — Prepare the offline package

1. Use a trusted Mac that is allowed to connect to the internet.
2. From the project root, run:

   ```zsh
   ./Scripts/prepare_offline_bundle.sh
   ```

3. Wait for dependency checkout, native-library compilation, model verification, and Swift package resolution to finish.

**Result:** The script recreates `Vendor` from pinned revisions and creates the transferable package under `outputs/LocalAssistant-OfflineKit`.

If the WhisperKit model is downloaded manually, preserve the complete `openai_whisper-small` directory structure.

#### Step 3 — Transfer and disconnect

1. Copy the complete prepared project and offline package to trusted physical media.
2. Transfer them to the destination Mac.
3. Disable Wi-Fi, Ethernet, VPNs, and other network interfaces before continuing.

Keep the destination disconnected throughout installation, building, auditing, and normal use.

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

**Result:** The Release application is created under `DerivedData/Build/Products/Release` without automatic package resolution.

#### Step 6 — Audit the offline boundary

Run the static boundary audit against the Release application:

```zsh
./Scripts/audit_offline_boundary.sh \
  ./DerivedData/Build/Products/Release/LocalAssistant.app
```

The audit requires exactly the approved App Sandbox, microphone, application-scoped bookmark, and user-selected read-only entitlements. It rejects every unexpected entitlement, inspects packaged resources for network-related implementation text, and lists linked libraries for review.

> Static inspection is not full runtime verification. Formal verification should also exercise the signed application with every network interface disabled, inspect runtime sockets, and test indexing, chat, OCR, voice, Open, Reveal, and Revoke against controlled fixtures.

#### Step 7 — Launch and authorize a folder

1. Open the Release application.
2. In **Settings**, choose **Add Folder** and select only the folder the assistant should read.
3. Return to the assistant after indexing finishes.

Revoking a folder removes its bookmark and dependent private index records without changing the source folder. Saved result cards remain in history but become unavailable when their source authorization no longer exists.

Writable application data remains inside the macOS sandbox's Application Support directory:

```text
LocalAssistant/
├── Index/assistant.sqlite3
├── Models/
└── Voice/                       # Temporary recordings only
```

SQLite may create `-wal` and `-shm` files beside the database. Conversation history remains local until it is cleared through the application or its container is removed. Index refresh is manual; the application has no persistent file watcher, login item, background helper, or localhost service.

## Release notes

### Current release status

| Release area | v0.9 status | Meaning |
|---|---|---|
| Approved scope | Complete | The exhaustive review, safe in-scope fixes, focused checks, and offline Release build were explicitly requested. |
| Source implementation | Complete | The v0.9 audit corrections and documentation changes are present in source. |
| Debug compilation | Not run | The exhaustive pass requires focused native checks and the offline Release build rather than a separate Debug build. |
| Release build | Passed | The v0.9 offline Release build completed from the verified pinned local dependencies. |
| Focused testing | Passed | The v0.9 native harness passed prompt, file-action, voice-file, constrained-retrieval, and SQLite failure checks; preparation-script safety fixtures also passed. |
| Interface inspection | Not run | Computer Use was not approved for Local Assistant, so light, dark, and minimum-window screenshots still require review. |
| Code review | Complete | The exhaustive whole-scope review and no-skips investigation are complete. |
| Formal verification | Not run | Runtime socket inspection and full disconnected acceptance remain separate. |
| Installed stable bundle | Current v0.8 | The v0.9 source pass does not replace or claim verification of the installed v0.8 bundle. |

### v0.9 — Exhaustive correctness and privacy hardening

- Applied requested file-type constraints inside metadata and full-text queries before candidate limits, and added adaptive vector-neighbor expansion so valid constrained semantic matches are not hidden behind other file types.
- Neutralized Qwen chat-control markers in questions, local history, paths, and excerpts before untrusted text enters a parsed chat template.
- Resolved current symlink targets before explicit Open or Reveal actions and rejected targets outside the authorized root.
- Made SQLite reads distinguish normal completion from execution failure, reject malformed required identifiers, and close a partially initialized database connection after setup failure.
- Removed duplicated presentation state, dead prototype APIs, unused constants, and duplicate indexed-item decoding while retaining compatible prototype-era database tables.
- Hardened temporary voice recordings with owner-only permissions, failed-start cleanup, and stale-recording cleanup before the next capture.
- Recorded unreadable traversal paths in indexing exclusions instead of silently continuing.
- Restricted Release signing to the four approved sandbox entitlements and made the static audit reject every unexpected entitlement.
- Hardened connected dependency archive extraction on older system Python versions while preserving safe in-repository symbolic links.

### v0.8 — Settings hierarchy, styled messages, and documentation

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

### v0.7 — Card-aware answers and project hygiene

- Stopped grounded replies from repeating filenames, paths, source numbers, or file-by-file lists already presented in result cards.
- Added a deterministic local safeguard that replaces duplicated card metadata with a concise match count when necessary.
- Applied the same safeguard to restored conversation history while preserving reusable cards.
- Added project-hygiene rules and removed obsolete build caches, historical application bundles, Finder metadata, and download-state files while preserving installed offline models and dependency pins.

### v0.6 — Model clarity, durable result cards, and documentation

- Redesigned **Models** as a plain-language readiness summary for Chat and answers, File search, and Voice input.
- Added overall readiness, private model-storage usage, launch-check acknowledgement, and actionable recovery wording without exposing model filenames in the interface.
- Stored ranked result-card snapshots with their assistant messages and restored them after relaunch.
- Added migration for older citation-only messages when the cited item still exists in the current index.
- Revalidated saved-card actions against the current index, read-only folder authorization, path containment, and disk presence.
- Prevented result actions from collapsing into narrow vertical controls.
- Standardized human-facing release labels with a `v` prefix and aligned the project folder name with the application name.

### v0.5 — Conversation history and compact result cards

- Added local timestamps below user and assistant messages.
- Added a confirmed Clear Conversation action in the assistant header and application menu.
- Limited history deletion to saved messages and current results; folders, permissions, models, index records, and source files remain unchanged.
- Reduced result-card height and replaced stacked ranking signals with one concise **Why it matches** explanation.

### v0.4 — Settings hierarchy

- Reorganized Settings around assistant status, shortcut availability, folder access, and one focused privacy statement.
- Styled Control, Option, and Space as separate accessible keycaps.
- Kept an individual **Update Index** action on every folder and showed **Update All Folders** only when multiple folders were authorized.
- Reduced repeated privacy wording while retaining read-only access and explicit revocation controls.

### v0.3 — Intent-aware retrieval and native interface

- Added local routing between ordinary conversation, clarification, and structured file search.
- Made requested file types hard constraints instead of filename keywords.
- Added deterministic clarification for singular, underspecified file requests while retaining broad listing requests such as “Show me PDFs.”
- Added automatic bottom scrolling, corrected message alignment, a richer native visual system, in-window Settings, responsive result cards, and the selected blue folder-and-sparkle icon.

### v0.2.0 — Focused assistant workflow

- Simplified the interface around conversation, file retrieval, voice input, shortcut access, and Settings.
- Added crash-safe sequential indexing, folder revocation, local conversation, and lazy local speech-model loading.

### v0.1.0 — Initial prototype

- Established the sandboxed SwiftUI application, read-only folder authorization, local indexing, embedded inference, hybrid retrieval, OCR, and local voice foundation.

## Product reference

### Capabilities

| Capability | Availability | Notes |
|---|---|---|
| Local conversation | Available | Runs through an embedded model in the application process. |
| Intent-aware routing | Available | Selects conversation, clarification, or constrained file search. |
| Hard file-type filtering | Available in v0.9 source | Supports folders, PDFs, documents, spreadsheets, presentations, images, code, text, and archives, with constraints applied before per-channel candidate limits. |
| Hybrid retrieval | Available | Combines filename, path, keyword, semantic, recency, and reciprocal-rank signals. |
| Explainable result cards | Available | Shows file type, confidence, path, a concise match reason, and explicit actions. |
| Durable result cards | Available | Restores saved cards with conversation history after relaunch. |
| Card-aware answers | Available | Summarizes results without duplicating filenames, paths, or source lists already shown in cards. |
| Styled conversation text | Available in v0.8 | Distinguishes each sender and renders lightweight local emphasis, inline code, and list markers. |
| Automatic conversation scrolling | Available | Follows new messages, results, and completed answers while respecting reduced motion. |
| Message timestamps | Available | Uses local time for today and an abbreviated local date and time for older messages. |
| Clear conversation history | Available | Removes saved messages and cards after confirmation. |
| Read-only folder selection | Available | Uses macOS security-scoped bookmarks. |
| Folder revocation | Available | Removes authorization and dependent private index records. |
| Manual incremental indexing | Available | Updates one or several authorized folders sequentially. |
| PDF and image OCR | Available | Uses PDFKit and Apple Vision. |
| Local voice input | Available | Loads the speech model when the microphone is first used. |
| Global quick-call shortcut | Available | Uses fixed `⌃⌥Space` while the application process is running. |
| Speech output | Not included | No text-to-speech surface is included in the current interface. |
| Feishu bridge | Not implemented | Reserved for a separately approved future network boundary. |
| Runtime web access | Prohibited | The application has no browser, download route, or network entitlement. |

### Supported content

| Content | Local processing |
|---|---|
| Plain text and common source files | Text extraction and chunking |
| PDF | PDFKit extraction; Vision OCR for image-only pages |
| PNG, JPEG, HEIC, TIFF, BMP, and GIF | Apple Vision OCR |
| DOCX | Visible Open XML text |
| XLSX | Visible worksheet and shared-string XML text |
| PPTX | Visible slide XML text |
| Pages | OCR from an available local preview |
| Other files and folders | Name, path, type, and metadata search |

Complex formulas, charts, comments, embedded objects, encrypted files, and proprietary Pages IWA bodies are not fully reconstructed. The scanner does not follow symbolic links and skips hidden paths, credential-like files, package descendants, common caches, and build directories.

### Local architecture

| Responsibility | Embedded component |
|---|---|
| Interface | SwiftUI |
| Chat and intent | Qwen3-4B Q4_K_M GGUF |
| Embeddings | Qwen3-Embedding-0.6B Q8_0 GGUF |
| Inference | Statically linked llama.cpp |
| Relational metadata and history | Embedded SQLite |
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
│   ├── Features/                 # Assistant, result cards, and Settings
│   ├── Security/                 # Private application-container directories
│   ├── Resources/                # Icon, property list, and sandbox entitlements
│   └── VendorBridge/             # Static native-library bridges
├── Scripts/                      # Preparation, installation, build, and audit tools
├── Vendor/                       # Recreated pinned dependencies; excluded from Git
└── outputs/                      # Generated offline transfer kit; excluded from Git
```

## Troubleshooting

### Why does Settings say a feature is not ready?

Open **Settings → Models**. If Chat and answers, File search, or Voice input is unavailable, reinstall the verified offline model package. Do not add runtime network access as a repair.

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

### Why is the quick-call shortcut unavailable?

Another application may already own `⌃⌥Space`. Quit or reconfigure the conflicting application, then relaunch Local Assistant.

### Why does voice input not start?

Confirm that the complete `openai_whisper-small` directory is installed and microphone permission is allowed. The first use takes longer because the local speech model loads only when needed.

### Why does offline package resolution fail?

Return to the connected preparation phase and rerun `prepare_offline_bundle.sh`. Do not temporarily enable networking on the disconnected destination to let Xcode resolve a missing package.

## Boundaries and limitations

### Privacy and security boundaries

These boundaries are product requirements rather than optional settings:

- **No application network access.** The signed application must not have network client or server entitlements.
- **No runtime downloads.** Required models and frameworks must already exist on the destination Mac.
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
- Chat and semantic search require verified local model assets.
- Voice input requires the complete local speech model and macOS microphone permission.
- Office and Pages extraction is intentionally best-effort.
- Index refresh is manual.
- The global shortcut is fixed and works only while the application process is running.
- Built-in conversational knowledge may be incomplete; file-specific answers remain bounded by displayed evidence.
- No Feishu or other network bridge exists. Any future bridge requires a separately approved and isolated network boundary.

Preparation tools may use the internet on a trusted staging Mac, but they are not packaged or invoked by the runtime application. For a physically offline deployment, prepare and verify all assets first, transfer them using trusted media, disconnect the destination Mac, and only then install and use the application.

## License

No project-level license has been assigned. Each dependency and model retains its own license and attribution requirements; review them before redistribution.
