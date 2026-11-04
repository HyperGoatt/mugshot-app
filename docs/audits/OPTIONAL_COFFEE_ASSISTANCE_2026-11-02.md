---
document_type: historical
status: locally-verified-candidate
---

# Optional Luna assistance evidence — 2026-11-02

Current implementation and rollout contract: [AI assistance](../AI_ASSISTANCE.md).

**Delivery continuation:** the [November 4 activation and phone QA ledger](OPTIONAL_ASSISTANCE_PHONE_QA_2026-11-04.md)
supersedes the local-only delivery state below. The dated test chronology is preserved.

## Scope and user journeys

The owner requested all five optional helper groups using Luna, with no core app
dependency on AI. The owner approved `gpt-6-luna` after the live model list showed
no `gpt-6.1-luna`. Journeys were derived from that request: reviewed capture,
owner-only memory retrieval, cautious taste observations, Home experiments,
and optional weekly wording. Saving/publishing, manual capture/search, existing
Taste Passport, Home records and deterministic recaps remain independent.

## Initial ECC checkpoints

- Backend tests were written before the handler. Initial RED:
  `qa/pglite/node_modules/.bin/deno test --cached-only supabase/functions/coffee-assistance/handler_test.ts`
  failed with TS2307 for the intentionally missing `handler.ts`.
- The test-first handler then passed 7/7 tests. One initial test fixture omitted
  its claimed source quote; supplying the actual source fixed the fixture while
  retaining strict source validation.
- Added provider boundary tests: 10/10 pass. Deno coverage across handler and
  provider is 84.0% lines, 88.2% branches, 88.9% functions.
- `node qa/pglite/check-coffee-assistance.mjs` passes: client/RPC denial,
  duplicate/global request IDs, unknown owners, daily/monthly quotas, absence of
  content columns, and account-deletion cascade.
- Initial native compile found a nested shorthand-closure error and an actor-
  isolated default-argument initializer. These were build defects, not behavioral
  RED evidence. Both were corrected; native validation was still in progress at this checkpoint.
- Client unit tests were added during implementation. Do not describe all native
  client code as test-first. Subsequent confirmed behavior defects use focused
  RED -> fix -> GREEN evidence.

At that initial checkpoint, no production schema/function/secrets were changed,
no physical-device install was performed, and no TestFlight action occurred.
Later results are appended below; unexecuted checks are never a PASS.

## Additional executed boundaries

- Runtime RED for exact-model routing: the provider test observed two calls
  instead of one when `gpt-6.1-luna` was supplied. Exact `gpt-6-luna` validation
  restored GREEN (10/10 Deno tests). Checkpoints: `3d59a61` -> `5dfa43e`.
- Runtime RED for global spend after erasure: the disposable database admitted
  request 3,001 after deleting one account's receipts. A separate anonymous
  month/count aggregate now survives owner deletion while identifiable receipts
  still cascade. The same 3,000-reservation contract passes, including client
  denial on both tables. Checkpoints: `420a384` -> `ad4ce15`.
- Actual synthetic provider checks pass for six text task fixtures and two
  image-only fixtures (bag and recipe), all using `gpt-6-luna`. Printed Colombia
  origin and the printed 10 g ingredient quantity were extracted. No production
  journal, user image, or Supabase data was sent to these probes.
- First native batch: 36/37 pass, with all 13 new helper tests passing. The one
  failure was an inherited Home V4 test expecting `.actuals.progressStep == 2`;
  the unchanged parent source maps actuals to preparation step 1. Its stale
  expectation was corrected without changing Home behavior.
- Next native batch: 38/38 unit tests pass, including the owner/completion/private-
  note factory boundary. UI close-without-consent passes; three UI tests fail at
  the disabled-action check after tapping the consent row midpoint. Direct native
  inspection verifies that activating the trailing switch sets consent to 1 and
  enables generation. The UI tests now target that switch and assert its value.
  Offscreen acceptance checks also scroll before waiting for a lazy Form row.
