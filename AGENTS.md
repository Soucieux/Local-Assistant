# Local Assistant Product Guardrails

- Keep the runtime fully local: do not add network entitlements, clients, servers, telemetry, runtime downloads, web views, or updater code.
- Keep authorized source folders read-only. Opening and revealing files must remain explicit user actions.
- Treat requested file types as hard retrieval constraints, never as ordinary keyword hints.
- When a request is underspecified and searching would require an arbitrary choice, ask a concise clarification question instead of guessing.
- Do not label an uncertain result as a best match; visible confidence language must reflect the underlying rank.
- When file cards are present, do not repeat filenames, absolute paths, bracketed source numbers, or per-file metadata in assistant prose. Use the message for a concise result acknowledgement or requested content insight and the cards for file details.
- Preserve a focused single-column assistant. The interface may feel rich through hierarchy, typography, icons, restrained color, and depth, but must not become visually overwhelming.
- Keep folder access, revocation, indexing, model state, shortcut state, and privacy details in Settings.
- Write Settings copy for the person using the app: describe what is ready, what it enables, and how to recover. Keep model filenames and implementation terminology in documentation or diagnostics.
- Preserve natural capitalization in responses, explanations, filenames, and other content. Reserve uppercase styling for short telemetry and interface labels.
- Update `README.md` and its release-status table whenever a user-facing capability, version, privacy boundary, or validation status changes.
- Every user-facing implementation must increment both the marketing version and build number.
- Prefix human-facing release labels with `v`; keep Xcode marketing and bundle version values numeric.
- Distinguish source implementation, build, testing, code review, formal verification, and installed-bundle status. Never present one phase as evidence for another.
- Keep the application light-only. Do not mark user-facing UI work release-ready until screenshots from the built app have been reviewed in the intended light appearance, including while macOS uses Dark appearance. Check message alignment, control states, contrast, spacing, truncation, and the smallest supported window size.
- For every rebuild, place the new `Local Assistant.app` at the project root and remove stale generated versions. Do not retain a previous-bundle copy, and remove the `DerivedData` build cache once that copy is verified, so the project root is the only place the built app exists.
