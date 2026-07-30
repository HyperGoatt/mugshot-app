
-- Replay-safe historical repair (2026-07-22).
-- The original one-off profile repair assumed this Auth user existed, which
-- prevented data-less Supabase branches from replaying production history.
insert into public.users (id, display_name, username)
select
  auth_user.id,
  'amandakm3',
  'amandakm3_f242'
from auth.users as auth_user
where auth_user.id = 'f2421502-1e33-401c-92e5-c68a1a92369d'::uuid
on conflict (id) do nothing;
;
