# Mugshot Private Beta UX/UI Audit

Date: 2026-07-03  
Device evidence: iPhone 17 Pro simulator, iOS 26.2  
Build: `testMugshot`, bundle `co.mugshot.app.testMugshot`

## Evidence Captured

Current screenshots are saved in `docs/audits/beta-readiness-2026-07-03/screenshots/`.

1. `01-feed-friends.jpg` - Feed, Friends
2. `02-feed-everyone.jpg` - Feed, Everyone
3. `03-remote-visit-detail.jpg` - Remote Visit Detail
4. `04-owner-menu.jpg` - Owner edit/delete menu
5. `05-add-top-required-photo.jpg` - Add Visit top/photo-required state
6. `06-map-location-off.jpg` - Map with location denied
7. `07-map-search-error.jpg` - Map search error
8. `08-saved-favorites.jpg` - Saved Favorites
9. `09-cafe-detail.jpg` - Cafe Detail
10. `10-profile-recent.jpg` - Profile Recent
11. `11-settings.jpg` - Settings
12. `12-settings-about.jpg` - Settings About
13. `13-edit-profile.jpg` - Edit Profile

Limits: the simulator session was already signed in, so Auth, Onboarding, and missing-config states were audited from implementation rather than a fresh screenshot flow. The iOS 26 simulator drag API failed for some scroll actions, so below-the-fold areas were checked through visible runtime trees and SwiftUI source. This is not a full WCAG audit.

## Executive Summary

Mugshot has a coherent product idea and a stronger visual direction than a default CRUD app: warm cream backgrounds, coffee-toned palette, serif display headings, tactile cards, a clear Add-first tab bar, photo-backed visit detail, cafe save states, and private notes all support the intended premium sip-journal feel.

The app is not fully private-beta ready for a small external audience yet. It is functional enough for internal dogfooding, but several visible states still expose implementation scaffolding, sample-data artifacts, and unpolished loading/error states. The biggest beta risks are:

- The core photo-backed loop is undermined by feed/profile visit photos that show an app screenshot instead of an actual drink/cafe photo.
- User-facing copy leaks backend language such as "Supabase live" and "This posts to Supabase", making the app feel like a test harness.
- The Add flow is robust but dense, form-heavy, and blocked by a disabled CTA without enough inline guidance.
- Map search can fail into a dead-feeling error panel with no direct recovery path.
- Cafe Detail and Saved expose "Photo loading" and empty photo blocks as visible content, which makes the premium visual promise collapse.
- Settings/About/Privacy/Terms are too thin for external beta trust.
- Accessibility risk is high because the app relies on many fixed font sizes, low-contrast secondary text, tiny labels, opacity-disabled controls, and generic icon accessibility labels.

Recommendation: run a focused front-to-back polish pass before external beta. The highest ROI is not new scope; it is replacing development artifacts, strengthening states, cleaning hierarchy, and making every core loop confirmation feel intentional.

## Screen-By-Screen Audit

### Auth, Session Loading, Missing Config

Problem:
- Auth has a coherent brand entry, but it is a basic email/password card. It lacks beta reassurance around account creation, photo/privacy expectations, and why a user should trust a private beta with location and photos.
- `AuthLoadingView` uses a plain spinner plus "Checking session"; it feels temporary and does not carry brand personality.
- Missing config says "Supabase config needed" and instructs the user to create an xcconfig file. That is fine for developers, but unacceptable if this build can ever reach a tester.

Desired experience:
- Auth should feel like a calm beta gate into a personal journal, not a generic login form.
- Loading should feel branded and stable.
- Missing config should either never ship or present a graceful unavailable state for TestFlight users.

Implementation direction:
- Add a small "Private beta" trust strip with photo privacy, private notes, and saved cafe persistence.
- Replace "Checking session" with a branded loading mark and copy like "Opening your journal".
- Gate developer-only missing config behind debug builds, or make the release message non-technical with support contact.

### Onboarding

