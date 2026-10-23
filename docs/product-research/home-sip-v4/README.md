---
document_type: decision_record
status: accepted
date: 2026-09-29
decision_owner: Joe Rosso
---

# Log a Sip · Home V4 — Made yours

> **Status: accepted product direction and visual acceptance reference.** Native
> V4 implementation is tracked in [Home and Recipes implementation](../../HOME_RECIPES_IMPLEMENTATION.md).
> The images are design evidence, not proof of device or TestFlight acceptance.
> This replaces the Home V3 *experience*, based on Joe's September 29
> connected-iPhone walkthrough and subsequent product interview. It does not
> supersede V3's existing data, privacy, or release evidence. Do not treat the
> mockups as native acceptance or a changed TestFlight build.

[Open the ordered gallery: 19 destinations, 22 images](gallery.html) or review the
[screen directory](screens/). The gallery begins with Recipe Book, walks through
the pumpkin latte, then shows the saved result, discovery, and quick path.

The example ingredient amounts and source credit are illustrative mockup data,
not verified instructions from the named creator. The latte photo is a generated
illustration, not a user photo.

## The promise

**Recognize what you are making, make it with as much help as you want, then log
the sip exactly as you would anywhere else.** Home is preparation context for a
Mugshot, not a parallel journaling product.

The core test is Joe's real scenario: he sees a pumpkin latte with cream cheese
cold foam on a social video, saves its syrup and foam instructions, combines
those with his preferred espresso and milk, makes it, records what he actually
used, rates the finished sip, and chooses to keep the extra syrup for next time.
The second latte should take fewer taps than the first.

## What the interview changed

| V3 friction observed on the connected iPhone | V4 decision |
| --- | --- |
| Home visually replaced the entire Log a Sip experience. | Keep header, draft state, and Cafe / Home / Elsewhere selector; replace only the content below. |
| “What did you make?” appeared before the drink existed. | Guided Home begins with “What are you making?”; “Already made it?” is the quick path. |
| Espresso target editing was hard to type into and ratio did not respond clearly. | Use normal editable numeric inputs, explicit ratio/yield mode, immediate recalculation, clear units, and optional contextual Mugsy help. |
| Equipment and grinder fields were blank chores. | Remember defaults from the selected recipe and saved gear; change only when needed. |
| Preparation was a field-heavy screen with tiny actions and little instruction. | Show one useful current action, large timer controls, and a clear skip; method guidance must actually teach when recipe steps exist. |
| Actuals were espresso-only and felt like another ugly form. | One concise Actuals surface includes coffee base and drink components; each value is unknown, measured, or explicitly “As planned.” |
| Home ended at an unfamiliar private-result stop. | Reuse Capture → Sip reflection → Review Mugshot → canonical Journal detail. Review defaults Private; no extra saved-result stop in the main path. |
| Journal Home led to an unrelated, crowded workbench. | Home filters the existing Journal sip list in place; Recipe Book lives under Keep exploring. |

## The complete primary flow

```text
Add → Log a Sip → Home
  ├─ Choose Latte / another drink or method
  │    ├─ Recent sip or recipe (Pumpkin Cream Latte first when relevant)
  │    └─ General Latte starting point
  ├─ Same-screen setup recognition: espresso · syrup · foam · milk
  │    ├─ Tap a component → inspect its recipe → return with edits intact
  │    └─ Change anything → beans, espresso, amounts, add/remove components
  ├─ Make this latte → optional coffee-base guidance / timer
  │    └─ Skip guidance is always available
  ├─ Actuals → measured, explicit As planned, or unknown
  ├─ Capture → photo and sip name, as in Cafe
  ├─ One scrolling Sip reflection → Mugsy, score, suggested and chosen criteria,
  │  pinning/importance, flavors, private journal note, make-again intent
  │    └─ With a tweak expands inline: next-time note + optional
  │       “Use 22 g in this latte next time”
  ├─ Review Mugshot
  │    ├─ Private → Save to journal
  │    └─ Friends / Everyone → Post Mugshot
  └─ Standard Journal Mugshot detail → Make again / Share / History
```

