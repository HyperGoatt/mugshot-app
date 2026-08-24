# Mugshot Home Workbench — Cafe Spine Revision

This eight-frame production mockup is the revised visual source of truth for the Home Log a Sip journey. It preserves Mugshot's current Cafe creation and publishing grammar while moving Home preparation ahead of capture and taste.

## Six product stages

1. **Log a Sip / Home Workbench** — Keep the existing `Cafe / Home / Elsewhere` pill exactly. Selecting Home replaces everything below the pill with the Home Workbench; there is no separate context-choice screen.
2. **Brew** — Read the chosen recipe while brewing, then record actual values and compare them with the source recipe before capturing the cup.
3. **Capture** — Rejoin the Cafe creation spine: photos and Poster, public caption, then drink name.
4. **Rate and remember** — Use the current Sip score, private journal, optional criteria, method-aware suggestions, and Home-only make-again intent. Then make the recipe version decision.
5. **Review Mugshot** — Use the current Cafe Review Mugshot layout with one compact Home brew summary and independent recipe privacy.
6. **Published Mugshot** — Open the canonical owner post with `Published to your journal`; make Share a visible secondary action from the finished Mugshot.

## Locked corrections

- The Home Workbench is the content beneath the existing Home pill, not a new first screen.
- Planned recipe values stay read-only while brewing. Actual values and deltas are captured immediately after the brew.
- Comparisons describe correlation only and never claim what caused the result.
- Photos, caption, and drink name come after actuals and before taste.
- The Sip screen has no `Criteria average / Your Sip score / Use average` card.
- A manually chosen score is the restorable baseline. Once numeric criteria are rated, those ratings update the displayed stars automatically; clearing all rated criteria restores the manual baseline.
- `Would you make it again?` remains separate from score math.
- The recipe screen contains only the recipe decision: keep the immutable source version or create a new immutable version.
- Review and published states reuse the Cafe Mugshot spine. Journal-note and recipe visibility remain independent from the post audience.

## Method-aware tasting suggestions

Suggestions are ranked, optional starting points. Mugshot never fills in the user's ratings.

| Selected method | Suggested criteria to prioritize |
|---|---|
| Espresso | Crema, extraction, sweetness, acidity, body, balance, finish |
| Pour-over / Chemex | Clarity, brightness, aroma, sweetness, balance, body, finish |
| AeroPress | Balance, body, clarity, acidity, texture, finish |
| French press / immersion | Body, texture, sweetness, balance, aroma, finish |
| Moka pot | Intensity, bitterness, body, balance, sweetness, finish |
| Cold brew | Refreshment, strength, sweetness, clarity, body, finish |
| Batch brew | Freshness, balance, temperature, body, aroma, value |
| Pod | Consistency, coffee presence, strength, body, finish, value |
| Custom | Drink-type suggestions, pinned criteria, and the user's recent setup |

Drink analysis can refine this ordering. For example, an espresso milk drink should prioritize milk integration, texture, coffee presence, sweetness, and temperature. Pinned criteria and the user's explicit prior setup should remain available without copying prior ratings.

## Continuous mock data

The flow uses Little Wolf Shantawene, Espresso, Recipe v3, Niche Zero, and Decent DE1. The plan is 18.5 g in, 40 g out, grind 17, 94 °C, and 28 seconds. The actual brew is 18.5 g in, 42 g out, grind 17, 94 °C, and 30 seconds, producing a computed 1:2.3 ratio and an optional Recipe v4.
