# Current Product Status

Date: 2026-07-03

## Founder-Level Read

Mugshot's native iOS app has crossed from prototype into a credible private-beta foundation for the personal journal loop. It is not ready to be positioned as a complete social cafe network yet.

## What A Real Signed-In User Can Do Today

- Sign in or create an account through Supabase Auth.
- Relaunch and restore the session.
- Load/bootstrap the matching profile row.
- Edit basic profile text fields.
- Create a signed-in visit with cafe, drink, caption, notes, ratings, visibility, and at least one photo.
- See saved visits in Profile Recent, Feed, and remote Visit Detail.
- See uploaded visit photos after relaunch.
- Like/unlike remote visits and add comments from remote Visit Detail.
- Favorite or mark cafes Want-to-Try and see that state persist.
- Save/favorite cafes from remote visit surfaces while preserving existing Want-to-Try state.
- Edit caption/notes/visibility on their own remote visits.
- Delete their own remote visits.
- Open Settings for Sign Out, About, Privacy, Terms, and support/contact.
- Search cafes through Apple Maps and use typed cafe fallback in Add Visit.

## What Looks Real But Is Local/Demo

- Signed-out profile stats/top cafes/favorites/wishlist are local shell data.
- Signed-out/local visits use `UserDefaults` and `PhotoCache`.
- Sample San Francisco cafes/visits seed the app when local data is empty.
- Local likes/comments/edit/delete exist for local visits only.
- Some cafe stats and "0 visits" states are local fallbacks.

## What Breaks Or Dead-Ends

- XcodeBuildMCP semantic tap/touch automation still does not reliably present the native Photos picker, but Computer Use coordinate-click fallback completed the 2026-07-03 photo-backed Add Visit smoke.
- Friends has no active native surface.
- Notifications have no active native surface and are intentionally blocked.
- Profile avatar/banner upload is missing.
- Public user profiles are missing.

## What Has Real Backend Data

- Supabase Auth session.
- `public.users` profile bootstrap and update.
- `public.visits` insert/read.
- `public.cafes` resolve/create/read.
- `public.visit_photos` read/write.
- `storage.objects` in `visit-photos` for uploaded images.
- `public.likes` read/write and `public.comments` read/write for remote visit social controls.
- `public.user_cafe_states` read/write.

## What Is Unsafe Or Risky

- Reintroducing notifications from old code before backend secret handling is redesigned.
- Pushing this branch directly to `main` while remote `main` has newer history.
- Treating local/demo stats as remote truth.
- Treating XcodeBuildMCP picker-tap failure as proof that photo creation is broken; the verified issue is semantic automation around the system picker, while visible Simulator interaction completed the upload path.
- Copying old `Auth` branch code wholesale.
- Committing ignored local config.

## What Should Not Be Touched Yet

- Push notifications.
- Widgets and app groups.
- Old Edge Functions and trigger code.
- Broad social graph work.
- Full Discover/Craft Sip/postcard features.
- Bulk branch/repo merges.
