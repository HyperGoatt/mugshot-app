# iOS Parity Roadmap

Date: 2026-06-30

Purpose: convert the web reference audit into an iOS implementation plan. This roadmap keeps the first native beta narrow: authenticate, create a real visit, upload photos, reload the feed, and persist cafe/profile state.

## Roadmap Principle

The current iOS app already has the right shape. The next phase should connect the existing shape to durable Supabase behavior. Avoid redesigning screens until the first authenticated journey is real.

## Phase 2A - Supabase Safety, Config, Auth, Profile Bootstrap

Status: implemented and simulator-smoke-tested on 2026-07-01. See `docs/PHASE_2A_AUTH_PROFILE_BOOTSTRAP.md`.

Goal:

- Establish a safe Supabase client and signed-in session in iOS.

User result:

- A user can sign up or sign in, relaunch the app, and still be recognized.
- The app can load or create the matching `public.users` profile.

Scope:

- Review existing Supabase security findings before adding native clients.
- Add official Supabase Swift dependency.
- Add public config loading without service-role secrets.
- Add `AuthService`.
- Add profile bootstrap/read for `public.users`.
- Preserve local/demo mode until the remote journey is stable.
- Add a minimal logged-out/auth state and session restore path.

Out of scope:

- Add Visit write path.
- Photo upload.
- Feed replacement.
- Friends.
- Notifications.
- Profile redesign.

Definition of done:

- App builds and launches in simulator. Done.
- Sign in works. Done.
- Sign-out service exists; full sign-out visual regression should be included in the next auth polish pass.
- Session restore works after relaunch. Done.
- Profile row is fetched or created safely. Done.
- No secret keys are introduced into the repo. Done.
- `docs/IOS_SIMULATOR_TESTING.md` remains accurate. Done.

Checkpoint:

- Phase 2A committed locally as `ff98451`.

## Phase 2A.5 - Security Checkpoint And Visit Trigger Quarantine

Status: read-only inspection completed on 2026-07-01. See `docs/PHASE_2A5_SECURITY_CHECKPOINT.md` and `docs/PHASE_2B_READINESS.md`.

Goal:

- Confirm Phase 2A is safe to preserve and decide whether real no-photo visit creation can begin.

Result:

- Phase 2A diff was scanned for secrets and committed.
- `Config/SupabaseConfig.local.xcconfig` is ignored and was not committed.
- Supabase read-only inspection confirmed a `public.visits` `AFTER INSERT` trigger still calls `notify-friends-on-new-visit` with an embedded bearer credential.
- The trigger is not needed for Add Visit itself, but it would fire on every Phase 2B visit insert.

Decision:

- Real visit creation is blocked until the trigger is disabled, dropped, or rebuilt without embedded credentials.
- No live Supabase changes were made in Phase 2A.5.

## Phase 2B - Profile Setup And Edit Profile

Status: profile edit basics implemented and simulator-validated on 2026-07-01. See `docs/PHASE_2B_PROFILE_EDIT_BASICS.md`.

Goal:

- Make profile identity real enough for beta.

User result:

- A signed-in user can complete setup and edit username/display name/basic profile fields.

Scope:

- Wire onboarding/setup to Supabase profile fields.
- Add edit profile screen or profile edit sheet.
- Add username validation if backend supports it.
- Add avatar upload only if Storage policy is confirmed safe.

Out of scope:

- Banner upload unless avatar upload is already clean.
- Public user profile browsing.
- Friend graph.

Definition of done:

- Profile state survives reinstall/relogin. Partially done through Phase 2A bootstrap and remote edit path; live save validation still needs an approved backend-write pass.
- Username/display name validation errors are understandable. Basic local validation is implemented.
- Profile screen reflects remote data. Done for session restore/bootstrap and after successful update response.

Still out of scope:

- Avatar/banner upload until storage policy findings are resolved.
- Public profile browsing.

## Phase 2C - Real Add Visit Without Photos

Goal:

- Create the first durable Mugshot visit from iOS.

Gate:

- Do not start while the current `public.visits` insert trigger can fire with an embedded bearer credential.

User result:

- A signed-in user logs a visit and sees it after relaunch.

Scope:

