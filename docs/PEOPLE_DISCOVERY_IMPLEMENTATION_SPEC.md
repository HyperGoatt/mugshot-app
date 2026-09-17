---
document_type: living
status: current
last_verified: 2026-09-17
---

# People discovery implementation spec

## Status and scope

Approved scope: algorithm-first People discovery plus private contact invitations,
profile links/QR, invitation recovery, first-week prompting, and useful search
dead ends. The Option 1 redesign and `people_v2` migration are implemented and
locally verified in current source. The additive `people_v2` migration is
production-configured and verified; the redesigned client has passed Simulator
visual QA but has not changed TestFlight.

Documentation impact: product behavior, architecture/data ownership, Supabase
contracts, privacy/safety, and analytics. The implementation uses Tier 3 local
verification plus Tier 4 backend and consolidated runtime gates under
[Verification policy](VERIFICATION_POLICY.md). Local results and rollout state
are recorded in current living status documents rather than inferred here.

Goal: help a tester find a known person and form a reciprocal friendship without
having to remember their Mugshot username. Preserve the independent journal
experience and existing request/accept relationship model.

| Required capability | Concrete delivery |
| --- | --- |
| Contacts | One-person native Messages invitation; the phone number remains device-local |
| 1. Profile links and QR | Visible Share my profile / My QR actions and system Camera-compatible QR |
| 2. Mutual-friend suggestions | Explainable, dismissible, privacy-filtered suggestions |
| 3. Contextual suggestions | Viewer-authorized shared posts, lists, and explicit invitation destinations |
| 4. Invite completion | Web/install/auth handoff with durable pending destination and recoverable code |
| 5. First-week prompt | Optional prompt after first successfully published Mugshot |
| 6. Search dead ends | Useful retry, Contacts, and invitation actions instead of an empty screen |

## Existing foundation and gaps

The legacy `PeopleHubView.swift` remains available for source compatibility, while
Feed and Profile now present `PeopleDiscoveryHubView.swift`. The new hub composes
requests, sent requests, friends, contextual/mutual/interaction suggestions,
private contact invitations, profile link/QR sharing, invite creation/link
resolution, and actionable
search dead ends. `PeopleDiscoveryService.swift` owns versioned RPC and Edge
contracts; `FriendInviteRouter.swift` preserves a bounded pending route through
installation/authentication handoff. The existing friendship graph, block rules,
profile projection and `SocialDiscoveryService` response path remain authoritative.
`FriendsDiscoverabilitySettingsView` now saves the three versioned preferences
described here and rolls failed optimistic changes back to the server result.

These observations are source evidence, not a new runtime audit. Discovery uses
the current publication contract: some explicitly published Friends content can
appear on a public profile. Friendship does not redefine those publication rules.
Private content, private taste evidence, and background location never create
suggestions. Existing share links retain their existing authority and revocation.

## Information architecture and screens

Reuse Mugshot typography, colors, avatar, status-card, Mugsy empty-state and
button components. Do not introduce another bottom navigation tab. People opens
as the existing sheet with a navigation stack; preserve the originating screen
when dismissed. Use a visible Find friends action in Feed and Profile; the
Friends Feed empty state makes this the primary action. Keep the toolbar shortcut.

### P1 — People hub

Title: Find your people. Persistent search field: Name, @username, or profile link.
When present, Friend requests is the first section and offers inline Accept and
Decline. Then show Invite contacts (“Send a private invite”), Share profile, and
My QR. Suggested for you is a horizontal card rail with a visible next-card peek,
one explanation, Add, profile navigation, and dismiss. Friends and Sent remain
vertical lists below. There is no normal invite-code field in the hub.

Suggested contains at most ten initial cards and a paginated Show more action.
Each card has avatar, display name, username, one permitted explanation, Add
friend, and a dismiss control. Tapping identity opens the existing profile.
Accessibility labels distinguish Add friend for each person. Friends offers
local filtering plus server pagination; do not silently cap the full list at 50.

First-time/zero-graph state: Mugsy, “Your coffee people are out there,” followed by
Contacts and Share my profile. Never fill this state with arbitrary strangers.
Established accounts retain the top actions in a compact row. Requests remain
visible even when suggestions fail.

### P2 — Search

Debounce typing by 250 ms; cancel old work and reject late responses using a
query generation and account scope. Strip one leading @ for handle searches;
normalize case/whitespace; support full name and surname tokens. Parse supported
Mugshot profile URLs as routes, including aliases, rather than fuzzy search text.
Reject foreign hosts and never fetch arbitrary pasted URLs. Exact username
matches precede name matches and fuzzy matches; mutuals break otherwise equal
matches. Keep direct name search independent of suggestion opt-in.

