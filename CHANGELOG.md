# Local Assistant changelog

Every change to Local Assistant, newest first, in one shape: the summary from the history table, then what changed, what was checked and how it was delivered. The README's Change history table lists the newest 10 and links here.

<a id="history-strip"></a>

## History strip — 2026-10-06

- **Changelog:** The README's Change history opens with a history strip, `CHANGELOG.svg`, drawn from the changelog: the entries of every period as shaded cells, release months marked, and the span, total and version range beside them.

### Added

- **Strip:** a light card under the Change history heading shows how the entries spread over time.
  - One cell per period: the years before the last twelve months, then each month, shaded by how many entries it holds; an empty cell is a quiet month.
  - An orange pill under a month with releases carries how many it had, its latest version beneath, and a summary gives the span, the total and the version range.
- **Alternative text:** the image line states the span, the total, the busiest period, the longest quiet stretch and the version range, so the strip reads without the picture.

### Changed

- **Structure:** `CHANGELOG.svg` joins the structure tree.
- **Scope:** Documentation only; the strip and its image line are generated, never edited by hand.

<a id="three-quick-links"></a>

## Three quick links — 2026-10-06

- **Layout:** The line of section links under the title now holds three quick links, Quick start, Architecture and Change history, in place of one for every section; the outline of the whole README is the one GitHub, Obsidian and Project Control provide.

### Changed

- **Why:** the line had grown to as many as fourteen links, drew the eye without saying where each led, and duplicated the outline every reader already has.
- **Line:** `Quick start · Architecture · Change history`, the same three in every project README: get going, see how it is built, see what changed.
- **Scope:** Documentation only.

<a id="readme-source-audit"></a>

## README checked against the source — 2026-10-06

- **Audit:** The Connector's Python stack, CryptoKit, the Carbon hotkey and a Build & Delivery table joined the architecture tables, and the structure tree lists the three root documents.

### Changed

- **Why:** a check of the README against the source found the Connector's LangGraph workflow and Keychain storage undocumented, two imported frameworks without a row, no build or test tooling in Architecture, and a tree without the root documents.
- **Architecture:** CryptoKit, whose SHA-256 digests tell changed files from unchanged ones and derive stable identifiers; Carbon HIToolbox, which registers the quick-call shortcut; LangGraph with its SQLite checkpointer and keyring for the Connector; the Swift row now says the main app has no LangGraph dependency.
- **Build & Delivery:** a new table for the Xcode project and `Config/` manifests, the build scripts, Swift Testing for the app's tests, and unittest and hatchling for the Connector.
- **Structure:** `ARCHITECTURE.md`, `CONTRIBUTING.md` and `CHANGELOG.md` join the tree.
- **Scope:** Documentation only.

<a id="changelog"></a>

## Documentation — 2026-10-06

- **History:** The complete change history now lives in `CHANGELOG.md`, one entry per change with its summary, what changed, what was checked and how it was delivered; the README table keeps the newest ten rows and opens each entry from its Details cell.

### Changed

- **Why:** the README carried every record's details in one collapsed block, with older records in an archive folder, so a reader opened the table and then searched the block, and the details had no fixed shape.
- **Changelog:** `CHANGELOG.md` holds every record this project ever kept, newest first. An entry is its anchor, a dated heading, its summary bullets, then only the subsections it needs: Added, Changed, Fixed, Removed, Checked, Delivered.
- **Migration:** each earlier record's labelled bullets sit under Changed, its evidence under Checked and its status under Delivered; a record over the block limit became a lead with sub-points. Every statement was carried over; none was shortened.
- **Archives:** the one archived period file under `history/` were folded into the changelog in the same shape and the folder was removed.
- **README:** the Change history table keeps the newest ten rows, each Details cell opening its entry; the details block and the earlier-history list are gone, and every link into a record now reaches the changelog.
- **Scope:** Documentation only.

<a id="readme-alignment"></a>

## Documentation — 2026-10-05

- **Alignment:** Capabilities carries the overview marker; the architecture notes sit under Architecture, and the structure tree is no longer collapsed.

### Changed

- **Why:** every project README shares one structure; this one still lacked part of it.
- **Capabilities:** now carries the overview marker, so Project Control shows it as the other projects' capabilities.
- **Architecture:** the four notes about its tables, which opened Project structure, now close Architecture.
- **Project structure:** the source tree stands on its own, no longer inside a collapsed block.
- **Unchanged:** every sentence inside the sections that stayed; links to a moved part were updated.
- **Scope:** Documentation only.

<a id="readme-skeleton"></a>

## Documentation — 2026-10-05

- **Structure:** Sections follow the order and names every project README now shares, under a contents line; sections were renamed and moved, and no wording was removed.

### Changed

- **Why:** project READMEs named and ordered the same kinds of section differently, so setup, workflow and
  architecture sat in a different place in each.
- **Order:** the sections now run Overview, Capabilities, Quick start, Usage, Workflow, Architecture, Project structure, Models, Limits, Troubleshooting, Current release, References, Contributing, Change history.
- **Renamed:** Local architecture is now Architecture, Architecture and project structure is Project structure, Models and shared storage is Models, and Boundaries and limitations is Limits.
- **Moved:**
  - Capabilities now comes before Quick start, and Build from source joined Quick start.
  - Supported content sits under Usage.
  - How local RAG works, Request flow, and How A2A is used sit under Workflow.
  - Models is its own section after Project structure, and Design reference sits under References.
- **Project Control:** How A2A is used carries an ignore marker, so the app shows what it showed before.
- **Opening:** a contents line under the title links every section.
  - The overview opens with its describing line as a plain paragraph, where it was a quotation.
- **Unchanged:** every sentence, table, diagram and Project Control marker inside the sections; whole sections
  moved, and links to a renamed section were updated.
  - One sentence that named the Local architecture tables now names the Architecture tables.
- **Scope:** Documentation only.

<a id="v6-4-build-64"></a>

## v6.4 / build 64 — 2026-10-05

- **Models:** The app keeps no model of its own; it reads the three models in place from a model folder chosen under Settings → Models.
- **Settings:** Models names the chosen folder and says when none is chosen, when it can no longer be found, and when a model is missing or damaged.
- **Installer:** The offline installer puts models into the shared library instead of the app's private storage.
- **Evidence:** 160 Swift and 43 Connector tests, the Release set's signatures, the offline-boundary audit and a launch passed; the owner then chose the model folder in the delivered app, which verified every model in it.

### Changed

Local Assistant no longer keeps models in its private storage. It reads them in place from a model folder the user chooses, and Settings says plainly when that folder or a model in it is missing.

Local Assistant and OpenClaw Connector advance to v6.4/build 64; the Connector's runtime and companion app are unchanged.

- **Model folder.**
  - The app read its three models from a Models folder inside its sandbox container; on this Mac those files were hard links to the shared library, and an offline install made real copies there.
  - **Settings → Models** now has **Choose Folder…**. The app keeps a read-only bookmark to the chosen folder and reads the models there, at the shared library's paths: `gguf/` for the chat and file-search models and `whisper/` for the speech model.
  - The Mac library and the library on the external SSD are both valid choices.
  - Each model is still checked against its pinned checksum, and the speech model against the installed checksum manifest, before it is used.
- **Settings states.**
  - Models shows the chosen folder with the size of the models read from it.
  - It has its own wording for no folder chosen, a chosen folder that can no longer be found, a model missing from the folder, and a damaged file.
  - **Check Now** loads the models when a drive is reconnected, without reopening the app.
- **Removal.** **Remove Downloaded Models** is gone, because the app must never delete files in a shared library. **Stop Using** forgets the chosen folder and leaves it untouched.
  - A model that is already loaded stays in memory until the app is reopened, as it did after the earlier removal.
- **Installer.** `Scripts/install_offline_assets.sh` installs the kit's models into a model library, `~/Documents/AI-Models` unless a folder is given, leaves a model the library already holds as it is, and still writes the checksum manifest into the sandbox.
- **After updating.** The app shows **Choose your model folder** until the folder is chosen once; the earlier Models folder in the sandbox is no longer read.

### Checked

- All 160 Swift tests passed, five of them new for the model folder states, and all 43 Connector tests passed.
- The new Settings states were rendered from the built app in the light appearance at the minimum window width and reviewed: no folder chosen, folder not found, a model missing, and everything ready.
- The offline Release build, run in a separate working copy, produced the signed v6.4/build 64 main application, the matching signed Connector, and `Local Assistant Release.dmg`.
- Both bundles passed strict deep signature verification, the main app passed the offline-boundary audit with its four entitlements unchanged, and the disk image checksum is valid.
- The Connector was not launched.

### Delivered

- The set replaced the v6.3 artifacts at the project root, where the application launched, stayed running for ten seconds without a crash report, and quit on request.
- On 2026-10-05 the owner chose the Mac library in the delivered app and confirmed that selecting the model folder and voice input work; the app verified all 23 model files at the library's paths.
- The replaced v6.3 set and the 23 model links in the sandbox's earlier Models folder were moved to the Trash with approval on 2026-10-05.
- Delivered uncommitted on 2026-10-05, then committed as `09a3323`, with this citation after it.

<a id="readme-structure"></a>

## Documentation — 2026-10-05

- **Readability:** Long paragraphs, bullets and table cells are now short leads with sub-points, one fact each; no detail was removed.

### Changed

- **Why:** many records and some guidance ran as bullets or paragraphs of 50 to 100 words, which hid
  the separate facts inside them.
- **Layout:** every paragraph, bullet and table cell over 50 words is now a short lead with
  sub-points, one fact each. The wording was moved, not rewritten.
- **Unchanged:** every section, heading, link, anchor, table row, diagram, number and identifier.
- **Scope:** Documentation only; no source, version or delivered application changed.

### Checked

- **Evidence:** compared with the previous version, no word is removed, and the headings, anchors,
  links, code spans, numbers and fenced samples are identical. The README layout, link and history
  checks pass.

<a id="v6-3-build-63"></a>

## v6.3 / build 63 — 2026-10-02

- **Server kit:** The Connector's server setup kit carries Local Assistant bridge v1.5.6, whose store manager no longer needs a package the kit does not ship, and which reads the CloudBase token only from its own section.
- **Checks:** The kit check now also reads the Python the kit's shell scripts embed, which is where the missing package hid.
- **Delivery:** Signed v6.3 applications and a rebuilt disk image replace the v6.2 set at the project root.

### Changed

The OpenClaw server setup kit embedded in the Connector now carries Local Assistant bridge v1.5.6. Local Assistant and OpenClaw Connector advance to v6.3/build 63; the main application, the Connector runtime and its companion app are unchanged.

- **Store manager imports.**
  - The kit's reminder store manager checked a new reminder for duplicates with a rule it imported from OpenClaw's synchronization package, which the kit does not ship, so on a server without the synchronizer it would refuse every new reminder at that check.
  - The rule now lives in the shared `runtime_support` package the kit already carries, and the synchronizer uses the same copy.
