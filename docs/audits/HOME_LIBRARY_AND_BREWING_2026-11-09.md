---
document_type: historical
status: verification-checkpoint
date: 2026-11-09
---

# Home library and repeat brewing verification

> Follow-up: [development iPhone installation and launch](HOME_LIBRARY_PHONE_2026-11-09.md).
> The original Simulator checkpoint is preserved below.

Current behavior: [Home recipes and brewing](../HOME_RECIPES_IMPLEMENTATION.md).
Scope: [approved recommendations](HOME_PERSONA_WALKTHROUGH_2026-11-09.md)
and [implementation plan](../plans/home-library-and-brewing-2026-11-09.plan.md).
Candidate branch: `codex/home-library-flow`, held draft PR #109.

| Walkthrough | What to verify |
| --- | --- |
| First visit | Saved opens the one Home library; Journal is a shortcut to it. An empty shelf gives a local starter and a recipe capture action. Bag entry needs only a name. Neither a home nickname nor equipment is required. |
| Capture and reuse | External search announces the browser. Link, screenshot, clip, caption and manual paths share the recipe editor. An idea can be saved without a brew; a ready recipe can be made. The shelf opens and closes detail directly. Recipe kind is editable. A drink can reference a base or add-in, switch the linked version and keep the amount. Serving scaling leaves source versions intact. |
| Organize and prepare | Pinned recipes, sorts, filters, no-match reset and archived restore live on the shelf. Bags and gear each manage their own archive, with filters and sort suited to the item. Preferences set defaults; the applied inputs and today's edit are visible before making. |
| Make and log | A tea or matcha starter needs no account, inventory or Luna. Quick opens name/photos, and guided opens one instruction and its next action. Timers and explanations stay next to the instruction. Both routes use shared rating and review and can save privately without a photo or rating. |
| Compare and repeat | Saved Home detail shows the frozen plan, recorded actuals and the last compatible attempt where measurements exist. Unknowns stay blank. Make again starts a private draft with the same plan or one explicit change. Written instructions and timers stay together. |

## Boundaries reviewed

- Recipe and part references resolve the exact version, including retained
  versions. Today's values, actuals and repeats copy into the owner's draft;
  the existing recipe and default settings stay intact.
- Comparison and repeat require the current owner scope. Similar names alone
  cannot compare different recipe versions, a serving with a whole batch, or
  different measurements or units. No comparison enters a public post.
- Private review and the separately previewed share audience remain distinct.
  Navigation and scope fences prevent a late photo save from being applied to
  a different draft or account.
- Capture remains useful with no AI or network. Speech is opt-in for the current
  video; disabling it retains frame/caption text and fences late speech and
  assistance results. Optional brew assistance receives selected recorded facts;
  it cannot write actuals or publish.

## ECC verification

- RED reproduced missing sort/filter behavior, recipe readiness and composition
  boundaries, starter edit propagation, and late speech acceptance. Focused
  GREEN checks exercise those paths and localized numeric entry.
- Screen recordings showed input losing its final character on keyboard
  dismissal. The setup nickname uses a single-line field, and the repeat amount
  keeps its editing buffer in UIKit and commits before closing the keyboard.
  The screen checks assert the full input before and after Done.
- The combined candidate builds and passes 185 native cases in 13 suites on
  an iPhone 17 Pro Simulator. They cover owner scope and recovery, versioned
  references, inventory filtering, saved/draft state, compare and repeat,
  and offline/link/video source fallbacks.
- Sixteen distinct screen journeys passed across the candidate and targeted
  retries. They cover the empty shelf, standalone inventory, named preferences,
  direct recipe detail, no-match reset and archive restore; discovery, manual
  and caption entry, large text, syrup reuse and matcha; both start intents,
  private review Back and unrated save, and context and autosave continuity.
  The latte journey verified an explicit 18 g actual in the private comparison
  and a 40 g yield in the repeat guide. Native tests exercise Last time
  selection and its version and unit boundaries.
- Repository diff and documentation checks pass. The previous physical
  acceptance describes an earlier build.

Verification uses a disposable iPhone Simulator app with synthetic data, an
invalid backend and analytics disabled. It does not modify the owner's phone,
saved recipes or posts. Supabase deployment, physical acceptance and TestFlight
are separate release gates.
