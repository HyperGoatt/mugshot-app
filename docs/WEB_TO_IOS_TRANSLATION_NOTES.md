# Web To iOS Translation Notes

Date: 2026-06-30

Purpose: capture how to translate the web app reference into native SwiftUI work without copying web implementation details directly.

## Translation Rule

Use the web app for:

- Product intent.
- Data contracts.
- Query shape.
- Edge cases.
- Empty/error state expectations.

Do not use the web app for:

- Native component structure.
- Styling tokens.
- Navigation architecture.
- Map implementation details unless required by backend identity.
- Dependency choices that do not apply to SwiftUI.

## Current Native Boundaries

Existing local boundaries:

- `DataManager`: local app data and mutations.
- `PhotoCache`: local/disk photo storage.
- `MapSearchService`: MapKit search.
- `LocationManager`: CoreLocation.
- `TabCoordinator`: tab switching.

Recommended remote boundaries:

- `AuthService`: Supabase Auth session, sign in, sign up, sign out.
- `ProfileRepository`: `public.users` fetch/create/update.
- `VisitRepository`: visit create/read/detail mutations.
- `CafeRepository`: cafe fetch/search/state.
- `PhotoStorageService`: Storage upload and `visit_photos` records.
- `SocialRepository`: likes, comments, friends, notifications later.

Keep SwiftUI views thin. Views should call view models or repositories instead of constructing Supabase queries inline.

## Web Route To iOS Surface Mapping

| Web route | Native destination | Notes |
| --- | --- | --- |
| `/welcome` | `OnboardingView` plus auth entry | Keep native onboarding; add auth-aware state |
| `/auth` | New auth screen | Email/password first |
| `/setup-profile` | Onboarding/profile setup | Write to `public.users` |
| `/feed` | `FeedTabView` | Replace local visits gradually |
| `/map` | `MapTabView` | Keep MapKit unless Google identity is required |
| `/add` | `AddTabView` | Wire existing flow to Supabase |
| `/saved` | `SavedTabView` | Back with `user_cafe_states` |
| `/profile` | `ProfileTabView` | Current signed-in user |
| `/user/:userId` | Future public profile view | Defer until social profile browsing matters |
| `/visit/:id` | `VisitDetailView` | Back with remote detail |
| `/cafe/:id` | Cafe detail from Saved/Map/Add | Back with remote detail |
| `/friends` | Future Friends screen | Defer |
| `/notifications` | Future Notifications screen | Defer |
| `/settings` | Future Settings screen | Add lean account/legal first |
| `/feedback` | Optional beta feedback | Defer or use external feedback |
| `/company`, `/privacy`, `/terms` | Legal/about screens or web links | Needed before broad beta |

## Auth Translation

Phase 2A implementation note: iOS now has `AppAuthModel`, `AuthService`, `ProfileService`, and `MugshotRootView` for email/password auth, session restore, and `public.users` bootstrap.

Web source concepts:

- Supabase session.
- `useAuth`.
- `ProtectedRoute`.
- Profile bootstrap against `users`.

iOS translation:

- Keep using the app-level auth/session model added in Phase 2A.
- Restore session before deciding signed-out vs main shell.
- Do not block all public/local demo screens if the team wants preview mode, but make signed-out state explicit.
- Keep setup profile separate from sign-in success.

Native state decision:

```text
Launching -> Auth session check -> Signed out OR Needs profile setup OR Main app
```

## Profile Translation

Web profile fields include:

- Username.
- Display name.
- Bio.
- Favorite drink.
- Location.
- Instagram.
- Website.
- Avatar.
- Banner.

iOS first pass:

- Username.
- Display name.
- Location.
- Bio if already in schema.
- Avatar only after Storage policy is confirmed.

Do not add settings/profile controls that cannot persist.

## Add Visit Translation

Web Add Visit is broad. Native should start narrow:

Phase 2B web-flow extraction on 2026-07-01 confirmed the current web sequence:

1. Auth gate or login CTA.
2. Location type: Cafe, Home, Travel, Other.
3. Cafe path searches nearby/recent/results, upserts or reuses a cafe row, then selects it.
4. Craft Sip paths collect location/setup name, brew method, equipment, and visibility toggles.
5. Drink type: Coffee, Matcha, Hojicha, Tea, Chai, Other.
6. Coffee can include brew method; Other requires custom drink type.
7. Specific drink/subtype is required.
8. Photos are optional, up to 10.
9. Smart rating template chooses user preferred, then system match, then generic fallback.
10. Category ratings calculate overall score; quick overall rating is also allowed.
11. Caption and private notes are optional and capped at 200 characters.
12. Visibility maps to `private`, `friends`, or `everyone`.
13. Submit uploads photos first, inserts `visits`, inserts `visit_photos`, invalidates visit queries, shows success, and navigates to Feed.

