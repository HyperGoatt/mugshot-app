-- Reflection preferences are conservative and owner-only. This phase stores
-- intent but does not re-enable the quarantined legacy push path.

create table public.user_reflection_preferences (
  user_id uuid primary key references public.users(id) on delete cascade,
  monthly_recaps boolean not null default true,
  yearly_recaps boolean not null default true,
  on_this_sip_reminders boolean not null default false,
  reflection_reminders boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.user_reflection_preferences enable row level security;
create policy "Owners read reflection preferences"
on public.user_reflection_preferences for select to authenticated
using (user_id = (select auth.uid()));

revoke all on public.user_reflection_preferences from public, anon, authenticated;
grant select on public.user_reflection_preferences to authenticated;

create or replace function public.get_reflection_preferences()
returns public.user_reflection_preferences
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.user_reflection_preferences;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  insert into public.user_reflection_preferences(user_id) values(actor)
  on conflict(user_id) do nothing;
  select * into result from public.user_reflection_preferences where user_id=actor;
  return result;
end; $$;

create or replace function public.set_reflection_preferences(
  p_monthly_recaps boolean,
  p_yearly_recaps boolean,
  p_on_this_sip_reminders boolean,
  p_reflection_reminders boolean
) returns public.user_reflection_preferences
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.user_reflection_preferences;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  insert into public.user_reflection_preferences(
    user_id,monthly_recaps,yearly_recaps,on_this_sip_reminders,reflection_reminders,updated_at
  ) values (
    actor,p_monthly_recaps,p_yearly_recaps,p_on_this_sip_reminders,p_reflection_reminders,now()
  ) on conflict(user_id) do update set
    monthly_recaps=excluded.monthly_recaps,
    yearly_recaps=excluded.yearly_recaps,
    on_this_sip_reminders=excluded.on_this_sip_reminders,
    reflection_reminders=excluded.reflection_reminders,
    updated_at=now()
  returning * into result;
  return result;
end; $$;

revoke all on function public.get_reflection_preferences() from public, anon;
revoke all on function public.set_reflection_preferences(boolean,boolean,boolean,boolean) from public, anon;
grant execute on function public.get_reflection_preferences() to authenticated;
grant execute on function public.set_reflection_preferences(boolean,boolean,boolean,boolean) to authenticated;