This is a **guided path**, not a mandatory sequence of forms. A user can skip
preparation, measurements, photo, score, criteria, and the next-time decision
when saving privately. From the same Home entry, **Already made it?** opens a
two-input-surface quick log: Capture → Sip reflection → Review. A quick log can
attach a recent recipe without opening its making guide. Review is the shared
finish for both paths, not a third Home-specific input form.

### 1. Bring an idea into Recipe Book

Recipe Book holds **preparations**, **components**, and **complete drinks** in
one searchable library, not separate siloed products. A recipe can be a
name-and-link reference, a pasted caption, a detailed espresso, a syrup batch,
or a latte linking several recipes. Source URL and creator credit are preserved.
Pasting instructions is available now as the design target; social-video
extraction is not promised.

The first-screen action is “Save a recipe idea.” Users can paste the caption
and name the idea, then structure it only when useful. They can save pumpkin
syrup and cream cheese cold foam separately, then create one Pumpkin Cream
Latte that references those recipes plus House espresso. Each component can be
inspected without losing the parent editor. The linked amount (20 g syrup in
this latte) belongs to the *drink*; the syrup recipe's batch yield and
instructions remain independent. A user may also start directly from a known
latte recipe or a blank drink.

An iOS screenshot/share-sheet route from social apps is a **feasibility
exploration**, not a V4 launch promise. Verify platform APIs, permissions,
source rights, and how a user corrects extracted text before committing to it.
The reliable baseline is Share/copy link or paste text into Mugshot.

### 2. Recognize the drink before Make

Home under Log a Sip presents a short set of likely drinks/methods, with Latte
prominent for this scenario and the full catalog behind search. Once Latte is
chosen, a visual recent shelf appears above the normal Latte starting point.
The recent Pumpkin Cream Latte opens on the **same setup screen**, not a new
flow. Show the drink's identity and four compact component rows: House
espresso, pumpkin syrup, cream cheese cold foam, oat milk and ice. Recipe
version, amount, or compact target belongs on each row; extensive steps and
equipment do not.

Mugsy's invitation is a human prompt such as “Making this one again? Looks good
as-is. Change anything if you want.” Every component is tappable. “Change
anything” opens an edit sheet for beans, espresso recipe or ratio, milk,
linked components, and amounts. The default setup is already usable. Mugshot
does **not** ask whether each component is ready; tapping a component is the
user-controlled way to open its preparation if needed. The Make action mainly
guides the coffee/tea base and final assembly when actionable instructions
exist. It must not turn syrup, foam, and espresso into three automatic journal
entries.

### 3. Make and record, with genuine optionality

The Make surface adapts to espresso, pour-over, AeroPress, French press, moka
pot, drip/batch, cold brew, matcha, hojicha, tea, drink assembly, and custom
methods. It displays one current instruction and a useful timer/target rather
than a stack of empty optional fields. Timer controls meet normal touch sizes.
Coffee dose, yield, and time are easy to edit with decimal support and
appropriate keyboards. For espresso, changing dose/ratio/yield immediately
shows the other value and the ratio, while making clear which value drives the
calculation. Mugsy can explain a ratio or flag a factual difference; he must
not diagnose taste before the user has tasted the drink.

After Make, one Actuals surface lists both coffee-base and drink-ingredient
amounts. Each item has three distinct states:

1. **Unknown** — empty; the app knows nothing about the actual value.
2. **As planned** — a deliberate tap with a small celebratory check/haptic;
   the planned number is explicitly confirmed as the actual for this attempt.
3. **Measured** — a typed amount with unit, e.g. 37.2 g espresso out or 22 g
   pumpkin syrup.

The app never silently promotes recipe targets to actuals. “As planned” applies
per item, not to all ingredients because one item was confirmed. A fact-only
Mugsy line may say “A little more espresso and syrup than planned. Taste comes
next.” Later coaching may connect the user's *reported* taste and measurements,
carefully framed as a possible experiment, not a causal diagnosis. For long
brews, an active batch persists by timestamp and can resume later; a serving
may reference the batch without duplicating it.

### 4. Finish like every other Mugshot

