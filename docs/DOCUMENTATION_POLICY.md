---
document_type: living
status: current
last_verified: 2026-08-24
---

# Documentation policy

## Required classification

Every Markdown document is one of:

- **Living:** current implementation, operations, verification, or roadmap.
- **Decision record:** locked product intent with explicit amendments.
- **Historical:** dated evidence retained without rewriting its chronology.

Living documents use YAML front matter with `document_type: living`,
`status: current`, and an ISO `last_verified` date. Historical documents that
contain superseded implementation claims must display a link to the current
living source before the old content.

## Change contract

Before implementation, classify documentation impact as one or more of:

- product behavior;
- architecture or data ownership;
- Supabase schema, RPC, Storage, Auth, Edge Function, or schedule;
- signing, capabilities, versioning, distribution, or release state;
- privacy, safety, analytics, or operations;
- no living-document impact.

For every category except the last, update `CHANGELOG.md` and each affected
living document with the same branch change. A task is not complete while a
living document contradicts source or verified environment evidence.

Status language must remain exact:

- **Implemented:** present in source.
- **Locally verified:** passed the named local check.
- **Production configured:** required production infrastructure is present.
- **Physically accepted:** exercised on signed hardware in the named APNs
  environment.
- **TestFlight accepted:** exercised from the named processed TestFlight build.

Never use a stronger status to summarize a weaker proof.

## Historical preservation

Do not rewrite an old audit or checkpoint to make it appear current. Add a
supersession banner, retain its date and observations, and link to the current
living document. Fix spelling, broken links, or an explicit factual erratum only
when the correction is labeled.

## Verification

`./scripts/check-documentation.sh` validates the living manifest, metadata,
local links, known stale claims, and branch documentation impact. Documentation-
only changes also require diff inspection and `git diff --check`; they do not
require an app build.
