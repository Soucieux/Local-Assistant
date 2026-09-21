# Contributing to Local Assistant

Thank you for helping improve Local Assistant. This guide covers the project-specific boundaries
that apply whether the source is viewed in its canonical private workspace or in the standalone
public repository.

## Start here

- Read the [project README](README.md) for supported behavior, setup, architecture, and current
  release evidence.
- Keep each change focused on the requested behavior and match the surrounding style.
- Update the README when a meaningful change affects capabilities, setup, architecture, workflows,
  release identity, or history.
- Keep temporary build output, credentials, private app data, and local model files out of source
  control. Retain only the established project-root delivery artifacts documented by the README.

## Project boundaries

- Keep the main macOS app fully local and offline. Do not add network entitlements, clients,
  servers, telemetry, runtime downloads, web views, or updater code to the app target.
- Keep authorized source folders read-only. Opening or revealing a file must remain an explicit
  user action.
- Keep CloudBase reminders as hidden, read-only local knowledge. Local Assistant must not add,
  update, complete, reschedule, or remove a remote reminder itself.
- Keep outbound work in the separate, opt-in OpenClaw Connector. For an inferred reminder mutation,
  keep confirmation in the assistant conversation and send only the exact confirmed request. Keep
  explicit standalone `OpenClaw` or `Open Claw` as the outbound gate for non-reminder requests.
  Never attach cached reminders, indexed files, or conversation history.
- Preserve the Connector's narrow security boundary: its documented pinned SSH tunnel, loopback
  Gateway destination, Keychain credentials, and owner-only spool must not migrate into the main
  app.

## Retrieval and interface behavior

- Treat requested file types as hard search constraints. Ask a concise question when a search
  would otherwise require an arbitrary choice, and do not present uncertain results as confident
  matches.
- When file cards contain filenames, paths, and metadata, keep the assistant message focused on the
  result or requested insight instead of repeating those details.
- Render answers as native, selectable Markdown. Keep layouts responsive, links inert, and the app
  light-only, including when macOS uses Dark appearance.
- Keep folder access, revocation, indexing, model state, shortcuts, and privacy details in Settings,
  with recovery-oriented language for the person using the app.

## Checks for a change

- Run the focused tests and build checks that cover the changed behavior. A passing focused check
  establishes only the behavior it exercises.
- For interface changes, inspect the built app at the intended screen and state, including the
  smallest supported window and light appearance while macOS uses Dark appearance.
- Keep temporary test builds separate from the delivered `Local Assistant.app`. Do not replace a
  signed or delivered artifact without following its release and recovery procedure.
- For installed-app instructions, assume a clean Mac whose user knows only how to open Mac Terminal
  and the server terminal. Give location-specific steps, completion cues, and nearby recovery help.
- When changing the prepared llama.cpp source under `Vendor/llama.cpp`, also follow upstream's
  [contribution guide](https://github.com/ggml-org/llama.cpp/blob/master/CONTRIBUTING.md) and
  [agent instructions](https://github.com/ggml-org/llama.cpp/blob/master/AGENTS.md), which the
  prepared tree preserves as `CONTRIBUTOR_GUIDANCE.md`.

<a id="version-and-build-policy"></a>

## Version and build policy

Local Assistant uses a marketing version and an integer build number:

- Write versions as `v<major>.<minor>`, with one minor digit from `0` through `9`. After `v0.9`
  comes `v1.0`.
- Derive the build as `major x 10 + minor`; for example, `v5.4` uses build `54`.
- Advance both values together for every change except a documentation-only one. Documentation
  corrections, history reconciliation, configuration prose, an unchanged clean rebuild, and
  artifact relocation do not by themselves require a new version.
- Keep source metadata, packaged artifacts, and documentation on the same version and build. Never
  relabel an existing signed or distributed artifact as a newer release.
- Record source implementation, tests, builds, installation, deployment, and publication as
  separate evidence states; completion of one does not prove the others.

The canonical private workspace also applies its root repository instructions and scoped internal
procedures. Those private files remain authoritative for repository-wide workflow and automation;
this standalone guide supplies the project-facing rules that must travel with the exported subtree.