Results use the same actionable person row. Load 20 per page with opaque cursors.
No results: “No match yet. Try their name or @username.” Actions: Choose from
Contacts and Invite a friend. Network failure uses Retry and retains the query;
it must not claim nobody matched. Clearing search restores the hub scroll state.

### P3 — Private contact invitation

Show the disclosure below before opening `CNContactPickerViewController`. Enable
only contacts with a phone number and allow exactly one selection. The chosen
name and number remain transient on device; neither is sent to Supabase,
analytics, or the suggestion algorithm. Mugshot creates only a revocable invite
link, then pre-fills the native Messages composer with that one recipient. The
user must tap Send. Cancellation causes no upload, message, or error. This is
not phone-number account matching, SMS authentication, or background contact
sync, and it incurs no Mugshot SMS-provider cost.

### P4 — Share profile and My QR

Reuse the current profile share hub and canonical profile URL. Add a lightweight
share-link action without requiring image generation. My QR renders that same
canonical HTTPS URL on device with name, @username, readable URL, Share, and Copy
link. A system Camera scan opens the existing profile route; no in-app camera
permission is needed for this release. QR never encodes email, phone, a friendship
grant, or a private-content capability. Expired/unavailable profiles use the
existing unavailable destination with a People action. Announce Copy completion
and expose the textual URL for VoiceOver; QR is never the only route.

### P5 — Invitation landing and return

Profile links continue to work as profile links. A distinct Invite a friend
action creates a revocable, expiring invitation URL `/invite/{token}` and a
recoverable code. It identifies the inviter and grants no content or friendship.
Installed app: resolve, authenticate if needed, then show inviter profile with
Send friend request. New installation: landing page shows inviter's permitted
identity, distribution-appropriate install button, Open Mugshot, and invite code.
During TestFlight use the configured beta enrollment destination; do not promise
App Store availability or bypass external tester eligibility.

Normal Universal Links do not guarantee post-install attribution. The supported
recovery is reopening the original invitation after install. No fingerprinting,
automatic clipboard reads, or third-party deferred-link SDK is required. Preserve
an opened pending route through
sign-in/profile setup and app relaunch for up to seven days or token expiry,
whichever comes first. Bind it to the initiating account when known; clear it on
sign-out/account change. A new account can explicitly reopen the original link.

Resolve before showing identity and recheck before mutation. Self-invite opens
own profile; friends show Already friends; outgoing shows Request sent; incoming
shows Accept request. Invalid, expired, revoked, blocked, or unavailable destinations
give a generic unavailable message. Retryable transport errors have Retry.
The user explicitly sends or accepts a request; opening a link never does so.

### P6 — First-week prompt and contextual entry points

After the first successful non-Private publication, queue a dismissible card for
the next Feed visit, outside the publication/share confirmation. For accounts
less than seven days old with zero confirmed friends, show “Find your coffee
people” with Contacts, Share my profile, and Not now. Show at most once per
account; recording a dismissal is durable across devices. Existing testers with
zero friends receive the permanent hub/empty-state actions, not a forced onboarding
replay. Failed or Private saves do not trigger the card. Never block logging.

Expose Add friend on authorized participant profiles in shared Mugshots and
accepted collaborative lists. A contextual suggestion requires an actual shared
object the viewer can currently read, an eligible candidate, and discoverability
consent. Receiving a public post link alone does not prove a personal relationship
and does not populate a persistent suggestion. It can offer the author's profile
as an explicit action on the viewed post. A direct profile/invite link always
resolves through its own permissions.

### P7 — Friends and discoverability settings

Real controls replace informational labels: Let people find me by email remains
an optional legacy capability, while People suggestions and Show mutual-friend
reasons default on when no preference row exists. Explicit opt-outs remain
authoritative. Contact invitations and account discoverability are independent;
settings never request address-book access.

## Shared state contract

