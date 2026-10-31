# The Weekly Pour — design approval prototype

Status: **proposed, awaiting Joe's approval**. October 31, 2026.

A native SwiftUI mockup of a complete replacement for the current Week in review
presentation. No production app view, notification, backend or journal is changed.
The publishing candidate and owner-accepted completion haptics stay intact.

## The design argument

The existing recap gives the owner a report to read. The replacement gives them
something to rediscover: a tiny, personal coffee story hosted by Mugsy. The reason
to open is an actual memory, not a consumption score or a demand to keep logging.
The weekly invitation promises a familiar format with different personal content.

1. **A recognizable invitation.** A generic, private Sunday push leads directly
   into the correct account's completed week. The same cover is reachable in
   Journal; a recap must never depend on successfully receiving a notification.
2. **An opening worth opening.** Mugsy welcomes the owner as their own photos fan
   into view. A restrained coffee movement resolves into an immediately usable CTA.
3. **One idea per chapter.** A handful of remembered moments, a highest-rated sip,
   the owner's places/home rituals, and a repeat order. Big photographs and type
   replace the current stack of similarly weighted panels.
4. **A small discovery.** Turning the standout photo reveals the saved caption.
   The owner's content supplies the surprise. No AI-generated memory, flavor
   inference, invented achievement, friend mention or health/consumption claim.
5. **A keepsake ending.** A postcard gathers the week. Sharing opens an explicit
   preview; private Home sips are excluded by default and require an opt-in.
   Private notes/captions never appear on the share card.
6. **An experience that adapts.** One sip gets one meaningful memory, not six
   padded pages. A quiet week gets warm acknowledgment and archive navigation;
   it does not receive a new push under the current eligibility policy.

## Captured audit

The actual current native recap was opened on October 31 in a synthetic Simulator
fixture and captured in [01-current-week.jpg](before/01-current-week.jpg) and the scrolled
[metric panels](before/02-current-week-lower.jpg).

| Step | Observed state | Finding |
| --- | --- | --- |
| 1. Open Week in review | Usable native sheet, immediate Done | Clear escape and period selector work; preserve immediate navigation. |
| 2. First viewport | Small Mugsy, long text hero, share CTA, another text panel | The owner's personal memory has little visual emphasis; sharing appears before an emotional payoff. |
| 3. Read the recap | Repeated explanatory prose and uniform stacked panels | Weak pacing and visual contrast. There is no clear beginning, discovery or ending in the first viewport. |

This is an audit of that captured landing state, not an invented end-to-end
production notification test. The native source confirms the same existing
reflection destination retains month/year and account routing. Current physical
Debug profiling also identified brief sheet-layout cost; the redesign is not a
claim that release performance has been fixed.

## What the native mockup includes

- Journal entry and recap archive context, without replacing app-wide navigation.
- Private lock-screen invitation proposal, with no actual notification sent.
- Cover, remembered moments, highest-rated sip, places/Home rituals, repeat order,
  and a postcard ending.
- Interactive previous/next/close, horizontal swipes, photo/caption flip and share
  preview with a working private-Home inclusion toggle.
- Quiet-week, one-sip and genuinely photo-free variants; Reduce Motion uses discrete settled states.
- Approved code-native Mugsy geometry, expressions, articulated limbs and props.

The prototype uses existing Mugshot photos and fictional fixture records. It is
not the owner's activity and is never written to Supabase or analytics. The native
mockup defines exact proposed layout/type/color/motion; real data mapping,
account/lifecycle integration, final accessibility and performance acceptance
follow approval. The current app's report remains installed and unchanged.

## Fixture truth and week semantics

Current date anchor: October 31, 2026, America/New_York. The latest completed week
ends Sunday October 25 at 6 PM; its start is the preceding UTC 168-hour boundary,
matching the existing reminder contract. October 18–25 is the displayed range.