- **Token.** The store manager and the reminder bridge read the CloudBase token only from the `cloudbase` section of the server's secrets file; the legacy `tencentCloudbase` section is no longer read. The server was checked on 2026-10-02 and has no such section.
- **Kit check.**
  - `OpenClawConnector/tests/test_server_kit.py` checked only the kit's `.py` files, so the store manager's import, inside a Python program its shell script runs, was invisible to it.
  - It now also parses every Python program embedded in a shell script the kit builder copies, the setup script included, and fails on any import the kit does not satisfy.
- **Release badge.** The badge under this README's title had still named v5.9/build 59; it now names this release.

### Checked

All 43 Connector tests passed.

- Against the previous store manager, the extended kit check fails and names the duplicate check's import of `reminder_calendar_sync`; against this source it passes.
- The OpenClaw side's tests are recorded with bridge v1.5.6 in the OpenClaw workspace's change history.
- The offline Release build, run in a separate working copy, produced the signed v6.3/build 63 main application, the matching signed Connector, and `Local Assistant Release.dmg`.
- Both bundles passed strict deep signature verification, the main app passed the offline-boundary audit, the disk image checksum is valid, and the mounted image carries both v6.3/build 63 applications beside its Applications link.
- All 26 files in the Connector's embedded kit match their OpenClaw source byte for byte, and its plugin reports v1.5.6.
- The Connector was not launched.
- No Swift source changed, so the Swift suite was not rerun.

### Delivered

- The set then replaced the v6.2 artifacts at the project root, where it passed the same identity, signature, offline-boundary and disk-image checks with its kit matching this source; the application launched from there, stayed running, quit on request, and left no crash report.
- The owner moved the replaced v6.2 set to the Trash before the new set was copied in.
- Delivered uncommitted on 2026-10-02, then committed as `2683a50`, with this record after it, and published to the public repository the same day.

<a id="v6-2-build-62"></a>

## v6.2 / build 62 — 2026-10-02

- **Server kit:** The Connector's server setup kit carries Local Assistant bridge v1.5.5, which reads the pending-report retry budget only under its current name.
- **Delivery:** Signed v6.2 applications and a rebuilt disk image replace the v6.1 set at the project root.

### Changed

The OpenClaw server setup kit embedded in the Connector now carries Local Assistant bridge v1.5.5. Local Assistant and OpenClaw Connector advance to v6.2/build 62; the main application, the Connector runtime and its companion app are unchanged, and only the embedded kit differs from v6.1.

- **Retry budget.** The shared report spool reads its retry ceiling only from `PENDING_REPORT_MAX_ATTEMPTS`. The v6.1 kit also honoured the former `AUDIT_CARD_MAX_ATTEMPTS`; the server was checked on 2026-10-02 and nothing there sets it, so the fallback is gone. The ceiling still defaults to 32 attempts.

### Checked

All 43 Connector tests passed, including the check that every module a shipped kit file imports ships with it.

- The offline Release build produced the signed v6.2/build 62 main application, the matching signed Connector, and `Local Assistant Release.dmg`.
- Both bundles passed strict deep signature verification, the main app passed the offline-boundary audit, the disk image checksum is valid, and the mounted image carries both v6.2/build 62 applications beside its Applications link.
- All 26 files in the Connector's embedded kit match their OpenClaw source byte for byte, and its plugin reports v1.5.5.
- The Connector was not launched.
- No Swift source changed, so the Swift suite was not rerun.

### Delivered

- The set then replaced the v6.1 artifacts at the project root, where it passed the same identity, signature, offline-boundary and disk-image checks with its kit matching the committed source; the application launched from there, stayed running, quit on request, and left no crash report.
- Once those checks passed, the replaced v6.1 set and the llama.cpp build intermediates under `Vendor/`, which the next release build recreates, were moved to the Trash with approval.
- Delivered uncommitted, then committed as `b5c96e0` and published to the public repository on 2026-10-02.

<a id="v6-1-build-61"></a>

## v6.1 / build 61 — 2026-10-01

- **Server kit:** The Connector's server setup kit carries Local Assistant bridge v1.5.4, whose installer checks for the SSH host key before changing anything and names an unreadable settings file instead of stopping with a traceback.
- **Setup:** Each readiness wait ends within 30 seconds, and a rejected operator token is named as the cause.
- **Delivery:** Signed v6.1 applications and a rebuilt disk image replace the v6.0 set at the project root.

### Changed

The OpenClaw server setup kit embedded in the Connector now carries Local Assistant bridge v1.5.4. Local Assistant and OpenClaw Connector advance to v6.1/build 61; the main application, the Connector runtime and its companion app are unchanged, and only the embedded kit differs from v6.0.

- **Installer checks.**
  - `setup-server.sh` checks for the server's Ed25519 SSH host key with its other preconditions, before it installs or changes anything; the v6.0 kit found out only after reconfiguring the Gateway and SSH.
  - An `openclaw.json` that is not plain JSON, or a `~/.openclaw/.env` that cannot be read, stops setup with the file named instead of a Python traceback.
- **Readiness.**
  - Each readiness wait ends within 30 seconds, every request limited to the time left; a CloudBase call that hung could stretch the v6.0 wait to about eight minutes.
  - When the Gateway refuses the Agent Card, setup says the operator token was rejected instead of advising a re-run that would fail the same way.
- **Bridge.** The shared `runtime_support` package keeps its internal names private and holds one Markdown escaper, the bridge handler imports its error type from its owner, and the plugin's response limit is the one copy of the configuration value; behaviour is unchanged.
- **Retry budget.** The shared report spool reads its retry ceiling from `PENDING_REPORT_MAX_ATTEMPTS`, named for both reports it governs, and still honours the former `AUDIT_CARD_MAX_ATTEMPTS` when the new name is unset.
- **Store manager and configuration.** The shared configuration's headers describe its defaults and overrides, the store manager's contract header covers its ownership mode and the delete outcomes CloudBase returns, and three store-manager conditions no input could reach are gone; behaviour is unchanged.

### Checked

All 43 Connector tests passed, and the check that every module a shipped kit file imports ships with it passed again after the kit's last change.

- The offline Release build produced the signed v6.1/build 61 main application, the matching signed Connector, and `Local Assistant Release.dmg`; the kit was then embedded again with bridge v1.5.4, the Connector re-signed and the disk image rebuilt.
- Both bundles passed strict deep signature verification, the main app passed the offline-boundary audit, the disk image checksum is valid, and the mounted image carries both v6.1/build 61 applications beside its Applications link.
- All 26 files in the Connector's embedded kit match their OpenClaw source byte for byte, and its plugin reports v1.5.4.
- The Connector was not launched.
- No Swift source changed, so the Swift suite was not rerun.

### Delivered

- The set then replaced the v6.0 artifacts at the project root, where it passed the same identity, signature, offline-boundary and disk-image checks; the application launched from there, stayed running, quit on request, and left no crash report.
- The replaced v6.0 set is kept as a recovery copy outside the project until it is moved to the Trash.
- Delivered uncommitted, then committed as `540c2e1` and published to the public repository on 2026-10-01.

<a id="v6-0-build-60"></a>

## v6.0 / build 60 — 2026-09-27

- **Server kit:** The Connector's server setup kit carries Local Assistant bridge v1.5.2, whose configuration reads the Feishu target and CloudBase address from an untracked settings file on the server.
- **Setup:** Its installer finds the CloudBase address where the bridge will, and stops before changing anything when it is missing.
- **Delivery:** Signed v6.0 applications and a rebuilt disk image replace the v5.9 set at the project root.

### Changed

The OpenClaw server setup kit embedded in the Connector now carries Local Assistant bridge v1.5.2. Local Assistant and OpenClaw Connector advance to v6.0/build 60; the main application, the Connector runtime and its companion app are unchanged, and only the embedded kit differs from v5.9.

- **Server settings.**
  - The kit's `config.sh` and `config.py` read `FEISHU_TARGET` and `CLOUDBASE_ENDPOINT` from an untracked `local.env` in the OpenClaw workspace, so scheduled jobs and the bridge find both without the crontab or the Gateway supplying them.
  - The v5.9 kit installed a configuration that reads neither, so running its server setup on a server that keeps them in `local.env` would have left every scheduled job without them.
- **Installer.** `setup-server.sh` finds the CloudBase address the way the bridge will at run time: from the environment, the Gateway's `.env` or the workspace's `local.env`. A missing address stops setup before anything changes, with an instruction to add it to `local.env`.
- **Store manager.** A missing CloudBase setting is named instead of reported as a connection failure.
- **Audit list.** The shared configuration no longer lists `TOOLS.md` and `HEARTBEAT.md`, which OpenClaw 2026.9 retired, among the documents its integrity audit expects.

### Checked

All 43 Connector tests passed, including the check that every module a shipped kit file imports ships with it.

- The offline Release build produced the signed v6.0/build 60 main application, the matching signed Connector, and `Local Assistant Release.dmg`, which replace the v5.9 artifacts at the project root.
- Both bundles passed strict deep signature verification, the main app passed the offline-boundary audit, the disk image checksum is valid, and the mounted image carries both v6.0/build 60 applications beside its Applications link.
- The application launched from the project root, stayed running, quit on request, and left no crash report; the Connector was not launched.
- No Swift source changed, so the Swift suite was not rerun.

### Delivered

- All 26 files in the Connector's embedded kit match their committed OpenClaw source byte for byte.
- The replaced v5.9 set is kept as a recovery copy outside the project until its removal is approved.
- Committed as `3194c65` and published to the public repository on 2026-09-27.

<a id="v5-9-build-59"></a>

## v5.9 / build 59 — 2026-09-26

- **Icon:** The app icon is rebuilt in the macOS icon shape, so the app shows its full artwork instead of a smaller copy inside a grey frame.
- **Folder:** The project folder's icon is set from the same master, so the folder and the app look identical.
- **Delivery:** Signed v5.9 applications and a rebuilt disk image replace the v5.8 set at the project root.

### Changed

On current macOS, the application showed a smaller copy of its icon inside a light-grey rounded frame, while the project folder showed the full artwork, so the two looked like different versions.

- macOS draws that frame around an app icon whose outline does not match its own rounded square, and this artwork filled the whole canvas with rounded corners of its own.
- Local Assistant and OpenClaw Connector advance to v5.9/build 59; the Connector's own icon, the Connector runtime, the server bridge and the runtime contract are unchanged.
- **App icon.** The 1024-pixel master in the asset catalog is now the same artwork made full-bleed (its transparent corners filled with the cream background), clipped to the rounded square macOS draws for app icons, 824 of 1024 pixels. Every smaller size in the catalog was regenerated from it.
- **Folder icon.** The project folder's Finder icon was set from the same master.

### Checked

The offline Release build produced the signed v5.9/build 59 main application, the matching signed Connector, and `Local Assistant Release.dmg`, which replace the v5.8 artifacts at the project root.

