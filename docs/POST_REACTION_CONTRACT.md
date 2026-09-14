---
document_type: living
status: current
last_verified: 2026-09-14
---

# Post reaction contract

> Current repair: [Repair and sharing status](REPAIR_SHARING_STATUS.md) supersedes
> the earlier delivery and acceptance statements below for moderation, Friends
> publication, profile sharing and the reported native bugs. Those earlier
> checkpoints remain evidence of the previous candidate, not this repair's acceptance.


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

## Reaction people candidate

`list_visit_reaction_people_v1(p_visit_id, p_reaction_kind, p_cursor, p_limit)`
requires an authenticated live account and post access. It returns `people`,
`counts`, and `next_cursor`; people use stable user IDs and authorized profile
summaries. Pages sort by `(created_at DESC, user_id DESC)`. The optional cursor
contains both fields; limits clamp to 1–50. Counts cover all authorized people
regardless of the selected filter. Blocked/restricted users are excluded using
the existing user visibility predicate. Historical Likes remain Likes.

The full-post summary sits inside the action row immediately before Save and
opens All/nonzero-type filters. Yummy uses `cup.and.saucer.fill` consistently
in the picker, active control, totals and people sheet. Profile navigation
retains the sheet and selected filter. Existing writes remain optimistic, restore
prior state on failure, and refresh authorized counts after success. Migration
`20260914155145` is locally verified and deployed as migration 171. Production
reaction samples passed; the dev build is installed, with owner acceptance pending.
