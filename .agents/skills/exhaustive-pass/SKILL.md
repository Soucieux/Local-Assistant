---
name: exhaustive-pass
description: Use only when the user explicitly invokes $exhaustive-pass or requests an exhaustive, no-skips review of Local Assistant code. Review and simplify the complete approved scope, audit every applicable coding-style rule against every scoped file, investigate every proposed skip, check secret exposure, apply safe authorized fixes, and run focused native tests plus the offline Xcode build. Never invoke automatically.
---

# Exhaustive Pass

Run one complete five-phase Local Assistant audit. Never create a commit, push, pull request, release, or unrelated feature as part of this skill.

## Scope and native equivalents

1. Read the governing project and global instructions completely before inspecting or editing code.
2. Use the paths named by the user. When no scope is named:
   - review all staged, unstaged, and untracked first-party application files when the repository has a commit baseline;
   - review the complete first-party application source, configuration, scripts, and documentation when the repository has no commit baseline.
3. Exclude `.git`, `Vendor`, model assets, built `.app` bundles, `DerivedData`, generated `outputs`, and this skill package unless the user explicitly includes them. Review dependency pins and build integration, but do not audit third-party source as project code.
4. Preserve unrelated user work. Apply safe in-scope fixes unless the user requests read-only review or the active workflow has not authorized edits.
5. Use these direct native equivalents and no broader substitutes:
   - missing project `coding-style` skill → project `AGENTS.md`, active global code standards, and established patterns in comparable Local Assistant files;
   - web API, Cloud Function, or remote database exposure → local SQLite reads, logs, conversation history, result cards, interface output, and sandbox boundaries;
   - `npm run build` → focused native checks followed by the project's offline Xcode Release build.
6. Keep one checklist that accounts for every scoped file, every style rule, and all five phases.

## Phase 1 — Code review and simplification

Use the `code-review` skill as the review framework, then inspect every scoped file through four lenses:

1. **Reuse** — find genuine opportunities to reuse an existing utility, service, constant, component, or established pattern.
2. **Simplification** — remove unnecessary state, branches, indirection, abstractions, and duplication without changing required behavior.
3. **Efficiency** — remove proven repeated work, allocation, rendering, iteration, file I/O, database work, or model work on the actual execution path.
4. **Architectural placement** — keep each responsibility in the correct existing layer and preserve the documented local data flow.

Apply every safe, authorized, in-scope correction. Do not introduce speculative abstractions or refactor code merely to make it look different.

## Phase 2 — Complete coding-style audit

Build the applicable rule checklist before judging files:

1. If `.agents/skills/coding-style/SKILL.md` exists, read it completely and enumerate every second-level heading as a checklist item.
2. Otherwise, read project `AGENTS.md` and the active global code standards completely. Enumerate every applicable requirement as the equivalent style checklist. Translate incompatible terminology only to its direct language equivalent, such as JSDoc to Swift documentation comments.
3. Read every scoped file from beginning to end. Searches and summaries do not replace the full read.
4. Record one verdict for every file and every checklist item:
   - **Compliant** — the final file satisfies the rule.
   - **Fixed** — the rule was violated and the final file contains the correction.
   - **N/A** — the rule cannot apply to that file; give a concrete one-line reason.
5. If any scoped file or checklist item lacks a verdict, repeat the phase. File count is not a reason to abbreviate the matrix.

## Phase 3 — No-skips investigation

Collect everything described during Phases 1 or 2 as optional, low-priority, skipped, deferred, or out of scope. For each item:

1. Read the complete relevant code and trace the full correction scope.
2. Apply the correction when it improves correctness, clarity, reuse, or efficiency and remains authorized.
3. Do not use workload, file count, inconvenience, or low impact as a reason to skip.
4. Leave an item unresolved only with concrete evidence of one of these conditions:
   - the finding is a false positive;
   - the proposed correction makes behavior worse;
   - the correction has a hard architectural conflict;
   - the alternative is not an actual clarity or efficiency improvement;
   - the correct change requires unauthorized material scope expansion.
5. Cite the relevant code and explain the evidence for every unresolved item. Treat an environmental failure as blocked testing, not as a technical skip.

## Phase 4 — Secret-exposure audit

Check the same scope in two dimensions:

1. **Hardcoded secrets** — search for credential literals, environment identifiers, openids, API keys, bearer values, tokens, passwords, private keys, and similar sensitive material. Distinguish public dependency locations, hashes, bundle identifiers, and model revisions from credentials.
2. **Sensitive values leaving their boundary** — inspect local SQLite reads, logs, conversation persistence, result cards, assistant text, crash output, and sandbox handoffs. Confirm they do not expose credentials, hidden source content, or another unauthorized path beyond the explicitly authorized local interface.

If the project contains no API, Cloud Function, remote database, or secret-bearing surface, record a justified N/A instead of inventing one. Fix confirmed exposure without adding runtime networking or weakening the read-only boundary.

## Phase 5 — Focused testing and build

After all authorized fixes:

1. Run focused native tests for every affected behavior. Do not count compilation as a test.
2. When no suitable test exists, use the smallest deterministic native test or harness that exercises the changed behavior without expanding into unrelated test infrastructure. If no valid focused test can run, report the result as not ready.
3. Restore `Vendor` from pinned project revisions only when required for testing or building. Prefer an existing verified offline source package. If restoration requires network access, obtain explicit approval and use only the preparation workflow; never add network access to the application.
4. Run the project's offline Xcode Release build through `./Scripts/build_offline.sh` or its exact documented native equivalent.
5. Do not report the pass complete or the code ready when focused testing or the build fails, is blocked, or is not run.

Report the reviewed scope, safe fixes grouped by phase, the complete style verdict matrix, evidence for every unresolved skip, the secret-exposure result, and the exact test/build commands and outcomes. End with exactly one status: **Ready**, **Not ready**, or **Blocked**. Never commit automatically.
