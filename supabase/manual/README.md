# Supabase Manual Runbooks

This directory contains reviewable Supabase SQL/runbooks that must be applied manually. These files are not migration history and should not be executed automatically by local app builds.

Rules:

- Review each file before running it.
- Run SQL only in the intended Supabase project.
- Do not paste secrets, bearer tokens, service-role keys, APNs keys, or private credentials into these files.
- Prefer applying changes through Supabase Dashboard SQL editor or an approved Supabase migration workflow after review.

## Current Runbooks

- `phase_2a5_quarantine_visit_notify_trigger.sql`
- `phase_2d_visit_photo_storage_policy.sql`

Use this before Phase 2B real visit creation. It removes the unsafe `public.visits` insert trigger that invokes `notify-friends-on-new-visit` with an embedded bearer credential.

Use the Phase 2D policy runbook before native visit photo uploads. It narrows `visit-photos` inserts so authenticated users can only upload into their own top-level Storage folder.
