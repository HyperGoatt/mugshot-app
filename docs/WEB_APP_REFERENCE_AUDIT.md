# Web App Reference Audit

Date: 2026-06-30

Purpose: Phase 1.6 reference audit of the existing Mugshot web app, using it as product and backend evidence for the native iOS roadmap. This is an audit-only document. It does not authorize starting Supabase, auth, profile, feed, map, add visit, friends, notifications, or media work in the iOS app.

## Reference Repo

Web repository:

```text
HyperGoatt/mugshot-520470e9
```

Local temporary clone used for inspection:

```text
/private/tmp/mugshot-web-reference
```

Commit inspected:

```text
a036556
```

The temporary clone is outside the iOS app repository and should not be treated as source of truth for native code. It is a reference for product behavior, Supabase shape, and UX scope.

## Access And Run Result

Codex was able to access the web repo through the GitHub connector and clone it locally with `gh`.

Local web validation:

- `npm ci` did not pass because `package-lock.json` is out of sync with `package.json`.
- `npm install` completed in the temporary clone.
- `npm run build` passed.
- `npm run dev -- --host 127.0.0.1 --port 4201` ran locally.
- The app was inspected in the in-app browser at `http://127.0.0.1:4201/`.

Build/runtime notes:

- Build succeeded with a large bundle chunk warning.
- Browser console showed React Router future-flag warnings.
- Several logged-out/public-page transitions produced React "Maximum update depth exceeded" warnings. This appears to be a web quality issue and was not debugged or fixed during this audit.
- `npm install` reported dependency vulnerabilities in the temporary clone. No dependency remediation was attempted.

## Tools Used

- GitHub connector and `gh` for repository access and repo metadata.
- Build Web Apps frontend testing workflow for local Vite build/run and browser inspection.
- Browser app control for route navigation, screenshots, and console observation.
- Product Design audit workflow for visual/product surface review.
- Supabase skill for understanding boundaries and avoiding unsafe backend changes.
- iOS debugger workflow and XcodeBuildMCP evidence from Phase 1.5 for native comparison.

No Supabase data was modified. No backend functions, migrations, storage policies, auth settings, or database records were changed.

## Stack Summary

The web app is a Vite React app:

- React 18
- TypeScript
- React Router
- TanStack React Query
- Tailwind CSS
- shadcn/Radix UI
- Supabase JS
- Google Maps libraries
- Vite PWA plugin
- Vitest

The native app is a SwiftUI iOS app:

- SwiftUI
- MapKit
- CoreLocation
- PhotosUI
- local `DataManager`
- local `PhotoCache`
- no third-party dependencies yet
- no Supabase Swift client yet

## Web Environment Configuration

The web app has environment variables for:

- Supabase project id
- Supabase URL
- Supabase publishable/anon key
- Google Maps API key

The web client file also contains public Supabase configuration directly in source. The exact key is intentionally not repeated here. This appears to be public client configuration rather than a service-role key, but the iOS app should still use a cleaner config strategy before adding the Supabase Swift client.

## Supabase Assets In Web Repo

The web repo contains Supabase source files:

```text
supabase/config.toml
supabase/functions/pwa-nearby-cafes/index.ts
supabase/functions/pwa-search-cafes/index.ts
supabase/migrations/*.sql
```

Migration count in the web repo:

```text
13
```

This is materially different from the iOS repo, which currently has no local `supabase/` folder. Phase 2A should decide whether the iOS repo should import the web Supabase folder, reference it as upstream, or keep it in a separate backend repo.

## Routes Found

Public routes:

- `/welcome`
- `/auth`
- `/feed`
- `/map`
- `/add`
- `/saved`
- `/profile`
- `/user/:userId`
- `/visit/:id`
- `/cafe/:id`
- `/company`
- `/privacy`
- `/terms`

Protected routes:

- `/setup-profile`
- `/edit-profile`
- `/friends`
- `/notifications`
- `/settings`
- `/settings/notifications`
- `/settings/privacy`
- `/settings/about`
- `/feedback`
- `/feedback/:id`

Observed web bug:

- `VisitDetail` navigates owners to `/edit-visit/:id`, but no matching route is registered in `App.tsx`.

