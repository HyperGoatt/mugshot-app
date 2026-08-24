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
| Likes, comments, mentions, reactions and tags | Supabase social rows/RPCs | Optimistic UI only | Reconcile to server result; stale account responses are discarded |
| Friends, blocks, reports and enforcement | Supabase caller-bound RPCs | Presentation cache | Privacy and block checks fail closed |
| Saved cafes and cafe lists | `user_cafe_states` and cafe-list RPCs | Guest saved state and merge queue | Preserve explicit user intent until merged or dismissed |
| Activity and unread count | `activity_events` through caller-bound RPCs | Current page and pending route | Push failure never removes Activity history |
| Push preferences and device ownership | Versioned preference/device RPCs; v3 badge capability defaults false | Installation ID, last token hint, uncertainty flag | Register only for the exact authenticated account; malformed capability data disables remote registration |
| Nearby reminders | iOS notification/location state | Region/cooldown store | Independent of remote Activity delivery |
| Analytics | PostHog project | SDK queue | No private content or product identifiers |

## Compatibility behavior

The client uses versioned RPCs and treats missing functions as compatibility
states, not empty data. Existing Activity code retains a hardened legacy read
fallback. The backend now advertises additive `push_badge_sync` support while
retaining v2 device registration and delivery revalidation; the client-side
capability read remains the next implementation stage.

## Current migration boundary

The repository migration head is
`20260824171405_expire_pre_schedule_activity_backlog.sql`. The complete head
passed a data-less disposable replay, all 54 remote SQL contracts, and focused
hermetic cutover coverage. Local and live histories are aligned at all 126
migrations, worker version 6 and the minute schedule are active, and the
additive `push_badge_sync` capability is live. Client capability adoption
follows the order in
[the Supabase release workflow](SUPABASE_RELEASE_WORKFLOW.md).

## Non-negotiable invariants

- Never mix guest or previous-account state into a signed-in remote write.
- Never treat demo content, cached counts, or local search results as Supabase
  truth.
- Never remove a protected draft or pending submission before remote success.
- Never trust a client-supplied account ID when Auth can supply the caller.
- Never make push availability a requirement for viewing in-app Activity.
