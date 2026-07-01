# Phase 2B Readiness

Date: 2026-07-01

Purpose: decide whether Mugshot can safely start real Add Visit creation without photos after Phase 2A auth/profile bootstrap.

## Decision

Not ready yet.

Phase 2B should wait until the `public.visits` insert trigger is disabled, dropped, or rebuilt without an embedded credential. The trigger currently fires on every visit insert and calls the notification Edge Function with an embedded bearer credential.

## Direct Answers

Can Phase 2B safely insert into the `visits` table?

- Not while the current trigger can fire.
- Yes after the trigger is safely quarantined or rebuilt.

Does the risky trigger fire on visits?

- Yes. It is an `AFTER INSERT FOR EACH ROW` trigger on `public.visits`.

Does RLS allow authenticated users to create their own visits?

- Yes. The `visits` insert policy checks that `auth.uid()` matches `user_id`.

Does the current schema support a no-photo visit?

- Yes. `poster_photo_url` is nullable and photos live separately in `visit_photos`.

What tables are required for Phase 2B?

- Required: `users`, `visits`.
- Usually required for cafe visits: `cafes`.
- Not required for no-photo Phase 2B: `visit_photos`, storage buckets, likes, comments, friends, notifications, user devices.

Minimum viable `visits` insert fields:

- `user_id`: authenticated user's UUID.
- `caption`: non-empty text.
- `visibility`: likely `private`, `friends`, or `everyone`.
- `overall_score`: numeric score.
- `ratings`: JSON object, can start as `{}` only if the app intentionally allows unrated visits.
- `cafe_id`: existing or newly created cafe UUID for cafe visits; nullable in schema for non-cafe contexts.

Useful optional fields for Phase 2B:

- `drink_type`
- `drink_subtype`
- `drink_type_custom`
- `notes`
- `category_scores`
- `location_name`
- `city_state`
- `context_type`

Phase 2B should explicitly avoid:

- Photo upload.
- `visit_photos` inserts.
- Storage bucket changes.
- Friends feed behavior.
- Push notifications.
- Device registration.
- Likes/comments.
- Feed replacement.
- Map replacement.
- Saved replacement.
- UI redesign.
- Any live backend migration beyond the approved trigger quarantine/fix.

## Recommended Phase 2B Prompt

```text
Phase 2B: real Add Visit creation without photos, continuing from completed Phase 2A and Phase 2A.5.

Before implementing, read:
- docs/PHASE_2A_AUTH_PROFILE_BOOTSTRAP.md
- docs/PHASE_2A5_SECURITY_CHECKPOINT.md
- docs/PHASE_2B_READINESS.md
- docs/SUPABASE_SECURITY_BACKLOG.md
- docs/SUPABASE_AUDIT.md
- docs/IOS_PARITY_ROADMAP.md
- docs/NEXT_10_TASKS.md
- docs/REPO_MAP.md
- docs/IOS_SIMULATOR_TESTING.md

Do not start if the public.visits insert trigger still fires with an embedded bearer credential. First verify that the trigger has been disabled, dropped, or rebuilt without storing credentials in SQL metadata.

Implement only no-photo visit creation:
- Add a small VisitRepository beside DataManager.
- Map the existing Add Visit form to public.visits.
- Use the authenticated user's UUID for user_id.
- Create or reuse a cafe row only as needed for the selected cafe.
- Insert caption, notes, visibility, drink type/subtype/custom drink, ratings JSON/category scores, overall score, and cafe_id when available.
- Keep existing UI structure and local/demo fallback as narrow as possible.
- Show recoverable error state if the remote insert fails.

Explicitly avoid:
- Photo upload.
- visit_photos.
- Feed replacement.
- Map replacement.
- Saved replacement.
- Friends.
- Notifications.
- Push/device registration.
- Likes/comments.
- Profile/media work.
- UI redesign.

After implementation, build and launch on iPhone 17 Pro iOS 26.2, verify auth/session restore still works, create one no-photo visit, confirm the row exists in Supabase without triggering notification/push behavior, and update docs.
```