Problem:
- Onboarding matches the warm palette but is mostly static value rows and plain profile fields.
- The rating template step explains percentages without giving users a sense of how ratings affect their sip journal.
- Disabled Next on profile basics has no visible explanation when username/location are empty.

Desired experience:
- Onboarding should quickly prepare the user for the first sip log and reduce fear around photo, cafe, ratings, notes, and visibility.

Implementation direction:
- Add a first-sip oriented final step: "Next: log your first sip" with photo, cafe, drink, rating, visibility preview.
- Make disabled Next explain missing fields inline.
- Use the same progress and tactile chip language as Add Visit so onboarding and logging feel connected.

### Main Bottom Navigation

Problem:
- The custom tab bar is clear and Add-forward, but the centered Add button overlaps content in several screenshots and creates crowding at the bottom of Add/Profile/Feed.
- The Feed icon uses `square.grid.2x2`, which reads more like dashboard/grid than social feed.
- Search/filter header icon buttons have empty actions in Feed and Saved, which creates dead controls.

Desired experience:
- Bottom nav should feel polished, predictable, and not cover primary content.

Implementation direction:
- Add bottom safe padding to scroll views based on the custom nav height.
- Use a feed/list/social icon for Feed.
- Remove disabled/dead header icons until functional, or show a clear disabled affordance with no tap target.
- Add light haptic feedback on tab switch and Add tap.

### Map And Cafe Sheet

Problem:
- Map has a good functional base: search, location banner, pins, rating legend, and my-location button.
- With location off, the top banner plus search bar plus bottom legend makes the screen visually busy.
- Search failure shows "Can't reach Apple Maps right now. Try again in a bit." inside a large blank panel with no direct action.
- Pin values are tiny and may be hard to read at glance.
- The legend is useful but feels like an overlay card from a utility app rather than a premium map control.

Desired experience:
- Map should feel calm and exploratory, with failures that still let users log or save a cafe.

Implementation direction:
- Collapse the location-off banner after first display into a small "Location off" chip.
- On search error, offer "Use typed cafe name" and "Try again" directly in the panel.
- Increase pin hit area and provide accessible labels like "Ritual Coffee Roasters, 4.6 average".
- Restyle the legend into a compact bottom capsule or an info popover.

### Feed Friends / Everyone

Problem:
- The feed layout has good hierarchy: author, cafe, drink, caption, meta chips, like/comment/save.
- The first card photo is an app screenshot, which immediately makes the app feel like QA data rather than a real cafe journal.
- Friends and Everyone use the same card design and sample artifacts, so the tabs do not feel meaningfully distinct.
- The stat pill shows "19 sips" or "7 sips" but reads as a feed count without explaining scope.
- The search icon is a dead control.
- Like/comment counts are visually quiet and may not communicate tappability.

Desired experience:
- Feed should feel like a living stream of actual sips. Every visible card should reinforce coffee, cafe, taste, and person.

Implementation direction:
- Replace seeded/test photos and captions before beta. Use real drink/cafe photos or a premium no-photo legacy treatment.
- Use scoped copy like "7 public sips" or remove the count if it is not actionable.
- Make social controls larger and more button-like, with optimistic haptic feedback and visible liked/saved transitions.
- Remove or wire search.

### Add Visit Full Flow

Problem:
- Add is the strongest structured flow: it has required-photo messaging, progress, photo picker, cafe search, drink type, ratings, caption, notes, visibility, validation, and save state.
- It is also the most visually dense. The top screen contains a hero card, progress card, photo card, and bottom nav all at once.
- User-facing backend copy appears repeatedly: "Supabase live", "This posts to Supabase", "Storage ready".
- Disabled CTA says "Complete required details" but the button is below the fold; the top progress chips are not tappable shortcuts.
- The required photo state is clear, but "Choose from library" is the only visible photo action. Camera capture is not offered on the current top state.
- Validation errors are appended after the user attempts saving, but many required sections appear below the fold.

Desired experience:
- Logging should feel like a guided ritual, not a long settings form.

