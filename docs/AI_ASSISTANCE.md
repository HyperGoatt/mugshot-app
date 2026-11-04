---
document_type: living
status: current
last_verified: 2026-11-04
---

# Optional coffee assistance

## Delivery state

The `codex/luna-assistance` candidate is production-configured for optional
`gpt-6-luna` requests. Function version 3 is enabled after 67 hosted contracts,
eight authenticated synthetic text/image probes and quota/ownership denial
checks. Existing data was preserved around the exact additive migration.

**Mugshot Luna QA 0.5.3 (8)** is installed as the development app on the owner's
iPhone 16 Pro / iOS 27.0.1. It restores the existing account and renders Feed;
human acceptance of real helper responses remains pending. No TestFlight action
occurred. Parent PR holds remain, and the separate Weekly Pour visual proposal
is excluded. [Current activation and phone QA](audits/OPTIONAL_ASSISTANCE_PHONE_QA_2026-11-04.md)
contains the package receipt and checklist; the [November 2 ledger](audits/OPTIONAL_COFFEE_ASSISTANCE_2026-11-02.md)
retains the original implementation evidence.

The subsequent [Journal/bean correction](audits/JOURNAL_AND_BEANS_2026-11-04.md)
records the reported physical Journal crash and installed add/scan controls in
current Home setup. Corrected Journal opening is now physically verified with the
existing account; touch navigation and real helper acceptance remain human QA.

## Simpler native access — November 4 candidate

The [Home library candidate](audits/HOME_LIBRARY_EXPERIENCE_2026-11-04.md) replaces
per-request consent forms with one short, explicit Enable Luna control, remembered
per account/device and revocable in Home preferences. Opening the library itself
makes no AI request. Selecting a bag photo then reads it directly into editable
fields; invoking another contextual helper requests its result without a second
Generate step. Recipe idea capture can read selected screenshots/pasted text into
a draft. The source-capture follow-up below removes its separate copy prompt for
new factual capture from selected public posts/attachments. Ordinary Save stays
separate; known protected recipe records retain their no-copy guard.
The candidate is installed and physically opens Journal and Saved → Home library
on the owner's iPhone, including all library sections and bag entry/cancel.
These owner-account checks leave Luna permission unchanged and send no real photo.
The source-capture follow-up verifies the caption-to-guidance-to-rating/review
journey in a separate local-only iPhone app. Real owner bag-photo/save acceptance,
the Photos picker and optional spoken-step recognition remain separate checks.

## Product behavior

The [recipe canvas and drink builder](design/home-recipe-composer-2026-11-04/README.md)
reuse the existing extractor. Selecting a recipe-use label or combining saved
parts needs no model request. Source caption/image boundaries, remembered Luna
permission and ordinary Save remain unchanged. Composition links private saved
versions; it does not copy or publish their instructions automatically.

The [source-capture follow-up](audits/HOME_SOURCE_CAPTURE_2026-11-04.md) adds native
reads of available public Instagram/TikTok captions and screenshot/video-frame
OCR before optional Luna structuring. Clear section parsing remains available
without AI. Chosen source facts fill the new capture draft automatically, without
a per-recipe legal checkbox. Video speech recognition is optional and on-device;
raw audio is not sent to OpenAI. Combined text reserves the credit slot inside the existing
20-item/800-UTF-16-unit evidence limit. The server/model/quota are unchanged.

| Helper | Entry | Existing independent behavior |
| --- | --- | --- |
| Bag capture | Saved → Home library → Beans → Scan a bag → photo | Apple Vision scan, editable fields and ordinary Save |
| Recipe capture | Bring in a recipe in the recipe editor | Blank/template entry, source text and normal recipe draft/save |
| Memory search | Find a memory alongside Journal archive search | Ordinary local search, filters and timeline |
| Taste observations | Notice a taste pattern in Journal tools after three completed memories | Existing evidence-based Taste Passport |
| Home experiments | Explore a next experiment in a saved Home sip's actions | Actual measurements, next-time notes, repeat and comparison |
| Weekly reflection | Reflect on this week inside the existing week recap | Canonical deterministic recap, counts, photos and sharing |

These are five feature groups; capture has separate bag and recipe tasks. There
is no general chat, autonomous agent, background generation, or AI dependency in
authentication, save, publication, recipe persistence, search, scoring or recaps.
Luna starts disabled for each account on this device. Its short enable control
names OpenAI and selected photos, recipe text and saved sip details. After explicit
enablement, the user starts work by selecting a scan/import source or invoking a
contextual tool. Selected evidence stays inspectable. No passive journal-wide
background processing occurs.
The legacy in-editor copy helper retains its source-copying confirmation. New
public-link/attachment capture automatically fills factual fields, keeps source
credit and does not assert or expand a source's reuse permission. Known
protected/no-copy recipes cannot use import. Accepted fields update only
the editable draft; ordinary Save remains a separate action. Recipe capture
preserves attribution and existing fields, appends selected literal ingredient
and instruction text without inventing numeric amounts, and does not change
recipe visibility. Brew suggestions are read-only and do not modify a recipe.

Model interpretation is labeled as an AI suggestion with inspectable source
references. Printed roaster notes are never personal sensory evidence. Planned
targets never become recorded actuals. Sparse evidence cannot establish a fixed
taste identity, expertise, extraction diagnosis, or causal conclusion. Weekly
facts use completed canonical and deduplicated saved Home activity, excluding
drafts. AI reflection text stays out of the existing automatic share card.