## Screenshot Evidence

Screenshots were captured to:

```text
/private/tmp/mugshot-parity-screenshots
```

Unauthenticated screenshots:

- `01-welcome.png`
- `02-auth.png`
- `03-feed.png`
- `04-add.png`
- `05-saved.png`
- `06-profile.png`
- `07-company.png`
- `08-privacy.png`
- `09-terms.png`
- `10-map.png`
- `11-friends-protected.png`
- `12-notifications-protected.png`
- `13-settings-protected.png`
- `14-visit-detail-missing.png`
- `15-cafe-detail-missing.png`
- `16-mobile-welcome.png`
- `17-mobile-feed.png`
- `18-mobile-add.png`
- `19-mobile-saved.png`

Authenticated screenshots:

- `20-auth-feed-friends.png`
- `21-auth-feed-everyone.png`
- `22-auth-feed-discover.png`
- `23-auth-map.png`
- `24-auth-add.png`
- `25-auth-saved.png`
- `26-auth-profile.png`
- `30-auth-friends.png`
- `31-auth-notifications.png`
- `32-auth-settings.png`
- `33-auth-settings-notifications.png`
- `34-auth-settings-privacy.png`
- `35-auth-settings-about.png`
- `36-auth-edit-profile.png`
- `37-auth-feedback.png`
- `38-auth-visit-detail-public.png`
- `39-auth-visit-detail-craft.png`
- `40-auth-cafe-detail.png`
- `41-auth-user-profile-dairiequeen.png`

`27-auth-visit-detail.png` was captured during a click attempt that stayed on Feed, so it should not be used as visit-detail evidence.

## Web Product Inventory

### Auth And Profile

Web behavior:

- Email/password sign up and sign in through Supabase Auth.
- Session restore through Supabase client session state.
- Authenticated users are expected to have a row in `public.users`.
- New users without completed profile media/profile state are routed through setup.
- Profile setup supports display name, username, avatar, and onboarding-style profile fields.
- Edit Profile supports profile text fields, avatar, banner, favorite drink, location, Instagram, website, Log Out, and Delete Account UI.
- Public user profile route supports username or UUID lookup.

iOS state:

- iOS onboarding creates a local `User`.
- iOS has no Supabase Auth, no session restore, no remote `users` bootstrap, no edit profile, no avatar/banner upload, and no public user profile.

### Feed

Web behavior:

- Feed tabs: Friends, Everyone, Discover.
- Friends feed uses the friend graph to find visible friend visits.
- Everyone feed shows public visits.
- Discover includes greeting, nearby cafes, friends' recent visits, and "Spin for a Spot".
- Visit cards show user, cafe/craft context, drink, caption, photo carousel, score, likes, comments, saved/wishlist actions, and share.
- Logged-out users can see public-style surfaces but social actions route to auth.

iOS state:

- iOS has Friends and Everyone toggles, local seeded visits, local likes/comments, and local detail navigation.
- Feed data is local/demo only.
- Search icon is visible but has no implemented action.
- No Discover tab.
- No real social visibility, friend graph, remote likes/comments, or backend photo data.

### Add Visit

Web behavior:

- Location types: Cafe, Home, Travel, Other.
- Cafe search and selection.
- Craft Sip paths with setup, brew method, equipment, location context, and visibility toggles.
- Drink types include Coffee, Matcha, Hojicha, Tea, Chai, and Other.
- Coffee brew methods and drink subtypes.
- Up to 10 image uploads.
- Rating templates, system templates, user templates, smart matching, weighted category scoring.
- Caption, private notes, and visibility.
- Inserts `visits`, uploads photos to Storage, inserts `visit_photos`, and invalidates cached queries.
- Captures analytics events.

iOS state:

- iOS has a polished local Add Visit flow with cafe search, drink info, photos, ratings, caption, notes, visibility, validation, and local save.
- No Supabase write path.
- No remote photo upload.
- No backend rating templates.
- No Craft Sip backend model yet.

### Map

Web behavior:

- Google Maps based map.
- Uses Supabase-backed cafe data and user cafe state.
- Shows visited/saved/wishlist/favorite signals.
- Has a Sip Squad mode that can include friend visits.
- Place search and nearby search use Supabase Edge Functions that call external place/search APIs.