Implementation direction:
- Replace backend language with user language: "Ready for beta", "Photo required", "Saves to your journal".
- Make progress chips tappable anchors to missing sections.
- Keep the photo block first, but reduce hero/progress duplication.
- Use inline missing-field badges on each section.
- Add haptic feedback when a required item becomes complete.
- Consider a sticky bottom CTA that states the next missing requirement, e.g. "Add a cafe to continue".

### Remote And Local Visit Detail

Problem:
- Remote detail has a strong large photo and useful score overlay.
- Owner arrivals from Feed show "Sip saved / Added to your taste journal and Profile Recent", which is wrong context after reopening an old saved visit.
- The owner menu is reachable, but Edit/Delete are hidden under a small ellipsis at top left.
- No-photo legacy state exists and is honest, but its visual treatment is generic.
- Comments are standard text field plus send icon, not especially social or premium.

Desired experience:
- Visit Detail should be the canonical saved object, not a save-confirmation screen except immediately after posting.

Implementation direction:
- Only show the "Sip saved" success header immediately after post. For normal detail, start with photo and visit identity.
- Move owner actions into a clearer "Manage" menu or include contextual labels.
- Add a subtle transition from posted Add flow into detail, then from dismissal into Feed/Profile.
- Improve no-photo legacy with a small "Legacy sip" badge and cafe/drink hierarchy rather than a generic placeholder.

### Owner Edit/Delete Visit

Problem:
- Edit/Delete exist and use native menu/dialog patterns, which is good for reliability.
- The destructive flow is mostly system-native and not visually integrated with Mugshot.
- Delete copy says it removes the remote visit from Profile, Feed, and cafe history, which is clear but could be emotionally safer.

Desired experience:
- Owner controls should feel trustworthy, explicit, and reversible where possible.

Implementation direction:
- Keep the native confirmation but add specific visit title/cafe in the message.
- During deletion, show a branded blocking progress state and disable the menu.
- After deletion, route to the correct previous surface and show lightweight confirmation.

### Saved: Favorites, Want To Try, All Cafes

Problem:
- Saved works as a cafe library, but it is the most CRUD-like screen.
- Cards are dense: thumbnail, title, score, address, tags, visits, and three to four footer actions compete in a small area.
- Empty/placeholder cafe images are bland and repeated.
- Data quality issues are visible: "babas on cannon" lowercase, 0.0 score, 0 visits but favorited.
- The filter icon is present but not functional.

Desired experience:
- Saved should feel like a curated personal cafe shelf.

Implementation direction:
- Improve cafe image fallback: use a branded cafe tile, neighborhood initials, or last visit color treatment instead of generic image icons.
- Prioritize one primary action per card: Details or Log Visit. Move Directions/Website into detail or a compact overflow.
- Normalize cafe title casing for display.
- Hide or explain 0.0 scores for unvisited saved cafes, e.g. "Unrated".
- Wire or remove filter.

### Cafe Detail

Problem:
- Cafe Detail has the right actions: Log Visit, Favorite, Want to Try, Directions, Recent Visits.
- The hero currently displays "Photo loading" visibly and takes a large area, making the screen look unfinished.
- The main action stack is large and plain; it feels more like controls than a cafe profile.
- Recent visits begin below the fold and can be partly obscured by the bottom sheet/nav context.

Desired experience:
- Cafe Detail should feel like a place profile built from personal memory.

Implementation direction:
- Replace "Photo loading" text with skeleton shimmer or a soft branded placeholder.
- If no photo exists, use a designed no-photo cafe header with cafe name/address and save state, not a large blank hero.
- Use Log Visit as the primary full-width CTA, with Favorite/Want to Try as compact toggles.
- Show visit count/average in a tighter stats row with "Unrated" for no score.

### Profile

Problem:
- Profile is warm and personal, with avatar, stats, taste identity, and Recent content.
- The "Taste identity" dot row is visually pleasant but not self-explanatory.
- Segmented tabs fit tightly and may break with Dynamic Type or localization.
- Profile recent repeats the same screenshot-as-photo artifact seen in Feed.
- "hidden gem hunter" appears hard-coded and may feel fake.

