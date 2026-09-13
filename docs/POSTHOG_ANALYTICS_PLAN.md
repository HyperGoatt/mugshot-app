---
document_type: living
status: current
last_verified: 2026-09-13
---

# Mugshot PostHog analytics plan

## Principles

- Optimize for completed memories, repeat reflection, friend connection, and successful expression.
- Do not optimize for time spent, notification opens alone, purchases, caffeine consumption, or streaks.
- Use the existing PostHog project and reuse the wizard-created analytics assets where they match this taxonomy.
- Keep product analytics within PostHog's free product-analytics allowance. Session replay, surveys, experiments, and broad UI autocapture are out of scope.
- Never send captions, journal or raw-note content, cafe/place identifiers, names, email addresses, search text, coordinates, photo data, social identifiers, auth tokens, or raw error messages.

## Event taxonomy

All custom event names use lower-case `object_verb` spelling. Common properties are `analytics_version`, `platform`, `app_version`, `app_build`, `build_configuration`, and `is_authenticated`.

| Area | Events | Controlled properties |
| --- | --- | --- |
| Acquisition and identity | `authentication_completed`, `authentication_failed`, `account_signed_out` | `auth_flow`, `auth_method`, `error_code` |
| Onboarding | `capture_preferences_viewed`, `capture_preferences_completed`, `capture_preferences_skipped` | non-sensitive completion booleans only |
| Navigation and retention | `screen_viewed` plus PostHog application lifecycle events | `screen_name`, `source` |
| Core journey | `sip_composer_opened`, `sip_context_selected`, `sip_step_viewed`, `sip_publish_attempted`, `sip_published` | `entry_point`, `is_draft_resume`, `context`, `step`, `visibility`, `capture_mode`, bounded counts, content-presence booleans, `duration_seconds`, `is_remote`, `was_recovery` |
| Drop-off and recovery | `sip_publish_blocked`, `sip_publish_failed`, `sip_draft_saved`, `sip_recovery_resumed`, `sip_publication_deduplicated` | `reason`, `error_code`, `recovery_state`, the core-journey snapshot, `duration_seconds` |
| Engagement | `cafe_state_changed`, `sip_liked`, `comment_added` | `surface`, `state`, `action` |
| Sharing | `share_hub_viewed`, `share_format_selected`, `share_template_selected`, `share_photo_layout_selected`, `share_destination_tapped`, `share_handoff_opened`, `share_handoff_failed`, `system_share_completed`, `share_hub_dismissed` | `format`, `destination`, `template`, `photo_layout`, `visibility`, `has_public_link`; no shared content or identifiers |
| Notifications | `notification_education_viewed`, `notification_permission_result`, `notification_registration_result`, `notification_preference_changed`, `activity_opened`, `activity_route_result` | coarse permission/result/category/source/environment values only; never tokens, account/social/content IDs, notification text, or deep links |

Anonymous installs use the SDK-generated random distinct ID. After authentication, Mugshot calls `identify` with the Supabase UUID so PostHog links the pre-authentication journey to the account. Sign-out calls `reset` so subsequent activity on a shared device receives a new anonymous identity. No account profile fields are attached.

## Dashboard structure

### Mugshot — Product Journey

- Sign-up to first published sip funnel
- Sip publication funnel
- Sip publication outcomes
- Authentication outcomes
- Median publish duration by context

### Mugshot — Engagement & Retention

- Weekly active sip publishers
- Weekly active users by screen
- Weekly retention after first publication
- Weekly repeat-publication retention
- Sip publisher lifecycle
- Sharing conversion funnel
- Cafe state changes, likes, comments, and completed shares

### Mugshot — Analytics Quality

- Core event volume with previous-period comparison
- Missing required properties on `sip_published`
- Authentication, publication, and sharing failures
- Recovery and publication-deduplication signals
- Push registration failure rate and notification route failures by build/environment

### Mugshot — Notification tolerance

- Education-to-permission outcome
- Push master/category opt-out trends
- Activity opens split by in-app and notification entry source
- Registration outcomes split by sandbox and production

Notification opens are diagnostic, never the primary success metric. Reconsider
the all-friends default if roughly 20% disable all push or tester feedback
repeatedly describes it as noisy.

## Cohorts and alerts

Dynamic cohorts:

- Mugshot — Activated publishers: at least one `sip_published` within the available one-year window.
- Mugshot — Repeat publishers: at least two `sip_published` events in 30 days.
- Mugshot — Recovery users: at least one `sip_recovery_resumed` event in 30 days.

The five free-tier alert slots are used for:

- Published sip volume anomalies.
- Sip publication failure anomalies.
- Missing `analytics_version`.
- Missing `entry_point`.
- Any prevented duplicate sip publication.

The existing wizard dashboard is aligned with the canonical names instead of creating a duplicate basics dashboard. All saved insights exclude the existing Internal / Test users cohort.

## Sprint 1 account erasure follow-up

Read-only project metadata on September 13 identified project `521217` in US
Cloud. Its public project token matches the native configuration; no person or
event records were read. The existing SDK identifies accounts by Supabase UUID,
so resetting the SDK locally is not evidence that server-side analytics was
removed.