| State | Required behavior |
| --- | --- |
| Initial/loading | Stable layout, labeled progress, no zero-result flash |
| Partial error | Keep independently successful requests/friends sections; section retry |
| Empty | Offer Contacts, Share profile, and invite-code entry |
| Offline | Cached permitted connection data may be shown as stale; disable mutations; no contact upload queue |
| Add pending/success/failure | Disable duplicate tap; server-confirmed Sent; retry preserves person and source |
| Request race | Refetch authoritative state on conflict; no accidental reciprocal auto-accept |
| Incoming | Accept and Decline inline with per-row pending/error state |
| Suggestion dismissed | Hide immediately, undo for five seconds, persist suppression for 90 days |
| Block/delete/suspension | Remove person and relevant cached reasons; server rechecks every read/write |
| Account switch | Cancel tasks and clear results, identifiers, routes and optimistic state |
| Contact picker canceled | Return unchanged; no zero-match or failure analytics |
| Match unavailable | Explain service error, retry or invite; never misclassify as no match |
| Expanded Contacts denied/restricted | Continue with picker/link/code; Settings link only when appropriate |
| Accessibility | Dynamic Type wrapping, 44-point targets, explicit row actions, no color-only states |

## Backend and data ownership

All names below are proposed additive versioned contracts. Confirm migration
ordering and existing return types before implementation. Continue using the
existing friendship/block/moderation authority; do not create a second social graph.

### Tables and lifecycle

| Proposed storage | Data and access | Retention |
| --- | --- | --- |
| `private.discovery_identifiers` | user_id, kind, server-keyed HMAC digest, key_version, verified_at; unique active kind/digest; service-only access | Until opt-out, identifier change or deletion |
| `private.discovery_preferences` | actor-owned email_discoverable, suggestions_enabled, mutual_explanations_enabled, consent_version/time | Account lifetime; off immediately suppresses reads |
| `private.discovery_suppressions` | viewer/candidate pair and expires_at; access only via actor-bound RPC | 90 days; delete with either account |
| `private.friend_invites` | owner, token/code digests, created/expires/revoked timestamps; no recipient address | 14-day validity; delete within 30 days after expiry/revocation |
| `private.friend_discovery_state` | account prompt_consumed_at, first_friend_at, bounded source enum | Account lifetime; included in account deletion |
| Existing request metadata or private attribution sidecar | request_id, source enum, request creation time; no contact/link payload | Until request lifecycle ends plus 30 days for aggregate processing |

Reuse Auth's verified current email on explicit opt-in; never read raw Auth
identifiers from the client or expose them in public profile projections. For
Apple relay users, initially explain limited matchability and offer profile
sharing. A later optional additional email must complete verification without
replacing login identity. Phone matching requires a separate OTP-backed verified
identifier flow, ownership/reassignment handling and an abuse budget; do not
enable it merely because a number is present in a contact.

Normalize email with the same canonicalization as verified identity enrollment;
trim whitespace and normalize case consistently with Mugshot Auth. Do not strip
plus aliases or provider-specific dots. Future phone matching uses validated
international E.164 numbers with explicit country resolution.

### Legacy email matching contract

The following contract remains documented for deployed-client compatibility,
but the current People hub does not call it. The visible Contacts action is the
device-local invitation flow in P3. Keep the capability disabled unless a later
product decision explicitly restores email matching.

`POST /functions/v1/match-selected-contacts-v1` requires a valid authenticated
session and explicit consent_version. Body: random per-operation item keys and
email arrays, at most 50 items/200 unique addresses/32 KB. Response:
`{items:[{item_key,matches:[PersonSummary]}],has_more:false}`. No emails, digests,
phone numbers, hidden-account counts, or match reasons containing identifiers
are returned. Request-scoped item keys map results to device-local selections.

The Edge Function transiently receives selected raw addresses over TLS, normalizes
them and computes a keyed HMAC using a server secret. It looks up only opted-in,
verified, currently visible accounts. The secret and identifier table are never
client accessible. A plain SHA hash of an address/number is not anonymization.
This design protects stored identifiers but does not hide submitted addresses
from the matching service. Do not claim end-to-end private matching.

Never log request bodies, identifiers, hashes or item keys in analytics, tracing,
crash breadcrumbs or error responses. Persist only bounded abuse counters and
aggregate outcomes; raw submitted addresses exist only for the request lifetime.
Discard local selected identifiers/results on leaving the flow, backgrounding,
sign-out or account change. Refresh requires selecting again. Initial account
limits: 10 match calls/hour and 1,000 addresses/day, with additional service/IP
abuse controls; return 429 and Retry-After without partial results. Limits are
configurable and cannot make dictionary enumeration impossible; review before
rollout, monitor abuse, and keep a server kill switch.

### RPC and route contracts