iOS state:

- iOS uses MapKit and local cafe annotations.
- It has search through `MKLocalSearch`, local pins, a location-off banner, a cafe bottom sheet, favorite/want-to-try actions, and log visit entry.
- No remote cafe state, no friend overlay, no Google place id mapping, and no Edge Function-backed cafe search.

### Saved

Web behavior:

- Backed by `user_cafe_states`.
- Shows favorites, wishlist, and user cafe history.
- Shows counts and cafe cards with actions.

iOS state:

- iOS has local favorites, want-to-try, all cafes, cafe cards, and cafe detail.
- No remote `user_cafe_states`.
- No cross-device persistence.

### Visit Detail

Web behavior:

- Rich public visit detail.
- User link, cafe/craft context, photo carousel, score, category ratings, likes, comments, replies, mentions, owner delete menu, share/postcard behavior.

iOS state:

- iOS has local visit detail with likes, comments, edit, and delete.
- No remote comments/replies/mentions, no real user links, no backend delete, no share/postcard flow.

### Cafe Detail

Web behavior:

- Cafe detail requires auth for full view.
- Shows photos, Favorite, Save, Get There, Share, stats, friends who have been, popular drinks, recent activity, and a fixed Log a Visit CTA.
- Uses aggregate stats through Supabase RPC.

iOS state:

- iOS has local cafe detail with hero photo, stats, actions, recent visits, map and website links.
- No remote aggregate stats, friends, public photos, or backend save/favorite state.

### Friends

Web behavior:

- Friends list.
- Friend requests.
- User search.
- Accept, decline, and remove friend flows.
- Mutual friends RPC.
- Friend notifications.

iOS state:

- No Friends surface yet.
- Mentions are local text highlighting only.

### Notifications

Web behavior:

- In-app notification center.
- Unread count.
- Mark read, mark all read, delete all.
- Notifications generated by likes, comments, replies, mentions, and friend events.
- Settings UI for notification preferences.

iOS state:

- No in-app notifications yet.
- No push/device-token work yet.

### Settings, Legal, And Feedback

Web behavior:

- Settings index.
- Notification settings UI.
- Privacy settings UI.
- About settings.
- Company, Privacy, Terms public pages.
- Feedback board and feedback detail, backed by Supabase views/tables.

iOS state:

- No settings screen.
- No legal/company surfaces.
- No feedback board.

Several settings controls look like UI-only preferences and should be verified before native implementation. In particular, Download My Data and Delete Account appear in UI but no complete account/data workflow was confirmed during this audit.

## What The Web App Proves

The web app proves that Mugshot is not just a local visit tracker. The fuller product is:

- A social coffee log.
- A place memory system.
- A cafe map.
- A taste/rating system.
- A profile and friend graph.
- A media-backed visit feed.
- A lightweight discovery product.

The iOS app already has the right native shell: Map, Feed, Add, Saved, Profile. The main gap is not screen shape. The main gap is durable backend behavior.

## Native Beta Implications

The native private beta should not chase every web feature at once. The critical beta path is:

1. Safe Supabase config and auth.
2. Profile bootstrap and edit profile.
3. One real Add Visit write path.
4. Visit photo upload.
5. Feed reload from backend data.
6. Saved/cafe state persistence.
7. Cafe detail and visit detail backed by Supabase.

Friends, notifications, feedback, settings depth, advanced discovery, postcards, analytics, and full Craft Sip depth should follow after the core logged-in loop is stable.

## Risks To Carry Forward

- The iOS repo has no Supabase migrations or backend source, while the web repo does.
- The remote Supabase audit already found security/config drift that should be handled before native code expands backend usage.
- The web app has a missing Edit Visit route.
- The web app has public client Supabase config in source.
- The web app package lock is stale.
- The web app has console loop warnings on some logged-out/public transitions.
- Settings and account-management features need backend verification before being copied to iOS.

## Audit Boundary

This audit did not:

- Modify web or iOS product code.
- Modify Supabase.
- Commit files.
- Rotate secrets.
- Fix package dependencies.
- Implement native auth, profile, media, feed, map, friends, notifications, or settings.

