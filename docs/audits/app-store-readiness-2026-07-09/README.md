# Mugshot iOS App Store Readiness Audit

Date: 2026-07-09  
Scope: live mobile PWA at `https://mugshotapp.co/`, current iOS private-beta branch, and the three most recent UI branches.

## Verdict

Mugshot has a distinctive, genuinely promising native visual system. It is **not App Store-ready yet**. The core journal loop works, but visible development content, developer-facing copy, incomplete privacy/account handling, and inconsistent media/state design would undermine first impressions and trust.

The right strategy is **polish and truthfulness, not feature expansion**. Keep the iOS launch promise narrow: *photograph a coffee moment, rate it, remember the cafe, and revisit your taste history.* Do not market it as a mature social network until the friend graph and notifications are real.

## Evidence and audit limits

### Captured flow steps

| # | Step | Health |
|---|---|---|
| 1 | PWA guest Friends feed | Good guest entry; clear value and sign-in CTA. |
| 2 | PWA Everyone feed | Functional, but public test data visibly hurts credibility. |
| 3 | PWA guest Add, Map, Discover, and Auth | Strong route-level gates and a clearer product map than iOS. |
| 4 | iOS Feed, loading to remote data | Functional, premium shell; test image/copy undermines it. |
| 5 | iOS Visit Detail, social actions, ratings, comments | Functionally capable; visual hierarchy and success context need work. |
| 6 | iOS Add Visit, top state and detail fields | Strong capabilities; too dense and exposes implementation language. |
| 7 | iOS Map, Saved, Profile, and Settings | Map is strong; Saved/Profile/Settings still show placeholder or incomplete product states. |

Screenshots are in `screenshots/`. The iOS build succeeded on an iPhone 17 simulator. The build emitted one warning for a retroactive `CLLocationCoordinate2D` `Codable` conformance. The XCTest run did not return within two minutes and was stopped; do not treat it as a passing test run.

The iOS run was already signed in. The live PWA was reviewed as a guest because no test-account credentials were present in the available task context. This is therefore a visual/flow audit, not a multi-account or complete accessibility certification.

## Branch read

- `codex/private-beta-readiness-2026-07-03` — current audited build. It has the real signed-in journal loop: auth/session restore, photo-backed visits, remote feed/detail, likes/comments, saved cafes, profile edit, and settings.
- `codex/unified-mugshot-ui-system` — the newest local descendant. It improves shared components and profile presentation, but does not close the product gaps. It also introduces a banner treatment before profile-media upload exists. Do not merge it wholesale as a substitute for launch polish.
- `claude/mugshot-ui-ux-revamp-design-system` — a large alternate styling pass. Mine reusable component ideas, but avoid merging an alternate shell wholesale; it increases visual churn without solving data quality, trust, or parity.

## Feature parity

| PWA capability | iOS state | Launch call |
|---|---|---|
| Guest routes for Feed, Add, Map, Saved, Profile | iOS has auth, but signed-out experience is a generic form rather than a coherent guest preview | Should improve soon |
| Public/Everyone feed | Present, remote-backed | Must fix data quality and scope labels |
| Friends feed and friend graph | Scope control exists; no native friends/requests surface or proven semantics | Optional for a journal-first launch |
| Discover: nearby cafes, friends activity, Spin for a Spot | Missing | Defer; it is feature breadth, not core retention |
| Add contexts: Cafe, Home, Travel, Other; Craft Sip | Cafe-focused only | Defer; keep the cafe visit loop focused |
| Rich rating templates and smart matching | Basic ratings exist | Should improve soon only if scoring is Mugshot's differentiated habit |
| Profile setup, avatar/banner, public profiles | Basic text edit only; no media/public profiles | Avatar should improve soon; banner/public profiles later |
| Likes, top-level comments, cafe save state | Present on remote visit detail | Must polish state changes and error/retry behavior |
| Notification center | Missing | Defer until the underlying social graph is tested |
| Cafe aggregates, friends-at-cafe, popular drinks | Partial/basic detail | Later |
| Share/postcard, feedback board, analytics | Missing | Later |

The PWA is product evidence, not a quality bar. Its live Everyone feed also exposes `Unknown` authors and `Codex ... smoke` test captions, so iOS must not copy that weak data hygiene.

## UI and UX findings

### What already feels right

- The cream, espresso, sage, and muted latte palette is calm and recognizable.
- Serif display headings work especially well on Feed, Profile, and Add.
- The floating iOS tab dock is more intentional than the PWA's standard bottom navigation.
- MapKit is a good native choice. The map search and restrained rating legend make the personal-cafe-map concept immediate.
- Add Visit has real structure: photo, cafe, drink, rating, caption, notes, and visibility. It is substantially more robust than a thin check-in form.

### Highest-impact visual problems

