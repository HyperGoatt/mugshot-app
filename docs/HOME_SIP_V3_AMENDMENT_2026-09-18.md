---
document_type: decision_record
status: accepted
date: 2026-09-18
---

# Home Sip V3 direction amendment

This amendment supersedes the central-entry and composer portions of the earlier
Home Workbench direction. It does not replace the recipe library, immutable recipe
versions, account-scoped workspace, attribution, privacy, or historical attempts.

## Locked product decision

Home is a context inside the existing full-screen **Log a Sip** composer. Choosing
Home must never make the user leave that composer for a separate **What did you
make?** destination.

The default Home journey is setup-first:

1. **Setup (1 of 4):** resume active work, choose a usual or recipe, choose a
   method, create a recipe, or brew freely.
2. **Make:** optional adaptive guidance. This is not an extra numbered form.
3. **Capture (2 of 4):** optional media, editable sip name, and optional actuals
   or changes.
4. **Reflection (3 of 4):** the production Sip score, criteria, importance,
   Mugsy, flavor, and private-note UI, plus optional make-again intent and a
   next-time note.
5. **Saved (4 of 4):** a durable private result with repeat, share, save-as-recipe,
   comparison, history, and optional recipe-version actions.

**Already made it? Quick log** is always visible from Setup. It contains only
Capture (1 of 2) and Reflection (2 of 2), then reaches the same saved result.
Recipe selection never forces guidance.

## Save and share boundary

A Home attempt is locally durable before success is shown and before sharing can
begin. Rating, media, measurements, criteria, notes, and guided preparation are
optional for private journaling; only a sip name is required.

Share creates or reuses an idempotent publication draft and enters the standard
**Review Mugshot** surface. Publication still requires Mugshot's standard score,
caption, media or Mugsy placeholder, and audience. An explicitly selected recipe
version may be shared as Full details, Name only, or Do not attach. Linked recipes
never publish recursively. Private notes, next-time notes, inventory, local media
paths, and unselected instructions never enter the post payload.

## Method model

Recipes use one additive **Preparation** template for coffee, matcha, hojicha,
tea, components, complete drinks, and custom methods. Legacy Coffee recipes remain
readable without rewriting history. A string-backed method identifier preserves
known aliases and unknown/custom identities.

The catalog includes espresso, pour-over, AeroPress, French press, immersion,
moka pot, batch/drip, siphon, Turkish/ibrik, Vietnamese phin, pod/capsule, cold
brew, flash brew, percolator, cowboy/boiled, instant, traditional and shaken
matcha, matcha builds, whisked and steeped hojicha, hojicha builds, western tea,
gongfu, cold-brew and iced tea, chai concentrate, tea builds, milk/foam,
syrup/sauce/concentrate, tonic/soda, blended/frozen, complete-drink assembly, and
custom preparations.

Each method supplies an original Mugshot vector identity, a small set of useful
starting values, optional advanced fields, guidance behavior, relevant timing,
criteria suggestions, and a photo-free presentation. Custom fields keep stable
keys while their labels remain editable.

## Ownership and compatibility

The account-scoped Home workspace remains authoritative for recipes, immutable
versions, attempts, drafts, sessions, media, conflicts, and synchronization.
Targets remain frozen with a recipe version; actuals remain independent and
optional. Existing server workspace projections transport the additive fields,
so this amendment needs no destructive migration or speculative backfill.

Two data-preserving flags have separate jobs:

- `MugshotRoadmap.homeRecipes.v1` controls workspace/library availability.
- `MugshotRoadmap.homeSipV3Route.v1` controls the central Home composer route.

Disabling the route flag restores the previous central Home route without
deleting V3 data.

## Canonical design evidence

The approved 50-screen gallery is indexed in
[Home Sip V3 screen manifest](design/home-sip-v3-2026-09-18/SCREEN_MANIFEST.md).
The gallery is review evidence, not production navigation and not a requirement
that one user traverse 50 screens.

## iOS 27 compatibility gate

iOS 27 is the required current runtime for Home Sip V3. The candidate must not
fall back to iOS 26.3 to avoid an iOS 27 failure. On 2026-09-18, the focused
Home workspace suite passed 30 of 30 tests on a clean iPhone 17 Pro Simulator
running iOS 27.0. The central Home journey also passed setup-first routing inside
Log a Sip, and the quick path passed Capture 1 of 2 through an unrated,
photo-free private save. Direct rendering of Setup and Quick Log was inspected
on the same runtime.

This is iOS 27 runtime compatibility evidence using the repository's currently
installed Xcode 26.2 toolchain. It is not a claim that the app has been compiled
with a future Xcode 27 SDK, physically accepted on the owner's iPhone, or
accepted through TestFlight.
