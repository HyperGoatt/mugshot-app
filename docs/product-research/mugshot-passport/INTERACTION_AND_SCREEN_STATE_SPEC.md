# Mugshot Passport — Interaction and Screen-State Specification

**Status:** Selected product direction · **Visual source of truth:** Living Atlas · **Implementation status:** No code authorized

**Storyboard:** [Living Atlas seven-surface storyboard](visuals/living-atlas-seven-surface-storyboard.png)

## Experience contract

Mugshot Passport is one living, explainable portrait of a person’s coffee life. It is not a score, profile quiz result, second post-publish destination, or static label. The owner should be able to recognize the portrait quickly, explore the memories behind it, correct it, and decide what may be shared.

The core loop is:

**Journal evidence → cautious pattern → recognizable memory → owner correction → better future pattern**

The visual metaphor is an editorial memory atlas. A geographically nonliteral route connects photo memories from cafes, Home, recipes, and Elsewhere to the patterns they support. The route communicates continuity, not exact travel or location history.

## Surface map

| Entry point | Surface | Required behavior |
| --- | --- | --- |
| **Journal → Passport** | Full owner Passport | Canonical destination. Journal uses **Memories / Passport** as peer views. |
| **After publishing** | Passport update receipt | Summarizes the new entry’s effect and links into the relevant pattern. Never renders a second full Passport. |
| **Owner Profile** | Compact shared-cover preview | Shows what other people may see and opens the canonical owner Passport or sharing controls. |
| **Another person’s Profile** | Shared Passport projection | Shows only descriptors and memories that are safe for that viewer. |
| **Deep link** | Pattern detail or shared cover | Restores the intended destination after access is checked; falls back safely if access changed. |

## Screen 1 — Living Atlas home

### Purpose

Answer “What does Mugshot understand about me?” in under ten seconds, then make the evidence inviting to explore.

### Anatomy, top to bottom

1. **Context chrome**
   - In Journal: the existing Journal header and **Memories / Passport** switch; no redundant back button.
   - From a deep link or publish receipt: back or close returns to the exact origin.
   - Audience control shows **Everyone, Friends,** or **Private** and opens the sharing preview.

2. **Passport signature**
   - A one-sentence synthesis, such as **“Bright, textural, and quietly ritual-driven.”**
   - A quiet **Updated Jul 23** label.
   - No archetype title, number, percentile, or “one of 512” language.

3. **Three lenses**
   - **You reach for** — recurring choices.
   - **You notice** — sensory attention.
   - **You return to** — rituals, places, recipes, and contexts.
   - Each lens shows one short claim and a confidence word.

4. **Where your patterns live**
   - A privacy-safe route connects three to five photographic memory pins.
   - Default filter is **All memories**. Alternatives are **Cafes, Home, Recipes,** and **Elsewhere** when evidence exists.
   - Labels use the least revealing useful place name and a date, never an exact address.

5. **What this says about you**
   - Shows the currently selected pattern, confidence word, evidence-family summary, and **Why am I seeing this?**
   - A compact update strip appears only when something changed since the last visit.
   - Primary action: **Explore this pattern**.

### Interaction rules

- Tapping a lens filters the route and selects its strongest current pattern without leaving the screen.
- Tapping a photo pin selects it and reveals a compact memory preview. Tapping that preview opens the existing journal-entry detail.
- The atlas is not pannable or zoomable. It behaves like editorial evidence, not a literal map.
- Changing the memory filter preserves the selected lens when possible. If no matching evidence remains, the first supported pattern is selected.
- **Explore this pattern** pushes Pattern Detail.
- Pull to refresh is allowed, but the last safe projection stays visible while refreshing.
- The route, stamp, and watercolor forms are decorative and never carry unique meaning.

## Screen 2 — Pattern Detail

### Purpose

Turn a summary claim into an understandable story with evidence, counter-evidence, context, and owner control.

### Anatomy

- **Observation:** one plain-language statement, never a diagnosis or fixed identity.
- **Confidence:** **New clue, Taking shape, Well established,** or **Changing**, followed by one sentence explaining what that word means.
- **Seen most when:** context chips derived from time, setting, method, or occasion.
- **Evidence trail:** two to five tappable journal memories with photo, drink, high-level place, date, and the specific signal that contributed.
- **What complicates it:** contradictory or narrowing evidence when present. Mugshot should show uncertainty rather than silently average it away.
- **What could help:** one optional reflection prompt or suggested next experiment.
- **Owner controls:** **This fits**, **Not quite**, and **Keep this private**.
- **Explanation:** persistent **Why am I seeing this?** link.

### Interaction rules