- Both bundles passed strict deep signature verification, the main app passed the offline-boundary audit, the disk image checksum is valid, and the mounted image carries both v5.9/build 59 applications beside its Applications link.
- Rendered through macOS's own icon lookup, the application now draws its full artwork with no frame, and its outline matches the folder icon to within 0.2% of pixels.
- The application launched from the project root, ran without a crash report, and quit cleanly; the Connector was not launched.
- No source code changed, so the Swift and Python suites were not rerun.

### Delivered

- The replaced v5.8 set, kept as a recovery copy outside the project until these checks passed, was then moved to the Trash with approval, together with the llama.cpp build intermediates under `Vendor/`, which the next release build recreates.
- Delivered uncommitted and recorded in `33ccd0b`; the public mirror still carries v5.8.

<a id="script-headers"></a>

## Documentation — 2026-09-24

- **Scripts:** Every build, preparation, installation and check script opens with a header stating its purpose, inputs, what it reads and writes, and who runs it.

### Changed

- **Scripts:**
  - The ten zsh scripts under `Scripts/` now open with a header comment stating what the script
    does, its inputs, what it reads and writes, and who runs it, the same documentation the
    project's Swift declarations and Python functions carry.
  - A reader can learn a script's purpose and prerequisites from its first lines instead of working
    them out from its variable block.
- **Scope:** Comments only. No script changes behavior, and the delivered v5.8/build 58 applications
  and disk image at the project root remain current.

### Delivered

Every script passes `zsh -n`, and the documented index-activity check ran to completion with its
header in place. Documentation only; delivered uncommitted and recorded in this documentation commit.

<a id="v5-8-build-58"></a>

## v5.8 / build 58 — 2026-09-24

- **Fixes:** Reminder summaries, History, and cards now count tag groups the same way, and a malformed scheduled reminder snapshot is reported once instead of on every poll.
- **Extraction:** HTML files are read by parsing their markup on the indexing actor rather than through the main-thread WebKit importer.
- **Maintenance:** Duplicated logic and unused code removed, repeated values named, and the Connector's parameter and return documentation completed.

### Changed

One batch of corrections across every first-party file. Local Assistant and OpenClaw Connector advance to v5.8/build 58 and the Connector runtime to v1.9.1; the server bridge v1.4.0 and runtime contract v3 are unchanged because no wire contract changed.

**Corrected behavior**

- **Reminder tag groups.**
  - The spoken summary, the History bubble, and the reminder cards each derived a tag group their own way, so a reminder tagged with the words "No tag" was counted together with untagged reminders in the summary while the cards showed two sections.
  - All three now use one rule on the reminder itself: a blank tag is untagged, and tags that differ only by capitalization or surrounding spaces form one group that keeps its displayed spelling.
- **Malformed scheduled snapshot.**
  - A scheduled reminder snapshot that could not be read was left in place, so the one-second health poll rejected it again on every pass and kept reporting a failed refresh, even after **Refresh Now** succeeded, until the Connector's next scheduled run.
  - A rejected snapshot is now discarded like an accepted one and reported once.
- **HTML files.**
  - HTML was imported through `NSAttributedString`, whose HTML importer is backed by WebKit and documented as unsupported away from the main thread.
  - Called from the indexing actor it had to synchronize with the main run loop for each file, measured here at about 0.7 seconds against under 0.01 seconds for direct parsing.
  - HTML is now decoded with the same encoding detection as plain text and parsed directly, with external entities never loaded: scripts, styles, and templates are left out, block elements stay on their own lines, the page title is indexed, and unclosed fragments are still read.
  - Rich-text files name their type explicitly so a mislabeled file can never be routed to that importer.
  - A local probe observed no network request from the old importer, so this is a threading and speed correction rather than a privacy one.
- **One re-extraction.** Because the text produced for unchanged HTML files changes, the extraction version rises to 3 and every indexed file is re-extracted once on the next indexing run.
- **Offline audit.** The last `file | grep -q` pipeline in the offline-boundary audit is replaced by the shell match the rest of the script uses. Under `pipefail` that pipeline could skip a bundled binary instead of auditing it, which is the failure the script's own comment warns about.
- **Setup wording.** The existing-installation screen said every release needs one server update for A2A. It now says a fresh server setup ZIP is needed only when the server was set up from an older release.

**Simplified without changing behavior**

- **Shared logic.**
  - One implementation now serves each of these:
    - SHA-256 hex rendering,
    - the indexing progress fraction,
    - the stored-passage identifier,
    - copying an indexed item with a new content hash,
    - embedding blob binding,
    - the item column list used by six queries,
    - the ZIP entry size guard shared by the Office and Pages extractors,
    - route-parser tokenizing,
    - search-kind ordering,
    - and the installed version label shown in About and Settings.
- **Less work.** An empty reminder query no longer reads the reminder cache twice.
- **Named values.**
  - Repeated button-state numbers in both design systems, the Activity screen's status colors, the llama sequence capacity, and the Connector's permission masks, SSH patterns, and workflow node names now have names.
  - Connector host validation keeps its allow-list and leading-dash check and drops three checks the allow-list already implied, identically in Python and Swift.
- **Connector errors.** Sixty-three five-line error constructions became three named constructors, and the reminder snapshot request is built in one place for both verification and the scheduled refresh.
- **Unused code removed.** `ReminderSpoolService.spoolURL()`, `SearchFilter.none`, and the `system` message role had no callers, and no release ever stored a `system` message.
- **Removed what only had one value.**
  - The voice input modes both ended capture after a pause, so the flag that said so, its parameter and its test are gone;
    - the hand-written conversation encoder was identical to the compiler's and would have silently dropped any field added later;
    - and the app no longer creates the Connector spool folders itself, because the spool service creates and protects them on every use.
- **Schema.** Four prototype-era tables that no code reads or writes are no longer declared; a database created before this release keeps its empty copies untouched.
- **Documentation in code.**
  - Every Python callable in the Connector, its tests, and the staging scripts now documents its parameters, return value, and raised errors.
  - Stale comments about speech output and the capture limit were corrected, and the one remaining compiler warning — handing the speech library's non-Sendable components to its streaming actor — is explained where it occurs and left visible rather than silenced.

**Documentation corrected**

- The release badge still named v5.4/build 54.
- The privacy summary listed temporary voice recordings, although microphone audio is processed in memory and never written to disk.
- The v5.5 record still described its source as uncommitted.
- Four archived August 2026 rows used a descriptive label in the **Record** column.

### Checked

- **Tests.** Eleven cases were added for tag grouping, the discarded snapshot, and HTML extraction. Repeated fixtures in the reminder spool, folder indexing, and Connector service tests became helpers, and one statement-cache test was renamed because batched lookups are deliberately not cached.

155 macOS test cases and all 43 Connector tests pass against this source from a Debug build kept outside the project; the index-activity and indexing-decision script checks pass; and the Connector companion sources type-check with the build script's settings.

- The interface changes — token-named colors with the same system values and one reworded setup sentence — were reviewed visually on 2026-09-23.

The offline Release build produced the signed v5.8/build 58 main application, the matching signed Connector, and `Local Assistant Release.dmg`, which replace the v5.7 artifacts at the project root.

- Both bundles passed strict deep signature verification, the main app passed the offline-boundary audit, the disk image checksum is valid, and the Connector's embedded kit carries `config.py`, `config.sh` and the v1.5.1 installer, each identical to its source.
- The user opened the built application on 2026-09-24 and confirmed it works.
- Not established by this build: the signature is ad-hoc with the hardened runtime rather than Developer ID, so the disk image is not notarized for distribution beyond this Mac.

### Delivered

- The source was delivered uncommitted and recorded in `6c2f551` and `d86e626`; the build is recorded in `da3e6f9`, and the public mirror was published from it on 2026-09-24, its tip `26a11b1` matching this folder's tree and commit sequence.

<a id="openclaw-kit-shared-config"></a>

## v5.7 / build 57 — 2026-09-23

- **Server kit:** Ships the shared configuration the reminder bridge imports, so installing the kit onto an older server no longer fails at import.
- **Setup:** Carries bridge v1.5.1, whose installer names a missing CloudBase endpoint up front instead of timing out.

### Changed

- **Server kit:**
  - The OpenClaw server setup kit now ships the shared `config.py` and `config.sh` beside the
    reminder bridge and store manager that import them.
  - On a server whose workspace was older than that configuration, the previous kit installed the
    bridge without it, so the bridge failed at import and setup stopped with only a readiness
    timeout.
- **Setup:** The kit now carries Local Assistant bridge v1.5.1. Its installer checks for a CloudBase
  endpoint before it changes anything and says how to supply one. The bridge cannot serve a
  reminder request without an endpoint, and the earlier installer reported that only as a timeout.
- **Guard:** `OpenClawConnector/tests/test_server_kit.py` fails whenever a file the kit ships
  imports a module the kit leaves out. A standalone checkout cannot build the kit, so it skips them.
- **Release alignment:** Local Assistant and OpenClaw Connector both advance to v5.7/build 57. Only
  the Connector's embedded server kit changed; the main application's behavior is unchanged.

### Checked

The full macOS test suite passed, 146 test cases, and all 43 Connector tests passed.

- The offline Release build produced the signed v5.7/build 57 main application, the matching signed
  Connector, and `Local Assistant Release.dmg`.
- Both bundles passed strict deep signature verification, the main app passed the offline-boundary
  audit, and the disk image checksum is valid.
- The Connector's embedded kit was confirmed to carry `config.py`, `config.sh` and the v1.5.1
  installer, each identical to its source.

### Delivered

- The rebuilt deliverables are at the project root; publication was not requested.
- The source and this record are committed together.

<a id="private-local-capabilities-icon"></a>

## v5.6 / build 56 — 2026-09-21

- **Identity:** A private conversation core now connects visibly to local documents, voice input, and reminders.
- **Delivery:** The matching main app and Connector, plus the clean-Mac disk image, were rebuilt and validated.

### Changed

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

### Checked

The full macOS test suite passed.

- The offline Release build produced the signed v5.6/build 56 main application, the matching signed
  Connector, and `Local Assistant Release.dmg`.
- Both bundles passed strict deep signature verification, the main app passed the offline-boundary
  audit, the disk image checksum is valid, and the packaged 256-pixel icon representation matches
  the source catalog pixels.

### Delivered

- The rebuilt deliverables are at the project root; publication was not requested.

<a id="upstream-llama-cpp-links"></a>

## Documentation — 2026-09-21

- **Contributor guide:** The two llama.cpp links now address upstream, because the prepared vendor tree is not part of the repository and neither link resolved for a reader of it.
- **Label:** The second link now names the upstream agent instruction document it actually opens.

### Changed

