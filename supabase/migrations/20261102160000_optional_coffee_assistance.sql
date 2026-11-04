-- Optional AI never participates in publication, journal writes, or recipe saves.
-- This service-only ledger retains no prompts, images, notes, or model output.
create table public.coffee_assistance_reservations (
  request_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  task text not null check (task in ('bag_scan', 'recipe_import', 'memory_search', 'taste_insight', 'brew_experiment', 'weekly_reflection')),
  created_at timestamptz not null default now()
);
create index coffee_assistance_reservations_time_idx on public.coffee_assistance_reservations(created_at);
create index coffee_assistance_reservations_owner_time_idx on public.coffee_assistance_reservations(user_id, created_at);
alter table public.coffee_assistance_reservations enable row level security;
revoke all on public.coffee_assistance_reservations from public, anon, authenticated;
grant select, insert, delete on public.coffee_assistance_reservations to service_role;

-- Anonymous aggregate survives account deletion: erasure cannot replenish spend.
create table public.coffee_assistance_monthly_budget (
  month_start date primary key,
  reserved_count integer not null default 0 check (reserved_count between 0 and 3000)
);
alter table public.coffee_assistance_monthly_budget enable row level security;
revoke all on public.coffee_assistance_monthly_budget from public, anon, authenticated;
grant select, insert, update on public.coffee_assistance_monthly_budget to service_role;

create function public.reserve_coffee_assistance_v1(p_actor uuid, p_request uuid, p_task text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  budget_month date := date_trunc('month', now() at time zone 'UTC')::date;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  if p_actor is null or p_request is null or p_task is null or p_task not in ('bag_scan', 'recipe_import', 'memory_search', 'taste_insight', 'brew_experiment', 'weekly_reflection') then
    return false;
  end if;
  -- A global transaction lock makes parallel requests share the same quota view.
  perform pg_catalog.pg_advisory_xact_lock(601102, 1);
  insert into public.coffee_assistance_monthly_budget(month_start)
    values (budget_month) on conflict do nothing;
  if not exists (select 1 from auth.users where id = p_actor)
     or exists (select 1 from public.coffee_assistance_reservations where request_id = p_request)
     or (select count(*) from public.coffee_assistance_reservations where user_id = p_actor and created_at >= date_trunc('day', now() at time zone 'UTC') at time zone 'UTC') >= 20
     or (select reserved_count from public.coffee_assistance_monthly_budget where month_start = budget_month) >= 3000 then
    return false;
  end if;
  -- Reserve before provider work. Failed/unknown requests keep their reservation;
  -- retries use a new ID, so ambiguous network failures cannot overspend the cap.
  insert into public.coffee_assistance_reservations(request_id, user_id, task) values (p_request, p_actor, p_task);
  update public.coffee_assistance_monthly_budget
    set reserved_count = reserved_count + 1 where month_start = budget_month;
  return true;
end;
$$;
revoke all on function public.reserve_coffee_assistance_v1(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.reserve_coffee_assistance_v1(uuid, uuid, text) to service_role;
