# Repo Branch Reconciliation

Date: 2026-07-02

## Decision

Use `/Users/joe.rosso/Desktop/Projects/testMugshot` as the active native iOS source of truth for the next Mugshot build sequence.

Do not push this branch directly to `main`. After a fresh fetch, remote `origin/main` is ahead of the local `main` pointer and contains older-but-broader `Auth` lineage work. The safest backup strategy is to push the current validated Desktop state to a dedicated backup/audit branch.

## Current Active Repo

- Path: `/Users/joe.rosso/Desktop/Projects/testMugshot`
- Project: `/Users/joe.rosso/Desktop/Projects/testMugshot/testMugshot.xcodeproj`
- Scheme: `testMugshot`
- Remote: `https://github.com/HyperGoatt/mugshot-app.git`
- Current branch at audit start: `codex/phase-2b-real-add-visit`
- Latest local commit at audit start: `49350ed Add auth and profile foundation tests`
- Local branches: `codex/phase-2b-real-add-visit`, `main`
- Remote branches after fetch: `origin/main`, `origin/Auth`, `origin/development`, `origin/codex/fix-email-verification-auth-flow`, `origin/claude/audit-github-repo-opsQ3`
- Remote default: `origin/HEAD -> origin/main`
- Fresh validation: build/run passed; tests passed 20/0.

## Branch Ambiguity

Local `main` and `codex/phase-2b-real-add-visit` both point at `49350ed`, while `origin/main` points at `2f2da62`.

That means direct `main` push is inappropriate without a deliberate reconciliation/merge plan. This audit should be preserved on a clean branch without force pushing, deleting branches, or overwriting remote work.

## Other Local Sources Found

### `/Users/joe.rosso/Documents/mugshot-app`

- Git repo.
- Remote: `https://github.com/HyperGoatt/mugshot-app.git`
- Branch: `Auth`
- Latest inspected commit: `bbf99ca craft sip`
- Contains richer native product work, Mugsy assets, Friends, Notifications, widgets, and older Supabase service patterns.
- Recommendation: use as selective harvest source only.

### `/Users/joe.rosso/Documents/mugshot-app-main`

- Not a Git repo.
- Contains similar older native snapshot and Mugsy assets.
- Recommendation: reference only, not source of truth.

### `/Users/joe.rosso/mugshot-app`

- Git repo.
- Remote: `https://github.com/HyperGoatt/mugshot-app.git`
- Branch: `development`
- Latest inspected commit: `fd6c7fb`.
- Older/experimental; not the base.

### `/Users/joe.rosso/mugshot-PWA`

- Web/PWA product reference.
- Separate remote: `https://github.com/HyperGoatt/mugshot-520470e9.git`
- Recommendation: use for product flow reference, not native code.

## What To Bring Over Later

Bring in small reviewed slices only:

- Mugsy asset image sets and empty-state patterns.
- Friends/Notifications UX references after backend safety is resolved.
- Useful design-system components if they match the current SwiftUI style.
- Cafe detail/feed/profile ideas that improve the core loop without old architecture baggage.

Do not bring over:

- Old `DataManager` wholesale.
- Old notification trigger/function assumptions.
- Widget targets/app group entitlements.
- Dirty workspace files.
- Migration/function files without a fresh security review.

## Recommended Backup Branch

Use a branch such as:

`codex/audit-roadmap-backup-2026-07-02`

This branch name makes the purpose explicit and avoids pretending the branch is ready to replace `main`.
