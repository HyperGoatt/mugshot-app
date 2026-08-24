---
document_type: historical
status: superseded
superseded_by: CURRENT_PRODUCT_STATUS.md
---

> Historical snapshot. Implementation-status claims below describe the audit date, not the current app. Use [Current product status](CURRENT_PRODUCT_STATUS.md) and [Repository map](REPO_MAP.md).

# Mugshot Codebase Audit

Date: 2026-07-02

## Executive Summary

The active native iOS app is no longer just a local prototype. The core signed-in personal loop is working enough for narrow private-beta hardening:

1. Sign in or restore a Supabase session.
2. Bootstrap and edit the current user's `public.users` profile.
3. Create a real Supabase visit from Add Visit.
4. Optionally upload visit photos to Supabase Storage.
5. Reopen the saved visit from Profile Recent, Feed, and remote Visit Detail after relaunch.
6. Save Favorite and Want-to-Try cafe state through `user_cafe_states`.

The app is still not a full social product. Friends, notifications, remote like/comment mutations, public user profiles, settings, privacy/legal screens, profile media, and broader cafe discovery are either missing or only read/demo/local. The next work should be beta hardening around the core loop, not a broad feature expansion.

## Tools And Context Inspected

- Available Codex skills/plugins for iOS, Supabase, GitHub publishing, frontend/product workflows, documents, PDFs, spreadsheets, and security.
- XcodeBuildMCP simulator tools for build, launch, screenshot, and tests.
- Local Git state, local branches, remote branches, remotes, latest commits, and dirty working tree.
- Current repo docs under `docs/`.
- Native SwiftUI app code under `testMugshot/`.
- Supabase service layer under `testMugshot/Services/Supabase/`.
- Tests under `testMugshotTests/` and `testMugshotUITests/`.
- Asset catalogs and sibling/local Mugshot repositories and snapshots.

## Source Of Truth

- Active repo: `/Users/joe.rosso/Desktop/Projects/testMugshot`
- Xcode project: `testMugshot.xcodeproj`
- Scheme: `testMugshot`
- Remote: `https://github.com/HyperGoatt/mugshot-app.git`
- Current branch at audit start: `codex/phase-2b-real-add-visit`
- Local latest commit at audit start: `49350ed Add auth and profile foundation tests`
- Remote `origin/main` after fetch: `2f2da62 Merge pull request #4 from HyperGoatt/Auth`

Recommendation: keep this Desktop repo/branch as the working source of truth for the Supabase-safe rebuild, but do not push it directly to `main` because remote `main` has newer unrelated history. Push a clean backup branch instead.

## Branches And Repositories Found

Local branches in active repo:

- `codex/phase-2b-real-add-visit`
- `main`

Remote branches:

- `origin/main`
- `origin/Auth`
- `origin/development`
- `origin/codex/fix-email-verification-auth-flow`
- `origin/claude/audit-github-repo-opsQ3`

Sibling/local repos and references:

- `/Users/joe.rosso/mugshot-app`: Git repo on `development`, older and less useful as base.
- `/Users/joe.rosso/Documents/mugshot-app`: Git repo on `Auth`, product-richer, contains Mugsy assets and older native screens.
- `/Users/joe.rosso/Documents/mugshot-app-main`: not a Git repo, useful snapshot only.
- `/Users/joe.rosso/mugshot-PWA`: web/PWA reference repo, separate product reference.
- `/Users/joe.rosso/Documents/mugshot-app*/fun time`: Mugsy PNG source folders.

## App Structure

- `testMugshot/testMugshotApp.swift`: app entry, creates shared `DataManager`, shows `MugshotRootView`.
- `Views/Auth/`: Supabase auth gate, sign in/up UI, missing-config state.
- `Views/MainTabView.swift`: Map, Feed, Add, Saved, Profile tabs.
- `Views/Add/`: real signed-in Add Visit and local signed-out fallback.
- `Views/Feed/`: remote Feed and remote Visit Detail; old local detail remains for local visits.
- `Views/Map/`: MapKit shell, search, pins, cafe bottom sheet, remote cafe-state sync.
- `Views/Saved/`: saved/favorites/want-to-try, cafe detail, remote cafe recent visits.
- `Views/Profile/`: current user profile, remote edit sheet, remote recent visits, local stats/top lists.
- `Services/Supabase/`: auth, profile, visit, cafe, cafe-state, photo upload, config/client provider.
- `Services/DataManager.swift`: local `UserDefaults` store and local shell data.

## What Is Working

- App builds and launches on iPhone 17 Pro simulator.
- Tests pass: 20 passed, 0 failed.
- Supabase config loading rejects obvious secret/service-role keys.
- Auth/session restore path exists and has prior simulator validation.
- Profile bootstrap and text edit are real Supabase-backed.
- Add Visit creates a real Supabase visit for signed-in users.
- Visit photos can upload to the `visit-photos` bucket and attach to a visit.
- Profile Recent reads real visits for the signed-in user.
- Feed reads real remote visits for Friends/Everyone scopes.
- Remote Visit Detail reads real visit, photos, likes count, comments, author, cafe, ratings, and owner notes.
- Saved/Map/Cafe Detail read and write Favorite/Want-to-Try state through Supabase for signed-in users.
- Local/demo fallback still keeps signed-out/local surfaces usable.

## What Is Broken Or Incomplete

- Friends UI/graph is absent in this active app.
- Notifications are absent and should remain blocked until the old trigger/function path is rebuilt safely.
- Remote like/comment mutations are missing; remote detail is read-only for social actions.
- Remote visit edit/delete is missing.
- Settings, privacy, legal, about, account deletion, and data export are missing.
- Profile avatar/banner upload is missing.
- Public user profiles are missing.
- Map discovery is Apple Maps/local shell first; no robust backend discovery or friend overlays.
- Cafe detail lacks broad aggregate stats, popular drinks, friend context, and global activity.
- Rating templates are local rather than Supabase system/user template backed.
- Seed/demo data still mixes with remote shell data, especially stats and non-Recent profile tabs.
- Accessibility and Dynamic Type have not been fully audited.

## Security And Config Hygiene

- `Config/SupabaseConfig.local.xcconfig` exists locally and is ignored by Git.
- The committed config file contains placeholders only.
- No service role key should ever be used in the iOS app.
- The code rejects keys with obvious secret/service-role markers.
- Manual Supabase SQL files explicitly warn not to paste secrets.
- The historical visit notification trigger with embedded bearer-token risk is documented as quarantined; do not restart notifications from that path.

## Validation

Fresh validation on 2026-07-02:

- Build and launch: passed via XcodeBuildMCP on iPhone 17 Pro, iOS 26.2.
- Tests: passed, 20 passed, 0 failed.
- Screenshot: captured Map launch state with bottom tabs, location-off state, search, and pins visible.
- Live auth/profile smoke: not re-entered during this pass because local credentials are intentionally ignored; prior docs record signed-in simulator smoke passes.

## Recommendation

Back up this state to a clean branch, then continue with a narrow beta-hardening sequence. Do not merge old native branches wholesale. Harvest Mugsy assets and old product surfaces selectively after the core loop remains stable.