Desired experience:
- Profile should be the user's personal coffee memory, not a generic stats page.

Implementation direction:
- Make Taste Identity explain itself in one short line or replace with top taste/cafe insight.
- Ensure segmented controls reflow or use horizontal scroll at larger text sizes.
- Remove hard-coded persona chips unless they are derived from behavior or editable.
- Ensure Recent cards match Feed/Detail photo quality.

### Edit Profile

Problem:
- Edit Profile is functional but plain: a long list of fields with little grouping, no avatar/display preview, and no clear optional/required distinction.
- Website accepts `mugshotapp.co` without visible URL normalization guidance.
- The Save button is below the fold; users may not know whether changes are valid until they scroll.

Desired experience:
- Editing identity should feel lightweight and reassuring.

Implementation direction:
- Add a compact preview at the top showing avatar, display name, username, and bio as they will appear.
- Mark required fields and optional fields.
- Normalize and preview username/URL changes inline.
- Consider a sticky Save button or top-right Save once fields are valid.

### Settings: About, Privacy, Terms, Support, Sign Out

Problem:
- Settings has clean styling but too little substance for external beta.
- About is one sentence. Privacy and Terms appear as static detail cards, not complete policies.
- Support is a mailto link, but there is no fallback copy if Mail is not configured.
- Sign Out is visually a secondary button despite being account-critical and destructive.

Desired experience:
- Settings should build trust. Private beta users should understand privacy, support, and sign-out consequences.

Implementation direction:
- Expand Privacy/Terms into beta-appropriate full text or link to hosted policy pages.
- Add app version/build and support email text.
- Confirm Sign Out with a short dialog if there is any unsynced local state.
- Provide a clear "Delete account" plan later, but do not add scope for this beta unless required by policy.

### Empty, Loading, Error, No-Photo, Disabled States

Problem:
- Mugsy empty-state assets are a strong brand move.
- Loading states are mostly spinner plus literal text.
- Errors often show raw localized backend messages or generic "Could not..." copy.
- Disabled controls rely on opacity, which may fail contrast and does not explain recovery.
- No-photo placeholders vary by surface: "No photo yet", "Photo loading", generic image icons, blank beige blocks.

Desired experience:
- States should feel designed, helpful, and consistent.

Implementation direction:
- Create a single state system: loading skeleton, empty Mugsy card, recoverable error card, legacy no-photo card, disabled CTA helper.
- Never show "Photo loading" as a final visible label in large hero areas.
- Map backend errors to user-friendly messages and specific next actions.
- Add retry, use typed cafe, or contact support where relevant.

## Flow Audit

### First Launch

Health: needs beta polish.

- Signed-in restore works in the captured session and goes straight to Feed.
- Auth and loading states exist, but loading and missing config are plain/developer-facing.
- Private beta trust is underdeveloped before the user is asked to sign in.

### Log Sip

Health: functionally strong, visually dense.

- Required fields are comprehensive.
- Photo requirement is clear at the top.
- Cafe/drink/rating/caption/photo progress exists.
- Backend-language copy and long form density reduce premium feel.
- Disabled save state needs better next-step guidance.

### Saved Visit Verification

Health: needs context correction.

- After saving remote visits, the app opens Remote Visit Detail and then dismisses to Profile.
- Feed/Profile/Saved persistence appears supported, but current detail copy says "Sip saved" even when reopening an existing visit from Feed.
- The photo artifact makes it difficult to trust the saved-photo loop visually.

### Social Interaction

Health: functional but understated.

- Like, comment, and save-cafe controls exist.
- Like/comment controls lack richer pressed/liked/commented feedback.
- Comment UI is plain and tucked below detail content.

### Cafe Saving

Health: broad coverage, inconsistent polish.

- Save/favorite/want-to-try appears across Feed, Saved, Map/Cafe Detail, and Visit Detail.
- The mental model between Favorite, Saved, and Want to Try needs tighter labels. Feed says "Save Cafe", Saved tab says Favorites, cafe detail has Favorite and Want to Try.
- 0.0 saved cafes and lowercase cafe names reduce trust.

