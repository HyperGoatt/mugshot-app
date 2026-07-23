# Collaborative cafe list deployment gate

Status: database contract deployed on 2026-07-22; repository client and backend
contracts are aligned. A final signed-build acceptance pass with disposable
identities remains before broad alpha distribution.

## Why a gate is required

`20260722034500_alpha_collaborative_cafe_lists.sql` removes authenticated Data API
access to raw collaborator, inviter, and contributor identifiers. The hydrated v2
RPC projections return those identities only when the caller may see them and mask
them after a block while retaining the cafe and its durable provenance.

`20260722102000_alpha_recipe_collaboration_hardening.sql` bounds invitation consent,
and `20260722110000_alpha_collaborative_list_activity_lifecycle.sql` adds durable
lifecycle Activity plus retry-safe ownership transfer. The latter adds a
server-maintained ownership epoch and one private receipt for the current transfer
generation. The receipt is not client-readable, is replaced on the next owner
change, and cascades away with the list or either account.

Older builds read those raw columns directly. They can still list cafe-list metadata,
but their detail request will fail after the migration. The new build uses only:

- `list_cafe_lists_v2()`
- `get_cafe_list_v2(uuid)`
- the caller-bound collaborative-list mutation RPCs

## Required release order

1. Ship or distribute the v2-projection app build and set it as the minimum supported
   alpha build.
2. Confirm no supported app path selects `cafe_list_members.user_id`,
   `cafe_list_members.invited_by`, or `cafe_list_items.contributor_id` directly.
3. Back up the production-like Supabase project and verify the restore procedure.
4. Apply the additive migration sequence in a non-production branch or disposable
   project and run the collaborative-list SQL contract/security suites plus the
   repository PGlite lifecycle harness.
5. Exercise invitation, cancellation, acceptance, decline, block masking, editor
   mutations, transfer with an intentionally dropped response and retry, ownership
   transfer back and forth, leave, and delete using test accounts.
6. Apply to the production-like project only with explicit approval and a recorded
   rollback window.

Steps 2 through 6 are complete for the repository and live backend: the app uses
the v2 projections, a daily physical backup completed before deployment, the
complete 44-file SQL suite passed after a clean QA reset, the migration was
forward-applied with explicit authorization, and preserved list/data counts did
not change. Step 1 remains a distribution control: set the new build as the
minimum supported alpha build before inviting additional testers. The final
gesture/copy acceptance pass should use only disposable collaborators.

The live rollout preserved existing cafe-list, membership, invitation, and item rows. The
ownership epoch backfills existing lists to generation zero without changing an
owner; lifecycle receipts begin only with a future transfer. This gate does not
authorize deleting, rewriting, or reseeding the current Joe, Amanda, or other
pre-alpha account data.
