---
document_type: historical
status: installed-human-qa-pending
---

# Luna phone QA and backend activation — 2026-11-04

Current behavior and rollback: [AI assistance](../AI_ASSISTANCE.md).
This continuation supersedes the delivery state in the
[November 2 implementation ledger](OPTIONAL_COFFEE_ASSISTANCE_2026-11-02.md).

## Delivered state

The owner requested keeping Luna, using the OpenAI credit, and loading the app
on their phone for human QA. The credit benefit and delivered credit balance were
read from the connected OpenAI account; no payment method, auto-top-up, spending
limit, subscription, organization link, or model was changed. Credential values
remain outside source control and the iOS bundle.

- `coffee-assistance` is active at version **3**, using `gpt-6-luna` with the
  server enable switch on. Exact reviewed bundle SHA-256:
  `ac85df24cc401ba4ecadff5b566efd2781b000ba04464aea5543070625be25b6`.
- Only `20261102160000_optional_coffee_assistance.sql` was applied to production.
  The held Home V4 public-preparation migration remains excluded. The exact
  release bundle now reports no pending migrations; this does not claim that
  every migration on the stacked native branch is live.
- **Mugshot Luna QA 0.5.3 (8)** is installed as `co.mugshot.app.dev` on the
  owner's iPhone 16 Pro / iOS 27.0.1. It launched, restored the existing account,
  and rendered Feed. The normal `co.mugshot.app` installation and the earlier
  motion fixture remain installed.
- Binary source is commit `535d9aa`. The only package-label adjustment is
  `CFBundleDisplayName=Mugshot Luna QA`, followed by signing with the same
  existing development identity and identical entitlements. The package passes
  strict/deep signature verification and contains no OpenAI key. Production
  analytics is disabled in this QA package.
- [Package and local-data receipt](optional-assistance-2026-11-04/phone-install-receipt.json).
  All **52** pre-existing Application Support files were backed up privately and
  matched byte-for-byte after installation, before launch. Private screenshots,
  account containers, credentials and billing screenshots are not committed.
- Human acceptance of the helper responses on the phone remains pending. No
  TestFlight archive, upload, assignment or acceptance occurred. Parent PR holds
  remain in force; installation does not merge that native stack.

## Verification and protected data

The owner approved the temporary data-less Supabase branch at the quoted
**$0.01344/hour**. The branch initially stopped at historical migration 113,
which requires an operational Vault secret. Inert fixture credentials allowed
the remaining 72 migrations to replay atomically. All schedules were disabled
before commit; no production data or operational worker credentials were copied.

| Check | Observed result |
| --- | --- |
| Complete guarded hosted contract suite | **67/67 pass**, no failures |
| Actual Auth -> Edge -> quota RPC -> Luna -> validated result | **8/8 pass**: six text tasks and original fictional bag/recipe images |
| Unauthenticated, wrong owner, missing consent, duplicate operation | HTTP **401 / 403 / 400 / 429**, respectively |
| Hosted service-only access | `anon` and `authenticated` cannot read either table or execute reservation RPC |
| Hosted quota/erasure | Global cap enforced; account deletion cascades identifiable receipts while anonymous budget stays spent; test transaction rolled back |
| Hosted daily quota | HTTP **429** after 20 admitted reservations, before provider access |
| Live disabled switch before activation | HTTP **503** without provider access |
| Live enabled no/invalid bearer | HTTP **401**; zero synthetic production reservations |
| Live backup | Completed physical backup dated **2026-11-04 10:50:06 UTC** |
| Existing production content | Whole-row SHA-256 aggregates and counts unchanged across **73** original public/Auth/Storage tables immediately around migration |
| Security advisors | No new WARN categories/findings; two expected INFO findings for service-only RLS tables without client policies |
| Phone package | Native compile, deep signatures, exact identity/entitlements, backend targeting, analytics suppression, secret exclusion and launch pass |

