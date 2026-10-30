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
- Deployment, root-cause reproduction and original-draft acceptance are pending.