Capture, Sip reflection, Review, and the saved Journal detail reuse the
production Cafe visual hierarchy and behavior. Home does not invent a second
rating system. The September 29 Cafe screenshots now supplied by Joe are the
specific reflection reference: the memory summary and Edit action, large Mugsy
coach, sip score and stars, “What shaped it?”, suggested-for-this-drink rail,
“Use last setup”, full criteria cards with edit/pin/remove controls, More /
Normal / Less importance, and “Just for my journal” remain in the same order
and scrolling surface. Home changes the identity to **Pumpkin Cream Latte ·
Home · your recipe** and adds one compact **Would you make it again?** control
*below* the private journal field: **Yes / With a tweak / Not this version**.
Choosing **With a tweak** expands the optional private next-time note and any
useful measured-change choices immediately beneath that control. It does not
navigate to another screen, hide criteria, or interrupt Review. Gallery images
13, 13b, and 14 are top, criteria, and expanded-tweak scroll states of **the
same Sip reflection screen**.

For example, if 20 g of syrup was planned and 22 g was measured, “Use 22 g in
this latte next time” is a deliberate choice. The selection is held in the
draft, then committed only after the private attempt is durable; a failed
commit must show a recoverable pending state, not claim the new default is
saved. It does **not** update merely because 22 g was logged or because the
user selected “With a tweak.” It does
**not** rewrite the pumpkin syrup component recipe. The current attempt saves
its original target and actual snapshots; the drink recipe receives a new
immutable version only after the private attempt is durable. Next time the
recent latte uses 22 g. An unchanged repeat creates no new version, and old
photos, scores, notes, and actuals are never copied into the next attempt.

Review Mugshot defaults to **Private** for Home. Preserve the current production
Review order and components: Photos and cover controls, drink identity/Edit,
Caption, Scores & criteria/Edit and disclosure, then Home's compact “How you
made it” summary, the existing Audience selector, Raw note visibility, recipe
sharing/source-rights controls, and Tag people. Home preparation is an addition
to the shared Review—not a replacement layout. The primary button says **Save
to journal** for Private; choosing Friends or Everyone changes it to the
current publish action with that audience, and invokes existing publication
requirements. Private saves need only a name. Social posts keep Mugshot's
existing score, caption, visual/Mugsy placeholder, and audience requirements.
Recipe attachment is version-specific and explicit: none, name only, or full
details. Linking a drink never recursively shares its syrup or foam
instructions. The private note and next-time note never enter a public payload.
A post failure leaves the private attempt and composer draft available for
retry.

The saved result uses the **same Mugshot post-detail structure already used by
Cafe and published Home entries**: toolbar, author, media hero with name/score,
caption, journal note according to its visibility, actions, taste evidence,
recipe, tags, and conversation when applicable. Add “How you made it” as an
expandable section in that existing detail sequence. Do not create a separate
Home result layout. Gallery images 17 and 17b show top and lower scroll states
of that one post detail.

## What must remain broad without becoming bulky

The screenshots follow one latte so the core interaction can be judged. The
underlying design must still support espresso alone; timed pour-over with
incremental or cumulative water targets; immersion and AeroPress; cold-brew
batches; matcha; hojicha; tea infusions; a syrup or foam made on its own; and a
custom named preparation. Each built-in method supplies sensible defaults and
Mugshot iconography. A user-defined method needs no developer-defined
category. Detailed equipment, beans, grind, temperatures, steps, custom
fields, source, and scaling stay behind an edit or detail action. Saved gear
and preferred recipes can prefill choices but never block first use.

## Priority and implementation order

| Priority | Slice | What ships / how we know it is right |
| --- | --- | --- |
| **P0 — repair the everyday spine** | Home content under the existing composer; Latte/recipe recognition; optional Make; one Actuals surface; production Capture/Reflection/Review/Journal detail; in-place Home Journal filter. | Joe can repeat a latte with a visible component overview and finish a private or social Mugshot without a Home-only detour. A quick log remains two input surfaces. |
| **P1 — make repetition rewarding** | Recent visual shelf; reliable preferred gear/beans; explicit As planned; per-attempt target/actual snapshots; make-again intent, next-time note, opt-in “use this next time”; immutable drink recipe versions. | A second pumpkin latte starts with the kept 22 g amount while the syrup recipe and first attempt remain unchanged. |
| **P1 — complete Recipe Book** | Paste/link capture, components and complete drinks, versioned links, source credit, parent-preserving component sheet, source-only and empty states. | A user can save a syrup, foam, espresso, and linked latte without fabricating a sip or publishing anything. |
| **P2 — method depth** | Adaptive guides, timers, ordered pours, durable cold-brew sessions, batch servings, custom fields, method-relevant defaults and accessible branded icons. | A first-timer gets instructions; an experienced maker can skip them and record only useful facts. No coffee-only assumptions leak into matcha, hojicha, tea, or custom. |
| **Explore, not promised** | iOS screenshot/share-sheet recognition and ingredient extraction; taste-informed Mugsy experiments after enough reliable data. | Feasibility, rights, correction, privacy, and user trust are proven before commitment. |

