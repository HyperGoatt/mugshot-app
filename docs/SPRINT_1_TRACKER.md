---
document_type: living
status: current
last_verified: 2026-09-12
---

# Sprint 1 delivery: trust, moderation, and working sharing

## Confirmed requirements

OpenAI moderation plus Joe's review queue; no Mugshot data shared for model
training or improvement. Private content is excluded from screening. Explicit
consent is required to publish existing and future Friends posts on public
profiles. Public profile links use `/profile/username`, preserve legitimate
legacy links, and never transfer old handles to another account. Complete
deletion, sip-link routing, existing expressive reactions, and removal of
unavailable Passport promises. Broad redesign and new growth features are out.

## Delivery states

| Workstream | Evidence | Remaining |
| --- | --- | --- |
| OpenAI setup | Dedicated Mugshot project created; feedback, evaluation/fine-tuning, and API input/output sharing all visibly Disabled organization-wide; project key saved locally outside Git; synthetic text-only moderation HTTP 200 | Server deployment and recurring release configuration checks |
| Profile consent | Versioned RPC, disable-only legacy setter, author plus tagged-profile consent; isolated PostgreSQL behavior test and iOS Debug app/test compile pass | Runtime acceptance and production deployment |
| Screening and review | Standalone provider boundary implemented; seven synthetic Deno tests pass Private exclusion, payload minimization, metadata stripping, fail-closed responses, retries and initial spam signals | Revision-bound database queue; scheduled worker; all outward gates; protected moderator queue; rate controls; reporting/enforcement and reconsideration |
| Existing shared content | Not screened | Updated disclosures, staged screening; unscreened content withheld from outward surfaces; owner access retained |
| Deletion | Existing V3 orchestration; audit found production initiation disabled | Fresh-auth/provider revocation, interrupted recovery, media/analytics cleanup, disposable-account and production acceptance |
| Readable profile and sip links | Implemented username RPC/routes, reserved aliases and tombstones, legacy token compatibility, public web recipient pages, and removal of service-worker API caching. Local handle contract and synthetic web render/revocation/retry checks pass | Native runtime acceptance, exact backend replay and deployment, installed-app journey |
| Reactions | Existing additive migration not production deployed at audit | Isolated replay, capability fallback, production deployment and candidate acceptance |
| Passport claims | Removed Journal upgrade-only entry and onboarding Passport promotion; marketing promotion, FAQ, feature schema and guide claims removed; legacy web page states unavailability | Source compile and marketing render checks pass; deployment and batched native acceptance remain |
| Release | Not accepted | Static/backend checks, batched Simulator and owner-promoted device acceptance, separately authorized TestFlight upload and exact-build acceptance |

## No-training operating contract

The organization sharing controls were inspected in the signed-in Platform on
2026-09-12 America/New_York. All three were Disabled, including API inputs and
outputs; no free-token data-sharing program was enabled. Settings apply across
projects. This is dated configuration evidence, not a guarantee against future
administrator changes. Verify again before production content processing.

Use only `/v1/moderations` for this integration. Never send user content to
training, evaluations, Playground feedback, or debugging conversations. Strip
image metadata, minimize shared fields, exclude private journal content, and
redact logs. Human review decisions remain in Mugshot. Provider processing must
be disclosed; no-training is distinct from retention and external processing.

Sources: [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data)
and [moderation](https://developers.openai.com/api/docs/guides/moderation).

## Acceptance

Test visibility for Private/Friends/Everyone across author, friend, tagged
profile, stranger, anonymous visitor, blocked viewer, and old client. Exercise
moderation failures, stale revisions, edit/delete races, retries and removals;
deletion uses disposable accounts and preserves collaborators. Verify no raw
content in telemetry or unintended OpenAI payload fields. Check canonical,
legacy, revoked, renamed and deleted-account links, reaction persistence and
the core capture/save/reopen journey.

Follow the repository verification and documentation policies. Record exact
commit, migration, Edge Function configuration, and build for each acceptance
state. No TestFlight archive/upload/group assignment until explicitly requested
after local validation. Credentials and screenshots containing account details
must never enter the repository.

## Local verification checkpoint

`verify-no-simulator.sh full-static`: 12 passed, 0 failed, 1 skipped
(optional pglast unavailable; hermetic PostgreSQL execution passed). Final
consent-read adjustment passed the focused PostgreSQL test and a fresh generic
iOS Debug app/test compile. Documentation checker and diff checks passed.
No Simulator was booted, no Supabase project was mutated, and no TestFlight
build was created. Readable sharing implementation now follows the consent checkpoint. Its isolated
handle contract, Edge type checks, PWA build, marketing verification (14 tests),
and synthetic Playwright recipient checks pass. Native integration and full
backend replay remain pending. Browser plugin was unavailable; local Playwright
used 390x844 and 1280x900 viewports. Profile/sip rendering, unavailable-state
clearing, retry, native-link destinations and absence of runtime errors passed.
Screening, deletion completion and release remain outstanding. Passport removal
passed the updated generic iOS app/test compile, marketing build verification,
and local browser navigation check. Final sharing-source compile passed after
restoring old-backend collection fallbacks and making share artwork require a
successful anonymous projection. UI test expectations now match the retired
Passport entry; execution remains queued for consolidated acceptance.


## Screening implementation checkpoint

The provider module is locally tested, not deployed or connected to content
writes. It admits only shared text and prepared JPEG/PNG bytes to standalone
moderation. Private audience and unverified no-training configuration stop
before transmission. Provider failures cannot produce approval; flags require
review. Queue leases, revision checks, outward publication gates and founder
review integration remain required before activation. No user content has been
sent during these tests.