- The first combined Simulator run was interrupted during prolonged diagnostics;
  no success is claimed for it. Later failure bundles contain actual executed UI
  assertions, not a CoreSimulator-only failure. A fresh disposable iOS 27 device
  is used for subsequent acceptance. Production analytics is blank and the app
  targets `https://assistance-fixture.invalid`.
- Static/backend suite passed 12/12 with no failures/skips. Final quota changes
  have separately passed their focused disposable contract. Documentation and
  whitespace checks pass. A scoped scan of 47 candidate files found no key-shaped
  credentials or local key material.

The native code also fences helper ownership to the owner of loaded Journal data,
rather than relabeling old rows with a new current account. Account changes close
an open archive and invalidate the helper source identity. Existing weekly counts
and sharing remain deterministic.

## Native review artifact

[Actual largest-text/Reduce Motion fallback capture](optional-assistance-2026-11-02/native-largest-text-fallback.png)
comes from the passing native XCTest journey and the real shared helper component.
The fixture source is original fictional text; the response in this image is an
injected failure, not a live customer or provider result. It proves readable,
reachable consent and fallback UI, not production backend activation.

## Final local evidence

Additional confirmed behavior boundaries and checkpoints:

| Boundary | RED evidence | Fix / GREEN evidence |
| --- | --- | --- |
| Saved Home feedback uses recorded ingredients | `3c1bc92`: missing recorded 15 g syrup; 14/15 helper unit tests passed | `173f179`: ingredient names join recorded actual amounts; 15/15 helper tests passed |
| Recipe text preserves multi-scalar Unicode within input limits | `e9a6a72`: runtime mismatch reconstructing 300 family emoji; 17/18 passed | `d47057e`: chunk before advancing, using UTF-16 limits and intact scalars; 18/18 passed |
| Home evidence proves its loaded account scope | `0e2a901`: intentional compile RED for the missing owner-aware factory signature, after correcting the test's scope enum spelling | `c09a7a6`: source scope is mandatory; guest/other-account sources return no evidence; 19/19 passed |

The Home scope change is wired through the archive and weekly helper. Guest data
and a workspace still belonging to a previous account cannot be relabeled as the
current account's AI input. Single-attempt actions separately require the live
workspace owner. The final source review also covers captured bearer tokens,
session/generation fences, consent withdrawal, bounds, source rights/attribution,
service-only quota access, and absence of prompt/image/answer logging.

| Guarantee or check | Evidence | Result |
| --- | --- | --- |
| Exact model, owner/consent/input bounds, references, quoted extraction, outage and disabled behavior | `handler_test.ts`, `provider_test.ts` | 10/10 Deno tests pass |
| Client denial, duplicate IDs, unknown actors, real RPC daily/monthly caps, deletion with global budget retained | `node qa/pglite/check-coffee-assistance.mjs` | PASS in disposable PGlite |
| Account, cache, cancellation, source factories, actuals, rights, Unicode and safe reviewed imports | `CoffeeAssistanceTests` in `mugshot-luna-home-owner-green.xcresult` | 19/19 pass |
| Existing Home behavior and analytics constraints | `HomeWorkbenchTests` (15), `MugshotAnalyticsTests` (9), fresh acceptance bundle | 24/24 pass; passing evidence reused |
| Consent defaults off; provider failure preserves the draft; explicit acceptance changes it; generation alone does not; largest text/Reduce Motion retain usable consent/fallback | Five `CoffeeAssistanceUITests` | 4/4 pass in boundaries bundle, fifth passes in green bundle |
| Actual Luna API accepts all task schemas and image inputs | Six text and two image-only original fictional fixtures | 8/8 pass; no customer content |
| Build, offline backend types, formatting, SQL parsing and hermetic contracts | `./scripts/verify-no-simulator.sh backend` final run | 12 checks pass, zero failures/skips; 256 SQL files parsed |
| Native compilation | Focused Xcode test builds | PASS; inherited redundant `#require` warnings remain |
| Formatting, documentation, whitespace and secrets | Deno fmt (7 files), documentation script, diff checks and 48-file scoped credential scan | PASS; local key remains private/ignored |

