---
document_type: historical
status: superseded
superseded_by: FEATURE_STATUS_MATRIX.md
---

> Historical phase checkpoint. Later Activity and notification work supersedes its delivery deferrals. Use the [Feature status matrix](FEATURE_STATUS_MATRIX.md).

# Phase 4 — Lightweight Friends and Shared Discovery

## Outcome

Phase 4 is ready to checkpoint under the program's risk-based gate policy. It adds collaboration that remains attached to coffee objects: trusted recommendations, explainable friend overlap, named cafe lists, immutable recipe sharing, comments, and a fixed set of subject-focused reactions.

It does not add followers, public popularity metrics, contacts gating, competitive compatibility rankings, or generic status posting.

## Product contracts

- Friend compatibility returns `strong_overlap`, `some_overlap`, or `still_learning`; it never returns a competitive rank or percentage.
- Compatibility uses only active TasteSignals supported by at least three distinct sips for both friends.
- Trusted recommendations are confirmed-friend, person-to-person shares for a cafe, visible sip, or exact immutable recipe version.
- A private sip cannot be recommended. A private recipe can be shared only through an explicit exact-version recommendation.
- Shared recipes use an allowlisted payload. Raw `brew_details`, captions, photos, companions, and private notes are not exposed.
- Cafe lists support Private, Friends, and Invited-only visibility; owner, editor, and viewer roles; pending invitations; revocation; contributor attribution; and ordered items.
- A pending invitee can read list metadata but cannot read Invited-only contents until accepting.
- Reactions are limited to Want to try, Great find, Dialed in, and Cozy. One person can hold one reaction per sip.
- Favorites and Want to Try remain durable system surfaces alongside named lists.
- All new writes are caller-bound RPCs. Authenticated clients have SELECT-only table grants.
- Every collaboration read rechecks blocks plus the underlying sip, recipe, list, or friendship visibility.

## Database migrations

- `20260714050516_phase_4_lightweight_friends.sql`
- `20260714051041_refine_cafe_list_invitation_visibility.sql`
- `20260714051404_expose_caller_bound_phase_4_policies.sql`
- `20260714051432_close_phase_4_direct_mutations.sql`
- `20260714051603_sanitize_shared_recipe_payloads.sql`
- `20260714052754_add_cafe_list_reordering.sql`

All were applied as forward, additive migrations to project `quskamnfwglctqewwfln`.

## Verification

- Swift Debug Simulator build: passed.
- Swift unit/model suite on iPhone 17 Pro, iOS 26.2: passed.
- `phase4_collaboration_contract.sql`: passed.
- `phase4_privacy_contract.sql`: passed.
- Existing `social_rls.sql`: passed.
- Existing `discovery_social_contract.sql`: passed.
- `migration_integrity.sql`: passed.
- `git diff --check`: passed.
- ASCII cafe copy scan: passed.
- Live reaction toggle: created, verified, and removed on the signed-in test account.
- Recommend-to-friend sheet: loaded the real confirmed-friend list without sending a recommendation.
- Saved cafe-list shelf and creation sheet: exercised in Simulator.
- Friend compatibility: exercised against an existing friend profile.

## Screenshot QA

- `01-reactions-and-recommend.jpg`
- `02-recommend-a-friend.jpg`
- `03-saved-cafe-lists.jpg`
- `04-friend-compatibility.jpg`

Stored under:

`/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/phase-4-lightweight-friends/`

## Risk-based gate judgment

No privacy, ownership, authorization, migration, or data-loss blocker remains. Transactional database tests cover owner, editor, viewer, pending invitee, stranger, and confirmed-friend boundaries without leaving test data behind.

The following are refinements, not Phase 4 blockers:

- Add richer destination routing from cafe and sip recommendations instead of the current inbox summary.
- Add drag-and-drop reordering in addition to the accessible up/down controls.
- Consider batching compatibility loads if friend lists become large.
- Add notification delivery only when Phase 5 notification preferences are available.

These items do not justify delaying Phase 5.