The first hosted probe reused a fixture request ID across bag and memory tasks;
the backend correctly returned 429. The fixture was corrected to generate unique
IDs, and all eight final cases passed. This was a probe setup error, not a
production behavior defect or claimed ECC behavioral RED.

Updating shared Edge environment variables advanced existing function version
counters by two. All 14 available pre-existing bundle hashes match their earlier
values; the two legacy PWA functions have unchanged entrypoints but no supplied
bundle hash. No existing function source was deployed. Moderation remains the
retired local-text/report path; the existing drink-analysis function remains
rules-based, and neither deployed source uses the OpenAI key.

The temporary QA branch was deleted after acceptance and its absence was
confirmed. The current server limit remains 20 requests/account/UTC day and
3,000/project/UTC month. These are request limits, not a dollar-budget guarantee.
The existing November 2 native unit/Simulator evidence is reused because the
Swift feature source is unchanged. No new app-wide coverage claim is made.

## Commands and evidence

- [Sanitized hosted acceptance output](optional-assistance-2026-11-04/hosted-acceptance.txt)
  preserves actual PASS/SUMMARY lines without credentials, account data or prompts.
- Pinned Supabase CLI **2.109.1**. The exact release directory contains the
  183 previously live migrations plus only the assistance migration.
- `./scripts/verify-supabase-qa.sh <temporary-branch-id>`: 67/67 PASS.
- Explicit synthetic deployed probes use only the temporary branch's Auth/API
  and original fictional text/JPEG inputs. Database quota tests refuse the live
  project and roll back the global-budget/erasure check.
- `supabase db push --linked --dry-run` in the exact release directory lists
  only the assistance migration before deployment, then reports up-to-date.
- `xcodebuild -project testMugshot.xcodeproj -scheme MugshotTests -configuration Debug`
  uses the actual connected phone UDID, isolated derived data, empty analytics
  token, and `COMPILER_INDEX_STORE_ENABLE=NO`. Early scheme/destination lookup
  errors were corrected before the successful compile; they are not test RED.
- `codesign --verify --deep --strict`, `devicectl device install app`, launch,
  installed-app inventory and physical screenshots establish package/launch
  evidence. Device/account identifiers and private screen captures remain local.

## Human QA — about 10 minutes

Open **Mugshot Luna QA**. The requests are real and use the selected details
shown in each consent preview. Use your own recipe or a source you may copy;
keep any new test sip or recipe Private. Each helper request counts toward the
20/day limit. Report whether the wording is useful, accurate and fast enough.

| Where | Try | Expected result |
| --- | --- | --- |
| Home coffee bag scan -> **Improve this scan** | A real bag with a clear label, then a harder crop | Printed details are accurate; unknowns stay unknown. Edit/deselect any wrong fields before acceptance. |
| Recipe editor -> **Bring in a recipe / Read a recipe** | Your own recipe text or screenshot with amounts and credit | Exact amounts/units and steps remain understandable; selected fields update the draft, with ordinary Save still separate. |
| Journal archive search -> **Find a memory** | A vague phrase for a sip you remember | Suggested evidence opens the correct owned entry. Private notes are included only when explicitly enabled and previewed. |
| Journal tools -> **Notice a taste pattern** | At least three completed memories | A cautious, useful observation supported by your records; printed roaster notes do not become your sensory experience. |
| Saved Home sip actions -> **Explore a next experiment** | A saved attempt with actual amounts and a next-time note | One practical change based on actuals and your feedback, without inventing missing measurements. |
| Weekly recap -> **Reflect on this week** | Compare with the ordinary recap | Counts and dates agree, drafts are excluded, and AI wording does not replace the deterministic share card. |

On one helper, open and close without consenting; on another, generate then
close without accepting. Existing content must remain unchanged. Check large
text if you use it. Assess whether the helper placement is easy to discover and
whether its wording earns the extra tap. Account-switch and AI-failure
boundaries already have automated evidence; any surprising phone behavior is
still a bug to investigate, not something to work around by changing old data.
