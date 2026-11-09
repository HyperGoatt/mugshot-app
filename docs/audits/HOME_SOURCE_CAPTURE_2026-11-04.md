---
document_type: historical
status: installed-physical-caption-journey-verified
---

# Home recipe capture and full-flow QA — November 4, 2026

**Later recipe UX:** [Native recipe canvas and drink composition](../design/home-recipe-composer-2026-11-04/README.md)
supersede this report's capture/composition presentation and candidate delivery
state. Source/media contracts and this dated phone chronology remain evidence.

Current implementation: [Home recipes](../HOME_RECIPES_IMPLEMENTATION.md),
[Luna assistance](../AI_ASSISTANCE.md) and [current product status](../CURRENT_PRODUCT_STATUS.md).
This owner-requested change affects product behavior, native data ownership,
media/network privacy and physical Debug test configuration. It changes no
Supabase schema, deployed function, model or TestFlight version.

## Behavior and limits

- Opening a saved recipe in Home library now shows the recipe details and the
  choice to make or log it. It no longer launches a sip merely by browsing it.
- Pasting a public Instagram post/Reel or TikTok post link starts a bounded,
  unauthenticated read of the selected post's caption. Tracking queries are
  removed. Login-required, removed, blocked or unreadable posts retain a
  link-only/manual/screenshot fallback. There is no universal social-video claim.
- Screenshot text is read on-device. Clearly labelled ingredients and steps can
  fill an editable recipe without Luna; enabled Luna can structure less regular
  text and the selected image. Factual capture fills automatically, without a
  separate copy checkbox. Ordinary Save and known no-copy guards stay explicit;
  importing does not assert a new source reuse permission.
- Public video media advertised by the selected page can be read when accessible;
  otherwise a saved clip can be chosen. Clips are bounded to 50 MB and 60 seconds
  (public downloads: 30 MB). Up to six sampled frames and visible text are used.
  Sampled frames cannot prove everything shown between them.
- Spoken steps are a separate optional on-device recognition choice. Unsupported,
  denied or failed speech recognition is labelled as unread; raw audio is never
  uploaded to OpenAI. This is not a full-video-understanding guarantee.
- Link caption, screenshot text and video text stay distinct while being combined
  in the editable source. Replacing a screenshot preserves its caption and user
  typing. Fields remain editable and AI never saves or publishes them.
- Only approved public social/media hosts are requested; every redirect is
  revalidated, bodies and timeouts are bounded, and the ephemeral session sends
  no login cookies or authorization. Web content is parsed as data, never run as
  script. Results after cancellation/account change cannot mutate the draft.

## ECC checkpoints and observations

- `58803c3`: intended missing-API RED for source validation, selected-post metadata,
  deterministic section parsing and actual on-device screenshot OCR.
- `caeec7e`: intended missing-API RED for distinct source contributions. Runtime
  evidence also exposes a real combined-source bug: 20 text entries plus credit
  made 21 evidence items, exceeding the server's 20-item contract.
- The first recipe-route test used a final word that iOS autocorrected, so its
  failure occurred during fixture lookup. That run is not route-bug proof.
  `8fd5d66` uses a stable fixture and confirms a runtime RED at the absent recipe
  details choice. The original route had already entered logging.
- `61d969f`: GREEN includes recipe-first navigation, source capture, source
  contribution preservation and the bounded credit slot. 31 focused unit/UI
  tests pass in `/tmp/mugshot-recipe-capture-green2.xcresult`.
- `eda9b94` → `d7cccac`: injected ephemeral transport RED/GREEN, then all 10
  source tests pass in `/tmp/mugshot-source-transport-green.xcresult`.
- A full native Simulator journey independently creates a recipe from a caption,
  opens it from the library, enters guidance, leaves actuals unknown and reaches
  the shared capture, rating and review screens with Luna disabled.
  `/tmp/mugshot-recipe-guidance-journey.xcresult`: 1/1 passes. It stops before the
  final sip save.
- `c7f3446`: a later runtime RED requires automatic factual filling without a
  separate copy prompt. The follow-up removes that prompt for new public-source
  capture, preserves explicit known no-copy restrictions and never sets a source
  reuse permission to true merely because extraction ran.
- `7312933`: automatic capture GREEN, including actual video-frame reading and
  the long-video boundary. The consolidated Simulator batch passes 58/58.
- Screenshot review of the physical journey found an empty “Today’s target” card
  for an instruction-only recipe. `fb73c7d` confirms that UI regression RED;
  `850c657` omits the card only when there are no displayed measurements. The
  measured latte still shows its output target. The follow-up also selects four
  stars through the real control before review, instead of only reaching an
  unrated rating screen.

## Physical QA boundaries

The existing development app's private Application Support was backed up before
this work. Owner content and screenshots stay under `/tmp`.

Native automation required signing into Xcode, accepting Apple's updated
Program License Agreement by the owner, and enabling UI Automation on the
iPhone. These were distinct infrastructure gates, not app regressions. The
first native runner timed out enabling automation; no journey test ran.

The existing account's library can be opened read-only. Journeys that create
recipe/preparation records use a separate local-only QA application on the same
iPhone with an invalid fixture backend and disabled analytics. Its data and
credentials are isolated from `co.mugshot.app.dev`; no fake content may be added
to the owner's account to establish these checks.