### Profile And Settings

Health: profile is promising; settings is thin.

- Profile communicates personal identity and stats.
- Edit Profile is complete but plain.
- Settings covers the required destinations but content is not beta-ready enough for external users.

## Design-System Consistency Audit

### Typography

- Serif display headings give Mugshot a distinct voice.
- Body and labels are mostly system font with many fixed point sizes.
- Several small labels are 10-12 pt, creating readability risk.
- Negative tracking in display text may reduce accessibility and should be checked at large Dynamic Type.

### Color

- Cream, sage, espresso, sand, and latte are applied consistently.
- Tertiary text often uses opacity over cream/sand, creating contrast risk.
- Red/error states use low-opacity red and may be too subtle.
- Disabled states use opacity only.

### Spacing And Layout

- Cards and pills are consistent but overused. Several screens feel like card stacks rather than native app experiences.
- Bottom nav overlaps or crowds content.
- Sheet headers use large top chrome and floating Done buttons, but internal sheet content sometimes starts too low or too empty.

### Cards And Controls

- Core cards are tactile and warm.
- Saved card footers feel table-like and dated.
- Header icon buttons are sometimes dead or generically labeled.
- Segmented controls look polished but are too tight for four options.

### Navigation

- The custom bottom nav is recognizable and Add-centered.
- Modal/sheet patterns vary: full-screen cover, sheet, NavigationStack sheets, and bottom cafe sheet.
- Detail sheets keep background content in the accessibility tree, which needs verification with VoiceOver.

### Iconography

- SF Symbols are consistent.
- Some icon choices are generic or misleading: Feed grid icon, search with no action, settings rows with decorative icons.
- `MugshotIconButton` defaults accessibility label to the raw system name unless overridden.

### Empty States

- Mugsy empty states are the strongest brand expression outside main content.
- Empty copy is generally helpful.
- Loading/no-photo placeholders need to match the Mugsy quality.

### Photo Treatment

- Photo is central to the product, but current sample/photo cache artifacts damage the whole experience.
- Large hero photos are good when real.
- Placeholder states need a designed hierarchy and should never look like broken image slots.

## Motion And Interaction Audit

Recommended improvements:

- Add haptics when a progress requirement becomes complete, when a visit posts, when liking/saving succeeds, and when toggling Favorite/Want to Try.
- Animate Add progress chips from incomplete to complete with a check transition.
- Use skeleton shimmer for feed/cafe/profile photo loading rather than text placeholders.
- Use matched or directional transitions from Add save to Visit Detail, and from Visit Detail dismissal to Feed/Profile persistence.
- Add optimistic heart/bookmark animations with rollback on error.
- Use a compact toast/snackbar for "Cafe saved", "Comment posted", "Visit deleted", "Profile saved".
- Respect Reduce Motion: disable scale/bounce and use opacity/state changes instead.
- Avoid full reload flashes after dismissing detail unless data actually changed.

## Accessibility Risks

- Many font sizes are fixed and small; Dynamic Type reflow is likely fragile, especially segmented controls, bottom nav, stat pills, and saved card footers.
- Low-contrast tertiary copy and disabled-opacity states need contrast testing.
- Icon-only buttons need meaningful accessibility labels, not raw SF Symbol names.
- Map pins need accessible labels and larger hit targets.
- The custom bottom nav needs VoiceOver selected-state announcements.
- The Add progress chips should expose completion state.
- Sheets may leave background content exposed in the accessibility tree; this requires VoiceOver testing.
- Color is used for rating pin ranges; legend helps visually, but VoiceOver labels must include the rating status.
- Motion should respect Reduce Motion.

## Prioritized Fix List

### P0: Must Fix Before Private Beta

1. Replace test/sample photo content.
   - Current problem: Feed/Profile/Detail show a screenshot of the app as the visit photo.
   - Desired experience: Every visible logged sip looks like a real drink/cafe memory.
   - Implementation direction: purge seeded QA photos/captions from beta data; use real seed photos or a polished legacy no-photo state.

