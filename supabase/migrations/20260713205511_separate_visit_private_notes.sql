-- Keep journal-only notes outside the social visit row. Feed, profile, map,
-- sharing, and notification visit queries cannot select this table, and RLS
-- exposes each note only to its owner.

alter table public.visits
  add constraint visits_id_user_id_unique unique (id, user_id);

create table public.visit_private_notes (
  visit_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  note text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint visit_private_notes_nonempty check (length(btrim(note)) > 0),
  constraint visit_private_notes_length check (char_length(note) <= 10000),
  constraint visit_private_notes_visit_owner_fk
    foreign key (visit_id, user_id)
    references public.visits(id, user_id)
    on delete cascade
    deferrable initially deferred
);

create index visit_private_notes_user_id_idx
  on public.visit_private_notes(user_id, updated_at desc);

alter table public.visit_private_notes enable row level security;

revoke all on table public.visit_private_notes from anon;
revoke all on table public.visit_private_notes from authenticated;
grant select, insert, update, delete on table public.visit_private_notes to authenticated;
grant select, insert, update, delete on table public.visit_private_notes to service_role;

create policy "Owners read private sip notes"
  on public.visit_private_notes
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners create private sip notes"
  on public.visit_private_notes
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Owners update private sip notes"
  on public.visit_private_notes
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Owners delete private sip notes"
  on public.visit_private_notes
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

insert into public.visit_private_notes (visit_id, user_id, note)
select id, user_id, btrim(notes)
from public.visits
where notes is not null and length(btrim(notes)) > 0
on conflict (visit_id) do update
set note = excluded.note,
    updated_at = now();

update public.visits set notes = null where notes is not null;

-- Keep the legacy nullable column for older app builds, but make it impossible
-- to repopulate with journal-only content that a social visit query could read.
alter table public.visits
  add constraint visits_legacy_notes_must_be_null check (notes is null);

-- Route journal notes sent by an older app build into the owner-only table.
-- The deferred owner FK lets an INSERT route the note before the visit row is
-- visible, while the check constraint guarantees the social row stays empty.
create or replace function public.route_legacy_visit_private_note()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.notes is not null and length(btrim(new.notes)) > 0 then
    insert into public.visit_private_notes (visit_id, user_id, note)
    values (new.id, new.user_id, btrim(new.notes))
    on conflict (visit_id) do update
    set note = excluded.note,
        updated_at = now();
  elsif tg_op = 'UPDATE' then
    delete from public.visit_private_notes
    where visit_id = new.id and user_id = new.user_id;
  end if;

  new.notes := null;
  return new;
end;
$$;

revoke all on function public.route_legacy_visit_private_note() from public;
revoke all on function public.route_legacy_visit_private_note() from anon;
revoke all on function public.route_legacy_visit_private_note() from authenticated;

create trigger route_legacy_visit_private_note
  before insert or update of notes on public.visits
  for each row execute function public.route_legacy_visit_private_note();
;
