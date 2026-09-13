# Shared-content screening

Status: provider boundary implemented and locally tested; queue, outward gates,
worker scheduling and moderator UI are not yet connected. Do not deploy this
folder as a live worker until the complete Sprint 1 release contract passes.

`provider.ts` calls only OpenAI `/v1/moderations` with `omni-moderation-latest`.
It accepts explicit shared text and JPEG/PNG bytes. It excludes Private content
before any request, removes container metadata and trailing image bytes, and
never sends IDs, row objects, private notes, human review decisions or feedback.
Unsupported media goes to human review without a provider request. Text and
image size limits are local operational limits, below the provider maximum.

The caller must obtain the current content revision and allowed fields from a
sealed database queue, validate current audience before sending, and compare
the revision again before applying the result. An `approved` result alone does
not authorize a publish or account action. Flags go to review, transient errors
retry, and malformed/configuration failures remain held. No automatic bans.

A false no-training configuration acknowledgment stops processing. Production
release must first verify all optional OpenAI organization sharing controls
Disabled and record that dated evidence. API credentials belong only in server
secrets. No request bodies or provider error bodies may enter logs or analytics.

Seven hermetic Deno tests exercise no-transmission boundaries, request field
minimization, malformed/contradictory flags, failures, spam signals and image
metadata removal. They use synthetic fixtures and mocked HTTP; no user content
or live API request is involved.

OpenAI image moderation does not support all text categories. It is one signal
alongside reports and human review, not a guarantee of detecting every issue.
See the [moderation guide](https://developers.openai.com/api/docs/guides/moderation)
and [data controls](https://developers.openai.com/api/docs/guides/your-data).
