---
document_type: historical
status: verified-development-and-production-provider
---

# Recipe focus and full-screen post completion — November 5, 2026

Current sources: [Home recipes](../HOME_RECIPES_IMPLEMENTATION.md),
[AI assistance](../AI_ASSISTANCE.md), [sharing](../REPAIR_SHARING_STATUS.md).

## Scope and observed failure

Documentation impact: recipe-import behavior and draft ownership, native post
completion/sharing, Edge provider instructions, privacy and development delivery.
No database schema change or TestFlight action is planned. The owner chooses
the full-screen result for successful Home, cafe and Elsewhere posts. Private
saves retain private-save behavior; sharing never silently changes an audience.

A read-only owner snapshot confirms the screenshot-imported PSL component has
29 ingredient rows and two steps. The ingredient list contains page chrome,
preparation headings and step fragments. Luna has supplied cleaner fields, but
the client appends them to the fallback's incorrect OCR rows. The original text
also contains an obscured/cropped last instruction. Saved owner versions, linked
drinks and published posts remain untouched during diagnosis. Private source,
identifiers and backups are excluded from this report and repository.

## ECC RED checkpoints

- The original parser executes 12 focused source tests: ten pass, two fail with
  three assertions. Synthetic wrapped-line/preparation and footer fixtures
  reproduce ingredient pollution and recipe/footer mixing. Raw console evidence:
  `/tmp/mugshot-psl-parser-red-2026-11-05.log`. Xcode stalls while finalizing the
  failed run; the incomplete result bundle is not claimed as a finalized receipt.
- A separate build-for-testing intentionally fails at the missing
  `CoffeeAssistanceRecipeImport.Draft` API. Tests require replacement of untouched
  generated rows while preserving typed names, edited ingredients and deletions.
  `/tmp/mugshot-psl-intended-api-red-2026-11-05.log`, exit 65.
- A completion-policy boundary test requires confirmed publication for the active
  owner. Private results, stale owners and incomplete saves must not open the
  full-screen posted result.

Implementation, native captures and GREEN/phone acceptance were pending at this
RED checkpoint. The closure below records the later evidence separately.

## Implemented behavior

- The native parser recognizes preparation headings, joins wrapped ingredients
  and numbered paragraphs, skips common page controls/promotions and stops before
  subsequent recipe/page sections. Labelled capture remains available without AI.
- `CoffeeAssistanceRecipeImport.Draft` owns only generated fields. Provider sections
  replace untouched fallback sections, preserve typed edits/deletions and leave
  usable fallback sections intact when AI output is empty or partial. Name/use and
  credit stay bounded inside the existing evidence contract. Save stays explicit.
- Luna focuses on one selected recipe, keeps supported measures/time/alternatives,
  identifies cropped details and returns exact contiguous supporting quotes.
  Recipe output is capped at 2,400 tokens; other tasks retain 1,000. Model remains
  `gpt-6-luna`, with no tools, `store:false`, unchanged guards/quotas and no automatic
  retry. A failure leaves the non-AI draft available.
- Confirmed Home, cafe and Elsewhere posts use one full-screen cover. Share opens
  a clean artwork preview; See post uses the existing owned remote/local detail
  callback inside the same cover. Finishing runs on dismissal. Private, incomplete
  and stale-owner results do not present the posted celebration.
- Existing finite motion, once-only account/operation marker, scene cancellation,
  Reduce Motion and haptic preference remain. Accessibility layout uses a smaller
  static hero, scrollable content and fixed bottom actions. External-audience
  acknowledgment and protected-link rules remain. Share preparation starts only
  when chosen, with visit/account/task guards and retained retry choices.

## Native GREEN and review

The final source is installed and launched as **Mugshot Luna QA 0.5.3 (8)** on
iPhone 16 Pro / iOS 27.0.1. This is the development app, not a TestFlight build.

| Evidence | Result | Receipt |
| --- | --- | --- |
| Source/parser/draft + completion policy + four result UI + two existing Home journeys | 35/35 | `/tmp/mugshot-psl-celebration-green2-2026-11-05.xcresult` |
| Assistance owner/cache/cancellation/Unicode/privacy boundaries after final integration | 19/19 | `/tmp/mugshot-psl-celebration-green3-2026-11-05.xcresult` |
| Final regular/reduced-motion/accessibility/private-result Simulator UI | 4/4 | `/tmp/mugshot-psl-celebration-green4-2026-11-05.xcresult` |
| Existing sharing domain/privacy/rendering boundary suite | 16/16 | `/tmp/mugshot-psl-celebration-green1-2026-11-05.xcresult` |
| Isolated physical native source/completion/assistance | 48/48 | `/tmp/mugshot-recipe-focus-physical-final-2026-11-05.xcresult` |
| Final isolated physical result/share/private/accessibility UI | 4/4 | `/tmp/mugshot-recipe-focus-physical-ui-retry-2026-11-05.xcresult` |
| Owner read-only existing PSL component and prefilled drink-builder open/close | 1/1 | `/tmp/mugshot-recipe-focus-owner-readonly-2026-11-05.xcresult` |
| Final Deno handler/provider contracts | 11/11 | `/tmp/mugshot-recipe-focus-provider-final-tests-2026-11-05.log` |
| Final repository backend/static/hermetic PostgreSQL gate | 12/12 | `/tmp/mugshot-recipe-focus-final-backend-2026-11-05.log` |

