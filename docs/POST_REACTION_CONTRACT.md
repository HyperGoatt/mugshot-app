---
document_type: living
status: current
last_verified: 2026-08-24
---

# Post reaction contract

## Scope and ownership

Expressive post reactions extend `public.likes`; they do not replace the
historical coffee-specific `public.visit_reactions` feature. Each authenticated
actor owns at most one `likes` row per visit through the existing unique
`(user_id, visit_id)` key.

The app-facing values are `like`, `love`, `laugh`, and `yummy`. Existing rows
default to `like`, so older clients retain their binary liked/not-liked
projection and their total count.

## Mutation RPC

`public.set_visit_reaction_v1(p_visit_id uuid, p_reaction_kind text)` binds the
actor to `auth.uid()`:

- `NULL` removes the caller's row.
- A valid value atomically inserts or changes the caller's single selection.
- Authentication, social-mutation eligibility, blocking, and visit visibility
  fail closed before any mutation.
- Invalid values fail with SQLSTATE `22023`; unavailable visits fail with
  `42501`.

The returned `VisitReactionState` contains `viewer_reaction`, counts for all
four kinds, and `total_count`. Count rows exclude accounts the caller cannot
view. Direct-table legacy Like reads remain available under existing RLS; the
iOS client also falls back to binary Like behavior during an additive
client-before-schema rollout.

## Activity lifecycle

The durable Activity kind remains `like` for old-client and preference
compatibility. One event is retained per actor/post. The selected kind is
stored in event metadata; changing a reaction updates that event without
creating another, and removing the reaction removes its event.

No historical `visit_reactions` rows are backfilled or rewritten.

## Verification state

- Implemented in migration `20260825030917_post_reactions.sql` and iOS source.
- Hermetic local coverage exercises legacy defaults, add/change/remove,
  invalid input, private and blocked visits, concurrent upserts, aggregate
  state, and Activity deduplication/removal.
- Production configuration, physical acceptance, and TestFlight acceptance are
  pending and must be reported separately.