| Contract | Inputs | Output and invariants |
| --- | --- | --- |
| `get_people_hub_v1` | page_size <= 20 | Independent initial request/friend/suggestion arrays plus typed per-section partial errors |
| `search_people_v2` | query <= 100 chars, rank/score/username/id cursor, limit <= 20 | PersonSummary page; normalized handle/name search; deterministic keyset pagination |
| `get_people_suggestions_v1` | limit <= 20 | PersonSummary + one coarse reason and ranking version; no raw private evidence |
| `dismiss_people_suggestion_v1` | candidate_id, undo boolean | actor-owned 90-day suppression; idempotent |
| `set_discovery_preferences_v1` | booleans, consent_version, expected_version | authoritative versioned preference result; opt-out deletes matching digest atomically |
| `match-selected-contacts-v1` `enroll_email` action | consent_version | derives verified current Auth email server-side; returns status only |
| `create_friend_invite_v1` | request_nonce | invite URL, code, expires_at; same nonce returns same invitation |
| `revoke_friend_invite_v1` | invite_id | owner-only, idempotent |
| Public invitation resolver | token | minimal currently permitted inviter identity and install/open actions; no friend graph or hidden content |
| `resolve_friend_invite_v1` | token or code | authenticated authoritative destination and relationship state |
| `consume_people_prompt_v1` | shown/dismissed/opened | atomic once-per-account claim; does not mark consumption on failed rendering |
| Friendship adapter v2 | target/request ID, source enum, request_nonce, optional validated invite_id | authoritative request row; wraps existing authorization and notifications |

PersonSummary: id, display_name, username, avatar reference via current permitted
media mechanism, friendship_state, permitted mutual_count, reason enum, next
action. Profile content remains fetched by existing authorized profile contracts.
No arbitrary actor UUID input; derive actor from auth.uid(). Suggestions/search
filter blocks in either direction, suspended/deleted accounts, self, ineligible
identities and suppressed candidates. Discovery opt-out removes recommendation
eligibility; it does not disable direct username search or shared profile links.
Explain this distinction in settings.

Reuse existing send/respond/cancel/remove semantics, notifications, and request
uniqueness. New adapters add attribution and retry idempotency without breaking
old clients. Retries return the existing state; opposite pending requests surface
Accept, never silently accept. Rate-limit search, invite resolution and friend
requests independently of contact matching. Start with 30 request creations/day,
20 invite creations/day and 10 failed code resolutions/15 minutes/account or
anonymous abuse bucket; tune in beta with aggregated evidence.

Invite tokens use at least 128 bits of cryptographic pseudorandom output; recovery
codes use 12 unambiguous base32 characters, grouped for readability. Derive both
with distinct HMAC domains from a server-generated random seed and a versioned
server secret. Store the seed, key version, owner-bound request nonce, and lookup
digests, not the bearer tokens; this lets an authorized creation retry reproduce
the same response. Retain the signing key through invite expiry and resolve code
collisions before committing creation. Never use sequential codes.
Public resolver responses reveal no target for blocked/unavailable accounts
when authenticated; anonymous landing content is limited to existing public
identity and cannot prove block status. Disable caching of invitation pages,
use noindex and no-referrer, and exclude tokens/codes from logs and analytics.
Expire after 14 days. Each recipient can use an invitation to start their own
request; owner revocation stops future resolution but does not remove friendships.
The four new backend capabilities are created disabled. QA must deploy and verify
the migration and both Edge Functions before enabling each capability explicitly.

### Suggestion ranking

Persistent suggestions rank eligible shared-Mugshot candidates, then mutual
friends, people who recently interacted with the viewer’s visible Mugshots,
people whose visible Mugshots the viewer recently interacted with, and shared
cafe-list members. Break ties by permitted mutual count, recency, and stable
account ID. Show one coarse reason. A tagged
account is not sufficient evidence unless the viewer can read the shared object.
Recheck membership, visibility and consent on each page; do not retain reasons
after access loss. Never reveal list titles or post content in reasons.

Count only confirmed reciprocal mutual edges visible to the viewer. If the viewer
turns mutual explanations off, use “Someone you may know” and return no mutual
count. Do not expose named intermediates. Ranking is deterministic, version
`people_v2`, with no popularity, private taste, address-book reverse inference,
phone lookup, or location ranking.

## Ready-to-use privacy and product copy

