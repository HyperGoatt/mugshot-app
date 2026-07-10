-- Mugshot App Store polish: prevent incomplete photo submissions from becoming visible.

alter table public.visits
  add column if not exists upload_state text not null default 'complete';

update public.visits
set upload_state = 'complete'
where upload_state is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'visits_upload_state_check'
      and conrelid = 'public.visits'::regclass
  ) then
    alter table public.visits
      add constraint visits_upload_state_check
      check (upload_state in ('uploading', 'complete', 'failed'));
  end if;
end;
$$;

create index if not exists visits_visible_feed_idx
  on public.visits (visibility, upload_state, created_at desc);

drop policy if exists "Public visits are world-readable" on public.visits;
create policy "Public visits are world-readable"
  on public.visits
  for select
  to public
  using (visibility = 'everyone' and upload_state = 'complete');

drop policy if exists "Friends can read friends visits" on public.visits;
create policy "Friends can read friends visits"
  on public.visits
  for select
  to public
  using (
    upload_state = 'complete'
    and visibility = 'friends'
    and auth.uid() is not null
    and (
      user_id = auth.uid()
      or exists (
        select 1
        from public.friends f
        where f.user_id = auth.uid()
          and f.friend_user_id = visits.user_id
      )
    )
  );
