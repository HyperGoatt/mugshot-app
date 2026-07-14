# Mugshot Repository Rules

These rules apply to every file and every contributor or agent working in this repository.

## Product invariants

- Mugshot is a personal coffee memory and tasting journal first. Discovery and friends support the journal; never turn the product into generic social media.
- Preserve the established cream, sage, espresso, editorial typography, Mugsy personality, photography, and native SwiftUI conventions.
- Use the ASCII spellings `cafe` and `cafes` in every user-facing string and product document. Never use an accented spelling.
- Keep private notes structurally separate from captions and all social content. Private notes must never enter Feed, sharing, notifications, analytics, drink analysis, public profiles, or public exports.
- Never add follower-performance mechanics, consumption leaderboards, caffeine goals, daily sip streaks, guilt-based notifications, or rewards tied to drinking volume.
- Merchant rewards, payments, loyalty, and partnerships remain a separate future domain unless the user explicitly authorizes that work.
- Preserve compatibility with existing visits, ratings, photos, friendships, saved cafes, recipes, drafts, and Supabase data.

## Source of truth and worktrees

- `main` is the stable, releasable source of truth. Never develop or commit directly on `main`.
- Start new work from a freshly fetched `origin/main` unless the user explicitly selects another baseline.
- Use one focused branch per task, normally named `codex/<short-topic>`.
- The daily Xcode checkout is `/Users/joe.rosso/Desktop/Projects/testMugshot`. Keep it on `main` for testing unless the user explicitly asks to test another branch.
- Codex implementation work belongs in a dedicated Codex worktree. Do not claim `main` in a Codex worktree when the daily Xcode checkout needs it.
- Never use the same branch in two worktrees. Before switching branches, inspect `git worktree list` and `git status`.
- Treat every pre-existing tracked or untracked change as user-owned. Never delete, overwrite, reset, clean, or silently stage it.
- Exclude machine-local Xcode state, derived data, secrets, and personal configuration from commits.

## Standard change workflow

1. Fetch the remote and inspect the current branch, worktrees, status, diff, and applicable repository instructions.
2. Confirm the requested scope and identify unrelated local changes before editing.
3. Create a focused branch from current `origin/main`.
4. Inspect the existing implementation, models, schema, tests, and design system before changing behavior.
5. Make the smallest coherent implementation that solves the requested problem. Keep presentation flags separate from domain behavior and data contracts.
6. Review the diff for accidental files, secrets, debug code, private data, accented cafe spellings, and unrelated changes.
7. Run validation proportional to risk and report exactly what passed, failed, or could not be run.
8. Commit only the intended files with a concise message.
9. Push or open a draft pull request only when the user has authorized publishing.
10. Merge, tag, deploy, or release only after explicit user approval.

## Git and pull requests

- Never force-push or rewrite `main`, shared branches, tags, or already-applied migration history.
- Never use destructive commands such as `git reset --hard`, `git clean`, or checkout-based file destruction without explicit user approval.
- Keep commits and pull requests focused. Do not mix unrelated product phases, cleanup, formatting, or local Xcode state.
- Resolve `main` divergence on the feature branch, preserve valuable history, and rerun validation before merging.
- Default pull requests to draft until implementation and relevant checks are complete.
- Pull request descriptions must state what changed, why, user impact, migrations, privacy/security impact, validation, screenshots for visual work, and any residual risk.
- Use a normal merge commit for major roadmap or release work when preserving history matters. Do not squash a multi-phase release unless the user deliberately chooses that tradeoff.
- Delete remote branches only after the merge and release are verified and only when no active worktree uses them.

## iOS and SwiftUI quality gates

- Prefer SwiftUI-native architecture and the shared Mugshot design system over one-off styling.
- Keep state ownership explicit, avoid duplicate submission paths, and share domain models and coordinators across presentations and entry points.
- Build the app and run relevant Swift tests before handing off code. For significant changes, run the full unit suite.
- For UI changes, run the affected flow in Simulator and perform screenshot-based QA rather than relying on compilation alone.
- Test Cafe and Home behavior plus Recipe behavior where applicable. Test Private, Friends, and Everyone visibility whenever publishing changes.
- Verify VoiceOver labels and order, Dynamic Type, contrast, Reduce Motion, keyboard behavior, touch targets, loading, empty, error, and offline states in proportion to the change.
- Preserve the deployment target of iOS 18.5 or later. Keep iOS 26 features availability-gated.
- Do not claim a manual flow passed unless it was actually exercised.

## Supabase and data safety

- Use additive, forward-only migrations. Never edit a migration that has already been applied remotely; correct it with a new migration.
- Every new table must have RLS enabled, explicit least-privilege grants, owner-aware policies, indexes for expected access paths, and contract tests.
- Keep `SECURITY DEFINER` functions narrowly scoped with an empty `search_path`; expose caller-bound public wrappers instead of granting private helpers to clients.
- Prefer authenticated, idempotent RPCs or Edge Functions for privileged writes. Retries must not create duplicate records.
- Preserve private-note isolation at the draft, model, payload, database, query, Feed, sharing, notification, analytics, and export layers.
- Never send captions, private notes, photos, tokens, credentials, or unrelated sensory text to drink parsing.
- Never expose secrets in code, commits, logs, diagnostics, screenshots, test fixtures, or tool output.
- Run migration-integrity, RLS, grants, ownership, RPC, retry, and privacy contract tests for relevant database changes.
- Apply remote migrations or deploy Edge Functions only with user authorization and record what was applied.

## Releases and stable baselines

- A release must come from reviewed and validated `main`, never directly from a feature branch.
- Before replacing a substantially divergent baseline, create a recoverable backup branch or tag and verify the final tree matches the tested candidate.
- Use semantic version tags such as `v0.5.1`, targeted at the final `main` merge commit.
- Verify the tag commit, marketing version, build, tests, migration state, and release notes before publishing.
- Release notes must summarize user-visible changes, validation, migrations or external configuration, known limitations, and rollback information.
- After release, keep the daily Xcode checkout on `main` and create all new work from the updated `origin/main`.

## Communication and judgment

- Lead with outcomes, surface risks early, and keep progress updates concise and evidence-based.
- Use reasonable judgment instead of blocking an entire phase on negligible outliers. Document residual risks and continue when the core experience is healthy.
- Ask before destructive actions, public social test posts, account changes, paid services, production deployments, merges, tags, or releases.
- Do not claim completion while required work remains. Clearly distinguish implemented, verified, deferred, and externally blocked work.