2. Remove backend/developer copy from user-facing UI.
   - Current problem: "Supabase live", "This posts to Supabase", "Storage ready", and "Supabase config needed" leak implementation.
   - Desired experience: User sees journal/privacy/save language.
   - Implementation direction: create release copy variants and debug-only config messaging.

3. Fix large photo loading/placeholder states.
   - Current problem: Cafe Detail and Saved show "Photo loading" or blank image blocks.
   - Desired experience: Loading feels intentional; no-photo feels designed.
   - Implementation direction: skeleton shimmer for loading, branded no-photo cafe tile for missing images.

4. Make Add disabled/validation guidance actionable.
   - Current problem: disabled "Complete required details" CTA is below the fold; missing items are not navigable.
   - Desired experience: user always knows the next required action.
   - Implementation direction: tappable progress chips, section-level missing badges, sticky next-step CTA.

5. Improve Map search error recovery.
   - Current problem: Apple Maps failure leaves a large dead panel.
   - Desired experience: user can retry or use typed cafe name immediately.
   - Implementation direction: add retry and "Use Babas as cafe" actions to error state.

6. Expand Settings legal/privacy/support enough for external beta.
   - Current problem: About/Privacy/Terms are placeholder-level.
   - Desired experience: beta user can understand data use and support path.
   - Implementation direction: complete copy or link to hosted policy pages; show support email and build version.

### P1: Should Fix For Polished Beta

1. Remove or implement dead header controls in Feed/Saved.
2. Correct Visit Detail context so "Sip saved" only appears immediately after posting.
3. Normalize cafe names and replace "0.0" with "Unrated" for unvisited cafes.
4. Simplify Saved card actions and make the screen feel like a curated cafe shelf.
5. Add haptics and visible transitions for like, save cafe, post comment, post visit.
6. Improve profile segmented tabs for Dynamic Type and cramped widths.
7. Add meaningful accessibility labels and selected states to custom controls.
8. Add sticky bottom padding so the custom tab bar never covers content.
9. Add branded loading and error components across Feed/Profile/Detail.
10. Add Edit Profile preview and clearer required/optional field treatment.

### P2: Later Polish

1. Refine Map pin visual system and legend interaction.
2. Add richer cafe hero treatment from visit photos or generated color/texture fallback.
3. Add microcopy to explain Taste Identity.
4. Refine comments visual design.
5. Add subtle screen transitions between tab changes.
6. Add skeleton rows for remote feed/profile refresh.
7. Improve onboarding rating template explanation and preview.

## Definition Of Done For Full UI Revamp

- Auth, onboarding, signed-in restore, and missing-config/release-failure states are fully branded and non-technical.
- User can log a sip with photo, cafe, drink, rating, caption, notes, and visibility without guessing next steps.
- A newly logged sip appears in Visit Detail, Feed, and Profile Recent with the correct photo and no reload confusion.
- Like, comment, save cafe, favorite, and want-to-try actions have optimistic visual feedback, error rollback, and haptics.
- Feed, Profile Recent, Saved cards, Cafe Detail, and Visit Detail share one photo treatment system.
- No screen shows development copy, raw backend errors, "Photo loading" as final UI, or test/sample artifacts.
- Empty, loading, error, disabled, no-photo, and legacy states use a consistent Mugshot state system.
- Bottom nav never obscures content and announces selected state to accessibility users.
- Header icon buttons are either functional or removed.
- Dynamic Type, VoiceOver labels, touch targets, contrast, Reduce Motion, and keyboard entry are tested on key flows.
- Settings includes complete About, Privacy, Terms, Support, app version/build, and reliable sign-out handling.
- Profile, Saved, and Cafe Detail use display-normalized cafe/user data and avoid fake/hard-coded identity labels unless editable or derived.
- The whole app feels like a personal coffee journal first, with social/cafe actions woven in quietly rather than exposed as database operations.
