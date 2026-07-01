# Mugshot Product Spec

Date: 2026-06-30

Purpose: summarize the product implied by the working web app and translate it into a native private-beta target. This is intentionally product-minded, not a full design spec.

## Product Thesis

Mugshot is a social coffee memory app. It helps people log what they drank, where they drank it, how it tasted, and which cafes are worth returning to. Over time it becomes a personal coffee map, a visual journal, and a lightweight social layer around taste.

The native iOS app already expresses the right core loop:

1. Find or choose a cafe.
2. Log a visit.
3. Rate the drink and experience.
4. Add photos and notes.
5. See visits in Feed, Map, Saved, and Profile.

The missing piece is durable identity and backend state.

## Primary Beta User

The first private-beta user is a coffee-curious person who:

- Visits cafes often enough to forget details.
- Takes photos of drinks or places.
- Wants to remember what was worth reordering.
- May care what friends tried, but does not need a full social network on day one.

## Beta Promise

The first iOS beta should promise:

```text
Log every coffee visit, remember what you loved, and build your personal cafe map.
```

Do not promise a complete social network until friends, visibility, comments, and notifications are real and tested.

## Core Objects

User:

- Auth identity.
- Username/display name.
- Profile metadata.
- Avatar/banner later.

Cafe:

- Place identity.
- Name, address, city, coordinates, external place id if available.
- Current user's state: favorite, wishlist, visited.

Visit:

- User.
- Cafe or non-cafe context.
- Drink type/subtype.
- Ratings.
- Overall score.
- Caption.
- Private notes.
- Visibility.
- Photos.
- Created timestamp.

Social interaction:

- Likes.
- Comments.
- Mentions.
- Friends and friend requests.
- Notifications.

## Native Private Beta Scope

Must ship for credible beta:

- Supabase auth/session restore.
- Profile bootstrap.
- Real Add Visit without photos, then with photos.
- Feed backed by real visits.
- Profile backed by real visits.
- Saved/favorite/wishlist persistence.
- Basic cafe detail and visit detail backed by remote data.
- Clear empty/error/loading states.
- Legal/privacy/about access before external distribution.

Should ship soon after:

- Edit profile.
- Avatar upload.
- Likes.
- Comments.
- Public user profiles.
- Friends list and requests.
- In-app notifications.

Should defer:

- Push notifications.
- Full Discover.
- Spin for a Spot.
- Feedback board.
- Advanced analytics.
- Postcard/share generator.
- Full Craft Sip system.
- Complex notification/privacy preference settings.
- Account deletion/data export until backend behavior is complete.

## What The Web App Contributes

The web app is valuable because it proves:

- The Supabase data model is already broad enough for the intended product.
- The social model exists: friends, requests, likes, comments, notifications.
- The visit model is richer than the local iOS model: photos table, rating templates, craft contexts, analytics.
- The map/saved/cafe detail loop already has backend concepts.
- Profile and media storage conventions already exist.

The web app should not be copied blindly. It should be mined for product intent and data contracts, then translated into native iOS patterns.

## iOS Product Shape

Keep:

- Native tab shell.
- Native MapKit feel.
- The existing Add Visit flow's calm, mobile-first structure.
- Local-first feeling while remote persistence is added.
- Ratings as a signature behavior.

Change:

- Replace local demo state with authenticated remote state.
- Make local seed/demo mode clearly separate from signed-in mode.
- Add profile/account flows.
- Hide or disable social controls until they have backend behavior.

Avoid:

- Building a marketing landing page inside the app.
- Recreating every web route as a native screen.
- Shipping fake settings toggles.
- Starting with social complexity before one real visit path is reliable.

## Open Product Decisions

1. Should iOS use Apple Maps place identity first, Google Places identity first, or a hybrid?
2. Should Craft Sip be part of the first private beta, or wait until cafe visits work?
3. Should everyone/public visits be visible by default, or should beta default to private/current-user?
4. Should friend-only visibility ship before the friend graph is fully testable?
5. Should feedback live in-app, or should beta feedback be collected outside the app?