- The contributor guide's two links into `Vendor/llama.cpp` now address upstream's
  [contribution guide](https://github.com/ggml-org/llama.cpp/blob/master/CONTRIBUTING.md) and
  [agent instructions](https://github.com/ggml-org/llama.cpp/blob/master/AGENTS.md).
- The prepared `Vendor` tree is recreated from pinned revisions and is not part of the repository,
  so both links resolved for no reader of the public repository. Only a checkout that had already
  run the preparation script could follow them.
- The second label also named the wrong destination.
  - The preserved file is upstream's agent instruction document under a local name, kept that way so
    no nested instruction file sits in a project folder.
  - The label now names what it opens, and the sentence still records that the prepared tree holds
    it as `CONTRIBUTOR_GUIDANCE.md`.
- The links address `master` rather than the pinned revision, because a contributor changing the
  prepared source should follow upstream's current contribution rules.

### Checked

Documentation only.

- Both upstream documents were retrieved and their headings match the preserved copies:
  `Contributors` for the contribution guide and `Instructions for llama.cpp` for the agent
  instructions.
- The repository link check now reports that all links in 31 documents resolve and name their
  destination, where it previously reported these two as broken; the README layout and retention
  checks pass.
- No source, build, application version or build number changed.

<a id="openclaw-kit-runtime-support"></a>

## v5.5 / build 55 — 2026-09-20

- **Server kit:** Ships the shared runtime_support package that the reminder bridge and the store manager import, so installing the kit no longer leaves the bridge unable to import.
- **Release:** Signed applications and a rebuilt disk image replace the v5.4 artifacts at the project root.

### Changed

- The server setup kit now ships `runtime_support`, the shared Python package that the typed reminder bridge and the reminder store manager both import, and the installer places it beside them in the workspace.
- Before this, the kit shipped both callers without their package.
  - Both import `runtime_support.strict_json`, so installing the kit onto a workspace provisioned before that module existed left the bridge unable to import at all, and the setup's own snapshot test then timed out against a Gateway that was healthy, reporting the wrong cause.
- The installer places the shared package before its callers, so a failure leaves the workspace on its previous self-consistent pair rather than a new caller over an older package.
  - Each install keeps the directory it replaces under a `.before-local-assistant-setup` name for rollback, and the two package installs now share one helper instead of repeating the same sequence twice.
- Existing users create and run a fresh server setup ZIP once for this to reach a server.

### Checked

The clean offline Release build produced signed v5.5/build 55 applications and a rebuilt disk image that replace the v5.4 artifacts at the project root.

- Both bundles pass a strict deep signature check and keep the project's ad-hoc signature;
  - the main application also carries the hardened runtime, which the Connector's build does not request;
  - the signed-app offline-boundary audit passes with only the four expected entitlements and no network entitlement;
  - and the disk image verifies its checksum and mounts with both applications at v5.5/build 55.
- The shipped Connector carries the corrected kit: its embedded setup payload contains the nine-module `runtime_support` package and the installer that places it before its callers.

### Delivered

Source change only. A kit built from this source was confirmed to carry the package, and every import the kit's bridge and store manager make resolved from the installed set alone; removing the package again reproduced the original `ModuleNotFoundError`.

146 macOS test cases and all 40 Connector tests pass against this source; the Debug test cache was removed afterwards so the project root holds only the delivered build.

Not established by this build: the applications were not launched, so runtime behaviour is unverified, and the signature is ad-hoc with the hardened runtime rather than Developer ID, so the artifacts are not notarized for distribution beyond this Mac. The source was uncommitted at delivery and is recorded in `40d43c1`.

<a id="soucieux-proprietary-license"></a>

## Documentation — 2026-09-13

- **License:** Added the approved Soucieux proprietary-software notice.

### Changed

- Added the approved Soucieux proprietary-software notice, reserving rights in original project
  materials while retaining third-party license and attribution requirements.
- Documentation only; application behavior, v5.4/build 54, artifacts, deployment, and publication
  status are unchanged.

<a id="public-contributor-guide"></a>

## Public contributor guide — 2026-09-11

- **Contributing:** Added a standalone project guide that works in both the canonical workspace and the public subtree mirror.
- **Links:** Removed README dependencies on parent-only repository files.
- **Repository:** Added a feature-first public GitHub description for new users.

### Changed

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

### Delivered

- **Status:** Documentation only. Application behavior, v5.4/build 54 source metadata, signed
  artifacts, installed applications, model storage, and deployment state are unchanged.

<a id="readme-organization"></a>

## README organization — 2026-09-06

- **Structure:** User guide first; one history table.
- **Rules:** Scoped contributor guidance under AGENTS.

### Changed

- **Structure:** Put purpose, capabilities, setup, architecture, and workflows before history.
- **History:** Merge matching repository-origin records into the owning change; preserve unique detail, evidence, and older links.
- **Ownership:** Keep user documentation here; route scoped contributor rules through root AGENTS.

### Delivered

- **Status:** Documentation changes only; initially delivered uncommitted and recorded in `3a5bd2c`. Existing application versions, artifacts, and deployment state are unchanged.

<a id="change-1"></a>
<a id="readability-maintenance"></a>

## Documentation readability — 2026-09-06

- **Change:** Reorganized long paragraphs and table cells without dropping details.

### Changed

- Reorganized long paragraphs and table cells without dropping details; consolidated imported history tables into indexes linked to complete readable records.
- Preserved existing destinations and README section mappings.
- Documentation only; no application or release artifact changed.

### Delivered

Local documentation changes; initially delivered uncommitted and recorded in this documentation commit.

<a id="change-2"></a>

## Documentation — 2026-09-06

- **Change:** Moved complete project descriptions, register details, and repository-origin history into this README.

### Changed

- Moved complete project descriptions, register details, and repository-origin history into this README; retained existing content, dates, release/build identifiers, Git evidence, and app-content mappings.
- Project guardrails now load through the root instructions only for this project.
- This is documentation maintenance; no application code, build, release, or deployment changed.

### Delivered

Local documentation update; initially delivered uncommitted and recorded in `3a5bd2c`

<a id="change-3"></a>

## v5.4 / build 54 — 2026-09-05

- **Change:** Reused statements and atomic activity writes.

### Changed

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

- Reuses prepared SQL statements across calls.
  - Every read and write on the private index used to prepare a statement and discard it, so SQLite
    reparsed and recompiled the same SQL once per file during a scan and five times per reminder
    during a sync.
  - Statements are now checked out of a per-connection cache and returned when the operation
    finishes.
- Clears a returned statement's bindings, so a cached insert does not keep the last embedding blob
  alive, and finalizes every cached statement when the connection closes.
- Bounds that cache to the 46 statements whose SQL is fixed.
  - SQL whose placeholder count follows the query — a search's token list, a batch of identifiers, a
    set of item kinds — is prepared per call and finalized, because caching it by text would leave a
    permanent entry for every distinct width the app ever sees.

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
  signed-app offline-boundary audit, and disk-image checksum and mount validation.
  - This is the first build to carry the v5.3 launchd correction.
  - Both applications are now installed on this Mac, and the Connector's existing-setup update
    re-registered the background job at the corrected path, so that correction is in effect here.
- The current release is **v5.4 (build 54)**.
- The private index now reuses its prepared SQL statements instead of preparing and discarding one for every operation, so a scan or a reminder sync stops re-parsing the same statement once per file.
- The release also commits a removed file's activity row together with its parent run summary, and a monitoring burst's events together, so a run interrupted mid-scan cannot leave those records disagreeing.

The project root now holds the signed v5.4 build 54 applications and disk image, which replace the v5.2 artifacts and are the first build to carry the v5.3 launchd correction.

Both applications are installed on this Mac and the Connector's existing-setup update has re-registered the background job, so that correction is now in effect here.

<details>

<summary>Detailed build, test, privacy, and release evidence</summary>

- **Source implementation:** **v5.4 status:** Complete; **Meaning:** Local Assistant and OpenClaw Connector advance to v5.4/build 54. Connector runtime v1.9.0, server bridge v1.4.0, and runtime contract v3 are unchanged because no wire contract changed, and no Connector source changed in this release.
- **Documentation:** **v5.4 status:** Complete; **Meaning:** Records v5.4/build 54 here and in the repository README, including the signed build, the installed-Mac launch-agent verification, and the checks that were not repeated.
- **Release build:**
  - **v5.4 status:** Complete; **Meaning:** The clean offline Release build produced `Local Assistant.app` and `OpenClaw Connector.app` at v5.4/build 54 with a rebuilt disk image, replacing the v5.2 artifacts at the project root.
  - Both bundles pass a strict deep signature check, and the `DerivedData` cache was removed so the project root is the only place the build exists.
- **Automated tests:** **v5.4 status:** Complete; **Meaning:** 146 macOS test cases and all 40 Connector tests pass on this source. The three added cases cover statement reuse and were each confirmed to fail when the reuse code is deliberately broken.
- **Static privacy audit:** **v5.4 status:** Complete; **Meaning:** The offline-boundary audit passes against the signed v5.4 application. It carries exactly four entitlements — sandbox, audio input, app-scope bookmarks, and user-selected read-only — with no network entitlement and no reachable network code path.
- **Interface inspection:** **v5.4 status:** Complete; **Meaning:** No copy, layout, or visual styling changed in this release, and the installed v5.4 application's screens were inspected after the upgrade.
- **Formal verification:**
  - **v5.4 status:** Partial; **Meaning:** The corrected launchd registration is verified on this Mac.
  - The installed v5.4/build 54 Connector wrote `com.soucieux.LocalAssistant.OpenClawConnector.plist` to `~/Library/LaunchAgents` with owner-only permissions, removed the superseded `~/LaunchAgents` copy, and launchd reports the job loaded from that path with its scheduled spawn armed and a zero exit code.
  - The disconnected acceptance run over the signed application was carried out separately; runtime socket inspection is still not part of this record.
- **Release artifact integrity:** **v5.4 status:** Complete; **Meaning:** `Local Assistant Release.dmg` verifies its checksum, mounts, and carries both applications at v5.4/build 54 beside the `Applications` link.

</details>

### Delivered

- **Status:**
  - Released v5.4/build 54 after the private index moved to reused prepared statements and paired
    activity writes;
    - the signed applications and disk image at the project root replace the v5.2 artifacts and are
      the first build carrying the v5.3 launchd correction, which is now installed and re-registered
      at the corrected launch-agent path on this Mac.

This v5.4/build 54 commit

<a id="change-4"></a>

## Documentation — 2026-09-04

- **Change:** Merged the version index and the dated maintenance history into one change-history table using the repository's required first-column labels.

### Changed

- Merged the version index and the dated maintenance history into one change-history table using the repository's required first-column labels: the exact version and build for an operation that changed them, `Maintenance` or `Documentation` otherwise.
- Build numbers were taken only from each release's own notes, so 20 rows carry one and 33 keep the version alone rather than a number derived from the numbering formula.
- No source, version, build, or artifact changed.
- Merged Local Assistant's version index and dated maintenance history into one change-history table following the repository's first-column convention.
- Build numbers were sourced from each release's own notes, so 20 rows carry a build and 33 keep the version alone rather than a derived number.
- No source, version, build, or artifact changed.

### Delivered

This documentation commit

<a id="change-5"></a>

## v5.3 / build 53 — 2026-09-04

- **Change:** Connector launchd reliability and shared code.

### Changed

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

### Delivered

This v5.3/build 53 commit

<a id="change-6"></a>

## Documentation — 2026-09-02

- **Change:** Linked Local Assistant's version-and-build declaration to the centralized repository policy and removed duplicated generic numbering rules.

### Changed

- Linked Local Assistant's version-and-build declaration to the centralized repository policy and removed duplicated generic numbering rules.
- Application behavior, metadata, artifacts, and release numbers are unchanged.

### Delivered

This documentation commit

<a id="change-7"></a>

## v5.2 / build 52 — 2026-08-31

- **Change:** Release-history reconciliation.

### Changed

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

### Delivered

This v5.2/build 52 documentation commit

v5.2 release-history commit

<a id="change-8"></a>

## v5.1 / build 51 — 2026-08-31

- **Change:** Explicit architecture inventory and README mappings.

### Changed

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

### Checked

Historical work record

### Delivered

`e63b486`, `5172de1`

<a id="change-9"></a>

## v5.0 / build 50 — 2026-08-29

- **Change:** Final deterministic ordering and indexing cleanup.

### Changed

- Released v5.0/build 50 after closing the remaining sort-order and indexing issues, naming remaining literals, sharing reminder-card formatting, correcting the historical v0.8 record, and rebuilding the disk image.
- Released v5.0/build 50 after applying the remaining sort-tie and indexing corrections, centralizing literals and reminder-card formatting, correcting the v0.8 historical description, and rebuilding the disk image.
- Breaks the remaining activity, search, and reminder sort ties with stable identifiers.
- Removes an unreachable indexing-worker respawn branch.
- Moves the remaining reminder, inference, and Connector literals into their existing constants.
- Shares one reminder timing formatter between the compact and full reminder cards.
- Corrects the historical v0.8 evidence and records the reconstructed release artifact.
- Advances Local Assistant and OpenClaw Connector to v5.0/build 50. Connector runtime v1.9.0, server
  bridge v1.4.0, and runtime contract v3 remain unchanged.

### Delivered

`0143e20`, `097ddbe`, `1f1cc86`, `10d3831`, `c305aa7`, `cb3c2f0`

<a id="change-10"></a>

## v4.9 / build 49 — 2026-08-28

- **Change:** Deterministic retrieval and connector resilience.

### Changed

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
  widened.
  - No user-facing copy, layout, or referenced design token changed.
  - Git reconciliation: Advanced Local Assistant to v4.9/build 49 and Connector runtime v1.9.0:
    testable indexing, bounded archive expansion, deterministic retrieval, safer connector spool
    recovery, split setup files, and completed constants/documentation.
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
  branches into one.
  - `index` is now 47 lines and no function in the folder exceeds 50.
  - The record and progress builders moved to `IndexingService+Records.swift` so the file stays
    inside the 800-line limit.
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

### Delivered

`66ae195` (2026-08-28)

Version-index record in `66ae195`; related date-group work: `5bcca17`, `5a2e1bc`, `562a8f7`, `2c99ce5`, `7f82e95`, `1b5fcef`, `9add7e4`, `66ae195`

<a id="change-11"></a>

## v4.8 / build 48 — 2026-08-26

- **Change:** Responsive setup and consistent result cards.

### Changed

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

### Delivered

Version-index record in `4556236` (2026-08-26); related date-group work in `dfb5057`, `5da7990`, `6185970`, `ea58bc9`, `d2cb05a`, `4ff727a`, `f5d19d1`, `f6642b5`, `ca687cb`, `407d9b5`, `863b665`, `3c33edf`, `be6ca96`, `3ffbe75`, `80003b0`, `436c130`, `7cc1ba2`, `c96c459`, `9f848ee`, `b90dd87`, `796129b`, `835964e`, `5436e43`, `4556236`, `1ea69a0`, `1c48542`, `1d7ce3c`

<a id="change-12"></a>

## v4.7 / build 47 — 2026-08-26

- **Change:** Private A2A connection to OpenClaw.

### Changed

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

### Delivered

`9f848ee` (2026-08-26)

Version-index record in `9f848ee`

<a id="change-13"></a>

## v4.6 / build 46 — 2026-08-26

- **Change:** Responsive native Markdown responses.

### Changed

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

### Delivered

`436c130` (2026-08-26)

Version-index record in `436c130`

<a id="change-14"></a>

## v4.5 / build 45 — 2026-08-26

- **Change:** Natural confirmation, centered processing, and dependency security.

### Changed

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

### Delivered

`be6ca96` (2026-08-26)

Version-index record in `be6ca96`

<a id="change-15"></a>

## v4.4 / build 44 — 2026-08-26

- **Change:** Conversational reminder confirmation and runtime compatibility.

### Changed

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

### Delivered

`be6ca96` (2026-08-26)

Version-index record in `be6ca96`

<a id="change-16"></a>

## v4.3 / build 43 — 2026-08-26

- **Change:** Natural reminder routing and responsive result cards.

### Changed

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

### Delivered

`be6ca96` (2026-08-26)

Version-index record in `be6ca96`

<a id="change-17"></a>

## v4.2 / build 42 — 2026-08-26

- **Change:** Content-height Local Assistant setup cards.

### Changed

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

### Delivered

`be6ca96` (2026-08-26)

Version-index record in `be6ca96`

<a id="change-18"></a>

## v4.1 / build 41 — 2026-08-26

- **Change:** Unified connection review and content-height setup cards.

### Changed

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

### Delivered

`be6ca96` (2026-08-26)

Version-index record in `be6ca96`

<a id="change-19"></a>

## v4.0 / build 40 — 2026-08-26

- **Change:** Credential-safe Connector updates and cleanup.

### Changed

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

### Checked

Historical work record

### Delivered

`be6ca96` (2026-08-26)

<a id="change-20"></a>

## v3.9 / build 39 — 2026-08-26

- **Change:** Reliable connector setup, refresh, and lifecycle.

### Changed

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

### Delivered

`ea58bc9` (2026-08-26)

Version-index record in `ea58bc9`

<a id="change-21"></a>

## v3.8 / build 38 — 2026-08-26

- **Change:** On-demand restricted SSH transport.

### Changed

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

### Delivered

`ea58bc9` (2026-08-26)

Version-index record in `ea58bc9`

<a id="change-22"></a>
<a id="v37--complete-private-tailscale-connection-setup"></a>

## v3.7 / build 37 — 2026-08-26

- **Change:** Complete private Tailscale connection setup.

### Changed

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

### Delivered

`ea58bc9` (2026-08-26)

`ea58bc9`

<a id="change-23"></a>

## v3.6 / build 36 — 2026-08-26

- **Change:** User-created server ZIP and corrected setup packaging.

### Changed

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
  boundaries.
  - Every setup card now uses concise bullet points, every card fills the same content width, the
    server commands and copy action remain inside server step 2, and **Open Connector App** remains
    inside the connector-configuration card.
- Reduced the disk image to the two standalone Mac applications. Required server installer and
  bridge files are embedded in Local Assistant and enter the exported ZIP only after the user
  requests it; development tests and documentation are excluded from that payload.
- Added a distinct generated icon to `OpenClaw Connector.app` and declared it in the connector
  bundle metadata.
- Preserved the app's network-denied sandbox while adding user-selected write access solely for the
  ZIP destination; authorized source-folder bookmarks remain read-only.
- Corrected post-payload signing so the final Local Assistant bundle retains its explicit sandbox
  entitlements, then rebuilt and checksum-validated the v3.6 build 36 release DMG.

### Checked

Historical work record

### Delivered

`ea58bc9` (2026-08-26)

<a id="change-24"></a>
<a id="v35--unambiguous-clean-device-openclaw-setup"></a>

## v3.5 / build 35 — 2026-08-26

- **Change:** Unambiguous clean-device OpenClaw setup.

### Changed

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

### Delivered

`ea58bc9` (2026-08-26)

`ea58bc9`

<a id="change-25"></a>
<a id="v34--live-openclaw-status-and-in-app-setup"></a>

## v3.4 / build 34 — 2026-08-26

- **Change:** Live OpenClaw status and in-app setup.

### Changed

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

### Delivered

`ea58bc9` (2026-08-26)

`ea58bc9`

<a id="change-26"></a>
<a id="v33--hidden-reminder-knowledge-and-explicit-openclaw-actions"></a>

## v3.3 / build 33 — 2026-08-26

- **Change:** Hidden reminder knowledge and explicit OpenClaw actions.

### Changed

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

### Delivered

`ea58bc9` (2026-08-26)

`ea58bc9`

<a id="change-27"></a>

## v3.2 / build 32 — 2026-08-26

- **Change:** Private reminder RAG and an opt-in OpenClaw connector.

### Changed

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

### Delivered

`ea58bc9` (2026-08-26)

Retrospective work record; retained source in `dfb5057`, `5da7990`, `ea58bc9` (2026-08-26)

<a id="change-85"></a>

## Removed the stale hard-coded version fallback so bundle metadata remains authoritative and unavailable metadata is reported explicitly — 2026-08-23

- **Change:** Removed the stale hard-coded version fallback so bundle metadata remains authoritative and unavailable metadata is reported explicitly.

### Changed

<ul><li>Removed the stale hard-coded version fallback so bundle metadata remains authoritative and unavailable metadata is reported explicitly.</li><li>Aligned indexing decision regression checks with the current content-indexing policy names and wording.</li><li>Made the documented release gates reusable across versions and corrected the offline-boundary command to audit the built root application.</li></ul>

### Delivered

`ccc028d`

<a id="change-28"></a>

## v3.1 / build 31 — 2026-08-22

- **Change:** Storage figures moved beside each button.

### Changed

- Moved the model-storage figure off its own line and into the **Remove Downloaded Models** row,
  right beside the button, inside the same grey-filled box.
- Moved the index-storage figure off its own line and into the **Clear Search Index** row the same
  way; the indexed-file count keeps its own separate line above the row.

### Delivered

`e53f304` (2026-08-22)

<a id="change-29"></a>
<a id="v30--storage-figures-next-to-each-reset-action"></a>

## v3.0 / build 30 — 2026-08-22

- **Change:** Storage figures next to each reset action.

### Changed

- Git index record, not an independently established release date: [Storage figures next to each reset action](#v30--storage-figures-next-to-each-reset-action).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Added an index-storage figure next to the indexed-file count in Folder Access, showing the actual
  on-disk size of the search index (database, passages, and vectors) beside **Clear Search Index**.
- The existing model-storage figure now sits directly beside **Remove Downloaded Models** instead of
  near the launch-check row.
- Dropped the "#" symbol from the version badge in the Settings header; it now reads as plain text
  (e.g. "v3.0").

### Delivered

`e53f304` (2026-08-22)

`e53f304`

<a id="change-30"></a>
<a id="v29--bordered-reset-rows-matching-the-folder-card-style"></a>

## v2.9 / build 29 — 2026-08-22

- **Change:** Bordered reset rows matching the folder-card style.

### Changed

- Git index record, not an independently established release date: [Bordered reset rows matching the folder-card style](#v29--bordered-reset-rows-matching-the-folder-card-style).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Gave **Remove Downloaded Models** and **Clear Search Index** their own grey-filled, bordered row,
  matching the visual treatment already used for each authorized folder.
- Moved **Remove Downloaded Models** to sit directly under the model capability list as its own row,
  rather than as a fourth entry sharing that list's box.

### Delivered

`e53f304` (2026-08-22)

`e53f304`

<a id="change-31"></a>
<a id="v28--simplified-reset-rows-and-corrected-model-removal-placement"></a>

## v2.8 / build 28 — 2026-08-22

- **Change:** Simplified reset rows and corrected model-removal placement.

### Changed

- Git index record, not an independently established release date: [Simplified reset rows and corrected model-removal placement](#v28--simplified-reset-rows-and-corrected-model-removal-placement).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Moved **Remove Downloaded Models** into the model capability list itself, directly below Chat/File
  search/Voice input, instead of sitting apart near the bottom of the Models section.
- Dropped the inline explanation text under **Clear Search Index** and **Remove Downloaded Models**;
  each row is now an icon, name, and button, with the full effect still explained in the
  confirmation alert before anything is deleted.
- Fixed a left-alignment inconsistency that made Clear Search Index appear indented relative to the
  folder list above it.

### Delivered

`e53f304` (2026-08-22)

`e53f304`

<a id="change-32"></a>
<a id="v27--reset-controls-integrated-into-their-owning-sections"></a>

## v2.7 / build 27 — 2026-08-22

- **Change:** Reset controls integrated into their owning sections.

### Changed

- Git index record, not an independently established release date: [Reset controls integrated into their owning sections](#v27--reset-controls-integrated-into-their-owning-sections).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Moved **Remove Downloaded Models** into the Models section, next to the capability list and
  storage details it affects.
- Moved **Clear Search Index** (and the indexed-file count) into Folder Access, next to the folder
  list and indexing controls it affects, instead of sharing a block with model controls.
- Removed automatic previous-build retention from the offline build script; a rebuild now always
  leaves exactly one application at the project root.

### Delivered

`e53f304` (2026-08-22)

`e53f304`

<a id="change-33"></a>

## v2.6 / build 26 — 2026-08-22

- **Change:** On-demand model removal, search-index reset, and status check.

### Changed

- Added an on-demand Check Now action in Settings that re-verifies installed models and re-counts
  indexed files instead of only checking at launch.
- Added Clear Search Index, letting a user rebuild the search index from scratch without deleting
  the app or losing folder access and conversation history.
- Added Remove Downloaded Models for a clean reinstall of the model files alone.
- Showed the on-disk storage each action would free, directly beside its button. Git reconciliation:
  Committed Settings reset controls and storage displays, with the documented v2.6–v3.1 iteration
  history; required one retained root-level app bundle after rebuild.
- Added **Check Now** to Settings, re-verifying installed models and re-counting indexed files on
  demand instead of only at launch.
- Added **Clear Search Index**, deleting every indexed file, passage, and vector, then immediately
  re-indexing every authorized folder. Folder access, monitoring preferences, and conversation
  history are untouched.
- Added **Remove Downloaded Models**, deleting every installed model file and its verification cache
  so a reinstall starts from a clean slate without deleting the application itself.
- Both destructive actions require confirmation and are disabled while indexing, a request, or voice
  capture is active.

### Delivered

`e53f304` (2026-08-22)

`e53f304`, `d2a7d3e`

<a id="change-34"></a>

## v2.5 / build 25 — 2026-08-21

- **Change:** Complete folder hierarchy and precise folder-scoped results.

### Changed

- Published every scanned file and folder as searchable metadata before expensive extraction begins,
  while preserving previously indexed passages. Interrupted runs no longer leave later folders
  absent from the hierarchy.
- Processed folder context before file contents and made a literal folder name or path the retrieval
  boundary, preventing unrelated semantic candidates outside that folder from being presented as its
  contents.
- Recovered explicit file and folder requests when the local routing model returns only a generic
  results acknowledgement, avoiding a response that claims matches while showing no cards.
- Added the installed release number to the Settings header.

### Delivered

`ccc334d` (2026-08-21)

<a id="change-35"></a>
<a id="v24--reliable-type-only-listings-and-idle-command-pulse"></a>

## v2.4 / build 24 — 2026-08-21

- **Change:** Reliable type-only listings and idle command pulse.

### Changed

- Git index record, not an independently established release date: [Reliable type-only listings and idle command pulse](#v24--reliable-type-only-listings-and-idle-command-pulse).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Normalized broad requests such as “Any PDFs?” into type-only listings so conversational filler no
  longer becomes a false semantic-evidence requirement.
- Preserved meaningful topics in requests such as “PDFs about insurance” and kept the requested file
  type as a hard constraint.
- Replaced the state-changing triangle phase collection with one stable continuous loop and
  increased the bright-to-dim contrast while retaining a static full-red Reduce Motion presentation.

### Delivered

`ccc334d` (2026-08-21)

`ccc334d`

<a id="change-36"></a>
<a id="v23--folder-aware-retrieval-and-coordinated-interface-motion"></a>

## v2.3 / build 23 — 2026-08-21

- **Change:** Folder-aware retrieval and coordinated interface motion.

### Changed

- Git index record, not an independently established release date: [Folder-aware retrieval and coordinated interface motion](#v23--folder-aware-retrieval-and-coordinated-interface-motion).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Indexed each authorized root and descendant folder as a first-class result with a bounded, locally
  embedded context derived from its name, relative path, and direct children.
- Added hierarchy-aware retrieval so a strongly matched folder promotes contained files and folders,
  while requested file types remain hard constraints within that scope.
- Prioritized exact folder and path evidence over unrelated document passages and explained scoped
  results with the folder that qualified them.
- Added folder-aware Open actions, response and screen crossfades, staggered result acquisition, and
  a slow idle pulse for the red command triangle. Reduce Motion keeps these states legible without
  movement.

### Delivered

`ccc334d` (2026-08-21)

`ccc334d`

<a id="change-37"></a>
<a id="v22--evidence-backed-result-cards-and-honest-visual-search-limits"></a>

## v2.2 / build 22 — 2026-08-21

- **Change:** Evidence-backed result cards and honest visual-search limits.

### Changed

- Git index record, not an independently established release date: [Evidence-backed result cards and honest visual-search limits](#v22--evidence-backed-result-cards-and-honest-visual-search-limits).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Stopped a hard file-type constraint from qualifying otherwise unrelated files when a request also
  contains a topic or content description. A non-empty search now requires filename, path, keyword,
  or semantic evidence.
- Derived hard file-type filters from the user's own words instead of trusting a model-generated
  kind. Requests for files containing images no longer become an invented PDF or image-file
  constraint.
- Replaced generic content-search reasons with the strongest concrete evidence, including a bounded
  indexed passage for keyword and semantic matches and calibrated wording for uncertain semantic
  relations.
- Reported requests that require recognizing visual subjects or embedded images as unsupported by
  the current text-and-OCR index. This prevents false result cards while preserving the separately
  scoped path to local multimodal retrieval.

### Delivered

`ccc334d` (2026-08-21)

`ccc334d`

<a id="change-38"></a>
<a id="v21--bounded-vector-search-visible-button-hover-states-and-clarified-semantic-image-limits"></a>

## v2.1 / build 21 — 2026-08-21

- **Change:** Bounded vector search, visible button hover states, and clarified semantic-image limits.

### Changed

- Git index record, not an independently established release date: [Bounded vector search, visible button hover states, and clarified semantic-image limits](#v21--bounded-vector-search-visible-button-hover-states-and-clarified-semantic-image-limits).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Capped every sqlite-vec nearest-neighbor request at the embedded extension's 4,096-result limit
  and stopped adaptive file-type expansion at the same boundary, preventing large indexes from
  producing a 5,120-neighbor database error.
- Added restrained hover feedback to every custom in-window button while preserving disabled states,
  keyboard focus, stable layout, and reduced-motion behavior. Native macOS alert and menu buttons
  retain their system-provided pointer states.
- Confirmed that extracted passages are embedded with the local Qwen text model, stored in
  sqlite-vec, and combined with filename, path, keyword, type, and recency signals during ranking.
- Clarified that standalone images and image-only PDF pages contribute OCR text, not a visual
  embedding. A chart can be found from its labels, caption, or surrounding extracted text;
  recognizing an unlabeled histogram by shape requires a future local image-text model or
  image-captioning stage.

### Delivered

`ccc334d` (2026-08-21)

`ccc334d`

<a id="change-39"></a>
<a id="v20--selectable-voice-interactions-finalized-speech-and-conversational-follow-ups"></a>

## v2.0 / build 20 — 2026-08-21

- **Change:** Selectable voice interactions, finalized speech, and conversational follow-ups.

### Changed

- Git index record, not an independently established release date: [Selectable voice interactions, finalized speech, and conversational follow-ups](#v20--selectable-voice-interactions-finalized-speech-and-conversational-follow-ups).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Added a persistent Voice input setting with **Click to speak** and **Hold Space** choices. Click
  mode sends after two seconds of silence; hold mode records while Space is held and sends on
  release without taking over the Space key during text editing.
- Kept live multilingual recognition for immediate feedback, then added one complete in-memory
  transcription pass before sending so the newest words and language decision are no longer limited
  to the last streaming hypothesis.
- Reframed recent history as actual user and assistant turns for the local Qwen model, bounded each
  retained message, and prioritized the newest turns so long older responses cannot remove the
  context needed by a follow-up.
- Cleared the previous displayed request when a new text or voice interaction begins while
  preserving a draft that is already being edited.

### Delivered

`ccc334d` (2026-08-21)

`ccc334d`

<a id="change-40"></a>
<a id="v19--one-light-visual-family-across-every-screen"></a>

## v1.9 / build 19 — 2026-08-21

- **Change:** One light visual family across every screen.

### Changed

- Git index record, not an independently established release date: [One light visual family across every screen](#v19--one-light-visual-family-across-every-screen).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Extended the warm light canvas, restrained scan texture, graphite hierarchy, signal-red identity,
  and sharper surfaces from the command screen into History, Activity, file results, and Settings.
- Kept each destination purpose-specific: History remains a chronological conversation archive,
  Activity remains a filterable indexing ledger, and Settings retains every native control, status,
  confirmation, recovery path, and privacy explanation.
- Preserved natural capitalization in assistant responses and file explanations while reserving
  uppercase treatment for short telemetry and interface labels.
- Kept the application intentionally light-only, including when macOS uses Dark appearance.

### Delivered

`ccc334d` (2026-08-21)

`ccc334d`

<a id="change-41"></a>
<a id="v18--light-command-interface-with-acquired-file-modules"></a>

## v1.8 / build 18 — 2026-08-21

- **Change:** Light command interface with acquired-file modules.

### Changed

- Git index record, not an independently established release date: [Light command interface with acquired-file modules](#v18--light-command-interface-with-acquired-file-modules).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Rebuilt the main screen around the approved light-only command design: a warm off-white canvas,
  restrained scan texture, compact local-status rail, black monospaced hierarchy, and signal-red
  command markers.
- Replaced rounded command cards and material controls with square-edged file modules, acquisition
  corners, section rules, and plain Open and Reveal actions. Main-screen modules omit absolute paths
  while retained History preserves the established record.
- Kept the idle prompt centered, moved the current request control to the bottom after interaction,
  and preserved live voice text, local processing state, responsive file wrapping, reduced-motion
  behavior, and the separate History screen.
- Restyled background indexing as a compact command strip without removing its percentage, folder
  state, Activity navigation, or safe Pause action.

### Delivered

`ccc334d` (2026-08-21)

`ccc334d`

<a id="change-42"></a>

## v1.7 / build 17 — 2026-08-21

- **Change:** Current command presentation with complete conversation History.

### Changed

- Replaced the accumulating main chat with a voice-first command surface that starts centered and
  moves its live voice or text input to the bottom after the first request.
- Presents only the current processing state, latest response, and latest file findings on the main
  screen; beginning another request replaces that presentation instead of adding another bubble.
- Displays file findings in a centered adaptive grid with a restrained acquisition animation, while
  retaining explicit Open and Reveal actions and a reduced-motion fallback.
- Moved the established chronological message layout to an in-window History screen. It includes
  restored messages and new requests from the current launch, while reopening the application resets
  only the main command presentation.

### Delivered

`ccc334d` (2026-08-21)

<a id="change-91"></a>

## Added selectable voice input (click-to-speak or hold-to-talk) with a 120-second maximum-capture safeguard so the microphone can never stay open unattended — 2026-08-21

- **Change:** Added selectable voice input (click-to-speak or hold-to-talk) with a 120-second maximum-capture safeguard so the microphone can never stay open unattended.

### Changed

- Replaced the chat view with a focused command surface and moved the complete retained conversation
  to its own History screen.
- Published the complete file and folder hierarchy before content extraction so interrupted indexing
  no longer leaves later folders undiscoverable.
- Made literal folder matches scope results to their own contents, preventing unrelated semantic
  guesses from being presented as folder evidence.
- Recovered explicit file and folder searches when the local routing model omits its structured
  marker.
- Added the installed release number to Settings. Git reconciliation: Committed the v1.7–v2.5
  iteration history: command/history redesign, light presentation, bounded click/hold voice input,
  evidence-backed results, folder-aware indexing/retrieval, layout refactoring, and v2.5/build-25
  metadata.

### Delivered

`76cc12d`, `c044bde`, `c8f84d3`, `4b5a142`, `ccc334d`

<a id="change-43"></a>

## v1.6 / build 16 — 2026-08-20

- **Change:** Spoken words appear and send, and the routing marker stays hidden.

### Changed

- Fixed spoken words never appearing and no request being sent.
  - Recognized text for a short phrase arrives as unconfirmed segments, which the app ignored: it
    read only the confirmed list, which fills once a recording is long enough to exceed the
    confirmation window, and the in-progress text, which is cleared as soon as each chunk finishes.
- Fixed a routing instruction being shown as the assistant's answer.
  - The model is asked for a doubled bracket marker and does not reliably reproduce the brackets, so
    a near miss was treated as ordinary conversation and the raw marker and payload were displayed.
  - The marker is now matched by its token, whatever brackets surround it.
- Neutralized that token wherever untrusted text enters a prompt, so an answer already stored in
  history cannot teach the model to repeat it.

### Delivered

`54d83be` (2026-08-20)

<a id="change-44"></a>
<a id="v15--recordings-end-on-a-pause-and-send-what-was-said"></a>

## v1.5 / build 15 — 2026-08-20

- **Change:** Recordings end on a pause and send what was said.

### Changed

- Git index record, not an independently established release date: [Recordings end on a pause and send what was said](#v15--recordings-end-on-a-pause-and-send-what-was-said).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Fixed a spoken request never being sent after the recording ended on its own. Finishing ran inside
  the task that following the recording had just cancelled, so the request was abandoned silently.
- Fixed the recording not ending after a pause. The level below which audio counted as quiet was far
  lower than a quiet room reports, so a pause was never recognized.
- Ended a recording on a pause in the audio rather than on recognized text. Recognition lags speech
  by about a second, so waiting for text delayed the stop or prevented it.
- Shortened the pause that ends a recording to two seconds.
- Reported a capture that fails instead of ending silently. A failed stream previously left the
  interface showing a recording that was no longer running, with no message and no error.
- Logged speech-library activity in Debug builds so a capture that produces no text can be
  diagnosed. Release builds stay silent.

### Delivered

`19babe8` (2026-08-20)

`19babe8`

<a id="change-45"></a>
<a id="v14--live-waveform-and-on-screen-speech-with-no-audio-written-to-disk"></a>

## v1.4 / build 14 — 2026-08-20

- **Change:** Live waveform and on-screen speech, with no audio written to disk.

### Changed

- Git index record, not an independently established release date: [Live waveform and on-screen speech, with no audio written to disk](#v14--live-waveform-and-on-screen-speech-with-no-audio-written-to-disk).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Replaced the text field with a live waveform while the microphone is open, drawn from the audio
  levels the speech model reports rather than a decorative animation.
- Showed recognized words in the conversation as they are spoken, so it is clear what the app has
  captured and when to stop. Settled words are shown plainly and words still being revised are
  dimmed, because continuous recognition rewrites its most recent words as more audio arrives.
- Ended a recording automatically after a pause, while the microphone control still stops it
  immediately.
- Stopped writing microphone audio to disk. Speech is recognized from memory as it arrives, so no
  recording file is created, and any file left by an earlier version is deleted at startup.
- Added a preparing state shown before capture begins. Continuous recognition needs the speech model
  loaded first, so the interface says so instead of opening the microphone and discarding what it
  cannot yet recognize.

### Delivered

`d389a01` (2026-08-20)

`d389a01`

<a id="change-46"></a>

## v1.3 / build 13 — 2026-08-20

- **Change:** The assistant stopped repeating its own result sentence.

### Changed

- Stopped the assistant repeating "I found N matches. They are shown below." for every request. When
  an answer duplicated card metadata, the app replaced it with that generated sentence, stored the
  sentence as the assistant's reply, and then showed it back to the model as recent conversation.

After a few such turns the model reproduced the sentence as its own answer, so every later request
  returned the same text and no results.

- Replaced a generated acknowledgement with a bracketed note wherever conversation history enters a
  prompt, so the model keeps the context that results were shown without a sentence to imitate.

### Delivered

`d389a01` (2026-08-20)

<a id="change-47"></a>

## v1.2 / build 12 — 2026-08-20

- **Change:** Vendored network code removed, with correctness fixes and automated tests.

### Changed

**Offline boundary**

- Removed the network path monitor that the vendored speech dependency started whenever it
  constructed a model-hub client, so no code in the application observes network state.
- Removed that dependency's fallback that downloaded a missing speech tokenizer from the internet,
  and moved the tokenizer into the verified offline model package instead. A missing tokenizer now
  reports a reinstall instruction rather than attempting a connection.
- Stored both dependency modifications in the repository and re-applied and verified them during
  preparation, so refreshing a pinned checkout cannot silently restore the original network code.
- Extended the boundary audit to reject any executable in the bundle that links a networking library
  or imports a network symbol, in addition to the existing entitlement checks.
- Recorded the verified checksum and size of every added tokenizer file in the model manifest, and
  made the preparation download fail loudly on a timeout, a partial file, or a truncated file
  listing.

**Search and extraction accuracy**

- Made a multi-word file request match words individually instead of requiring the whole phrase to
  appear as one run of characters, so a request naming a topic and a folder can still find the file.
- Treated `%` and `_` typed in a request as ordinary characters rather than as database wildcards.
- Scaled an oversized photograph or scan down to the supported recognition size instead of rejecting
  it, so a high-resolution image is no longer indexed with no text at all.
- Added Simplified Chinese alongside English to text recognition.
- Kept the text of a PDF's readable pages when recognition fails on one page, instead of discarding
  the whole document's text.
- Detected the encoding of a plain-text file rather than assuming UTF-8, so a file saved in another
  encoding is no longer indexed as replacement characters.
- Excluded the real system and cache directories by absolute path, which a sandboxed application
  cannot identify by name alone.
- Stopped a concise answer from being replaced by a match count when a result's name was an ordinary
  word, such as a folder named `Documents`.

**Voice, models, and lifecycle**

- Fixed voice capture discarding the first seconds of speech: the microphone now opens immediately
  while the speech model loads alongside it.
- Fixed a recording being read back before macOS had finished writing it, which could truncate or
  empty a transcription.
- Separated **Not installed** from **Damaged** in Settings so a missing model package and a file
  that no longer matches its checksum no longer share one recovery instruction.
- Reported voice input as unavailable when its tokenizer is absent, instead of reporting it ready
  and failing at first use.
- Re-verified model checksums on a weekly schedule rather than at every launch, and closed the
  private database when the application quits.
- Added an extraction version to each file's fingerprint, so an extraction correction re-extracts
  already-indexed files once instead of leaving them on superseded text.

**Performance and cleanup**

- Replaced a repeated per-result database lookup with one batched read, and stopped semantic search
  from scanning the whole vector table when no vector can satisfy the requested file type.
- Made passage splitting cost time proportional to a document's length rather than to its length
  squared.
- Removed a retrieval lookup against an empty prototype table that ran on every search and could
  never affect a score.
- Added a native test target with 46 automated tests covering request routing, search-text escaping,
  passage offsets, card-aware answers, and scanner exclusions.
- Added previews for every model readiness state, so the not-installed and damaged wording can be
  reviewed in both appearances without removing or corrupting installed model files. They are
  excluded from the shipped application.

### Delivered

`d389a01` (2026-08-20)

<a id="change-48"></a>

## v1.1 / build 11 — 2026-08-20

- **Change:** Simpler indexing controls and a clean shutdown on quit.

### Changed

- Reworked file-state counts into compact metric tiles and consolidated each folder's
  automatic-update state and action into one control.
- Added a dedicated pause action for an active indexing run and redesigned activity-history filters
  as consistent Source, Folder, and Status fields.
- Anchored restored conversations at the newest message to prevent a visible top-to-bottom jump when
  returning to the assistant.
- Added orderly llama.cpp, Metal, voice, monitoring, and indexing teardown so a normal Quit no
  longer produces an unexpected-termination report.

### Delivered

`d389a01` (2026-08-20)

<a id="change-49"></a>

## v1.0 / build 10 — 2026-08-20

- **Change:** Continuous folder monitoring, pausable indexing, and 30-day activity.

### Changed

- Added pausable per-folder indexing with determinate progress, percentages, and clearly labeled
  new, modified, unchanged, removed, and skipped states.
- Added process-lifetime native macOS folder monitoring, debounced incremental updates, and
  launch-time catch-up scans without a daemon, login item, server, or runtime network access.
- Added a same-window Activity screen with run filters, automatic monitoring events, summary badges,
  expandable file details, and a rolling 30-day retention policy.
- Kept retained activity after folder revocation while continuing to remove the bookmark and
  dependent searchable index records.
- Added a background-indexing banner so silent automatic work remains visible without blocking
  conversation.

### Delivered

`d389a01` (2026-08-20)

<a id="change-50"></a>

## v0.9 / build 9 — 2026-08-20

- **Change:** Hard file-type filters, prompt safety, and tightened entitlements.

### Changed

- Applied requested file-type constraints inside metadata and full-text queries before candidate
  limits, and added adaptive vector-neighbor expansion so valid constrained semantic matches are not
  hidden behind other file types.
- Neutralized Qwen chat-control markers in questions, local history, paths, and excerpts before
  untrusted text enters a parsed chat template.
- Resolved current symlink targets before explicit Open or Reveal actions and rejected targets
  outside the authorized root.
- Made SQLite reads distinguish normal completion from execution failure, reject malformed required
  identifiers, and close a partially initialized database connection after setup failure.
- Removed duplicated presentation state, dead prototype APIs, unused constants, and duplicate
  indexed-item decoding while retaining compatible prototype-era database tables.
- Hardened temporary voice recordings with owner-only permissions, failed-start cleanup, and
  stale-recording cleanup before the next capture.
- Recorded unreadable traversal paths in indexing exclusions instead of silently continuing.
- Restricted Release signing to the four approved sandbox entitlements and made the static audit
  reject every unexpected entitlement.
- Hardened connected dependency archive extraction on older system Python versions while preserving
  safe in-repository symbolic links.

### Delivered

`d389a01` (2026-08-20)

<a id="change-51"></a>

## v0.8 / build 8 — 2026-08-20

- **Change:** Settings reordered, conversation text styled, and the README rewritten.

### Changed

- Reordered Settings around Privacy, Folder Access, Models, and Assistant Status.
- Updated the Settings introduction to follow the same information hierarchy.
- Added restrained sender labels and role-specific typography to user and assistant messages.
- Added local lightweight styling for emphasis, inline code, preserved paragraphs, and simple list
  markers without introducing a web-rendering surface.
- Consolidated the README into task-focused sections, converted troubleshooting to questions and
  answers, integrated related operational guidance, preserved the architecture diagrams, and removed
  machine-specific paths.
- Converted the project folder into a lean source checkout by excluding regenerated dependencies,
  model assets, offline packages, and built applications from Git.

#### Delivery evidence

- The isolated Debug build and clean offline Release build completed using pinned local
  dependencies.
- The clean-built and installed bundles report v0.8 with numeric build `8`.
- The clean-built and installed executables are byte-identical with SHA-256
  `1deb2c96ea3f6da614cea02477e905ea9c2850f2e5dd4035057313b2432be8ea`.
- Deep signature validation and the static offline-boundary audit passed for the installed bundle.
- Focused source checks confirmed the requested Settings order, sender labels, local rich-text
  renderer, and absence of machine-specific paths in this README.
- The installed application launched successfully and remained running during the startup smoke
  check.
- Automated visual capture was unavailable because the current macOS environment did not grant
  accessibility or screen-recording permission; no permission boundary was widened to bypass that
  restriction.

### Delivered

`d389a01` (2026-08-20)

<a id="change-52"></a>
<a id="v07--answers-stopped-repeating-details-already-shown-in-the-cards"></a>

## v0.7 / build 7 — 2026-08-20

- **Change:** Answers stopped repeating details already shown in the cards.

### Changed

- Git index record, not an independently established release date: [Answers stopped repeating details already shown in the cards](#v07--answers-stopped-repeating-details-already-shown-in-the-cards).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Stopped grounded replies from repeating filenames, paths, source numbers, or file-by-file lists
  already presented in result cards.
- Added a deterministic local safeguard that replaces duplicated card metadata with a concise match
  count when necessary.
- Applied the same safeguard to restored conversation history while preserving reusable cards.
- Added project-hygiene rules and removed obsolete build caches, historical application bundles,
  Finder metadata, and download-state files while preserving installed offline models and dependency
  pins.

### Delivered

`d389a01` (2026-08-20)

`d389a01`

<a id="change-53"></a>
<a id="v06--plain-language-model-readiness-and-result-cards-that-survive-relaunch"></a>

## v0.6 / build 6 — 2026-08-20

- **Change:** Plain-language model readiness and result cards that survive relaunch.

### Changed

- Git index record, not an independently established release date: [Plain-language model readiness and result cards that survive relaunch](#v06--plain-language-model-readiness-and-result-cards-that-survive-relaunch).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Redesigned **Models** as a plain-language readiness summary for Chat and answers, File search, and
  Voice input.
- Added overall readiness, private model-storage usage, launch-check acknowledgement, and actionable
  recovery wording without exposing model filenames in the interface.
- Stored ranked result-card snapshots with their assistant messages and restored them after
  relaunch.
- Added migration for older citation-only messages when the cited item still exists in the current
  index.
- Revalidated saved-card actions against the current index, read-only folder authorization, path
  containment, and disk presence.
- Prevented result actions from collapsing into narrow vertical controls.
- Standardized human-facing release labels with a `v` prefix and aligned the project folder name
  with the application name.

### Delivered

`d389a01` (2026-08-20)

`d389a01`

<a id="change-54"></a>
<a id="v05--message-timestamps-clear-conversation-and-shorter-result-cards"></a>

## v0.5 / build 5 — 2026-08-20

- **Change:** Message timestamps, Clear Conversation, and shorter result cards.

### Changed

- Git index record, not an independently established release date: [Message timestamps, Clear Conversation, and shorter result cards](#v05--message-timestamps-clear-conversation-and-shorter-result-cards).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Added local timestamps below user and assistant messages.
- Added a confirmed Clear Conversation action in the assistant header and application menu.
- Limited history deletion to saved messages and current results; folders, permissions, models,
  index records, and source files remain unchanged.
- Reduced result-card height and replaced stacked ranking signals with one concise **Why it
  matches** explanation.

### Delivered

`d389a01` (2026-08-20)

`d389a01`

<a id="change-55"></a>
<a id="v04--settings-reorganized-around-status-folder-access-and-privacy"></a>

## v0.4 / build 4 — 2026-08-20

- **Change:** Settings reorganized around status, folder access, and privacy.

### Changed

- Git index record, not an independently established release date: [Settings reorganized around status, folder access, and privacy](#v04--settings-reorganized-around-status-folder-access-and-privacy).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Reorganized Settings around assistant status, shortcut availability, folder access, and one
  focused privacy statement.
- Styled Control, Option, and Space as separate accessible keycaps.
- Kept an individual **Update Index** action on every folder and showed **Update All Folders** only
  when multiple folders were authorized.
- Reduced repeated privacy wording while retaining read-only access and explicit revocation
  controls.

### Delivered

`d389a01` (2026-08-20)

`d389a01`

<a id="change-56"></a>
<a id="v03--local-routing-between-chat-clarification-and-file-search"></a>

## v0.3 / build 3 — 2026-08-20

- **Change:** Local routing between chat, clarification, and file search.

### Changed

- Git index record, not an independently established release date: [Local routing between chat, clarification, and file search](#v03--local-routing-between-chat-clarification-and-file-search).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Added local routing between ordinary conversation, clarification, and structured file search.
- Made requested file types hard constraints instead of filename keywords.
- Added deterministic clarification for singular, underspecified file requests while retaining broad
  listing requests such as “Show me PDFs.”
- Added automatic bottom scrolling, corrected message alignment, a richer native visual system,
  in-window Settings, responsive result cards, and the selected blue folder-and-sparkle icon.

### Delivered

`d389a01` (2026-08-20)

`d389a01`

<a id="change-57"></a>
<a id="v02--focused-interface-with-crash-safe-indexing-and-folder-revocation"></a>

## v0.2 / build 2 — 2026-08-20

- **Change:** Focused interface with crash-safe indexing and folder revocation.

### Changed

- Git index record, not an independently established release date: [Focused interface with crash-safe indexing and folder revocation](#v02--focused-interface-with-crash-safe-indexing-and-folder-revocation).
- Preserves the documented intermediate release; no separate commit/build is invented.
- Simplified the interface around conversation, file retrieval, voice input, shortcut access, and
  Settings.
- Added crash-safe sequential indexing, folder revocation, local conversation, and lazy local
  speech-model loading.

### Delivered

`f1eb446` (2026-08-20)

`f1eb446`

<a id="change-58"></a>

## v0.1 / build 1 — 2026-08-20

- **Change:** First sandboxed assistant with local indexing, retrieval, and voice.

### Changed

- Established the sandboxed SwiftUI application, read-only folder authorization, local indexing,
  embedded inference, hybrid retrieval, OCR, and local voice foundation.

### Delivered

`f1eb446` (2026-08-20)

<a id="change-99"></a>

## Committed v1.2–v1.6 extraction, search, voice, readiness, offline-boundary, and regression work — 2026-08-20

- **Change:** Committed v1.2–v1.6 extraction, search, voice, readiness, offline-boundary, and regression work.

### Changed

- Git record: Committed v1.2–v1.6 extraction, search, voice, readiness, offline-boundary, and regression work.
- Added/corrected the retrospective v0.1–v1.6 index and normalized early version labels; moved/named the built app at project root.

### Delivered

- `1d6ad8c`, `491acf5`, `e221dd3`, `7e7e4b4`, `866e483`, `38e911d`, `8395013`, `8c0951c`, `c988e5a`, `1b4c84d`, `d389a01`, `19babe8`, `54d83be`, `4c09d2e`, `21c6e15`, `58e9cc9`, `9767ba8`, `822bd04`, `ab0d831`, `f1eb446`

<a id="change-108"></a>

## Released v1.1 source with continuous native folder monitoring, pausable progress, and visible background indexing — 2026-08-16

- **Change:** Released v1.1 source with continuous native folder monitoring, pausable progress, and visible background indexing.

### Changed

<ul><li>Released v1.1 source with continuous native folder monitoring, pausable progress, and visible background indexing.</li><li>Added 30-day local activity history with redesigned filters, file-state metrics, and retained records after folder revocation.</li><li>Improved conversation restoration and fixed unexpected termination during local model and Metal shutdown.</li></ul> Git reconciliation: Added v1.0/v1.1 continuous indexing, activity history, navigation/shutdown fixes, regression checks, and release documentation.

### Delivered

`fa43bba`, `d624134`, `201be5f`, `9546eaa`

<a id="change-109"></a>

## Imported the native offline assistant and its preserved source history, guardrails, target/configuration, tooling, indexing, private retrieval/storage, UI — 2026-08-15

- **Change:** Imported the native offline assistant and its preserved source history, guardrails, target/configuration, tooling, indexing, private retrieval/storage, UI.

### Changed

- Git record: Imported the native offline assistant and its preserved source history, guardrails, target/configuration, tooling, indexing, private retrieval/storage, UI, and voice.
- The retained imported documentation already describes v0.9; this is not evidence that all earlier builds were published on the import date.

### Delivered

`91e3214`, `5718905`, `07d7ceb`, `f3fc64a`, `581035e`, `d20293e`, `2dd4e2d`, `bd87b98`, `ce02eec`, `6c60750`, `b11d6f2`, `079be3b`
