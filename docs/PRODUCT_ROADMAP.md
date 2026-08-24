---
document_type: living
status: current
last_verified: 2026-08-24
---

# Product roadmap

## Now: real notifications and TestFlight learning

- Release the disposable-QA-verified badge-aware backend and canonical worker
  schedule to live before the iOS client depends on `push_badge_sync`.
- Physically accept sandbox and production APNs across foreground, background,
  terminated launch, deep links, badges, preferences, sign-out, and account
  changes.
- Keep in-app Activity independent from remote delivery.
- Preserve the alpha all-friends post experiment with category opt-outs; add
  per-friend mute only if feedback establishes a real need.
- Process TestFlight feedback through small, risk-classified fixes and update
  living documentation with each change.

## Current product foundation

The V3 guided sip loop, Home Workbench, Feed, Map, Saved, Journal, Taste
Passport, friends, collaborative lists, safety, public sharing, ownership,
widgets, and share extension are implemented foundations. Work in these areas is
feedback-driven hardening rather than an assumption that the surface is absent.

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
