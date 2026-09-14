# Shared-content screening

Status: provider, revision-bound queue, worker, primary/collection publication
checks and protected reviewer preview are implemented and hermetically tested.
Scheduler activation, moderator/member runtime acceptance, full outward-surface audit, disclosures,
isolated full-history replay and production configuration remain incomplete.
Do not activate until the complete Sprint 1 release contract passes.

`provider.ts` calls only OpenAI `/v1/moderations` with `omni-moderation-latest`.
It accepts explicit shared text and JPEG/PNG bytes. It excludes Private content
before any request, removes container metadata and trailing image bytes, and
never sends IDs, row objects, private notes, human review decisions or feedback.
Unsupported media goes to human review without a provider request. Text and
image size limits are local operational limits, below the provider maximum.

The worker obtains the current revision from the sealed queue, admits only
owner-scoped Storage paths, then rechecks its lease after loading media and
immediately before provider transmission. Revision and lease comparisons fence
results after edits, media replacements, privacy withdrawal and human review.
Supabase requests and provider requests each have a 15-second deadline. An `approved` result alone does not
authorize a publish or account action. Flags go to review, transient errors
retry, and malformed/configuration failures remain held. No automatic bans.

A false no-training configuration acknowledgment stops processing. Production
release must first verify all optional OpenAI organization sharing controls
Disabled and record that dated evidence. API credentials belong only in server
secrets. No request bodies or provider error bodies may enter logs or analytics.

Eleven hermetic provider/worker Deno tests exercise no-transmission boundaries, request field
minimization, malformed/contradictory flags, failures, spam signals and image
metadata removal. They use synthetic fixtures and mocked HTTP; no user content
or live API request is involved.

OpenAI image moderation does not support all text categories. It is one signal
alongside reports and human review, not a guarantee of detecting every issue.
See the
[moderation guide](https://developers.openai.com/api/docs/guides/moderation) and
[data controls](https://developers.openai.com/api/docs/guides/your-data).

## Activation contract

The POST endpoint requires `x-screening-secret` matching
`SCREENING_WORKER_SECRET`. Processing also requires server-only
`OPENAI_API_KEY`, the Supabase server configuration,
`SCREENING_NO_TRAINING_VERIFIED=true`, `SCREENING_DISCLOSURE_VERSION=1`, and
`SCREENING_ENABLED=true`. Missing configuration prevents claiming jobs.
These flags are acknowledgments of verified release work, not substitutes for
publishing disclosures or checking Platform settings. No production values or
schedule have been installed by this implementation.

One invocation claims one job. Five failed or expired attempts transfer the job
to human review. Private/deleted source rows remove queued payloads; unrelated
private-note edits retain the shared-content revision. Structured rows with no
screenable text or media need no provider call. Human decisions and
reconsideration reasons remain in the sealed database audit history.

See [Sprint 1 delivery](../../../docs/SPRINT_1_TRACKER.md) for the exact pending
release gates. `moderation-review` validates the caller's authenticated user and
current server-side operator appointment, signs admitted media for 60 seconds,
and rechecks the content revision. Four synthetic handler tests cover authentication, revocation, withdrawal,
bounded input and media admission. Live endpoint acceptance is still pending;
reviewer responses are marked private/no-store.


## Dispatch limits

The database serializes claim reservations and limits dispatch to 60 claims per
minute globally and ten per owner, with six active leases globally and two per
owner. A held job stays pending without spending an attempt. Per-owner budget
rows contain only identifiers/counters, expire after a day of inactivity during
claim housekeeping, and cascade on account deletion. These are conservative
initial operational limits, not provider quotas or publication permissions.
The worker still claims one job per invocation. Scheduler installation and
throughput acceptance remain pending; no production processing is enabled.


## Scheduler setup

The migration defines the scheduler but does not create a running job. After
release gates pass, provision Vault entries `mugshot_screening_worker_url` and
`mugshot_screening_worker_secret`; the latter must match the Edge secret. Use
the service-only `configure_screening_schedule_v1(true)` to install exactly one
`mugshot-screening-v1` job every ten seconds. The stored cron command contains no
credential. Dispatch validates the Supabase worker URL and skips an empty or
fully leased queue. `configure_screening_schedule_v1(false)` removes this job
without requiring valid secrets. The Edge configuration gates remain mandatory.
No Vault values or running schedule have been installed by this source change.


Private recipes remain excluded from provider input even when an existing
explicit recommendation grants a named recipient access. Original recipient,
dismissal and block checks still apply; friendship alone and anonymous access
grant nothing. This preserves a trusted sharing path without silently converting
Private recipes to shared Friends/Everyone content. Recommendation notes remain
subject to their separate shared-content screening contract.