There are 43 distinct passing native unit tests and five distinct passing UI
tests across these focused runs. This is a union of reused passing evidence,
not a claim that the latest single command ran all 48. The earlier failed runs
and their actual assertion failures remain documented above.

### Executed commands and environment

- `./scripts/verify-no-simulator.sh backend`: final 12/12 PASS.
- `qa/pglite/node_modules/.bin/deno test --cached-only --coverage=/tmp/mugshot-luna-deno-coverage-final supabase/functions/coffee-assistance/handler_test.ts supabase/functions/coffee-assistance/provider_test.ts`: 10/10 PASS.
- `qa/pglite/node_modules/.bin/deno coverage /tmp/mugshot-luna-deno-coverage-final`:
  84.0% lines / 88.2% branches / 88.9% functions across handler/provider.
- `qa/pglite/node_modules/.bin/deno test --no-run --cached-only --no-remote --no-lock supabase/functions/coffee-assistance/index.ts`: entry point type-compiles offline.
- `qa/pglite/node_modules/.bin/deno fmt --check supabase/functions/coffee-assistance scripts/check-coffee-assistance-provider.ts scripts/check-coffee-assistance-vision.ts`: seven files pass.
- Native runs use `xcodebuild -project testMugshot.xcodeproj -scheme MugshotTests`,
  destination `D59CE5EF-6971-453B-B671-86ECBDA31E6E` (iPhone 17 Pro, iOS 27.0
  Simulator), derived data `/tmp/mugshot-luna-derived-data`,
  `-parallel-testing-enabled NO -collect-test-diagnostics never`, and focused
  `-only-testing:` selectors for the suites named above. Final domain run uses
  `-only-testing:testMugshotTests/CoffeeAssistanceTests -enableCodeCoverage YES`.
  Build settings explicitly use `MUGSHOT_SUPABASE_URL=https://assistance-fixture.invalid`,
  `MUGSHOT_SUPABASE_PUBLISHABLE_KEY=synthetic-key`, empty
  `MUGSHOT_POSTHOG_PROJECT_TOKEN`, `CODE_SIGNING_ALLOWED=NO`, and
  `COMPILER_INDEX_STORE_ENABLE=NO`. The installed fixture bundle is `co.mugshot.app`.
- Paid probes use Deno `--env-file=.env.local`, env access and networking limited
  to `api.openai.com`; the vision probe additionally reads only the two generated
  fictional JPEGs. They bypass Supabase and do not prove deployed Auth/RPC wiring.
- `./scripts/check-documentation.sh` and `git diff --check`: PASS.

### Coverage and limits

The final 19-test native domain run reports context 92.7%, recipe import 96.9%,
core request/result models 80.7%, session 92.9%, and service/cache 40.7% line
coverage. The separate shared-component UI run reports 83.6% for the shared
views, 98.2% for the unchanged core models and 95.2% for the unchanged session.
These are per-run focused file measurements, not app-wide or merged coverage.
The real authenticated URLSession transport is compiled and source-reviewed;
its deployed end-to-end path remains unexecuted. Tests inject transport for
account/cancellation and UI acceptance. The 80% ECC target is met in measured
handler/provider, context/import, model/session and shared UI behavior; the
transport coverage gap is explicitly retained rather than hidden with filler tests.

## Delivery disposition

Local build/types/format/tests/security/diff checks pass for review. Production
configuration and authenticated deployed acceptance are **not performed**.
No physical-device or TestFlight acceptance is claimed. Parent candidate PRs
retain their acceptance holds; this stacked candidate must not bypass them.
The API key and approved model work for the original synthetic provider probes;
the monthly promotional credit's billing treatment was not inspected.
