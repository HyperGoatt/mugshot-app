# Phase 3 — Explainable Taste Graph Checkpoint

Status: Complete under the risk-based roadmap policy.

Phase 3 advances because Taste Identity evidence is owner-only, source-separated, thresholded, explainable, and correctable. Your Mix now explains its primary recommendation basis, and drink interpretation corrections remain caller-bound and caffeine-free in the composer and ordinary sip detail.

## Product outcome

- Persistent `taste_signals` replace the Journal's local count-based identity when the Phase 3 flag is enabled.
- Order-preference evidence and explicit sensory-evaluation evidence are separate signal families.
- Mugshot retains emerging evidence but displays a durable claim only after three distinct supporting sips.
- Every visible claim opens “Why Mugshot thinks this,” including the journal entries that support it.
- Owners can dismiss a claim or rename it without modifying historical sips.
- Sip actions expose correction controls for preparation, temperature, serving size, and espresso shots.
- The immutable natural-language drink name remains unchanged by corrections.
- The correction UI never accepts caffeine milligrams and never sends captions or private notes.
- Your Mix cards show a structured primary reason: friend activity, Taste Identity match, saved cafe, journal evidence, or recent community activity.
- A DEBUG Phase 3 control changes presentation only; it does not fork journal or recommendation data.

## Database contracts

Repository and live migrations:

- `20260714044901_phase_3_explainable_taste_graph.sql`
- `20260714045207_refine_taste_graph_recommendation_reasons.sql`

The migrations add:

- Owner-only `taste_signals` with RLS, explicit grants, evidence visit IDs, confidence, calculation version, and owner correction state.
- Idempotent signal refresh after relevant visit and drink-analysis changes.
- Caller-bound owner correction RPC validation.
- Structured recommendation reasons from the existing ranked-feed contract.

## Verification evidence

- iOS 18.5+ Simulator build passed.
- Swift unit suite passed, including the three-entry threshold, evidence-family separation, owner wording, structured recommendation decoding, and privacy-safe correction payload tests.
- Live Supabase contracts passed:
  - `taste_graph_contract_passed`
  - `taste_graph_rls_passed`
  - `migration_integrity_passed`
- The contract transaction verified recalculation after visit deletion while preserving the owner correction.
- Live backfill produced 23 evidence records and six durable claims for the current journal.
- Live ranked-feed verification returned a non-empty structured reason for every sampled Your Mix result.
- Supabase advisors report no performance warning on the new Taste Graph table or policy. The security advisor notes the intentional caller-bound owner-state RPC; its ownership and allowed-value checks are covered by RLS tests.
- Simulator walkthrough covered Your Mix reasons, the Journal Taste Identity, evidence detail, and the owner drink-correction sheet.
- Screenshot QA:
  - `phase-3-taste-graph/01-your-mix-reason.jpg`
  - `phase-3-taste-graph/02-taste-identity.jpg`
  - `phase-3-taste-graph/03-evidence.jpg`

## Risk judgment and carried refinements

These do not block Phase 4:

- Signal refresh currently scans one owner's relevant journal evidence synchronously after a qualifying mutation. This is simple and deterministic for the current alpha scale; telemetry can justify queued incremental refresh later.
- The evidence sheet initially presents the canonical journal rows already loaded on device rather than a separate paginated evidence endpoint.
- Your Mix presents one primary explanation per card. A future explanation panel may show secondary contributing reasons.
- Signal labels use a curated mapping plus a readable fallback for custom tasting criteria; richer editorial wording can grow without changing the evidence contract.

None of these refinements can expose another user's evidence, turn an order preference into a sensory claim, mutate historical ratings, or contaminate social payloads with private notes.
