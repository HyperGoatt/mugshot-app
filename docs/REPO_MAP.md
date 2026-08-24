---
document_type: living
status: current
last_verified: 2026-08-24
---

# Repository map

## Repository and targets

This Desktop checkout is the active source of truth. It contains a SwiftUI iOS
app, unit and UI test targets, widgets, a share extension, Supabase migrations
and Edge Functions, hermetic PostgreSQL behavior tests, scripts, and product or
release evidence.

The app targets iOS 18.5 and pins Supabase Swift 2.54.1 and PostHog iOS 3.68.4
through the committed package resolution.

## App entry and shell

- `testMugshotApp.swift` configures analytics, local storage, system delegates,
  UI-test fixtures, and `MugshotRootView`.
- `MugshotRootView` owns auth callback intake, first-launch onboarding, session
  restore, profile completion, and transition into the app shell.
- `MainTabView` owns Map, Feed, composer, Saved, and Journal/Profile plus global
  sheets, routers, recovery coordinators, Activity, share/import commands, and
  scene lifecycle reconciliation.

## Product domains

| Domain | Primary responsibility |
| --- | --- |
| Auth/Profile | Identity, callbacks, session/account isolation and public profile projections |
| Composer/Visits | Cafe, Home and Elsewhere capture, drafts, uploads, publication, edit/delete and recovery |
| Home Workbench | Coffee library, recipes, brew plans/actuals, reuse and owner journal projection |
| Feed/Social | Viewer-scoped feed, detail, friends, likes, comments, mentions, reactions and tags |
| Map/Saved | Search, cafe identity, saved state, discovery and collaborative lists |
| Journal/Taste | Canonical history, reflections, Taste Passport and sensory projections |
| Safety/Ownership | Visibility, blocks, reports, enforcement, export, deletion and public links |
| Activity/Notifications | Activity events, preferences, device ownership, APNs delivery and deep links |
| System entry points | Widgets, share extension, universal links, local nearby reminders and pending commands |

## Data layers

`DataManager` remains the account-scoped local bridge for guest state, fallback
presentation, settings, fixtures, and recovery. Supabase services own signed-in
remote operations and enforce exact account checks before and after async work.
Viewer-specific RPC projections prevent raw-table access from becoming a privacy
shortcut.

See [Real data flow status](REAL_DATA_FLOW_STATUS.md) for the authority matrix.

## Backend

- `supabase/migrations/` is the forward-only schema source of truth.
- `supabase/functions/` contains pinned Deno Edge Functions for analysis,
  account deletion, Activity delivery, and public sharing.
- `supabase/tests/` contains SQL security and behavior contracts.
- `qa/pglite/` provides hermetic migration and lifecycle checks without a live
  Supabase connection.
- `scripts/verify-supabase-qa.sh` targets only a disposable QA branch and refuses
  production.

## Notification entry points

`NotificationDeviceCoordinator` owns iOS authorization and device RPCs;
`MugshotNotificationAppDelegate` owns APNs callbacks and presentation;
`ActivityService` and `ActivityCenterStore` own Activity data; and
`supabase/functions/deliver-activity` owns APNs transport and the additive
badge payload. V2/v3 device RPCs preserve client compatibility, while the
canonical Vault-backed `pg_cron` job owns one-minute worker invocation. Local
nearby cafe notifications share `UNUserNotificationCenter` but use a separate
route envelope.

## Verification

`scripts/verify-no-simulator.sh` provides fast, backend, and full-static modes.
The fast path validates diffs, spelling, documentation, conflicts, and migration
names. Backend adds Deno and hermetic PostgreSQL contracts. Full-static adds a
generic iOS compile without booting Simulator.

Simulator, connected-device, Release, and TestFlight checks are used only when
the risk tier or release gate requires them. See
[Verification policy](VERIFICATION_POLICY.md).
