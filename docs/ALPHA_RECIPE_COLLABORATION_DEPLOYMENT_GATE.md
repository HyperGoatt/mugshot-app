# Alpha Recipe and Collaboration Deployment Gate

Status: migrations and bounded expiry scheduler deployed on 2026-07-22. The
independent recipe-visibility, shared MugShot consent, and collaborative-list
database contracts are available to the aligned client.

This gate protects published MugShots and production-like pre-alpha data. It is
now the operational checklist for future releases, not authorization to rewrite
existing content.

Before enabling independent recipe visibility, shared MugShot invitations, or collaborative cafe lists:

1. Apply the alpha migrations in timestamp order through `20260722102000_alpha_recipe_collaboration_hardening.sql` in a disposable database restored from a current schema-only backup.
2. Confirm `private.visit_recipe_payload_staging.user_id` has the `ON DELETE CASCADE` Auth foreign key and that authenticated roles still have no direct table privileges.
3. Confirm `mugshot-alpha-ephemera-v3` exists in `cron.job`, is active, and successfully calls both bounded cleanup functions every 15 minutes. If pg_cron is unavailable, keep recipe staging and invitations disabled until an equivalent service-role scheduler is configured.
4. Verify the 20-stage per-account limit, 24-hour staging expiry, 14-day invitation expiry, and 12-invitee shared MugShot aggregate cap in a non-production database.
5. Verify deleting an inviter preserves accepted cafe-list memberships, cancels pending invitations, and does not delete published cafe-list content.
6. Run the recipe confidentiality, recipe visibility, shared MugShot, and collaborative cafe-list contract/security tests.
7. Exercise simultaneous add, move, and remove operations against one cafe list and confirm positions remain unique and contiguous.
8. Take and verify a database backup. Do not rewrite or purge existing visits, recipe versions, cafe lists, or shared MugShots as part of this rollout.

Deployment record: the QA branch cleanly replayed the complete production
migration history; all 44 SQL contract/security files passed; the affected
recipe, migration-integrity, and capability contracts passed again after the
scheduler migration. Production now has active job
`mugshot-alpha-ephemera-v3` on `*/15 * * * *`, and both cleanup functions
executed successfully inside a rolled-back validation transaction. There was no
expired production work at rollout. The first scheduled production run succeeded
at 2026-07-22 22:00 UTC. Existing visits, cafe lists, and Storage objects retained
their pre-deploy counts.

Roll back the feature flags—not user rows—if any gate fails.