`supabase/functions/delete-account/analytics.ts` implements an isolated erasure
adapter, with four focused synthetic Deno tests passing. It verifies the exact
account/person mapping, submits one person's events and recordings for cleanup,
and treats provider acceptance as submitted rather than complete. Verification
requires a matching completed receipt created after the current submission and
a valid verification timestamp. Requests use fixed regional API hosts, bounded
responses, no redirects, and coarse errors without provider payloads.

Migration `20260913065006_sprint1_analytics_erasure_queue.sql` captures the
account identifier when the deletion job is created. The scheduled deletion
worker claims it only after identity deletion is confirmed. It persists the
provider target before submission, checks receipts before retrying uncertain
submissions, and rejects a provider person linked to another existing account.
A durable provider-acceptance bit prevents repeated deletion submissions while
completion is pending. Unacknowledged submissions still check the saved receipt
before retrying. Five-minute leases fence concurrent workers. Thirty unsuccessful attempts move
the item to `attention`; unresolved identifiers are retained for support and
must not be silently purged. Verified event receipts clear those identifiers.

The native deletion response distinguishes pending, verified event cleanup,
attention, and unconfirmed status independently of Mugshot and Apple cleanup.
The provider's event receipt is not proof of recording deletion. Recording
absence or separate recording-erasure evidence remains an activation gate;
reviewed native source disables session replay. On September 13, the project
recording switch was found enabled, switched off, and verified disabled after
reload. The default last-30-days list found no matches, but its active-duration
filter means this is not complete recording-absence evidence.

Activation requires server-only `POSTHOG_ERASURE_PROJECT_ID=521217`,
`POSTHOG_ERASURE_PERSONAL_API_KEY` with project-scoped `person:write` (which
also permits the required person lookup), and
`POSTHOG_ERASURE_ENABLED=true`. The worker rejects other projects/regions and
uses claim limit zero when disabled, preserving queued attempts. The approved
personal key was created on September 13 and saved locally with
mode 0600 outside Git. Its UI scope is only `person:write` for this project; a
random synthetic UUID lookup returned HTTP 200 with zero results. The key is
not deployed, the local enable flag remains false, and no live analytics
deletion has run.
Native queued-event runtime acceptance, support recovery for attention items,
recording evidence, and disposable-account acceptance remain open.

References: [Persons API](https://posthog.com/docs/api/persons) and
[data deletion](https://posthog.com/docs/privacy/data-storage#data-deletion).

### Native queued-event finding

The resolved PostHog SDK source explicitly preserves its current event/replay/log
queues in `reset()`. `close()` stops queues but does not erase their disk files;
`optOut()` stops capture/integrations rather than proving queue disposal. Native
startup configures the SDK before account recovery, so queued events from a
previous run could be sent before a pending deletion is recovered. A deletion
integration must gate startup and dispose the deleted account's queued events,
including in-flight/relaunch handling. Do not substitute `flush()` as evidence:
provider documentation describes it as best-effort and asynchronous.

This finding is addressed in source by the startup/deletion boundary below;
consolidated runtime and provider acceptance remain required.
The PostHog credential setup tab currently redirects to sign-in. No credential
was created or provider person record changed during this inspection.
See [iOS configuration](https://posthog.com/docs/libraries/ios/configuration).

### Native deletion startup boundary

Source now starts analytics only after the account status is signed in/out and
Keychain deletion recovery is clear. App initialization no longer configures the
SDK. Immediately before the real deletion POST, an atomic local marker is
written and the SDK is closed. Capture, identification, reset and configuration
share a lifecycle lock; this process cannot restart analytics after suspension,
even if the network result is ambiguous or a different account signs in.

On a later process launch, marked telemetry is deleted before SDK setup. The
cleanup targets only the configured project's PostHog directory and legacy
`posthog.*` files under this app's Application Support bundle directory. It
preserves journal/media/Auth files and other project directories. It rejects
path traversal and a symbolic-link base. A cleanup failure leaves analytics
off and the marker retained for retry. Signed-out startup also discards the old
SDK identity/queue. Same-process analytics delivery remains paused after a
failed deletion attempt and resumes on a later eligible launch; account features
continue working. The disk cleanup is deferred to that launch so callbacks from
a stopped SDK cannot repopulate a newly started SDK's queue.

The layout was inspected against pinned PostHog iOS `3.68.4`, revision
`fe6193716ed54b0430b2d5370b746885fd442787`. Dependency upgrades must recheck
that layout. The SDK uses an ephemeral URL session with 15-second request and
30-second resource timeouts. Backend analytics erasure starts no sooner than
five minutes after identity deletion. These bounds and the quiet interval
reduce in-flight overlap; they are not proof of provider ingestion completion
or protection against events from older clients on another device.

Local evidence: the standalone Swift file-cleanup check passes durable restart,
namespace isolation, legacy cleanup, marker clearing, signed-out disposal and
invalid-path handling. The facade test covers same-process suppression and a
fresh-process restart, and is queued for the consolidated native test run.
Offline deletion/relaunch, failures, account switching, bounded outstanding
uploads and multi-device/older-client behavior remain acceptance gates.

Standalone check:
`swiftc testMugshot/Services/Analytics/AnalyticsDeletionQuarantine.swift qa/check-analytics-quarantine.swift -o /tmp/mugshot-analytics-quarantine-check`
then `/tmp/mugshot-analytics-quarantine-check`.
