# Phase 2 — Canonical Journal Checkpoint

Status: Complete under the risk-based roadmap policy.

Phase 2 advances because the primary Journal, detail, Repeat Sip, Brew Again, draft, bookmark, and recipe-version paths work without a known privacy, ownership, migration, or data-loss defect. Narrow presentation and scale refinements are tracked below rather than blocking Phase 3.

## Product outcome

- Bottom navigation is now Map, Feed, Add, Saved, and Journal.
- Profile editing and Settings live behind the Journal avatar.
- The owner Journal uses one `JournalEntryProjection` for the main surface, search, context filters, tags, bookmarks, calendar, timeline, map, and detail routing.
- Owner-only private notes participate in owner search through a separate query and are never added to `RemoteVisitSummary` or a social projection.
- Local drafts are visible with resume and discard actions. Resuming restores preserved local photos from the durable draft bundle.
- On This Sip shows same-calendar-date memories from prior years when evidence exists.
- Repeat Sip copies reusable context and details while resetting timestamp, ratings, caption, private notes, companions, uploaded media, and audience confirmation.
- Recipe entries expose Brew Again, producing a new Private Home attempt linked to the source recipe identity and version.
- The DEBUG Phase 2 Journal control can hide the new memory tools without forking domain data.

## Database contracts

Repository migrations:

- `20260714110000_phase_2_canonical_journal.sql`
- `20260714114000_harden_phase_2_journal_contracts.sql`

Live migration versions:

- `20260714042024_phase_2_canonical_journal`
- `20260714043328_harden_phase_2_journal_contracts`

The migrations add:

- Owner-only `visit_bookmarks` with RLS and explicit grants.
- Owner recipe identities and immutable recipe versions.
- `visits.recipe_version_id` so a historical sip references the exact blueprint brewed.
- Automatic backfill/materialization for Recipe visits and Home payloads that already contain a recipe name.
- Locked internal trigger helpers and init-plan-safe owner policies.

## Verification evidence

- iOS 18.6 build passed.
- Swift unit suite passed with 68 tests, including remote Repeat Sip, remote Brew Again, owner-note/tag search, and media-bearing multi-draft restoration.
- Targeted UI automation passed for Journal account/Settings routing and authentication-interrupted draft recovery.
- Live Supabase contracts passed:
  - `canonical_journal_contract_passed`
  - `canonical_journal_rls_passed`
  - `recipe_version_contract_passed`
  - `migration_integrity_passed`
- Live RLS verification confirmed another authenticated identity cannot read or create a bookmark for the owner visit.
- Live recipe verification created transaction-scoped v1 and v2 saves, confirmed independent immutable payloads, then rolled the fixtures back.
- Supabase advisors report no warning for the new materialization functions or new Journal policies after the hardening migration.
- Simulator walkthrough on iPhone 17 Pro / iOS 26.2 covered Journal home, timeline, calendar, map, sip detail, actions, and Repeat Sip handoff.
- Screenshot QA:
  - `phase-2-journal/01-journal-home.png`
  - `phase-2-journal/02-journal-map.png`

## Risk judgment and carried refinements

These do not block Phase 3:

- Journal map framing includes every located sip. A geographically incorrect legacy cafe coordinate can make the first frame wider than ideal; coordinate correction and clustering are discovery refinements.
- Calendar starts on today, even when today has no sip. Entry-day decoration and month summary graphics can be polished later.
- On This Sip initially features one matching memory on the main surface; the archive still contains all matching entries.
- Exact nested navigation restoration was smoke-tested for the primary paths, not exhaustively across every interrupted sheet and scroll offset.
- Recipe version allocation has a unique database constraint. Simultaneous duplicate writes for the same recipe are a very low-probability retry case and can receive serialized allocation if production telemetry shows it occurs.

None of these risks can expose private notes, cross account ownership, corrupt an existing visit, or silently overwrite recipe history.
