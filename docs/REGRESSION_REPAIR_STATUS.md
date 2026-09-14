---
document_type: living
status: current
last_verified: 2026-09-14
---

# Regression repair delivery

Scope: product behavior, account-scoped state/media ownership, Supabase RPC and
push contracts, and privacy. Existing content and enforcement stay unchanged.
No TestFlight or App Store distribution.

## Implemented candidate

- Retained Map/Feed/Saved/Journal views, account reset, warm 60-second list reuse,
  background refresh preserving existing content, offscreen location guards.
- Protected image coalescing and 64 MB/80-image memory cache; 55-second grants,
  early renewal without downloading unchanged pixels, denial/account/block clear.
  Persistent image task container also covers initially empty banner content.
- Activity and push actor/action copy with no private text, stable history and
  routes; retired technical screening alerts suppressed from consumer lists.
- Comment/reply author IDs and avatar/name profile actions.
- Post details omit routine sharing-status requests and banners; caption body,
  journal subheadline, unchanged Feed typography and serif journal family.
- Authorized reaction counts and paginated people with All/type filters, stable
  account IDs, profile navigation and historical Likes.

## Verification gates

- Passed generic Debug iOS build and generic Simulator app/test compilation.
- Passed isolated PGlite reaction pagination/filter/count/access/history checks.
- Passed nine push worker tests including final authorized title/body and badge.
- Joe's stored banner, profile projection, media permission and original 2048x1366
  JPEG verified; runtime rendering acceptance remains pending.
- Full static runner exposed a pre-existing July fixture missing the September
  moderation wrapper; fixture now applies that wrapper and grants before its
  unchanged safety expectations. The entire hermetic database suite passes.
- Consolidated Simulator: 32 focused tests passed (image coalescing, renewal,
  denied authorization, account clearing, post presentation and Activity routes).
  Two UI journeys passed: post-detail disclosure and four rounds of Map/Feed/
  Saved/Journal switching followed by working profile/settings navigation.
- Production migration 171 and `deliver-activity` deployed. Fresh transaction
  fingerprints prove all 72 original public/Auth/Storage tables unchanged;
  bucket visibility unchanged. No notification history rewrite or replay.
  Latest 50 Activity events contain zero generic titles; actor/action examples
  and five reaction-count samples passed; original banner authorization passes.
  One retired service alert remains retained in audit storage.
- Production-connected Debug 0.5.3 build 6 installed and launched successfully on
  Joe's iPhone (`co.mugshot.app.dev`).
- Owner acceptance, physical 200 ms warm-tab target, real push receipt, and
  full live-account reaction/profile round trips remain unverified. The Simulator
  rendered the detail fixture at accessibility XXXL; this is not a complete
  accessibility certification. No paid QA branch was created.

## Consolidated acceptance matrix

Use isolated fixtures for writes, access denial, blocking, refresh failure and
account switching. Verify tab content/scroll retention; authorized banner/avatars;
comment and reaction profile round trips; reaction add/change/remove/failure;
All/type pagination; expired/denied images; Dynamic Type; no routine status banner.
Production data verification is read-only except the authorized migration and
worker deployment. Preserve current public/Auth/Storage row fingerprints inside
the deployment transaction. No disposable paid resources are required.

## Owner walkthrough after installation

Open Activity and tap a recent event. Open your profile banner. Visit Feed,
Journal, Saved and Map twice. Open a comment author's avatar/name, then return.
Open the reaction totals, filter a type and visit a person. Compare the larger
caption with collapsed/expanded journal text. Hardware delivery and acceptance
must be recorded separately from compilation and Simulator evidence.

## Accepted-layout polish — 2026-09-14

Owner feedback confirms the repair is working. The follow-up moves reaction
totals into the action row before Save and replaces the Yummy cutlery icon with
a coffee mug. Tier 1 Debug compile, scoped diff and documentation checks passed.
The updated dev build is installed on Joe’s connected iPhone; this placement
awaits owner visual acceptance. No backend changes or distribution.