| Date | Remembered sip | Context | Rating | Privacy |
| --- | --- | --- | --- | --- |
| Mon Oct 19 | Flat white | Noonday cafe | 4.0 | Non-private sample |
| Wed Oct 21 | Filter coffee | Home | 4.0 | Private sample |
| Thu Oct 22 | Flat white | Noonday cafe | 4.0 | Non-private sample |
| Sat Oct 24 | Vanilla latte | Little Window cafe | 4.5 | Non-private sample |
| Sun Oct 25, before 6 PM | Espresso | Home | Not rated | Private sample |

Five total moments, two cafes, two private Home sips, one repeat order (Flat white,
twice). The 4.5-rated Vanilla latte is the highest-rated recorded sip; unrated
Espresso is not zero. No averages, caffeine, flavors or comparisons are fabricated.
Archive variants illustrate October 11–18 (one sip, Saturday Oct 17) and October
4–11 (quiet). Generic push copy includes no drink, cafe, count, photo or private text.

## Proposed motion and touch

- Cover: photo fan 350 ms, Mugsy gaze/blink/knee/wave 850 ms, clean settle.
- Navigation: 240 ms response; no auto-advance, held CTA or reading countdown.
- Photo turn: 350 ms, reversible immediately, accessible named button.
- Places: ticket rotations resolve once; no perpetual floating or steam loop.
- Ending: finite Mugsy acknowledgment and postcard settle. Frequent navigation
  owns one restrained selection cue, subject to the current Haptics preference.
- Reduced Motion: direct chapter changes and settled illustrations; all content
  and controls remain available. No flash/strobe/confetti barrage.

## Sources and reproduction

Editable source: [WeeklyPourPrototype.swift](source/WeeklyPourPrototype.swift).
The isolated preparation/capture scripts and exported native screens are retained
alongside it. Captures come from the running iOS Simulator, not a web redraw or
offscreen ScrollView export. Only the 62-point status area and 34-point home
indicator are cropped. Production app sources are dependencies, not edited by this package.
This is a mockup approval gate, not permission to integrate or distribute it.

See [DESIGN.md](DESIGN.md) for the proposed content/state contract and
[LICENSES.md](LICENSES.md) for the zero-additional-cost authoring boundary.


To reproduce in an isolated checkout (Codex performs these steps):

```sh
git worktree add --detach /tmp/mugshot-weekly-pour HEAD
./docs/design/weekly-pour-2026-10-31/prepare.sh /tmp/mugshot-weekly-pour
# Build the MugshotTests Debug scheme with the existing booted iPhone Simulator,
# synthetic backend and disabled analytics; see capture.py's explicit guard.
python3 docs/design/weekly-pour-2026-10-31/capture.py \
  /tmp/mugshot-motionqa-device-derived/Build/Products/Debug-iphonesimulator/testMugshot.app \
  --simulator '<iPhone-17-Pro-simulator-id>'
```

The preparation script refuses the active app checkout through the shared safety
helper. The capture script accepts only the isolated Simulator bundle and
synthetic backend, waits for a fresh per-launch native readiness marker, and then
captures the actual screen. `--only` refreshes changed scenarios. Raw system
screenshots are ignored. The design film uses `--recap-film`; real interaction
never auto-advances. Manual navigation or scene inactivity cancels author playback.


`reproduce.sh <detached-checkout>` runs the complete guarded build, fourteen native
captures, source/encoded film presence verification, boards and free local
HyperFrames check/render. Codex supplies `MUGSHOT_RECAP_SIMULATOR` and handles
checkout/dependency setup. The [QA record](QA.md) distinguishes the approval
prototype from integration and production evidence. [Source provenance](provenance.json)
and [native film evidence](film-evidence.json) are retained with the package.

The local review is `index.html`; its chapter controls browse actual native
captures and its motion tab plays `motion.mp4`. The supplementary six-second
`review/review.mp4` presents stills and does not replace native interaction.