- Evidence rows open the existing memory detail and return to the same scroll position.
- **This fits** strengthens owner confidence but does not fabricate additional behavioral evidence.
- **Not quite** opens the correction sheet.
- **Keep this private** removes the pattern from shared projections immediately while preserving it for the owner.
- A pattern with no remaining eligible evidence disappears from the active Passport and moves to a private correction history; the UI confirms this without punishment or loss framing.

## Screen 3 — Why am I seeing this?

Present this as a readable sheet, not a technical model report.

1. **What Mugshot noticed:** the contributing evidence families.
2. **Examples:** the specific owner-visible memories behind the statement.
3. **What the confidence word means:** a human explanation of recurrence, time, and variety.
4. **What was not used:** likes, follower activity, friend ratings, popularity, demographic inference, and unrelated behavior.
5. **What stays private:** which source fields and memories are excluded from shared projections.
6. **Make it yours:** direct routes to correction and audience controls.

Do not expose model weights, raw confidence percentages, internal prompt text, or a false causal explanation. If Mugshot cannot explain a pattern from retained evidence, it must not show the pattern.

## Screen 4 — Correction sheet

### Options

- **Not true for me**
- **Used to be true**
- **Only true in a certain context**
- **The wording feels wrong**
- **This memory should not count**

Context-specific correction asks for one optional qualifier, such as **only at cafes**, **only in summer**, or **only with milk drinks**. Wording correction accepts the owner’s short replacement phrase.

### Result

- Apply the visible change immediately.
- Show a reversible confirmation with **Undo**.
- Preserve a private audit record so future recalculation respects the correction.
- Never ask the user to defend a correction or complete a survey.
- A corrected phrase is owner-authored content. Sharing it requires the same Passport audience check as any generated statement.

## Screen 5 — Sharing preview and audience

Tapping the audience control always opens a preview before the first external exposure.

### Preview contents

- The exact signature and lens statements the selected audience will see.
- Only photos and memories already visible to that viewer class.
- A plain list titled **Not shared** covering private notes, exact evidence counts, hidden memories, exact addresses, companions, recipe details with narrower permissions, and correction history.

### Audience behavior

- Options are **Everyone, Friends,** and **Private**.
- To preserve the current alpha direction, **Everyone** may be preselected for a new Passport, but nothing becomes externally visible until the owner confirms the first preview.
- Later audience changes affect only the Passport projection. They never widen the audience of a sip, photo, recipe, caption, or private note.
- If a statement no longer has enough share-safe support after private evidence is removed, omit it from the shared projection rather than exposing a weaker guess.
- Saving requires server confirmation. On failure, keep the previous audience and explain that nothing changed.

## Screen 6 — Post-publish Passport update

The publish flow ends with a compact receipt above the normal completion action. It must classify the entry as exactly one primary state:

| State | Meaning | Example copy |
| --- | --- | --- |
| **No change** | The entry is saved but does not alter a visible pattern. | “Saved. Your Passport is still learning from this one.” |
| **Strengthened** | It reinforces an existing pattern. | “Your love of clarity is taking shape.” |
| **New clue** | It creates an eligible early observation. | “Quiet Home recipes may be joining your ritual.” |
| **Nuanced** | It narrows or adds context to a pattern. | “Fruit-forward shows up most in cold drinks.” |
| **Fading** | Recent evidence meaningfully weakens an older pattern. | “Your usual milk-drink pattern is changing.” |

The receipt shows one supporting photo or fallback, the affected pattern, a confidence word, and **View in Passport**. If several patterns changed, show the strongest user-relevant update and summarize the rest as **Two more updates** inside the canonical Passport.

Closing the receipt returns to the published Mugshot or origin. **Pour another one** remains optional.

## Screen 7 — Shared viewer Passport

The viewer sees the same brand and three-lens structure, but a deliberately smaller projection:

- signature and eligible lens statements;
- confidence words without counts or model detail;
- shared memory photos already available to that viewer;
- **Why you can see this** privacy explanation;
- no correction controls, private route segments, private context, or owner-only next steps.

Private, insufficient, blocked, unavailable, and access-revoked conditions all use the same neutral viewer state: **“This Mugshot Passport is not available.”** The UI must not reveal which privacy rule applied.

## State model