Read-only Supabase inspection also confirmed system templates for Coffee, Matcha, Hojicha, Tea, Chai, and Other/General, plus coffee brew-method templates such as espresso, latte, cappuccino, pour over, drip, french press, cold brew, and Aeropress.

First native remote insert:

- `user_id`
- `cafe_id` or created/matched cafe
- drink type/subtype/custom drink
- caption
- private notes
- visibility
- ratings/category scores
- overall score

Safe read slice already implemented:

- Profile Recent reads signed-in user's real `visits` rows.
- Profile Recent fetches related `cafes` rows for display.
- Feed reads signed-in Friends and Everyone scopes from real `visits` rows.
- Feed fetches related `users` and `cafes` rows for card display.
- Feed and Profile Recent cards open read-only remote detail.
- Remote detail fetches related `visit_photos`, `likes`, and `comments`, plus comment authors.
- Remote detail renders existing Supabase photo URLs and owner-only private notes.
- Later slices now write `visits`, `cafes`, `visit_photos`, Storage objects, and `user_cafe_states` for signed-in personal-loop behavior. Notification and social mutation rows remain unwired.

After first insert:

- photo upload
- `visit_photos`
- selected poster/photo order if schema supports it

Later:

- Craft Sip context
- rating templates
- analytics events
- advanced drink taxonomy

## Feed Translation

Web feed fetches many related objects in separate queries. iOS should define native DTOs or domain models that avoid leaking raw Supabase row shape into views.

Recommended first feed scopes:

- My visits.
- Everyone/public visits.

Implemented first read slice:

- Friends and Everyone tabs now query Supabase for signed-in users.
- Cards show remote author, cafe or context, drink, score, caption, date, and visibility.
- Cards are accessible buttons that open read-only remote detail.
- Local feed data remains a signed-out fallback.

Delay:

- Full Friends semantics until `friends` and visibility are tested with multiple accounts.
- Discover until nearby search and friend activity are real.

## Map Translation

Web uses Google Maps. iOS already uses MapKit and should keep it unless the backend requires Google place ids for identity.

Needed decision:

- Apple-first: save MapKit result metadata and match/create cafes in Supabase.
- Google-first: call existing Edge Functions and map returned cafe/place records into MapKit pins.
- Hybrid: use MapKit UI but store Google place id when available.

For beta, prefer the smallest reliable cafe identity path over perfect place deduplication.

## Storage Translation

Web uses:

- `profile-media`
- `visit-photos`
- `visit_photos`

iOS needs:

- Compression size rules.
- Upload progress.
- Cancellation/error state.
- Clear bucket privacy decision.
- Row insert rollback strategy if upload or visit create fails.

Do not rely on local `PhotoCache` as the source of truth after a remote photo upload succeeds. It can remain as an optimization or preview cache.

Current iOS status:

- Signed-in Add Visit has the first Storage-backed `visit-photos` upload path.
- Signed-in Favorite/Want-to-Try state now writes `user_cafe_states` after resolving the remote cafe id.
- Local/demo mode still uses `PhotoCache` and local cafe booleans.

## Social Translation

Web social features:

- Likes.
- Comments.
- Replies.
- Mentions.
- Friends.
- Friend requests.
- Notifications.

iOS sequence:

1. Likes.
2. Comments.
3. Mentions display.
4. Friends.
5. Notifications.
6. Push.

Do not build push before in-app notifications and security cleanup are complete.

## Settings Translation

Web settings includes notification and privacy controls. Some appear to be UI-only until backend persistence is verified.

iOS first settings:

- Account summary.
- Log out.
- Edit profile link.
- Privacy policy.
- Terms.
- About.

Defer:

- Download my data.
- Delete account.
- Detailed notification toggles.
- Privacy toggles.

Only add these when the backend behavior exists.

## Data Model Watchlist

Confirm these before Phase 2 implementation expands:

- Exact `users` column names and required fields.
- `visits` visibility values and rating JSON shape.
- `visit_photos` required fields and bucket policy.
- `cafes` identity columns, especially external place ids.
- `user_cafe_states` uniqueness and state fields.
- RLS expectations for insert/update/delete on every table used by iOS.
- Whether feedback tables belong in the native beta.

## Quality Watchlist

Carry these web findings forward:

- Web package lock is stale.
- Web build has large bundle warning.
- Web logged-out transitions can trigger maximum update-depth warnings.
- Web has an owner edit visit route with no registered route.
- Web source contains public Supabase config directly.

These do not block native implementation by themselves, but they are signals to keep native boundaries cleaner.
