---
document_type: living
status: current
last_verified: 2026-08-24
---

# Real data flow status

## Authority model

Mugshot uses remote truth for durable signed-in product state and scoped local
truth for guest use, recovery, caching, and preferences. A remote success is the
commit point; local state may optimistically present or recover a command but
must not overrule an authoritative remote result.

| Domain | Authoritative source | Local role | Failure behavior |
| --- | --- | --- | --- |
| Authentication | Supabase Auth | Callback queue and last-known presentation | Fail closed for account-bound operations |
| Profile and social identity | `public.users` and projection RPCs | Account-scoped cache | Never expose another account's cached identity |
| Visits, drinks, ratings and captions | Supabase visit schema/RPCs | Guest records, drafts and pending publication | Preserve draft/outbox until remote completion is proven |
| Visit and profile media | Supabase Storage plus metadata rows | Preview/cache and upload recovery | Clean partial uploads through bounded recovery paths |
| Home recipes and coffee library | Home Workbench tables/RPC projections | Draft/template cache | Remote owner projection wins after save |
| Feed, Journal and profiles | Viewer-specific Supabase projections | Rendering cache | Keep the last valid view and show an actionable error |
| Likes, comments, mentions, reactions and tags | `likes.reaction_kind`, caller-bound reaction/comment/tag RPCs, and historical `visit_reactions` compatibility rows | Optimistic UI only | Reconcile to server result; a missing additive reaction RPC falls back only to binary Like; stale account responses are discarded |
| Friends, blocks, reports and enforcement | Supabase caller-bound RPCs | Presentation cache | Privacy and block checks fail closed |
| Saved cafes and cafe lists | `user_cafe_states` and cafe-list RPCs | Guest saved state and merge queue | Preserve explicit user intent until merged or dismissed |
| Activity and unread count | `activity_events` through caller-bound RPCs | Current page, pending route and app-icon presentation | Push failure never removes Activity history; successful refresh/read actions apply the authoritative unread badge |
| Push preferences and device ownership | Versioned preference/device RPCs plus `get_backend_capabilities_v1`; v3 badge capability defaults false | Installation ID, last token hint, uncertainty flag | Register v3 only for the exact authenticated account and typed build environment; malformed capability data disables remote registration |
| Nearby reminders | Shared iOS notification authorization plus local location state | Region/cooldown store | Independent of APNs delivery while still triggering one safe registration reconciliation after permission changes |
| Analytics | PostHog project | SDK queue | No private content or product identifiers |

## Compatibility behavior

The client uses versioned RPCs and treats missing functions as compatibility
states, not empty data. Existing Activity code retains a hardened legacy read
fallback. The backend now advertises additive `push_badge_sync` support while
retaining v2 device registration and delivery revalidation. Source build 5 now
loads and validates that contract at account activation, registers badge support
only through v3, and reports missing layers without disabling Activity.

## Current migration boundary

The repository migration head is now
`20260825030917_post_reactions.sql`. That additive migration and its iOS model
are implemented and covered by a hermetic local contract, but are not deployed.
Live production remains aligned through
`20260824171405_expire_pre_schedule_activity_backlog.sql` at 126 migrations;
worker version 6, the minute schedule, and `push_badge_sync` are active there.
The reaction migration still requires disposable replay, the complete remote
contract suite, impact review, and an explicitly authorized live release.
Client capability adoption follows the order in
[the Supabase release workflow](SUPABASE_RELEASE_WORKFLOW.md).

The expressive contract is detailed in
[Post reaction contract](POST_REACTION_CONTRACT.md). Historical coffee-specific
`visit_reactions` data remains read-only compatibility data and receives no
speculative backfill.

## Non-negotiable invariants

- Never mix guest or previous-account state into a signed-in remote write.
- Never treat demo content, cached counts, or local search results as Supabase
  truth.
- Never remove a protected draft or pending submission before remote success.
- Never trust a client-supplied account ID when Auth can supply the caller.
- Never make push availability a requirement for viewing in-app Activity.
