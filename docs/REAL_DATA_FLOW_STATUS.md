---
document_type: living
status: current
last_verified: 2026-08-26
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
| Profile and social identity | `public.users`, sealed `profile_favorite_spots` / `profile_tagged_post_hides` / `profile_visibility_preferences`, and v4 profile projection/list RPCs | Account-scoped rendering cache plus DEBUG-only design fixture | Default to Friends plus Everyone only when the owner preference permits it; preference-off is Everyone-only and Private always fails closed |
| Visits, drinks, ratings and captions | Supabase visit schema/RPCs | Guest records, drafts and pending publication | Preserve draft/outbox until remote completion is proven |
| Visit and profile media | Supabase Storage plus metadata rows | Preview/cache and upload recovery | Resolve HTTP and durable `mugshot-storage://` values through the viewer-authorized remote pipeline, including Profile-share artwork; clean partial uploads through bounded recovery paths |
| Home recipes and coffee library | Home Workbench tables/RPC projections | Draft/template cache | Remote owner projection wins after save |
| Feed, Journal and profiles | Viewer-specific Supabase projections | Rendering cache | Keep the last valid view and show an actionable error |
| Cafe identity and detail visit cards | `public.cafes` provider rows plus viewer-scoped Supabase visit queries and RLS | Conservative read-time stitch projection and local visit fallback only when no visible remote visit is returned | Query all equivalent cafe IDs, then render only self, friend, and Everyone visits the backend permits; never mutate cafe rows or synthesize remote visibility from local history |
| Likes, comments, mentions, reactions and tags | `likes.reaction_kind`, caller-bound reaction/comment/tag RPCs, and historical `visit_reactions` compatibility rows | Optimistic UI only | Reconcile to server result; a missing additive reaction RPC falls back only to binary Like; stale account responses are discarded |
| Friends, blocks, reports and enforcement | Supabase caller-bound RPCs | Presentation cache | Privacy and block checks fail closed |
| Saved cafes and cafe lists | `user_cafe_states` and cafe-list RPCs | Guest saved state and merge queue | Preserve explicit user intent until merged or dismissed |
| Activity and unread count | `activity_events` through caller-bound RPCs | Current page, pending route and app-icon presentation | Push failure never removes Activity history; successful refresh/read actions apply the authoritative unread badge |
| Push preferences and device ownership | Versioned preference/device RPCs plus `get_backend_capabilities_v1`; v3 badge capability defaults false | Installation ID, last token hint, uncertainty flag | Register v3 only for the exact authenticated account and typed build environment; malformed capability data disables remote registration |
| Nearby reminders | Shared iOS notification authorization plus local location state | Region/cooldown store | Independent of APNs delivery while still triggering one safe registration reconciliation after permission changes |
| Criterion setup preferences | Account- and criterion-scope-bound `UserDefaults` stores (`sip` plus the applicable environmental context) | Authoritative for pinned criterion names and preferred importance only | Never carry a prior visit's criterion score into a new sip; clear account-owned preferences on account deletion |
| Sip drafts | Account-scoped `SipDraftStore` metadata and local photo bundles | Authoritative until publish completion is proven | Central Add creates a new draft ID; Resume draft or Journal explicitly selects saved work, and unreadable bytes are preserved rather than deleted |
| Analytics | PostHog project | SDK queue | No private content or product identifiers |

## Compatibility behavior

The client uses versioned RPCs and treats missing functions as compatibility
states, not empty data. Existing Activity code retains a hardened legacy read
fallback. The backend now advertises additive `push_badge_sync` support while
retaining v2 device registration and delivery revalidation. Source build 5 now
loads and validates that contract at account activation, registers badge support
only through v3, and reports missing layers without disabling Activity.

Editorial Atlas reads prefer v4 profile and profile-publication list RPCs. During an
additive rollout, missing v4 reads fall back to older projections and then
apply an Everyone-only client filter to visible Mugshots; missing tagged and
Favorite Spot mutations do not invent local remote truth. Existing v3 profile,
highlight, and binary social contracts remain available to older clients, but
the new UI neither reads nor renders Profile Highlight. The new profile contract
defaults Friends-on-profile on, exposes only caller-bound preference writes,
and excludes Private from authored, cafe, map, tagged, and anonymous-link
projections regardless of preference.
Profile-share content consumes that same profile-published sip set, sorts it by
`created_at` descending with an ID tie-breaker, retains validated durable
private-Storage references, and resolves them only for the authenticated viewer
while rendering artwork. The signed URLs are ephemeral rendering inputs and are
not persisted into the profile or share-link contract.

Cafe provider aliases remain separate remote source rows until an explicitly
reviewed data repair is authorized. The iOS read projection stitches only an
exact normalized cafe name plus equivalent street address, or a same-name
location within 50 meters when an address is missing; matching street numbers
are required when two differently formatted non-empty addresses use the
coordinate fallback. Visit reads use the resulting ID set and continue to rely
on RLS for visibility.

## Current migration boundary

The repository migration head is now
`20260826143102_profile_editorial_atlas.sql`. It follows the additive reaction
migration in repository order. The profile migration is production-configured
and its expected tables/RPCs resolve in the connected project; the additive
reaction migration remains implemented and hermetically verified but undeployed.
Live production now contains 127 recorded migrations through the profile
contract, with the reaction migration still absent; worker version 6, the
minute schedule, and `push_badge_sync` remain active.
The reaction migration still requires disposable replay, the complete remote
contract suite, impact review, and an explicitly authorized live release.
The profile migration has completed production configuration; live account
behavior and replacement-TestFlight acceptance remain separate product gates.
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
