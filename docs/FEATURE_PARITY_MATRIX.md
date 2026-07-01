# Feature Parity Matrix

Date: 2026-06-30

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
| Feed data | Supabase visits/users/cafes/photos/likes/comments | Local seeded visits | Partial | P0 | Replace with backend read after Add Visit write |
| Discover feed | Greeting, nearby cafes, friends recent, Spin for a Spot | None | Missing | P3 | Defer |
| Visit card media | Photo carousel from `visit_photos` | Local photo display/placeholder | Partial | P0 | Needs Storage upload first |
| Likes | Supabase likes, notifications | Local like count/state | Partial | P1 | Add after backend feed |
| Comments | Supabase comments, replies, mentions, notifications | Local comments | Partial | P1 | Add after backend feed |
| Share/postcard | Share/postcard behavior on detail | None | Missing | P3 | Defer |
| Add Visit base flow | Real Supabase insert | Local `DataManager` save | Partial | P0 | First core write journey |
| Cafe search in Add | Web search/selected cafe, likely Google-backed | MapKit local search | Partial | P0 | Use simplest cafe identity path first |
| Location types | Cafe, Home, Travel, Other | Cafe-oriented local flow | Partial | P2 | Defer non-cafe contexts unless needed |
| Craft Sip | Setup, brew method, equipment, home/travel context | None | Missing | P3 | Defer from first beta unless product says otherwise |
| Drink taxonomy | Coffee, Matcha, Hojicha, Tea, Chai, Other, subtypes | Local drink/custom drink support | Partial | P1 | Align model before remote writes |
| Rating templates | System/user templates, smart matching, weighted scoring | Local customizable template | Partial | P1 | Start with existing ratings JSON, then templates |
| Private notes | Supported | Supported locally | Partial | P0 | Include in first Supabase write if schema supports it |
| Visibility | Private, Friends, Public/Everyone | Local visibility | Partial | P0 | Include in first Supabase write |
| Visit photo upload | Supabase Storage `visit-photos` and `visit_photos` rows | Local disk cache only | Missing | P0 | Implement immediately after base Add Visit |
| Map | Google map with Supabase cafe state and friend overlays | MapKit local map and pins | Partial | P1 | Keep MapKit; back it with Supabase cafe state |
| Nearby/place search | Supabase Edge Functions for search/nearby | `MKLocalSearch` | Partial | P2 | Decide Apple-first vs Google-first before expanding |
| Saved cafes | `user_cafe_states` favorites/wishlist/history | Local favorite/want-to-try flags | Partial | P1 | Persist after feed/add basics |
| Cafe detail | Photos, aggregate stats, friends, popular drinks, activity | Local stats/recent visits | Partial | P1 | Back with Supabase after saved/cafe state |
| Visit detail | Remote visit, photos, likes, comments, replies, mentions | Local visit detail with edit/delete | Partial | P1 | Back with Supabase after feed |
| User profile | Public profile by username/UUID | Current local profile only | Missing | P2 | Add after friends/feed are useful |
| Friends | Friends list, requests, search, mutual friends | None | Missing | P2 | Defer until core social graph can be tested |
| Notifications | In-app notifications for social actions | None | Missing | P2 | Defer until likes/comments/friends are remote |
| Push notifications | Backend functions/device tokens exist in audit | None | Missing | P3 | Defer until security cleanup is done |
| Settings | Settings index plus notification/privacy/about | None | Missing | P2 | Add a lean settings screen for account/logout first |
| Legal pages | Company, Privacy, Terms | None | Missing | P1 | Add before external beta/TestFlight |
| Feedback board | Supabase-backed feedback board | None | Missing | P3 | Defer or keep web-only |
| Analytics events | `analytics_events` usage in web flows | None | Missing | P3 | Defer until product events are finalized |
| PWA/offline | Vite PWA service worker | Native app not PWA | Defer | P3 | Not directly relevant |
| Tests | Web has test tooling but package lock drift | iOS skeleton tests only | Partial | P1 | Add focused tests around auth/profile/write mapping |

## Top 10 Parity Gaps

1. iOS Add Visit does not write real `visits` rows.
2. iOS photos are local-only and do not upload to Storage or `visit_photos`.
3. iOS Feed is local/demo instead of Supabase-backed.
4. iOS Saved/Favorites/Wishlist state is local-only instead of `user_cafe_states`.
5. iOS profile edit and profile media are missing.
6. iOS visit and cafe detail screens are local-only.
7. Friends and notifications are absent in iOS.
8. Legal/settings/account-management surfaces are absent or not verified for iOS.
9. Supabase security backlog must be resolved or quarantined before real visit writes.
10. Core product tests are still mostly skeleton launch tests.

## Web Features To Copy Carefully

- Auth and profile bootstrap polish/setup-profile completion.
- Remote Add Visit write path.
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
