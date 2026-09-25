---
document_type: living
status: current
last_verified: 2026-09-25
---

# Product roadmap

## Launch quality is the active product gate

Finish Home Sip V3, then freeze feature additions except repairs needed for an
existing journey. Every visible iPhone feature stays in scope. The
[launch quality audit](LAUNCH_QUALITY_AUDIT.md) is the current numbered issue
ledger and exact-candidate acceptance matrix. No P0–P2 issue may remain at
submission. The iPhone-only target and clearer queued-import receipt are
implemented on the audit branch; complete package, hardware, backend, and
replacement-TestFlight acceptance remain open.

## Home Sip V3 implemented; acceptance is the active gate

The complete find/create → make or quick log → reflect → privately save → improve
→ optionally share loop is implemented in current source. Central Add > Log a
Sip > Home stays inside the production composer and opens setup-first; its visible
quick shortcut contains only Capture and Reflection. Journal > Home retains the
full My makes / Recipes workspace. The catalog now includes coffee, matcha,
hojicha, tea, components, complete drinks, and custom preparations. Existing
Home data, immutable versions, privacy, and Journal collections remain intact.

The next product gate is one consolidated Tier 4 runtime acceptance pass followed
by owner-promoted physical testing. The already-distributed TestFlight 0.5.3 (8)
still contains its historical placeholder; replacement upload remains a separate
explicit authorization and release gate.
[Implementation evidence and rollout requirements](HOME_RECIPES_IMPLEMENTATION.md).

## Now: real notifications and TestFlight learning

- Finish signed-device alert, app-icon badge, terminated-tap, category, and
  sign-out acceptance for the implemented `push_badge_sync` lifecycle. The
  immediate Feed unread-count issue found during the first real delivery is
  fixed and physically verified.
- Physically accept sandbox and production APNs across foreground, background,
  terminated launch, deep links, badges, preferences, sign-out, and account
  changes.
- Keep in-app Activity independent from remote delivery.
- Preserve the alpha all-friends post experiment with category opt-outs; add
  per-friend mute only if feedback establishes a real need.
- Process TestFlight feedback through small, risk-classified fixes and update
  living documentation with each change.
- Complete connected-iPhone runtime acceptance for the locally accepted
  44-report remediation branch, release the additive reaction contract through
  disposable QA before client reliance, and keep every report open until
  replacement-build acceptance.

## Current product foundation

The V3 guided sip loop, Home Workbench, Feed, Map, Saved, Journal, Taste
Passport, friends, collaborative lists, safety, public sharing, ownership,
widgets, and share extension are implemented foundations. Work in these areas is
feedback-driven hardening rather than an assumption that the surface is absent.

## People discovery Option 1 redesign; device acceptance pending

- The selected Option 1 People hub is implemented: requests first, private
  one-contact Messages invitations, share/QR, a horizontal reasoned suggestion
  rail, and friends/sent lists. `people_v2` combines mutual, shared-context, and
  recent visible interaction signals without contact or phone-number matching.
- The client, visual comparison, and hermetic backend contract are locally
  verified. The additive `people_v2` migration is production-configured and its
  live output/defaults plus protected row-count preservation are verified.
  The exact source is installed and launched on the connected iPhone. Remaining
  gates are hands-on interaction acceptance and a separately authorized
  replacement TestFlight.

## Next after notification acceptance

- Improve search and cafe identity when TestFlight evidence identifies concrete
  duplication or discovery failures.
- Refine Home recipe reuse and comparison from real repeated-brew behavior.
- Improve sparse social states while preserving independent Journal value.
- Complete accessibility, performance, and reliability fixes surfaced by the
  distributed build.
- Use cautious Taste Passport and recommendation improvements only when their
  explanations remain inspectable and private inputs remain protected.

## Deferred

- Per-friend push controls without noise evidence.
- Merchant rewards, payments, loyalty, or partnership systems.
- Popularity rankings, follower-pressure mechanics, consumption streaks, or
  notification-open optimization.
- Broad AI inference that invents taste facts, edits private content without
  confirmation, or publishes for a user.

## Go/no-go signals

- Reconsider all-friends push if roughly 20% disable all notifications or
  repeated tester feedback calls it noisy.
- Stop rollout for privacy, account isolation, destructive-flow, data-loss, or
  migration-safety regressions.
- Do not widen distribution until signed-device core journeys and current
  backend gates are green.