- Add `VisitRepository`.
- Map current iOS Add Visit fields to Supabase `visits`.
- Include cafe, drink, caption, notes, visibility, ratings JSON/category scores, and overall score.
- Keep current UI unless a minimal auth-aware validation state is required.
- Keep local fallback only as a controlled/dev path.

Out of scope:

- Photo upload.
- Likes/comments.
- Friends feed.
- Advanced Craft Sip.

Definition of done:

- One visit insert succeeds.
- Errors are visible and recoverable.
- Relaunch does not lose the visit.
- Backend row matches expected user id and visibility.

## Phase 2D - Visit Photo Upload

Goal:

- Move selected visit photos from local-only storage to Supabase Storage.

User result:

- A visit with photos is visible after relaunch and across devices.

Scope:

- Add `PhotoStorageService`.
- Confirm `visit-photos` bucket privacy/public-url strategy.
- Upload selected images before or during visit creation.
- Insert `visit_photos` rows.
- Show basic progress/error/retry behavior.

Out of scope:

- Image editing.
- Advanced compression pipeline.
- Postcard sharing.

Definition of done:

- Photos upload to the intended bucket.
- `visit_photos` rows link to the visit.
- Feed/detail can display uploaded photos.
- Failed uploads do not create confusing partial visits.

## Phase 2E - Backend Feed

Goal:

- Replace local/demo feed data with Supabase-backed visits.

User result:

- The user sees their own visits and public/everyone visits in the Feed.

Scope:

- Add feed read queries.
- Fetch visits, users, cafes, photos, counts, and current-user state needed for cards.
- Implement current user plus public/everyone first.
- Keep Friends tab visually present only if backed by clear empty/loading/auth states.

Out of scope:

- Full friend graph feed.
- Discover tab.
- Push notifications.

Definition of done:

- A just-created visit appears in Feed.
- Feed survives relaunch.
- Empty/error/loading states are humane.
- Local seed data is no longer mistaken for real remote data in signed-in mode.

## Phase 2F - Saved And Cafe State

Goal:

- Persist favorite/want-to-try/history state through `user_cafe_states`.

User result:

- Favorite and wishlist actions survive relaunch and appear in Saved.

Scope:

- Add `CafeRepository`.
- Back Saved tabs with remote cafe state.
- Wire favorite, wishlist, and visited status.
- Use existing iOS Saved UI where possible.

Out of scope:

- Full cafe discovery.
- Friends who have been.
- Aggregate stats beyond what is easy and safe.

Definition of done:

- Favorite/wishlist actions persist.
- Saved counts match remote state.
- Log Visit from Saved still works.

## Phase 2G - Visit Detail And Cafe Detail

Goal:

- Make detail screens show remote truth.

User result:

- Tapping a visit or cafe opens a detail screen backed by Supabase.

Scope:

- Fetch visit detail, photos, ratings, comments summary, and owner actions.
- Fetch cafe detail, photos, current user's state, user's stats, and recent activity.
- Keep UI close to existing iOS screens.

Out of scope:

- Full comments/replies.
- Friends who have been if friend graph is not live yet.
- Public share/postcard.

Definition of done:

- Detail screens can be opened from Feed, Map, Saved, and Profile.
- Delete/edit behavior is either implemented safely or hidden until supported.

## Phase 2H - Likes, Comments, Mentions

Goal:

- Add the first real social interactions.

User result:

- Users can like and comment on visible visits.

Scope:

- Likes.
- Comments.
- Basic mentions parsing and display.
- Notification row creation only if backend paths are safe.

Out of scope:

- Push notifications.
- Reply threading if it complicates beta stability.
- Moderation tooling.

Definition of done:

- Counts and current-user state update correctly.
- A relaunch preserves interactions.
- RLS permits only intended actions.

## Phase 2I - Friends

Goal:

- Add social graph only after individual social interactions work.

User result:

- Users can search for other users, send/accept requests, and see friends.

Scope:

- Friends list.
- Requests.
- User search.
- Remove friend.
- Friends feed visibility.

Out of scope:

- Suggestions/recommendations.
- Complex mutual-friend UI.

Definition of done:

- Friend request round trip works between two users.
- Friends-only visibility is testable.
- Feed can distinguish Friends and Everyone.