1. **Development content is user-facing.** The feed's hero image is a screenshot of the Add screen, captions include `Codex photo-required beta smoke`, and Saved contains lowercase cafe names and `0.0` ratings. This is the single fastest way to make a polished interface feel fake.
2. **The media treatment is inconsistent.** Feed/detail hero images, generic image placeholders, `No photo yet`, and literal `Photo loading` do not form a system. `Photo loading` is particularly damaging when it occupies a large cafe-detail hero.
3. **Add Visit is visually over-instrumented.** Its hero says `Supabase live` and `This posts to Supabase`, then repeats progress, required-photo state, and checklist chips. A customer should see “Saves to your journal,” not implementation details.
4. **Visit Detail has competing hierarchy.** The oversized photo is good, but the title overlays arbitrary photo content; the reopened detail still reads like a post-save confirmation. The lower action/ratings/comments cards are clean but visually isolated from the identity at the top.
5. **Saved is too much card UI.** Each compact cafe card asks the eye to parse thumbnail, score, address, tags, visits, Directions, Log Visit, and Details. Make Log Visit primary and move utility actions into detail/overflow.
6. **Profile is personal but generic.** The hard-coded “hidden gem hunter” chip and dot-based Taste Identity are not self-explanatory or convincingly user-derived. The newer branch's banner would add surface area without a real media-upload flow.
7. **Settings looks finished but is not launch-complete.** Privacy and Terms are short static copy, not accessible policies; Support has no visible fallback when email is unavailable.

### UX friction

- Guest PWA makes exploration and the value proposition easy. iOS asks for credentials before letting a new user understand the journal's payoff.
- The Add flow puts the disabled completion state and several requirements below the fold. Progress chips look interactive but do not act as shortcuts to the missing section.
- Feed's `Friends` and `Everyone` labels imply distinct social meaning before those semantics are credible. A `Following`/`Public` model should only ship when it has multi-account proof.
- Search/filter affordances are visible on Feed/Saved even where behavior is incomplete. Any dead affordance reads as unfinished.
- Like/comment/save are functional but visually quiet; completion states should be immediate, tactile, and unambiguous.

## App Store readiness blockers

### Must fix before launch

1. Remove all seed, QA, Codex, debug, placeholder, malformed-casing, and `Unknown` content from release data. Ship a clean empty state or a small curated demonstration set with real owners, photos, and copy.
2. Replace every developer-facing message: `Supabase live`, `Storage ready`, raw backend errors, and missing-config instructions must never reach a customer.
3. Create one state system for loading, empty, error, legacy-no-photo, unavailable, and disabled CTA states. Every state needs a clear next action or explanation.
4. Simplify Add Visit: one concise header, a persistent next-step CTA, tappable progress anchors, inline completion/error signals, and customer language. Keep photo required only if it is an intentional product requirement, and offer camera plus library.
5. Make Visit Detail truthful: show post-save success only immediately after creation; otherwise show a canonical journal entry. Guarantee readable title contrast over photos and give no-photo entries a designed identity.
6. Complete account and privacy basics. Apple requires an accessible in-app privacy-policy link, an App Store privacy-policy URL, and accurate App Privacy disclosures. Apps that support account creation must also let users initiate account deletion in-app. See [Apple's App Privacy guidance](https://developer.apple.com/app-store/app-privacy-details/), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), and [Apple's account-deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/).
7. Validate real-world failure paths: photo upload interruption/retry/cleanup, offline/slow network, no location, no search result, auth expiry, empty feed, and failed social action.

### Should improve soon

1. Replace initials-only identity with avatar upload; make a simple default avatar intentional until then.
2. Tighten Saved cards and normalize cafe display names. Use `Unrated` rather than `0.0` where no score exists.
3. Rewrite Profile Taste Identity as actual insights: favorite drink, favorite cafe, category mix, and a plain-language explanation.
4. Turn social controls into 44pt, clearly interactive controls with optimistic state, haptics, and recoverable errors.
5. Give signed-out iOS a small, browseable journal preview or an onboarding narrative equivalent to the PWA's guest gates.
6. Fix the Xcode warning and add stable UI tests for auth, Add validation, photo retry, feed states, and account-management flows.

### Nice to have later

- Discover/Spin for a Spot, Craft Sip, non-cafe contexts, public profiles, friends, notifications, replies/mentions, share postcards, analytics, and advanced cafe aggregates.

## Product direction

Make Mugshot feel like a **quietly excellent personal coffee memory book with a social layer**, not a small clone of a general social network.

The emotional cadence should be: *spot a drink → capture one beautiful photo → name the cafe → rate a few intentional qualities → save a memory → see the taste pattern grow.* Feed, map, and profile should all reinforce that same object. Social interactions are supporting proof, not the product's center of gravity.

Use the current iOS palette, typography, cards, and map as the foundation. Reduce ornamental cards in Add and Saved. Spend the next polish pass on content integrity, states, and response quality rather than new routes. Once every visible state looks deliberately authored—and the privacy/account path is complete—the app can feel cohesive, lovable, and ready to be judged as a real consumer product.
