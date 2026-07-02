# Feature Parity Matrix

Date: 2026-06-30

Update: 2026-07-02 Phase 2B/2D real-visit work quarantined the unsafe visit trigger path, wired signed-in no-photo and photo-backed Add Visit, and simulator-validated Profile Recent, Feed, Saved, Map, Cafe Detail, and remote Visit Detail after relaunch. Remaining gaps are hardening and later product surfaces, not the core personal journal loop.

Purpose: compare the existing web app reference against the current native iOS app so Phase 2 work can be staged deliberately. This matrix is evidence for planning only. It is not a request to implement everything.

Status key:

- `Matched`: native iOS has the same meaningful behavior.
- `Partial`: native iOS has the surface or local version, but not the full web/backend behavior.
- `Missing`: native iOS does not have the feature.
- `Defer`: not recommended for first private beta.

Priority key:

- `P0`: required before credible private beta.
- `P1`: important beta polish or core parity.
- `P2`: useful after the core loop is stable.
- `P3`: defer until later.

## Matrix

| Surface | Web reference | Current iOS | iOS status | Priority | Beta decision |
| --- | --- | --- | --- | --- | --- |
| App shell | Bottom navigation across Feed, Map, Add, Saved, Profile | Bottom tabs Map, Feed, Add, Saved, Profile | Partial | P0 | Keep native shell; order can remain native for now |
| Welcome | Marketing/welcome and auth entry | Local onboarding/welcome | Partial | P0 | Rework only as needed for auth handoff |
| Auth | Supabase email/password sign up, sign in, sign out, session restore | Native email/password auth, sign-out service, session restore | Partial | P0 | Phase 2A implemented; polish auth/setup later |
| Profile bootstrap | Creates/loads `public.users`; setup profile route | Loads/bootstraps current `public.users` and maps it to local `User` | Partial | P0 | Phase 2A implemented; edit/setup remains |
| Edit profile | Display name, username, bio, favorite drink, location, social links, avatar/banner | Basic remote edit sheet for text fields; no avatar/banner upload | Partial | P1 | Text fields implemented; media waits for storage safety |
| Avatar upload | Supabase Storage `profile-media` | Local avatar initial/path only | Missing | P1 | Add after profile edit basics |
| Banner upload | Supabase Storage `profile-media` | None | Missing | P2 | Defer unless easy with profile media |
| Feed scopes | Friends, Everyone, Discover | Friends, Everyone | Partial | P0 for backend feed, P2 for Discover | Start with public/current-user feed, add friends later |
| Feed data | Supabase visits/users/cafes/photos/likes/comments | Signed-in Feed reads real Supabase visits/users/cafes for Friends and Everyone; cards open read-only remote detail with photos, likes, and comments | Partial | P0 | Continue from read-only feed/detail to write-backed Add Visit and social actions |
| Discover feed | Greeting, nearby cafes, friends recent, Spin for a Spot | None | Missing | P3 | Defer |
| Visit card media | Photo carousel from `visit_photos` | Local photos render; remote Feed/Profile cards and detail render existing Supabase photo URLs when present | Partial | P0 | Needs native Storage upload for new visits |
| Likes | Supabase likes, notifications | Local like state plus read-only remote detail like count/current-user state | Partial | P1 | Add remote like mutation after write safety |
| Comments | Supabase comments, replies, mentions, notifications | Local comments plus read-only remote detail comments with authors | Partial | P1 | Add remote comment mutation after write safety |
| Share/postcard | Share/postcard behavior on detail | None | Missing | P3 | Defer |
| Add Visit base flow | Real Supabase insert with cafe upsert, drink subtype, ratings, visibility, optional notes/photos, success toast, and Feed navigation | Signed-in Add Visit creates/reuses cafes, inserts real visits, optionally uploads photos, and opens remote detail; signed-out mode remains local | Partial | P0 | Core write journey is live; keep hardening personal-loop edges |
| Cafe search in Add | Web search/selected cafe, likely Google-backed | MapKit local search | Partial | P0 | Use simplest cafe identity path first |
| Location types | Cafe, Home, Travel, Other | Cafe-oriented local flow | Partial | P2 | Defer non-cafe contexts unless needed |
| Craft Sip | Setup, brew method, equipment, home/travel context | None | Missing | P3 | Defer from first beta unless product says otherwise |
| Drink taxonomy | Coffee, Matcha, Hojicha, Tea, Chai, Other, subtypes | Local drink/custom drink support | Partial | P1 | Align model before remote writes |
| Rating templates | System/user templates, smart matching, weighted scoring | Local customizable template | Partial | P1 | Start with existing ratings JSON, then templates |
| Private notes | Supported | Supported locally | Partial | P0 | Include in first Supabase write if schema supports it |
| Visibility | Private, Friends, Public/Everyone | Local visibility | Partial | P0 | Include in first Supabase write |
| Visit photo upload | Supabase Storage `visit-photos` and `visit_photos` rows | Signed-in Add Visit uses a direct native `PhotosPicker`, uploads selected photos to Storage, and writes `visit_photos`; signed-out mode remains local | Partial | P0 | Picker selection and backend path were smoked with a real uploaded image; partial-failure cleanup can wait unless beta testing exposes it |
| Map | Google map with Supabase cafe state and friend overlays | MapKit map syncs signed-in Favorite/Want-to-Try state and writes toggles through `user_cafe_states` | Partial | P1 | Keep MapKit; add remote cafe aggregates later |
| Nearby/place search | Supabase Edge Functions for search/nearby | `MKLocalSearch` | Partial | P2 | Decide Apple-first vs Google-first before expanding |
| Saved cafes | `user_cafe_states` favorites/wishlist/history | Signed-in Saved syncs `user_cafe_states`; Favorite/Want-to-Try writes persist after relaunch; local/demo mode remains for signed-out users | Partial | P1 | Add richer aggregates and cafe create/reuse tests |
| Cafe detail | Photos, aggregate stats, friends, popular drinks, activity | Favorite/Want-to-Try writes are remote-backed; signed-in remote cafes load the current user's remote recent visits and open remote Visit Detail | Partial | P1 | Add richer Supabase cafe aggregates after personal loop |
| Visit detail | Remote visit, photos, likes, comments, replies, mentions | Local detail for local visits; remote Feed/Profile cards open read-only Supabase detail with photos, ratings, likes, comments, and owner-only notes | Partial | P1 | Add remote edit/delete and social mutations after writes are safe |
| Profile recent visits | Recent visits from Supabase user/cafe/visit rows | Real Supabase recent visit cards for signed-in user; local stats remain local/demo | Partial | P0 | Implemented as first safe real-data surface while visit writes are blocked |
| User profile | Public profile by username/UUID | Current local profile only | Missing | P2 | Add after friends/feed are useful |
| Friends | Friends list, requests, search, mutual friends | None | Missing | P2 | Defer until core social graph can be tested |
| Notifications | In-app notifications for social actions | None | Missing | P2 | Defer until likes/comments/friends are remote |
| Push notifications | Backend functions/device tokens exist in audit | None | Missing | P3 | Defer until security cleanup is done |
| Settings | Settings index plus notification/privacy/about | None | Missing | P2 | Add a lean settings screen for account/logout first |
| Legal pages | Company, Privacy, Terms | None | Missing | P1 | Add before external beta/TestFlight |
| Feedback board | Supabase-backed feedback board | None | Missing | P3 | Defer or keep web-only |
| Analytics events | `analytics_events` usage in web flows | None | Missing | P3 | Defer until product events are finalized |
| PWA/offline | Vite PWA service worker | Native app not PWA | Defer | P3 | Not directly relevant |
| Tests | Web has test tooling but package lock drift | iOS has launch tests plus lightweight remote DTO mapping tests | Partial | P1 | Add focused tests around auth/profile/write mapping |

