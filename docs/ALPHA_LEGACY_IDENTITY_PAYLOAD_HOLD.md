# Closed legacy identity-payload read boundary

Status: closed by `20260722031500_close_recipe_visit_payload_leak.sql` without
rewriting historical tester data.

The pre-alpha Supabase data is production-like and contains posts from multiple
real testers. The additive migration
`20260722014800_alpha_identity_sharing_contracts.sql` therefore preserves every
existing visit, recipe payload, and legacy companion row.

New client reads use allowlisted recipe, Taste Passport, tag, and shared
MugShot projections. Those projections do not return arbitrary recipe JSON, raw
taste evidence, hidden member identities, or hidden contribution counts.

## Closed confidentiality boundary

The follow-up migration revokes table-level `SELECT` from app roles and grants
only the explicitly safe visit columns needed for social, journal, map, and
recovery reads. App roles can no longer select `brew_details`, `brew_method`,
`equipment`, recipe provenance, notes, or other protected visit columns—even
from a post whose audience is Everyone. Authorized full recipe reads go only
through the caller-bound recipe projection.

New recipe visits use contract v2: the client stages the full payload in an
owner-bound, unexposed, expiring table, then inserts a socially safe visit row.
The existing materialization trigger consumes the stage transactionally into
the independently permissioned recipe version. The visit retains only recipe
name/version display metadata. A retry cannot recreate a stage after the visit
has committed.

Historical rows and JSON bytes remain unchanged. That is deliberate: closing
read access does not authorize destructive cleanup of production-like tester
data.

## Deployment gate

The column-privilege cutover intentionally breaks old binaries that still ask
PostgREST for protected visit columns. Deploy the compatible app and migration
as one coordinated release boundary, and enforce the compatible minimum app
version before enabling broad alpha access. Before applying the migration to
the production-like project:

1. A restorable backup of the production-like project has been verified.
2. The compatible app build is ready for distribution.
3. The migration and recipe confidentiality contract test pass against a local
   restore or disposable project.
4. Existing tester posts are smoke-checked through feed, Journal, profile, and
   recipe projection reads.

No scrub SQL is included. No remote migration has been applied from this
workspace.
