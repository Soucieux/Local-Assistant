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
4. Follow the folder's progress in Settings, or continue using the assistant while indexing runs in the background.
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

If the speech model is downloaded manually, preserve the complete `openai_whisper-small` directory structure, including the `tokenizer.json` and `tokenizer_config.json` files recorded in `Config/ModelManifest.json`. The application has no route to fetch a missing tokenizer.

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

**Result:** The Release application is created under `DerivedData/Build/Products/Release` without automatic package resolution, and a copy is placed at the top of the project as `Local Assistant.app` so it can be opened directly.

Any earlier copy is removed before the build starts, so a build that fails leaves no application at the top level rather than an older one that still appears current.

#### Step 6 — Audit the offline boundary

Run the static boundary audit against the Release application:

```zsh
./Scripts/audit_offline_boundary.sh \
  ./DerivedData/Build/Products/Release/LocalAssistant.app
```

The audit requires exactly the approved App Sandbox, microphone, application-scoped bookmark, and user-selected read-only entitlements, and rejects every unexpected entitlement. It then inspects the application executable and every bundled executable and fails if any of them links a networking library or imports a network symbol, because a binary that never links networking code cannot open a connection whatever its source might still say. It also inspects packaged resources for network-related implementation text.

The audit reports, rather than rejects, an unreachable service hostname still compiled into the binary. A string literal in unreachable code proves nothing either way; the entitlement set is what the operating system enforces.

> Static inspection is not full runtime verification. Formal verification should also exercise the signed application with every network interface disabled, inspect runtime sockets, and test indexing, chat, OCR, voice, Open, Reveal, and Revoke against controlled fixtures.

#### Optional — run the automated tests

The test target builds and runs entirely from local sources and needs no network access:

```zsh
xcodebuild -project LocalAssistant.xcodeproj \
  -scheme LocalAssistantTests \
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
├── Index/assistant.sqlite3
└── Models/
```

Microphone audio is never written to disk. Speech is recognized from memory while it is spoken, so no recording file exists to retain or clean up.

SQLite may create `-wal` and `-shm` files beside the database. Conversation history remains local until it is cleared through the application or its container is removed. While the application process is running, native macOS folder events schedule incremental updates; reopening the application performs a catch-up scan. Quitting stops monitoring completely. There is no login item, background helper, localhost service, or runtime network route.

## Release notes

### Current release status

| Release area | v1.6 status | Meaning |
|---|---|---|
| Approved scope | Complete | The v1.3 conversation fix and the v1.4 live voice interface were both requested. |
| Source implementation | Complete | The v1.3 conversation-history fix and the v1.4 streaming voice capture are present in source. |
| Debug compilation | Passed | The changed Swift sources compile in the native application target without warnings. |
| Release build | Passed | A clean offline Release build completed with pinned local dependencies. |
| Automated tests | Passed | The 66 tests in the `LocalAssistantTests` target passed against the Debug application. |
| Voice runtime testing | Partial | Live levels and the automatic stop were confirmed working when exercised. Recognized text did not appear and no request was sent; v1.6 corrects the cause. The retest has not been run. |
| Focused testing | Passed | Indexing-state decisions, activity retention, and speech-model loading with no tokenizer cache present passed focused checks. |
| Disconnected runtime testing | Partial | Indexing, chat, and voice were exercised with every network interface disabled. The conversation defect found there is fixed in v1.3; the retest is outstanding. |
| Static privacy audit | Passed | The Release bundle carries only the four approved entitlements and links no networking library. |
| Interface inspection | Not run | v1.4 adds a waveform composer and a live transcript bubble, neither reviewed in either appearance. Debug-only previews render every model readiness state in light and dark at the minimum window size. This is the main open gate. |
| Code review | Complete | The requested phase-by-phase review covered the whole source tree and its findings were resolved. |
| Formal verification | Not run | Runtime socket inspection and full disconnected acceptance remain separate. |
| Installed stable bundle | Model assets updated | The installed application's speech tokenizer was installed and checksum-verified; the bundle itself was not replaced. |

### Version index

Past application bundles are not retained, so this table and the notes below are the record of
what each release contained. Each entry names what that release changed and links to its
full notes.

| Version | What changed |
|---|---|
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
| v0.2.0 | [Focused interface with crash-safe indexing and folder revocation](#v020--focused-interface-with-crash-safe-indexing-and-folder-revocation) |
| v0.1.0 | [First sandboxed assistant with local indexing, retrieval, and voice](#v010--first-sandboxed-assistant-with-local-indexing-retrieval-and-voice) |

To confirm which release an application is, read `CFBundleShortVersionString` from its
`Info.plist`. Every release increments it, so it identifies one release exactly.

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

### v0.2.0 — Focused interface with crash-safe indexing and folder revocation

- Simplified the interface around conversation, file retrieval, voice input, shortcut access, and Settings.
- Added crash-safe sequential indexing, folder revocation, local conversation, and lazy local speech-model loading.

### v0.1.0 — First sandboxed assistant with local indexing, retrieval, and voice

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
| Continuous folder updates | Available in v1.0 source | Uses native macOS folder events while the application is running and performs a catch-up scan at launch. |
| Indexing progress and pause | Available in v1.0 source | Shows per-folder counts and percentage progress and safely pauses the active run without pruning unfinished index data. |
| Index activity | Available in v1.0 source | Retains automatic, manual, startup, and file-level results locally for 30 days, including history for revoked folders. |
| PDF and image OCR | Available | Uses PDFKit and Apple Vision. |
| Local voice input | Available in v1.4 | Shows a live waveform and the recognized words while speaking, and ends on a pause or an explicit stop. |
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
- Chat and semantic search require verified local model assets.
- Voice input requires the complete local speech model and macOS microphone permission.
- Office and Pages extraction is intentionally best-effort.
- Automatic refresh runs only while the application process is running; quitting stops every folder watcher until the next launch-time catch-up scan.
- The global shortcut is fixed and works only while the application process is running.
- Built-in conversational knowledge may be incomplete; file-specific answers remain bounded by displayed evidence.
- No Feishu or other network bridge exists. Any future bridge requires a separately approved and isolated network boundary.

Preparation tools may use the internet on a trusted staging Mac, but they are not packaged or invoked by the runtime application. For a physically offline deployment, prepare and verify all assets first, transfer them using trusted media, disconnect the destination Mac, and only then install and use the application.

## License

No project-level license has been assigned. Each dependency and model retains its own license and attribution requirements; review them before redistribution.