| State | Owner experience | Viewer experience | Primary action |
| --- | --- | --- | --- |
| **Loading** | Branded skeleton preserving the final layout; no guessed copy. | Same. | None |
| **No entries** | Mugsy with journal notebook, “Your Passport starts with a memory,” and a brief explanation. | Unavailable. | **Log a sip** |
| **Learning** | Route shows real memories; lenses say what Mugshot is learning without identity claims. | Unavailable. | **Add another memory** |
| **Formed** | Full Living Atlas and supported patterns. | Safe shared projection if permitted. | **Explore this pattern** |
| **Changing** | Existing claim remains visible with **Changing** and recent contradictory evidence. | Show only if still safely supported. | **See what changed** |
| **Corrected** | Owner wording or scoped qualifier is visible and marked **Edited by you**. | Show only if audience permits owner-authored copy. | **Review correction** |
| **Pattern hidden** | Removed from current Passport; available in private correction history. | Never visible. | **Undo** immediately after change |
| **Refreshing offline** | Last verified Passport remains with **Saved copy · may be out of date**. | Last verified viewer-safe projection only if policy permits caching. | **Try again** |
| **Hard failure** | No partial inference; explain that the Passport could not load safely. | Neutral unavailable state. | **Try again** |
| **Audience save failed** | Previous audience and preview remain intact. | No access change. | **Try again** |

## Evidence-to-interface rules

| Evidence family | Eligible sources | Owner Passport | Shared Passport |
| --- | --- | --- | --- |
| **Choices** | Drink, category, bean, method, additions, reorder intent | Claims about what the person tends to choose | Only from entries visible to that audience |
| **Sensory** | Criteria, ratings, flavor selections, owner wording | Claims about what the person notices | Summary only when share-safe support remains sufficient |
| **Affect** | Overall enjoyment and make-again intent | Adds strength or contradiction; never shown as expertise | No raw scores or private counts |
| **Ritual and context** | Cafe/Home/Elsewhere, time band, occasion, return behavior | Contextual pattern and atlas grouping | Coarsened context; no exact time, address, or companion |
| **Craft** | Recipe versions, method, repeat experiments | Home and recipe patterns | Only details whose recipe audience independently permits them |
| **Memory** | Photos, captions, saved places, repeat visits | Evidence trail and atlas pins | Only memories already visible to that viewer |
| **Private narrative** | Raw journal notes | May inform an owner-only observation when explicitly enabled | Never used to generate a shared statement |
| **Social activity** | Likes, comments, follower behavior, friend scores | Never used | Never used |

Owner and shared Passports are projections of one canonical Passport identity, but they are not produced by hiding rows after generation. Shared statements must be recomputed or revalidated from audience-eligible evidence so private information cannot leak through a summary.

## Confidence and freshness language

- **New clue:** supported enough to mention, but not enough to generalize.
- **Taking shape:** recurring across time, contexts, or evidence families.
- **Well established:** durable across a meaningful span and still current.
- **Changing:** recent evidence materially diverges from an established pattern.

These are visible product semantics, not public numeric thresholds. Internal thresholds must require distinct memories, resist duplicate or imported-entry inflation, weight recency cautiously, and preserve owner corrections. No confidence state is permanent.

## Visual, motion, and accessibility behavior

- Use the selected cream, foam, espresso, sage, mint, and sand palette with editorial serif headlines and readable system sans body text.
- Keep the atlas airy. Use three to five visible photo pins; additional evidence belongs in Pattern Detail.
- Route drawing may animate once on first formation or meaningful change, then remain still. Use a short draw and gentle photo fade, never confetti or continuous motion.
- With Reduce Motion, replace route drawing and sheet movement with immediate state changes or a short crossfade.
- VoiceOver reads signature, lenses, selected pattern, then evidence list. The decorative route is hidden.
- Every photo pin must have an equivalent accessible list item and meaningful label.
- At larger Dynamic Type sizes, replace the spatial atlas with a vertical chronological evidence trail.
- Minimum touch target is 44 × 44 pt. Confidence always has a text label; color is supplementary.
- Mugsy appears only in No entries, Learning, correction reassurance, or a rare formation milestone—not as persistent decoration.

## Acceptance criteria for the future build

1. A first-time owner can describe all three lenses after one glance.
2. Every visible pattern has an explanation, eligible evidence, and a correction route.
3. Selecting a photo pin can reach the originating journal memory and return without losing context.
4. A post-publish receipt links to the exact affected pattern and never creates a second Passport.
5. Viewer projections cannot expose private notes, exact hidden evidence, precise locations, companions, or narrower-audience recipes.
6. An audience failure leaves prior access unchanged.
7. Sparse evidence never produces a confident identity statement.
8. Social popularity never changes a personal pattern.
9. The full experience works without route animation, map gestures, or color-only meaning.
10. All product copy uses **Mugshot Passport**; **Taste Passport** and the Taste Bloom/radar visualization are removed from this experience.

## Product analytics

Measure the value loop without recording private content:

- Passport opened from Journal, Profile, or publish receipt;
- lens selected;
- pattern opened;
- evidence memory opened;
- explanation opened;
- correction started, applied, undone, or dismissed;
- sharing previewed and audience confirmed;
- post-publish update followed into the Passport;
- meaningful Passport return within 30 days.

Do not log raw note text, generated pattern copy, photo contents, exact location, correction wording, or private evidence identifiers in general analytics.
