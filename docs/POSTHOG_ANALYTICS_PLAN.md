---
document_type: living
status: current
last_verified: 2026-08-24
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
| Notifications | `notification_education_viewed`, `notification_permission_completed`, `push_registration_completed`, `notification_preference_changed`, `activity_opened`, `notification_route_completed` | coarse permission/result/category/source values only; never tokens, account/social/content IDs, notification text, or deep links |

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