The P0 slice must be built **within the existing Cafe flow's design system and
navigation**, not as another parallel Home UI. Reuse existing recipes,
identities, versions, attempts, account-scoped persistence, media, recovery,
rights, and publishing contracts. Migration is additive and idempotent; no
historical measurement is relabeled as target or actual. Existing Home entries
remain readable and old drafts remain recoverable. Feature rollback preserves
all saved data. No TestFlight upload is implied by this plan.

## Acceptance before this replaces V3

- On a real iPhone, Add → Home leaves the Log a Sip header, draft state, and
  three location pills visibly intact; choosing Cafe or Elsewhere returns to
  their current behavior.
- A new user can save a name-and-caption recipe, make a latte from linked
  components, or quick-log a finished drink without setting up inventory.
- The recent Pumpkin Cream Latte opens with espresso, syrup, foam, and milk at
  a glance. Opening a component and returning preserves latte edits.
- Espresso ratio/yield recalculates as edited; numeric and decimal input works
  with the keyboard. Saved equipment prefills, but can be changed.
- Make guidance is readable and skippable. The coffee-base timer remains
  accurate across backgrounding; cold-brew timing resumes from timestamps.
- Unknown, As planned, and Measured remain distinct after relaunch and sync.
  No unrecorded actual is manufactured from a target.
- Reflection preserves the exact existing Cafe Mugsy, score, suggested and
  user criteria, pinning, importance, edit, and journal behaviors. With a tweak
  expands inline and does not create a new screen. A
  private, unrated, photo-free sip saves successfully. Audience and social
  validation occur on Review, not on a separate Home stop.
- Opting in to 22 g changes only the latte's next recipe version. Declining it
  or making an unchanged repeat creates no version. Historical attempts remain
  accurate and separate.
- Friends/Everyone preview only the selected recipe version and selected
  publishable fields. Private notes, linked component instructions, inventory,
  and local media paths remain private. Failed post retry cannot duplicate it.
- The saved Home entry uses the canonical Mugshot post detail, with Home prep
  details added in the existing scroll; Journal Home filters sips in place and Recipe Book is easy to
  find.
- Run repository Tier 4 cross-screen acceptance when implementation begins:
  focused deterministic tests, full static gate, consolidated Simulator pass,
  then owner-promoted physical-device QA. Hardware and TestFlight acceptance
  are distinct gates.

## Design review questions, not blockers

The interview resolved the important product choices. The only questions worth
testing with the screenshots are: (1) does the recognition screen show the
right *amount* of component detail at a glance, (2) does the Actuals “As
planned” affordance feel satisfying without adding pressure, and (3) does
putting “keep this change” in Sip reflection feel natural on a real phone?
Those are validation questions, not reasons to make Joe repeat the interview.

## Visual evidence and reproduction

- [Ordered gallery](gallery.html) and [22 PNGs across 19 destinations](screens/)
- [Local screen renderer](mockups.html) and [WebKit capture script](render.swift)
- [Generated illustrative latte photograph](assets/pumpkin-cream-latte.png)
- Joe's [Cafe reflection top](references/cafe-reflection-top.jpg),
  [criteria scroll](references/cafe-reflection-criteria.jpg), and
  [journal scroll](references/cafe-reflection-journal.jpg) references

The capture script renders 22 iPhone-sized static images from local example
data. No network, app backend, or production account is involved. The images
express a proposed design, not verified tap targets or native runtime behavior.
