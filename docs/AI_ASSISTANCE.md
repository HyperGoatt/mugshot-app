---
document_type: living
status: current
last_verified: 2026-11-02
---

# Optional coffee assistance

## Delivery state

The `codex/luna-assistance` candidate implements optional helpers on the current
publishing/Home V4 candidate. Its parent PRs retain their existing acceptance
holds. This does not integrate the separate Weekly Pour visual proposal.
Backend handler/provider tests, a disposable PGlite quota contract, native domain
checks, five synthetic Simulator UI journeys and eight synthetic live provider
probes pass. The native app and test bundles compile. No production migration,
function deployment, iPhone install or TestFlight action has occurred for this candidate. The final evidence is recorded in the
[verification ledger](audits/OPTIONAL_COFFEE_ASSISTANCE_2026-11-02.md).

## Product behavior

| Helper | Entry | Existing independent behavior |
| --- | --- | --- |
| Bag capture | Improve this scan after choosing a bag photo | Apple Vision scan, editable fields and ordinary Save |
| Recipe capture | Bring in a recipe in the recipe editor | Blank/template entry, source text and normal recipe draft/save |
| Memory search | Find a memory alongside Journal archive search | Ordinary local search, filters and timeline |
| Taste observations | Notice a taste pattern in Journal tools after three completed memories | Existing evidence-based Taste Passport |
| Home experiments | Explore a next experiment in a saved Home sip's actions | Actual measurements, next-time notes, repeat and comparison |
| Weekly reflection | Reflect on this week inside the existing week recap | Canonical deterministic recap, counts, photos and sharing |

These are five feature groups; capture has separate bag and recipe tasks. There
is no general chat, autonomous agent, background generation, or AI dependency in
authentication, save, publication, recipe persistence, search, scoring or recaps.
Every request starts from a closed helper, previews the exact selected records
and optional image, and requires an unchecked-by-default per-request consent.
Recipe extraction also requires the user to confirm source-copying rights.
Known protected/no-copy recipes cannot use import. Accepted fields update only
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
- No cloud call happens on opening a helper. The user reviews details before
  allowing a request and may leave without sending anything.
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
  data-sharing choices still apply. The helper links current provider controls.
- The local result cache is memory-only, owner-bound, source-sensitive, limited
  to 30 items and five minutes. Consent withdrawal clears it. No prompt or result
  is persisted as journal or recipe content without explicit field acceptance.
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

After review and explicit production authorization, apply only
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
native domain/account/cancellation tests, and the consent/failure/review Simulator
journeys. The paid synthetic provider probe is explicit and separate from CI:
`scripts/check-coffee-assistance-provider.ts`. It must never receive production
journal content. Full commands and observed results belong in the evidence ledger.

Image-only provider acceptance uses original fictional fixtures generated by
`scripts/make-coffee-assistance-fixture.swift` and checked by
`scripts/check-coffee-assistance-vision.ts`. These probes run only on explicit
local invocation and never use user photos or production records.