One intermediate owner run skipped its case because opt-in variables were written
using the wrong runner-plist shape. It is excluded. The corrected final opt-in
sets exactly one target and passes 1/1 without skips. The private existing recipe
name is injected through the temporary runner environment, never stored in tests.

One physical follow-up was interrupted when a system notification covered Save.
It does not establish target-card acceptance. The test now clears banners before
toolbar taps/screenshots and waits for the capture sheet to close before using
library search; the focused retry passes. Private notification captures remain
outside the repository.

## Final verification

| Evidence | Result | Scope |
| --- | --- | --- |
| Consolidated Simulator batch | 58/58, zero failures/skips | 48 native cases and 10 UI cases; source/media, assistance, Home domain/library |
| Empty-target/measured-latte Simulator follow-up | 2/2 | Instruction-only card omission, preserved latte output, four-star rating, review |
| Isolated iPhone batch | 17/17, zero failures/skips | 12 native source/media cases and 5 Home library UI journeys on iPhone 16 Pro, iOS 27.0.1 |
| Final isolated iPhone follow-up | 1/1 | Automatic caption fill → library → guidance → actuals left unknown → capture → four-star rating → private review; stops before sip save |
| Final installed owner-app read-only check | 1/1 | Existing recipe opens details and offers Make, without starting a sip or resetting owner data |
| Synthetic live Luna images | 2/2 | Fictional bag/recipe JPEGs against `gpt-6-luna`; no real owner media |
| Fast repository checks | 7/7 | Diff/whitespace, conflict markers, ASCII spelling, living docs and migration names |
| Debug package | Pass | Signed, deep/strict verified; entitlements preserved; analytics disabled; actual OpenAI key absent |

Follow-up runs repeat relevant earlier cases; these counts must not be summed as
distinct tests. Exact identifiers/result-bundle paths and sanitized receipts:
[verification.json](home-source-capture-2026-11-04/verification.json),
[phone-receipt.json](home-source-capture-2026-11-04/phone-receipt.json),
[isolation.json](home-source-capture-2026-11-04/isolation.json).

Focused line coverage from the 58-case run is 263/294 (89.5%) across
`HomeRecipeSourceReader`, `HomeRecipeCaptureSources` and
`CoffeeAssistanceRecipeImport` only. It is not app-wide coverage. The media OS
adapter is 105/212 (49.5%), and the capture view is 308/453 (68.0%); the remaining
Photos transfer, speech permission/support/error and attachment interaction
branches are not represented as fully accepted. Real Vision OCR and bounded
AVAsset video-frame extraction run on both Simulator and hardware fixtures.

SwiftUI review covers draft ownership, account/generation fences, structured task
cancellation, preservation of user edits, nested-editor dismissal and temporary
file cleanup. Security review covers unauthenticated host/redirect allowlists,
body/time limits, no credential/cookie forwarding, protected-source guards,
bounded source/credit evidence, no script evaluation or sensitive response logs,
optional on-device speech and unchanged authenticated Luna server contracts.

The physical Debug unit-test host now resolves to `MugshotDiagnostics.app` on
iphoneos while the Simulator host is unchanged. Build settings confirm the device
path; source/media hardware tests use the isolated app, never the owner's host
for mutable fixtures.

## Installation and preservation

The final source candidate is installed as **Mugshot Luna QA 0.5.3 (8)** under
`co.mugshot.app.dev`. The accepted package's debug library SHA-256 is
`20bde1c8a81ad32f345e445c4157c0cfe6902c5b7a7e421dccfd08de369baabc`.
All 40 immediately pre-install Application Support files are byte-identical
before launch. Comparing the original pre-task backup with the final read-only
owner run preserves all 7 recipes, 6 attempts, 13 sessions, 1 recipe draft and
11 attempt drafts exactly, plus all 3 original sip-draft files byte-for-byte.
One ordinary runtime JSON `updatedAt` timestamp changes; this is not an
all-files-unchanged-after-runtime claim. No synthetic owner records were created.

Only the separate QA app creates test recipes/preparation records. Its private
backend, keychain and defaults are isolated; app groups, URL handlers, analytics
and embedded extensions are removed for that build snapshot. The temporary
Mugshot Flow QA app and its runner are removed after verification. The production
app is untouched. No TestFlight archive, export, upload or assignment occurs.
PR #109 remains stacked on held draft #108; no parent merge is promoted here.

## Inspected hardware captures and remaining acceptance

All three captures use fictional recipe data and contain no private notification:
[guidance](home-source-capture-2026-11-04/phone-guidance.png),
[four-star rating](home-source-capture-2026-11-04/phone-rating.png),
[private review](home-source-capture-2026-11-04/phone-review.png).

This establishes the caption-based Home journey on hardware, native screenshot
OCR and bounded movie-frame reading. It does not establish that every live social
post is readable, real owner Photos selection/save, optional spoken transcription
quality/permission, spoken VoiceOver, the full accessibility matrix or TestFlight
acceptance. Login-blocked sources keep the caption/screenshot/saved-clip/manual
fallbacks; no platform restrictions are bypassed.
