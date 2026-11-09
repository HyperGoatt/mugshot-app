---
document_type: historical
status: simulator-walkthrough
date: 2026-11-09
---

# Home library and Log a Sip: two ways through

> Current implementation: [Home library and repeat brewing](../HOME_RECIPES_IMPLEMENTATION.md#home-library-and-repeat-brewing--november-9-candidate).
> The original walkthrough and its limited Simulator evidence below are preserved.

Walkthrough baseline: `bcd5400` on `codex/home-library-flow`, with the
[ordered plan](../plans/home-persona-audit-2026-11-09.plan.md) and
[September Home interview read-back](../product-research/home-sip-v4/README.md).
These are two role-played walkthroughs in the native app with synthetic data,
not interviews with two new participants.

**Recommendation:** Keep one Home library. Make **Saved → Home library** the
primary door for things to use next time. Keep the Journal link as a shortcut
to the same library; use Journal itself for completed sips and making one
again. Saved lets a guest manage their library. Journal asks that guest to
sign in. Add → Home should remain the shortest way to use a recipe today.

## New to coffee and uncomfortable with app menus

Goal: save a tea recipe, make it with instructions, or record what I already
made. I have no saved bags, gear or named setup.

| Touchpoint | What I encounter | What would make it clearer |
| --- | --- | --- |
| Saved → Home library | The entrance is visible above the cafe filters. Once inside, an empty Drafts card and two rows of pills compete with three ways to start a recipe. | Keep the entrance. With an empty shelf, offer **Try a starter recipe** and **Save a recipe you found**. Show draft count and recipe filters when there is something to act on. |
| Find / Add a recipe | Find offers suggested search terms and **Search the web**, plus a path back into capture. Add offers link, screenshot, video, caption, name and a second entry to the drink builder. A name can save an idea without enough instructions to make it. Closing its detail takes Back to Recipe Book and then Done to get to Home library. | Say when a button leaves Mugshot. Put the four source choices behind one **Save a recipe** action. Offer **Type it in** explicitly, with **Save for later** for an idea and **Make this** when steps are ready. Return directly to the originating shelf from detail. |
| Recipe kinds / Build a drink | **Drink**, **Component** and **Brew** ask me to understand the library's taxonomy before I know what I have. The builder makes sense once I know what a base and a saved part are. | Give examples at the point of choice: **Whole drink** (iced latte), **Add-in** (syrup or foam), **Brew recipe** (espresso or tea). Suggest a kind after capture and let me change it. |
| Beans / Gear / Preferences | A bag and a tool can be added without opening Add. The bag editor starts with five labels including **Process**. Preferences explains optional setups, but it is the only library section where the meaning of a Home setup is visible. | Start manual bag entry with **Name on the bag**, then reveal optional bag details. Explain **Made at Home** as a nickname and tools if wanted. Keep every library item optional for logging. |
| Add → Home | The biggest action says **Log this sip**, while **Make with guidance** is disabled before choosing a starter. I have to infer which action helps me make the drink and which assumes it is already made. | Give me two clear intentions: **Help me make it** or **I already made it**. Let a starter answer the first choice and let the quick path go straight to the drink name/photo. Keep photo and rating optional for private Home saves. |
| Make → Capture → Rating → Review | Instructions and shared rating/review are useful. A novice can interpret measurements as a required test or confuse **Log** with **Share**. | Offer one instruction and one clear next action at a time. Keep **Measurements** as an optional detail and say **Save to Journal · Private** at the end. Preview the visibility of the saved sip before sharing. |

Where Mugshot helps: one reliable starter, what to do next, a timer when one
is useful, and a short explanation of a term at the point it appears. A tea or
matcha should get the same welcome as espresso. None of these require Luna.

## Experienced brewer dialing in a drink

Goal: find my usual brew, combine a saved blueberry syrup with a latte, choose
the beans/tools I actually used, and remember what to try on the next one.

| Touchpoint | What I encounter | What would make it better |
| --- | --- | --- |
| Recipe shelf and sorting | All / Drink / Component / Brew are filters. Search matches names. Pinned recipes come first; the remaining order uses last used, falling back to version creation. There is no explicit Home recipe sort menu. A search with no matches uses the same empty-library message as a new shelf. The archived recipe list lives in the nested Recipe Book. | Label the default order. Offer **Recently used**, **Newest**, and **A–Z**, with pins visible and method filters when the shelf warrants them. Show **No recipes match** and **Clear filters** for a filtered empty result. Surface restore in the main library. |
| Beans and gear | Bags are shown newest updated first; gear has no user sort. A single state value drives both archive switches, so changing it for bags can also reveal archived gear. Bean details already have useful depth: process, roast date, status and optional weights. | Separate archive visibility. Offer bag status and sort by roast date or name; let gear filter by role or setup. Show an unknown roast date honestly. Keep these options off the first-use path. |
| Preferences and selecting a setup | Favorite method and go-to beans are defaults for fresh setups. A named setup carries its own gear; a saved recipe keeps its saved details. The precedence is not obvious at the point of use. | Show what applied in a compact line such as **Brew bench · Alto decaf · Grinder**, with one **Change for this brew** action. Make it clear whether an edit applies today, to the default, or to a new recipe version. |
| Build a drink | The linked part is genuinely reusable. A drink can use 15 ml of syrup, open the syrup's original instructions, and return with its quantity intact. The batch is not changed by a per-drink edit. | Keep that model. Make **Base**, **Milk**, and **Add-ins** distinct on the canvas. Show source and version on linked parts and give an obvious way to switch a linked part without remaking the drink. |
| Guide, actuals and next try | Planned targets, optional measurements, and the common review are available. It takes effort to connect this result with the previous one. | Put **Plan → Actual → Last time** on the saved sip when comparable values exist. Keep unknown values blank. Add a quick **Make again** with one intentional change. Preserve recipe version and exact units. |

Where Mugshot helps: calculate ratios and serving quantities locally, keep
recipe versions and guide steps stable, and compare like with like. Luna can
optionally explain a measured difference or propose one small next trial
grounded in the user's recorded results. It should never fill in an unmeasured
value, infer espresso extraction from a flavored latte alone, or stand between
the user and Save.

## What to do next

1. **Make the first Home choice unambiguous.** Prototype the two intentions
   with a first-use tea recipe and no inventory. Check one-handed reach and
   larger text. Success: the person can choose instructions or log immediately
   without opening Preferences, and knows which action keeps the sip private.
2. **Make the library easier to return to.** Keep the existing entrances to one
   library. Add explicit sort, useful no-match states and independent archive
   controls. Check with a shelf containing a saved drink, brew, add-in, multiple
   bags and archived gear.
3. **Make repeat brewing worth logging.** Surface defaults, preserve current
   linked-recipe behavior, and prototype an optional last-time comparison.
   Verify an unmeasured value stays unknown and a changed serving quantity
   leaves the source recipe intact.

## Fix and verification ledger

- **RED at `bcd5400`:** the native header regression measured the Home title
  at x=32 points versus x=16 in cafe. The separate native test entered only
  an Elsewhere setting, terminated the app without Close, and found no
  resumable draft on relaunch. Tests and plan checkpoint: `12095f3`.
- **Source fix:** a shared setup header sits outside all changing surfaces and
  their scroll views. Setup keeps the original three contexts and stable
  icons, prevents context edits while recovery is locked, and keeps the
  existing draft manager. Nonblank Elsewhere settings now count as draft
  content and label an otherwise unnamed draft. Empty tab hops and automatic
  Home labels do not count as user work.
- **GREEN for the correction:** 46 native checks pass across V3 domain, scoped
  draft storage and deletion. Seven composer UI paths pass, including both
  former RED cases, name and photo retention while switching, no empty draft
  after tab hops, quick private save, and guided latte through private detail.
  One wider cafe criteria fixture did not reach the criteria screen: its
  synthetic local profile seeds an owned draft, while its unauthenticated
  draft picker opens the guest scope. The sheet showed All caught up despite
  the fixture count. Real account resume was not validated by that probe.
- **Beginner walkthrough:** saved a source-only idea through Find a recipe,
  imported an ingredient list and step from a typed caption, then found that
  tea through Add → Home → Choose a recipe. Guidance, capture, rating, review
  and the private saved result all opened without inventory or AI. Building
  and starting a matcha also passed, including a separate largest-text pass
  through saving an idea and building a drink.
- **Experienced walkthrough:** added two bags and a tool from Saved; confirmed
  recent bag ordering and coupled archive visibility; saved a favorite method,
  go-to beans and the default Brew bench Home setup; saw that name and the
  favorite shortcut when opening Add → Home. Created brew, component and drink
  ideas, checked each type filter, verified pins rise above newer recipes,
  and reproduced the misleading no-match message. Saved Berry syrup from a
  caption and used 15 ml in Berry latte. Opening the original instruction and
  selecting the same part again preserved the drink name and amount without
  duplicating the part. The drink advanced through guidance, reflection and
  private review. The older test script expected a mandatory measurements
  screen; its loop instead reached private saved detail, so that script is
  not counted as a clean pass.
- **Entry comparison:** Saved was reachable as a guest. With a local profile
  fixture, manually opened Journal → Keep exploring → Home library and saw
  Berry latte and Berry syrup from the Saved path. The automated shortcut
  lookup had selected an offscreen Saved element with the same label.
- **Input observations:** the first Simulator pass dropped a final character
  in a bag name and a setup name; the second setup pass saved the full name.
  Some older recipe automation taps attempted to move fields while the keyboard
  covered them. The caption-first and explicit keyboard dismissal walkthrough
  completed. In one automation tap near the Home footer, Quick Log opened
  while the target was the favorite method. Retest keyboard and footer hit
  targets with physical input before treating them as device regressions.
- **Scope:** isolated iPhone 17 Pro Simulator, iOS 27.0, invalid backend and
  analytics disabled. The current walkthrough uses fixtures; it does not
  exercise a live provider, mutate an owner's library, or promote a phone or
  TestFlight build. Prior delivery evidence remains in the November 5 audit.
