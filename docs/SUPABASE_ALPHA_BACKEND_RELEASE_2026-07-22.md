# Supabase alpha backend release — 2026-07-22

## Result

MugShot's live Supabase project and iOS client now share one versioned backend
contract. Nineteen forward migrations were deployed through
`20260722221500_enable_alpha_ephemera_scheduler`; `delete-account` v4 and
`deliver-activity` v1 are active. No live database reset, seed, test fixture,
account deletion, or destructive content action was performed.

## Data-preservation evidence

A completed live physical backup preceded deployment. The following live counts
were identical before and after the release:

| Data | Rows/objects |
| --- | ---: |
| Users | 5 |
| Cafes | 40 |
| Visits | 16 |
| Visit photos | 47 |
| Likes | 11 |
| Comments | 10 |
| Notifications | 14 |
| Friends | 6 |
| Friend requests | 6 |
| Saved cafe states | 6 |
| Private notes | 5 |
| Drink analyses | 16 |
| Taste signals | 21 |
| Cafe lists | 1 |
| Storage objects | 108 |

Deterministic whole-row fingerprints remained identical for every table whose
schema did not change. Fingerprints changed only where reviewed migrations added
columns/defaults or performed a specified backfill (`users`, `visits`, `comments`,
and `cafe_lists`); row counts did not change.

## Verification evidence

- A data-less QA branch was reset from the production migration history and
  reached a healthy state.
- Local-only migrations: 0. Remote-only migrations: 0. Live head:
  `20260722221500`. Recorded migrations: 104.
- Complete remote SQL/RLS/RPC suite after clean reset: 44 passed, 0 failed.
- Scheduler follow-up contracts after the final migration: 3 passed, 0 failed.
- Repository `full-static`: 11 passed, 0 failed, 1 optional `pglast` parser check
  skipped because the tool was not installed.
- Edge Function unit checks: `delete-account` 10 passed;
  `deliver-activity` 6 passed.
- Generic Debug app/test compile passed. No Simulator was booted or launched.
- Live capability RPC reports all 12 alpha capabilities available at contract
  version 1; the anonymous Data API request returned HTTP 200. Auth health also
  returned HTTP 200 with the project's publishable key.
- The recipe/collaboration cleanup scheduler is active every 15 minutes. Both
  bounded cleanup functions executed successfully inside a rolled-back live
  validation transaction, with zero expired work present. Its first real
  scheduled run succeeded at 2026-07-22 22:00 UTC.
- Post-deploy logs contained one successful Edge status request and no post-deploy
  API, Auth, Storage, or Edge errors. No tester app traffic occurred after deploy,
  so the final signed-client acceptance pass remains separate evidence.

## Advisor review

The release introduced no unknown advisor class. Live security advisors report:
14 intentionally sealed RLS tables with no policies, one historical `pg_net`
schema warning, four anonymous caller-bound SECURITY DEFINER RPC warnings, 121
authenticated SECURITY DEFINER RPC warnings, and leaked-password protection
disabled. The public/authorized RPC warnings are reviewed boundaries covered by
the contract suite; they are not blanket-waived and must be re-reviewed when a
grant or function body changes.

Performance advisors report 32 legacy `auth_rls_initplan` warnings plus
informational unindexed-foreign-key/unused-index notices. These are a measured
optimization backlog, not evidence of release failure.

## Intentionally gated after this release

- APNs delivery: missing Apple credentials and durable invocation schedule.
- New account-deletion initiation: missing live-session hook, fresh-session signed
  client proof, durable drain schedule, and disposable-account acceptance.
- Apple/Google provider activation and real email confirmation/reset acceptance:
  external provider credentials and controlled inboxes are required.
- Supabase leaked-password protection: still disabled and should be enabled before
  alpha widens.

In-app activity, independent recipe visibility, Taste Passport audience controls,
shared MugShot consent, ordinary tagging without consent, social safety,
moderation transparency, and collaborative cafe-list contracts are live.
