# Current Product Status

Date: 2026-07-02

## Founder-Level Read

Mugshot's native iOS app has crossed from prototype into a credible private-beta foundation for the personal journal loop. It is not ready to be positioned as a complete social cafe network yet.

## What A Real Signed-In User Can Do Today

- Sign in or create an account through Supabase Auth.
- Relaunch and restore the session.
- Load/bootstrap the matching profile row.
- Edit basic profile text fields.
- Create a visit with cafe, drink, caption, notes, ratings, visibility, and optional photos.
- See saved visits in Profile Recent, Feed, and remote Visit Detail.
- See uploaded visit photos after relaunch.
- Favorite or mark cafes Want-to-Try and see that state persist.
- Search cafes through Apple Maps and use typed cafe fallback in Add Visit.

## What Looks Real But Is Local/Demo

- Profile stats/top cafes/favorites/wishlist are partly local shell data.
- Signed-out/local visits use `UserDefaults` and `PhotoCache`.
- Sample San Francisco cafes/visits seed the app when local data is empty.
- Local likes/comments/edit/delete exist for local visits only.
- Some cafe stats and "0 visits" states are local fallbacks.

## What Breaks Or Dead-Ends

- Feed/remote Visit Detail social actions do not mutate Supabase.
- Friends has no active native surface.
- Notifications have no active native surface and are intentionally blocked.
- Settings/legal/privacy/about are missing.
- Profile avatar/banner upload is missing.
- Public user profiles are missing.
- Remote visit edit/delete is missing.

## What Has Real Backend Data

- Supabase Auth session.
- `public.users` profile bootstrap and update.
- `public.visits` insert/read.
- `public.cafes` resolve/create/read.
- `public.visit_photos` read/write.
- `storage.objects` in `visit-photos` for uploaded images.
- `public.likes` and `public.comments` reads in remote detail.
- `public.user_cafe_states` read/write.

## What Is Unsafe Or Risky

- Reintroducing notifications from old code before backend secret handling is redesigned.
- Pushing this branch directly to `main` while remote `main` has newer history.
- Treating local/demo stats as remote truth.
- Copying old `Auth` branch code wholesale.
- Committing ignored local config.

## What Should Not Be Touched Yet

- Push notifications.
- Widgets and app groups.
- Old Edge Functions and trigger code.
- Broad social graph work.
- Full Discover/Craft Sip/postcard features.
- Bulk branch/repo merges.
