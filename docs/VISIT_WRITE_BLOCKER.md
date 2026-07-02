# Visit Write Blocker

Date: 2026-07-01

Purpose: classify whether native iOS can safely create real Supabase-backed `public.visits` rows for Phase 2B.

## Decision

Resolved at the trigger-quarantine level after manual signing-key rotation and SQL quarantine.

The original blocker was the enabled `public.visits` insert trigger `notify-friends-on-new-visit`. A `public.visits` insert would fire this trigger once per inserted row. The trigger called `supabase_functions.http_request` and its trigger definition contained bearer credential text in database metadata.

On 2026-07-01, the user rotated the Supabase signing key manually. Codex then applied `supabase/manual/phase_2a5_quarantine_visit_notify_trigger.sql`, dropping `notify-friends-on-new-visit` from `public.visits`.

Current post-quarantine decision: the embedded-trigger blocker is no longer present. Phase 2B Add Visit writes may proceed only after one more preflight confirms the post-quarantine database state remains unchanged.

## Exact Classification

| Possible cause | Blocking? | Evidence |
| --- | --- | --- |
| Embedded bearer-token trigger | Resolved | Before quarantine, `notify-friends-on-new-visit` was enabled on `public.visits`, fired `AFTER INSERT FOR EACH ROW`, called `supabase_functions.http_request`, and the inspected trigger definition contained bearer text. After quarantine, it no longer exists on `public.visits`. |
| RLS | No | RLS is enabled, but policy `Users insert their own visits` allows inserts when `auth.uid() = user_id`. The authenticated role has `INSERT` on `public.visits`. |
| Missing required fields | No | Required client-supplied fields are manageable: `user_id`, `caption`, `visibility`, `overall_score`, plus either `cafe_id` or non-empty `location_name`. Defaults cover `id`, `ratings`, `created_at`, `updated_at`, `context_type`, `brew_method_visible`, `equipment_visible`, `rating_template_type`, and `category_scores`. |
| Cafe relationship requirements | No | `cafe_id` is nullable. The check constraint requires either `cafe_id IS NOT NULL` or non-empty `location_name`. Cafe visits should provide a valid `public.cafes.id`; non-cafe/craft visits can provide `location_name`. |
| Rating schema complexity | No | `ratings` is `jsonb` with `{}` default and `overall_score` is required. Native can start with current rating dictionary plus score. |
| Uncertainty | No | The blocking trigger is confirmed by live Supabase catalog inspection. |

## Trigger Evidence

Original live Supabase inspection found:

- Trigger name: `notify-friends-on-new-visit`
- Attached table: `public.visits`
- Timing: `AFTER`
- Event: `INSERT`
- Orientation: `FOR EACH ROW`
- Enabled state: `O`
- Function called: `supabase_functions.http_request`
- Safe metadata check: trigger definition contains bearer text

Therefore, inserting into `public.visits` would trigger it.

Post-quarantine inspection found:

- `notify-friends-on-new-visit` returns zero rows in `information_schema.triggers`.
- Remaining `public.visits` trigger: `visits_set_updated_at`
- Remaining trigger event: `BEFORE UPDATE`
- Remaining trigger function: `public.set_updated_at`
- Remaining `public.visits` insert trigger count: `0`
- Remaining `public.visits` trigger bearer count: `0`
- Remaining `public.visits` trigger `supabase_functions.http_request` count: `0`

There is also an unrelated `visits_set_updated_at` trigger:

- Attached table: `public.visits`
- Timing: `BEFORE`
- Event: `UPDATE`
- Function called: `public.set_updated_at`
- Does not fire on insert

## Schema Evidence

Relevant required/default behavior on `public.visits`:

- `id`: required, default `gen_random_uuid()`
- `user_id`: required
- `caption`: required
- `visibility`: required
- `ratings`: required, default `{}` JSON
- `overall_score`: required
- `created_at`: required, default `now()`
- `updated_at`: required, default `now()`
- `context_type`: required, default `Cafe`
- `cafe_id`: nullable
- `location_name`: nullable

Relevant checks:

- `visit_has_location`: `cafe_id IS NOT NULL OR location_name IS NOT NULL AND location_name <> ''`
- `visits_visibility_check`: visibility must be `private`, `friends`, or `everyone`

Relevant foreign keys:

- `visits.user_id` references `public.users.id`
- `visits.cafe_id` references `public.cafes.id`

## Applied Fix

1. The user clicked Rotate signing key in Supabase. The public JWKS endpoint now advertises one `EC` `P-256` `ES256` signing key.
2. Codex applied the reviewed quarantine runbook:
   - `supabase/manual/phase_2a5_quarantine_visit_notify_trigger.sql`
   - This dropped `notify-friends-on-new-visit` from `public.visits`.
   - It does not delete visit data.
3. Codex verified this query returns zero rows:

```sql
select
  trigger_schema,
  event_object_schema,
  event_object_table,
  trigger_name,
  action_timing,
  event_manipulation
from information_schema.triggers
where event_object_schema = 'public'
  and event_object_table = 'visits'
  and trigger_name = 'notify-friends-on-new-visit';
```

4. Codex verified inserts into `public.visits` no longer have a trigger path to `supabase_functions.http_request`.

## Remaining Caution

Supabase documentation says previously used legacy signing keys can continue to validate non-expired tokens until revoked. The connector does not expose the dashboard signing-key status directly, and Codex did not extract or use the old bearer token to test it. In the Supabase Dashboard, verify that the legacy HS256/shared-secret key is either intentionally retained under Previously used during the grace period or revoked if treating this as an active secret exposure.