## Privacy and ownership

- API keys remain server-only; `.env.local` is ignored and never an iOS resource.
- Opening the library or an unenabled helper makes no AI request. After explicit
  enablement, choosing a scan source or opening a contextual tool starts that
  bounded request. Bag reads fill editable identity fields while preserving typing
  made during the request. Manual save does not wait for a provider.
- The remembered permission is versioned and account-specific, revocable in Home
  preferences and erased on deletion. It is never adopted across accounts. A
  revoked permission invalidates active UI work and clears the result cache.
- Journal search excludes private notes unless the user enables its explicit
  inclusion control. Single-attempt feedback is visible in the request preview.
- Only owner-bound completed journal records and saved Home records are used.
  Home evidence also requires the loaded workspace scope to match that owner.
  The originating owner is fixed before presentation; changed owners dismiss
  helpers and invalidate work. Backend authorization binds the body owner to the
  verified, live Auth user. API calls use the originating account's captured
  bearer token, with owner checks before and after suspension.
- Evidence is capped at 40 records / 20,000 UTF-16 units, each detail at 800,
  titles at 120 and queries at 400. Search ranks available owner records locally
  before selecting candidates. It does not claim to search unloaded history.
- Selected images are redrawn as metadata-free JPEGs, no more than 1280 pixels
  per dimension / 290 KB. The server independently validates JPEG dimensions,
  inline data and request limits. No external image URL is fetched.
- OpenAI receives only task/query/evidence/image, not account IDs, request IDs,
  auth tokens, photo URLs or an entire automatically uploaded journal. Evidence
  IDs are needed for linking results. Results can cite only supplied IDs.
- Responses API uses `store: false`; this does not promise zero provider
  retention. OpenAI's standard abuse-monitoring retention and any organization
  data-sharing choices still apply. See [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data).
- The local result cache is memory-only, owner-bound, source-sensitive, limited
  to 30 items and five minutes. Permission withdrawal clears it. Scan/import
  results can fill editable capture fields; ordinary Save is required to persist
  them. Other contextual suggestions retain explicit acceptance.
- Product analytics records only fixed task/outcome enums. No prompts, images,
  questions, answers, source IDs, private notes or LLM content traces are sent to
  PostHog. Content moderation remains local text rules and report/human review.

## Backend contract and limits

`POST /functions/v1/coffee-assistance` verifies the bearer with Auth.getUser,
checks `is_live_account`, requires an exact owner and `selected-details-v1`
consent, validates bounded input and reserves a request before provider work.
It has no journal, recipe, audience or publishing mutation capability.

The service-only `coffee_assistance_reservations` ledger contains only request
UUID, owner UUID, task and timestamp. RLS/grants deny ordinary client access;
account deletion cascades these operational receipts. A second service-only
`coffee_assistance_monthly_budget` table contains only month/count, with no owner
identifier. Its anonymous aggregate survives deletion so erasure cannot replenish
already-used global quota. A transaction advisory lock enforces 20 reservations/account/UTC day and 3,000/project/UTC month across
workers. Duplicate request IDs cannot call the provider twice. Failed or unknown
requests retain their reservation. A manual retry uses a new ID and consumes
another slot. These are request caps, not a claim of exact dollar spending.

The server uses the owner-approved `gpt-6-luna` with reasoning `none`, no tools,
a strict output schema and 1,000 maximum output tokens. No automatic upgrade or
fallback model exists. Provider timeout is 20 seconds; native request/resource
timeouts are 25/30 seconds. Refusals, partial/malformed responses, invented
references, quota denial, missing configuration and outages return a generic
unavailable state with the original app data intact. No automatic retries.

## Configuration and release

Required server-only configuration is `OPENAI_API_KEY`,
`MUGSHOT_AI_MODEL=gpt-6-luna`, and `MUGSHOT_AI_ENABLED=true`, plus the existing
Supabase public and secret keys. The enable switch defaults off and is checked
before provider access. Local credentials are not production configuration.

The initial authorized activation completed on November 4. For future deployments,
after review and production authorization, apply only
`20261102160000_optional_coffee_assistance.sql`, deploy `coffee-assistance`, then
set its server-only secrets and enable switch. Preserve existing user content and
all prior backend services. Roll back optional assistance by setting
`MUGSHOT_AI_ENABLED=false`; do not remove user journal or recipe data. Verify
authentication/owner denial and the disabled fallback before enabling the native
candidate. Native distribution, physical-device acceptance and TestFlight are
separate gates under the [release workflow](SUPABASE_RELEASE_WORKFLOW.md).

## Verification

Follow [VERIFICATION_POLICY.md](VERIFICATION_POLICY.md). Run the focused Deno
handler/provider tests with coverage, `node qa/pglite/check-coffee-assistance.mjs`,
native domain/account/cancellation tests, and the permission/failure/review and automatic-scan Simulator
journeys. The paid synthetic provider probe is explicit and separate from CI:
`scripts/check-coffee-assistance-provider.ts`. It must never receive production
journal content. Full commands and observed results belong in the evidence ledger.

Image-only provider acceptance uses original fictional fixtures generated by
`scripts/make-coffee-assistance-fixture.swift` and checked by
`scripts/check-coffee-assistance-vision.ts`. These probes run only on explicit
local invocation and never use user photos or production records.