## Top 10 Parity Gaps

1. iOS still lacks remote like/comment mutations and edit/delete permissions for remote visits.
2. Photo upload is wired and manually picker-smoked; remaining photo hardening is cleanup for uploaded-but-unattached objects and finer per-photo progress/errors.
3. Cafe detail still lacks popular drinks, friend context, and broader remote aggregate stats.
4. Profile media is missing; profile text edit exists.
5. Friends and notifications are absent in iOS.
6. Legal/settings/account-management surfaces are absent or not verified for iOS.
7. Full friend-graph semantics still need multi-account validation.
8. Rating templates remain local/simple instead of system-template backed.
9. Supabase security backlog remains before social/push expansion.
10. Core product tests are still mostly focused mapping/launch tests.

## Web Features To Copy Carefully

- Auth and profile bootstrap polish/setup-profile completion.
- Remote Add Visit write path.
- Web Add Visit order: cafe upsert/select, optional photo upload, `visits` insert, `visit_photos` insert, query invalidation, Feed navigation.
- Visit photo storage model.
- Feed data joins and visibility logic.
- Saved/favorite/wishlist persistence.
- Visit detail and cafe detail data contracts.

## Web Features To Avoid Copying Blindly

- Missing `/edit-visit/:id` route.
- Package/dependency state.
- Public config hard-coded in source.
- Logged-out route behavior that causes maximum update-depth warnings.
- Settings controls that look UI-only until backend persistence is verified.
- Full Google Maps implementation if native MapKit can provide the beta experience.
