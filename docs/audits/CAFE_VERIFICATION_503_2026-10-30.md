# Cafe verification 503 incident — 2026-10-30

Historical evidence. Current data flow is documented in
[REAL_DATA_FLOW_STATUS.md](../REAL_DATA_FLOW_STATUS.md).

The owner explicitly authorized repair of cafe verification and a controlled
publication of the original protected five-photo draft. Scope: Supabase Edge
Function, privacy/diagnostics and operations; no schema or Storage-policy change.
No replacement post, copied draft ID, invented cafe or relaxed authorization is
permitted. Verify the exact original visit ID and frozen five-photo plan.

## Baseline

- Browser access restored. Supabase dashboard confirms all three Apple Maps
  secret names are configured; values were not read or copied.
- Exact original visit row is still absent before recovery. Previous device
  evidence showed `prepared` and five photos. A fresh read is currently blocked
  because Joe's iPhone is unavailable to CoreDevice; owner has been asked to
  connect/unlock it while independent server work continues.
- Existing function version 10 masks every thrown failure as HTTP 503. The
  underlying provider failure is not yet proven.

## TDD and security evidence

- RED checkpoint `3b94e48`: local Deno suite executes six tests, four pass and two
  fail because provider operation/status and bounded stage reporting are absent.
- GREEN after diagnostic implementation: six tests pass, zero failed.
- Command: repository-pinned Deno `test --cached-only --no-lock
  supabase/functions/verify-cafe/handler_test.ts`. Changed TypeScript is formatted.
- Tests retain auth denial, strict payload, rate limiting, provider ID/coordinate
  checks, verified-only writes, restricted JWT signature/scope, numeric HTTP
  diagnosis and raw-error redaction.
- Generic user response remains unchanged. Server log contains no secret,
  authorization header, actor/place identifier, provider body or journal content.

## Confirmed root cause and repair

An operator-only provider-read check in the live Edge runtime reproduced
`invalid_place`. Apple's token exchange and place lookup succeeded. The returned
ID matched the selection; name, coordinates and address types were valid. The
single 59-character address string contained CR/LF characters. Mugshot's parser
rejected every ASCII control character, including these valid address line
breaks, and its handler converted that error into a generic 503 before any cafe
admission, sip creation or photo upload.

Temporary versions 12–14 required the existing service-role credential plus a
specific incident header, used a fixed public cafe ID, never called persistence,
and returned only bounded failure/schema flags. Version 15 removed the probe and
restored the version 11 diagnostic-only bundle. Provider credentials and place
values were not copied to the browser, repository or logs. Supabase's built-in
test form supplied its existing administrator authorization; that header was
never extracted into shell commands or repository files.

- Address regression RED checkpoint `f7998b3`: seven pass, two fail, including
  full handler 503 vs expected 200. Boundary checkpoint `b15e18d` preserves
  rejection of leading/trailing tabs and other controls before trimming.
- Fix splits CR/LF boundaries, trims ordinary postal lines and joins nonempty
  parts with comma separators. Non-newline controls, empty addresses, oversized
  raw entries/combined addresses, mismatched IDs and invalid coordinates remain
  rejected. No alternate provider, invented catalog data or auth bypass is used.
- GREEN: all nine focused Deno tests pass, zero failures. The entrypoint and
  pinned dependency graph also type-check through `test --no-run`.

## Production deployment and acceptance boundary

- The same operator-only check with the repaired parser returned
  `provider_check: ok` against Apple's live response for the selected cafe.
  This proves provider verification; the probe deliberately did not call
  catalog persistence, create a sip or upload a photo.
- Final `verify-cafe` version **17**, deployed **2026-10-30T21:34:19Z**, is active
  with JWT verification enabled. A fresh downloaded bundle matches all five
  committed source files exactly and contains no temporary operator route.
  SHA256: `a3d48a28d0b3eb7a04a18a0e4aab9473d0b6370c3163d1a593b74359d19dc32a`.
- A fresh unauthenticated production POST returns **401**. Local static checks
  pass **7/7**, no failures/skips. Documentation integrity and diff checks pass.
- After deployment the exact original visit has **zero visit rows**, **zero
  photo rows**, and **zero Storage objects across buckets**. The owner has zero
  new visit rows during the controlled-check interval starting 21:20Z. The
  provider checks therefore did not publish or duplicate the protected draft.
- Physical original-draft acceptance is **blocked**: Joe's paired iPhone is
  unavailable to CoreDevice, and the fresh read-only draft backup fails because
  there is no trusted connection. The owner has been asked to connect/unlock
  that specific iPhone. No replacement draft, queue edit or manual database
  publication has been performed. The prior five-local-photo observation is
  historical evidence, not a fresh integrity check.
- Once connected: copy the frozen pending record and five local JPEGs before
  recovery; compare hashes/counts; launch the existing app and resume only the
  same original visit; confirm complete state, frozen audience, five distinct
  photo rows/objects, no other new post and an empty original outbox record.
  Do not equate eventual recovery with successful original publishing UX.
- This server-only hotfix needs no new native build. Existing client work has
  separate local/Simulator evidence in draft PR #105; no new physical-device
  or TestFlight acceptance is claimed by this service check.