The early UI run found a root identifier propagating onto footer buttons. The
final hub creates an explicit accessibility container and all four tests pass.
An initial physical runner timed out enabling automation before UI cases began;
the unlocked retry passes four UI cases. Its already passing 48 native tests are
reused, not counted as a successful initial UI run. A root build-for-testing also
hit the existing diagnostics module/test-import mismatch; the app-only Debug build
and independent isolated signed test build both pass. No repository signing or
module configuration is changed to work around that infrastructure limitation.

Collected GREEN2 file coverage is 88.4% for recipe import and 88.4% for source
reading. Draft apply/replace/remove functions are 91.3%/100%/82.1% in that run.
These are focused file/function measurements, not app-wide coverage. The first
backend invocation failed only changed-file formatting; formatting was corrected
and the final complete backend gate passes without skips.

SwiftUI review covers view-owned draft state, cancellation on source/use/account
changes, late-result guards, one-cover dismissal, immediate CTAs and no feedback
replay. Security review confirms unchanged Auth/live-owner/quota enforcement,
rights guards, bounded evidence/images/fields, no server URL fetch, no new logs
containing source content and no API key in either signed app or staged files.
Private owner screenshots/backups and unrelated Weekly Pour work are excluded.

## Hosted provider release

The owner approved a fresh data-less branch at $0.01344/hour. Branch
`recipe-focus-qa-2026-11-05` was created at 17:37 UTC, aligned all 185 local
migrations with inert scheduler secrets/inactive jobs, and passed **67/67** SQL
contracts. All mutations and synthetic Auth identities stayed on that branch.

Two direct synthetic text/image probes and the initial eight authenticated
task/image probes passed. A stricter text fixture then exposed a genuine provider
failure: Luna removed a banner from a source quote as well as the step value.
The existing validator correctly returned 503. Instructions now require short,
contiguous verbatim quotes; no validator was weakened. The final deployed bundle
passes four authenticated recipe cases: simple text/image and noisy wrapped
text/image. The noisy cases produce four ingredients/three steps, retain the
printed measures/time and exclude the discount, Print control and later latte.
The final shared prompt also passes the six text-task routes. An unrelated repeat
bag-image quality assertion omitted the expected origin in an otherwise valid
result; the earlier same-image check passed. This is not claimed as universal
image accuracy, and no bag behavior was changed in this task.

Hosted checks deny unauthenticated, foreign-owner and invalid-consent requests;
both ordinary database roles cannot access either operational table/reserve RPC.
Global/daily caps and account-erasure cascade pass, with the global/erasure probe
rolled back. Duplicate-reservation behavior is covered by the SQL/handler contracts.
Failures retain spend reservations; no owner content was sent as a probe.

A completed November 5 physical backup and empty exact 184-migration release dry
run precede deployment. The held Home V4 migration is excluded. Only
`coffee-assistance/provider.ts` changes in the five-file deployment bundle.
Production function **version 4** is ACTIVE and matches local reviewed sources:
SHA-256 `fdf7897e08ba8fd4a55a33ba1392839b1bd433279193069d0e89bab67dd4545c`.
Auth remains inside the unchanged entrypoint/handler, with the existing gateway
setting preserved. Main secrets and schema were not changed.

Before/after whole-row hashes and counts match across **75 protected tables**.
The 184-migration head, Storage object count/bucket visibility, capability response,
schedules, all 16 other Edge Function metadata records and security advisory counts
are unchanged. The two production no-bearer/invalid-bearer checks return 401 and
appear as 401 in the new version's logs. No production test row was created.
The QA branch was deleted; listing branches confirms only main remains. The prior
version-3 bundle is preserved privately for rollback, and the existing optional
assistance disable switch remains available without deleting user data.

## Owner preservation and acceptance boundary

All **45** original Application Support files match byte-for-byte immediately
after installation. After launch, isolated tests and the owner read-only check,
there are no new or removed files. The recipe workspace and all shelf content
remain unchanged; only the shelf's top-level `updatedAt` changes. Existing PSL
component versions, linked drink references, posts, drafts and source text are
preserved. The old imported ingredient list has **not** been silently repaired.
Both packages pass deep/strict signature checks and actual-key byte exclusion.
The mutable fixture app has an invalid backend, blank analytics, separate identity/
keychain and no owner app groups, schemes or extensions. Its temporary app/runners
are removed after verification; the normal app, Luna QA and Motion QA are retained.

No real owner post was fabricated for acceptance. The UI fixtures exercise the
same result/share views and a labelled fixture detail destination; production uses
the existing owned detail callback. Actual publication, authenticated post lookup,
system-share delivery to another app and the owner's original screenshot import
remain human QA. Cropped data and unavailable social sources remain honest limits.
Draft PRs #109/#108 and Home V4 promotion stay held. No archive, TestFlight upload,
marketing version or build-number change occurred.

## Human QA in Mugshot Luna QA

1. Add the PSL screenshot as a **new component**. Check that preparation text,
   Print, discounts and a later latte are absent from ingredients; wrapped lines
   remain together. Check any visibly cropped instruction manually.
2. Edit/delete one extracted row while reading. It should stay edited/deleted
   when Luna finishes. Save, reopen, and use it in a drink without changing its batch.
3. Post a real Home, cafe or Elsewhere sip. Confirm the full-screen moment, then
   Share → Story/Post/Style → Back, and See post → the actual saved post.
4. Save privately and confirm private behavior. With large text or Reduce Motion,
   keep actions reachable and avoid repeated animation when returning from Share.

[Fictional native gallery and concise receipt](../design/recipe-focus-post-celebration-2026-11-05/README.md).