| Surface | Copy |
| --- | --- |
| Contacts education | Choose one person and Mugshot will prepare a private friend invitation in Messages. Their contact information stays on this iPhone and is never uploaded to Mugshot. Nothing is sent until you tap Send. |
| Invitation review | Their phone number stays on this iPhone. Mugshot only creates the invitation link; Messages sends it after you tap Send. |
| Email discovery toggle | Let people who have my verified email find my Mugshot profile. Your email will not appear on your profile. |
| Suggestions toggle | Allow Mugshot to suggest your profile to people with mutual friends or shared activity they can already see. Turning this off does not hide your username or shared profile link. |
| Mutual explanation toggle | Allow your friendships to contribute to mutual-friend counts shown to people who can see your profile. Your name will not be included in the explanation. |
| Invitation preview | Join me on Mugshot so we can share our coffee finds: [invitation link] |
| First-week card | Find your coffee people. See what your friends are sipping and share your next find. |
| Invite destination | [Name] invited you to connect on Mugshot. Send a friend request to connect. |
| Invite unavailable | This invitation is unavailable. Ask your friend for a new link, or find them by @username. |
| Discovery off | Contact discovery is off. Your discovery email match has been removed. |
| Optional expanded access purpose string | Mugshot uses the contacts you allow to help you find friends by verified email. You choose who to invite. |

Full contact sync and phone-number account matching are out of scope. Do not add
either without a separately approved privacy, abuse, verification, and cost plan.

## Analytics contract

Extend the typed allowlisted event model in `MugshotAnalytics.swift` and follow
[PostHog analytics plan](POSTHOG_ANALYTICS_PLAN.md). Existing consent, identity,
sign-out reset and collection controls apply. No autocapture or replay on Contacts,
search, invitation, or discovery preferences screens.

Common event properties: existing analytics/app/build/platform fields plus source
enum (`feed`, `friends_empty`, `profile`, `people_hub`, `search_empty`, `first_week`,
`shared_post`, `shared_list`, `profile_link`, `invite_link`, `invite_code`, `contacts`).
Counts use buckets `0`, `1`, `2_5`, `6_20`, `21_plus`; durations capped at 3,600
seconds. Reasons/errors are enums, never server strings. Do not send contact names,
addresses, hashes, phone numbers, search text, profile URLs, tokens/codes, target
user IDs, relationship IDs, object IDs, contact keys, or lists of social edges.
The established signed-in analytics distinct ID remains the only account identity.

| Event | Trigger | Additional permitted properties |
| --- | --- | --- |
| `people_hub_opened` | Visible once per navigation | segment |
| `people_search_completed` | Latest settled query response only | result_bucket, outcome, duration_seconds |
| `people_contacts_started` | Education shown | mode=invite |
| `people_contacts_selection_completed` | Confirmed picker selection | selected_bucket, usable_bucket |
| `people_suggestion_opened` | Explicit candidate tap | reason, ranking_version |
| `people_suggestion_dismissed` | Dismiss/undo | reason, action, ranking_version |
| `people_friend_request_completed` | Server acknowledges mutation | action=send/accept/decline/cancel, outcome, error_code |
| `people_friendship_created` | Server-confirmed reciprocal transition | request_source, time_to_accept_bucket |
| `people_first_friend_reached` | First server-confirmed friendship per account | account_age_days capped at 365, request_source |
| `people_profile_share_opened` | QR/link/artwork action | format=qr/link/artwork |
| `people_invite_created` | Server creates unique invitation | outcome, error_code |
| `people_invite_resolved` | Explicit invitation/code resolution | outcome, auth_state, recovery=link/code |
| `people_invite_handoff_completed` | System composer/share completion callback | outcome=completed/canceled/failed |
| `people_prompt_viewed` / `people_prompt_dismissed` | Durable eligible display/dismissal | action where applicable |
| `people_discovery_preference_changed` | Server acknowledgment | preference enum, enabled, outcome |

Handoff completion proves neither delivery nor installation. Record accepted
invitation conversion only when server request attribution connects a resolved
invitation to a confirmed friendship; keep the join internal and publish aggregate
rates, not invitation IDs. A generic profile share has no reliable recipient
conversion denominator. Do not invent one from share-sheet callbacks.

The server stores request attribution and first-friend state transactionally with
the authoritative acceptance, keyed by request and account. This durable state is
the deduplicated source for aggregate conversion and future server-delivered
`people_friendship_created` / `people_first_friend_reached` events; clients do not
guess either event from retries. Respect analytics consent whenever that state is
delivered to analytics. Declined collection does not block friendship or overwrite
the operational state.