## Phase 2J - Notifications

Goal:

- Add in-app notifications after social actions exist.

User result:

- Users can see likes/comments/mentions/friend events in a notification center.

Scope:

- In-app notification list.
- Unread count.
- Mark read/all read.
- Navigation to related content.

Out of scope:

- Push notifications until Edge Function security and device-token handling are clean.

Definition of done:

- Notifications are generated by actual actions.
- Notification taps open the right screen.
- Empty state is clear.

## Phase 2K - Settings, Legal, Feedback, Polish

Goal:

- Prepare the app for a real external beta.

User result:

- The user can manage account basics and access required legal/about surfaces.

Scope:

- Settings root.
- Log out.
- Privacy/terms/about links or native screens.
- Basic account controls that are truly implemented.
- Feedback entry if the team wants in-app beta feedback.

Out of scope:

- Fake toggles.
- Data export/delete account unless backend flow is fully implemented.

Definition of done:

- TestFlight beta users can find account and legal basics.
- No settings controls pretend to do work they do not do.

## Recommended First 10 Implementation Tasks

1. Resolve or consciously quarantine the Supabase trigger/token security findings from Phase 1.
2. Decide where Supabase migrations/functions live for the iOS project.
3. Complete approved backend-write smoke testing for profile edit basics.
4. Add a repository boundary beside `DataManager`.
5. Create one real visit without photos.
6. Add visit photo upload and `visit_photos`.
7. Replace Feed with backend data for current user plus public/everyone visits.
8. Persist saved/favorite/want-to-try state through `user_cafe_states`.
9. Add focused tests around auth/profile/visit mapping.
10. Add lean settings/account/legal surfaces before external beta.

## Completed Phase 2A Prompt

This prompt was used to start Phase 2A:

```text
Phase 2A: Supabase safety, config, auth, and profile bootstrap only.

Before implementing, read:
- docs/MUGSHOT_RESTART_AUDIT.md
- docs/SUPABASE_AUDIT.md
- docs/WEB_APP_REFERENCE_AUDIT.md
- docs/FEATURE_PARITY_MATRIX.md
- docs/IOS_PARITY_ROADMAP.md
- docs/MUGSHOT_PRODUCT_SPEC.md
- docs/WEB_TO_IOS_TRANSLATION_NOTES.md
- docs/IOS_SIMULATOR_TESTING.md
- docs/REPO_MAP.md

Do not start Add Visit, photo upload, Feed replacement, Map replacement, Friends, Notifications, Saved, or Settings yet.

First, inspect the current repo and available tools. Use Supabase tools only for read-only verification unless I explicitly approve changes. Confirm the safe Supabase config strategy, add the official Supabase Swift client, implement sign up/sign in/sign out/session restore, and bootstrap the signed-in user's public.users profile. Preserve the existing local app shell. Build and launch in the iPhone 17 Pro simulator, capture screenshots/logs, and update docs with what changed.
```

## Manual Decisions Needed Before Or During Phase 2A

- Whether the web repo's `supabase/` folder should be copied into this iOS repo, referenced as an external backend repo, or treated only as historical reference.
- Whether existing Supabase security findings must be fixed before any native auth build.
- Whether beta authentication should begin with email/password only.
- Whether the iOS app should use the same Supabase project as the web app for development.
- Whether profile avatar upload belongs in Phase 2A or Phase 2B.

## Exact Next Codex Prompt

Use this prompt to start the next implementation phase:

```text
Phase 2B/2C decision point: continue Mugshot from completed Phase 2A.

Before implementing, read:
- docs/PHASE_2A_AUTH_PROFILE_BOOTSTRAP.md
- docs/SUPABASE_SECURITY_BACKLOG.md
- docs/NEXT_10_TASKS.md
- docs/IOS_SIMULATOR_TESTING.md
- docs/REPO_MAP.md

Do not start broad redesign, Friends, Notifications, public profile, Feed replacement, or Map replacement yet.

Confirm whether we are doing profile setup/edit polish first or moving directly to Add Visit Supabase insert. If moving to Add Visit, resolve or explicitly quarantine the Supabase trigger bearer-token issue before inserting visits.
```