Primary metric: accounts created in a cohort that gain their first reciprocal
friend within seven days / all new eligible accounts in that cohort. Exclude
staff/synthetic accounts, wait seven days for cohort maturity, and report sample
size. Consent-limited PostHog coverage must be labeled, not presented as all users.
Use privacy-reviewed aggregate operational counts if an all-account denominator
is required. Compare first-friend time, request acceptance, selected-address
match rate, invitation-to-friend conversion, empty-search rate and failure rate.
Guardrails: blocks/reports after new connections, request limits, privacy failures,
and notification-category opt-outs. Ship no growth target or statistical claim
without a baseline; alpha results remain directional at small sample sizes.

## Implementation sequence and acceptance gates

| Phase | Work and dependency | Exit evidence |
| --- | --- | --- |
| A — Hub and search | Extract reusable person row/state model; visible entry points; P1/P2; inline request actions; pagination; first-week state contract | Empty and populated fixtures, query-race tests, request-state tests, accessibility checklist |
| B — Sharing and invite completion | P4/P5, canonical QR, minimal link share, invite contracts/landing, pending-route persistence and recovery code | Installed/signed-out/new-install recovery matrix; token expiry/revocation and blocks enforced |
| C — Private contact invitation | P3/P7, one-contact picker, local phone handling, native Messages handoff, privacy copy | Cancellation, no-upload proof, recipient isolation, unavailable-Messages state |
| D — Suggestions and activation | `people_v2` mutual/context/interaction ranking with opt-outs, suppression, P6 prompt, durable attribution, typed analytics | Visibility-loss, default/opt-out, prompt deduplication, attribution and event-schema tests |
| E — Phone matching | Out of scope; requires a separately approved verification, privacy, abuse, reassignment, and cost plan | Separate product decision |

All six non-contact solutions and private contact invitations are in A–D. E is
not planned. Implement each phase behind independent server capabilities and
client flags. Never label the invitation picker as account matching. Deploy additive backend contracts
through the repository release workflow before enabling dependent clients. Keep
old search/friendship/profile clients compatible. Rollback disables each new
entry point and endpoint; do not drop existing friendships or invalidate current
profile links. Opt-out and deletion cleanup remain available during rollback.

Suggested implementation units: PeopleHubView, reusable PeopleRow, account-scoped
PeopleHubModel; PeopleSearchService; SelectedContactsCoordinator;
PeopleDiscoveryService; ProfileQRView; FriendInviteCoordinator; existing route
coordinator; discoverability settings; typed analytics events. Split presentation
from request/matching state so deterministic tests can cover races and cleanup.
Use the existing share renderer, safe media resolver, safety service and auth
lifecycle rather than parallel implementations.

## Verification and definition of done

Before runtime acceptance, run scoped diff review, documentation checks,
`scripts/verify-no-simulator.sh full-static`, focused pure state/route tests and
hermetic SQL/Edge Function contract tests. Do not seed or mutate real contacts,
real accounts or the linked production project for tests. Synthetic fixtures must
cover opted-out/missing/unverified/relay identifiers; duplicate addresses;
blocked/self/suspended candidates; mutual opt-outs; revoked list membership;
Private posts; concurrent request/accept/block; token/code brute-force limits;
expired codes; identifier change/deletion; pagination changes; stale network
responses and account switching. Assert sensitive fields are absent from events,
errors and all enabled logging layers.

One consolidated runtime session then covers P1–P7, large text/VoiceOver, picker
cancel and selection, denied/restricted/limited access where supported, installed
and cold-start invite routes, sign-in/setup continuation, share composer cancel,
offline retry, QR scan destination, and the actual beta install recovery journey.
Record hardware-only claims separately and follow owner promotion requirements.
No TestFlight archive/upload/assignment is authorized by this plan.

Source delivery is complete when A–D are implemented, backend contracts pass
isolated authorization tests, the available local runtime matrix passes at its
declared level, all six alternate discovery paths are wired, operational
deletion/opt-out is enforced, and measured analytics payloads contain only allowed
fields. Production rollout additionally requires disposable-QA cross-account
acceptance and the broader backend-dependent runtime matrix above. Record source,
local, production, physical and TestFlight states separately in living status.

## Sources and platform constraints

- [Apple contact picker](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller): selection without full address-book permission.
- [Apple contact-store access](https://developer.apple.com/documentation/contacts/accessing-the-contact-store): limited/full/denied access and management UI.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): data minimization and individually initiated invitations; no Select All bulk outreach.
- [Apple App Privacy details](https://developer.apple.com/app-store/app-privacy-details/): contact information includes hashed email and phone data.

Platform references were consulted during the discovery discussion. Confirm current
SDK signatures and platform/distribution requirements during implementation.
