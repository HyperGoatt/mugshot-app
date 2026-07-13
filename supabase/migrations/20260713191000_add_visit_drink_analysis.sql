-- Build a privacy-safe, versioned drink-analysis projection without putting
-- parser output or estimated caffeine on the social visits row.

create table public.visit_drink_analyses (
  visit_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  raw_drink_name text not null,
  raw_drink_hash text not null,
  analysis_schema_version integer not null default 1,
  parser_version text not null default 'pending',
  caffeine_reference_version text not null default 'traditional-averages-1',
  processing_status text not null default 'pending',
  canonical_family text,
  preparation text,
  temperature text,
  caffeine_modifier text,
  espresso_shot_count integer,
  serving_volume_ml numeric,
  estimated_caffeine_mg numeric,
  caffeine_calculation_basis text,
  caffeine_coverage text not null default 'excluded',
  preference_signals jsonb not null default '[]'::jsonb,
  confidence numeric not null default 0,
  provenance text not null default 'pending',
  model_output jsonb not null default '{}'::jsonb,
  user_overrides jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint visit_drink_analyses_visit_owner_fk
    foreign key (visit_id, user_id)
    references public.visits(id, user_id)
    on delete cascade,
  constraint visit_drink_analyses_status_check
    check (processing_status in ('pending', 'complete', 'failed')),
  constraint visit_drink_analyses_coverage_check
    check (caffeine_coverage in ('estimated', 'excluded')),
  constraint visit_drink_analyses_shot_count_check
    check (espresso_shot_count is null or espresso_shot_count between 1 and 8),
  constraint visit_drink_analyses_serving_volume_check
    check (serving_volume_ml is null or serving_volume_ml between 10 and 5000),
  constraint visit_drink_analyses_caffeine_check
    check (estimated_caffeine_mg is null or estimated_caffeine_mg between 0 and 2000),
  constraint visit_drink_analyses_confidence_check
    check (confidence between 0 and 1),
  constraint visit_drink_analyses_preference_signals_array
    check (jsonb_typeof(preference_signals) = 'array'),
  constraint visit_drink_analyses_model_output_object
    check (jsonb_typeof(model_output) = 'object'),
  constraint visit_drink_analyses_user_overrides_object
    check (jsonb_typeof(user_overrides) = 'object')
);

create index visit_drink_analyses_user_updated_idx
  on public.visit_drink_analyses(user_id, updated_at desc);

alter table public.visit_drink_analyses enable row level security;

revoke all on table public.visit_drink_analyses from public, anon, authenticated;
grant select on table public.visit_drink_analyses to authenticated;
grant select, insert, update, delete on table public.visit_drink_analyses to service_role;

create policy "Visible sip drink analyses"
  on public.visit_drink_analyses
  for select
  to authenticated
  using (public.can_view_visit(visit_id, (select auth.uid())));

create or replace function public.seed_visit_drink_analysis()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_raw_name text := coalesce(nullif(btrim(new.drink_subtype), ''), nullif(btrim(new.drink_type_custom), ''), nullif(btrim(new.drink_type), ''), 'Drink');
  v_serving numeric;
  v_shots integer;
begin
  begin
    v_serving := nullif(new.brew_details ->> 'servingVolumeMilliliters', '')::numeric;
  exception when invalid_text_representation or numeric_value_out_of_range then
    v_serving := null;
  end;

  begin
    v_shots := nullif(new.brew_details ->> 'espressoShotCount', '')::integer;
  exception when invalid_text_representation or numeric_value_out_of_range then
    v_shots := null;
  end;

  insert into public.visit_drink_analyses (
    visit_id,
    user_id,
    raw_drink_name,
    raw_drink_hash,
    serving_volume_ml,
    espresso_shot_count,
    processing_status,
    updated_at
  ) values (
    new.id,
    new.user_id,
    v_raw_name,
    md5(lower(v_raw_name)),
    case when v_serving between 10 and 5000 then v_serving end,
    case when v_shots between 1 and 8 then v_shots end,
    'pending',
    now()
  )
  on conflict (visit_id) do update
  set user_id = excluded.user_id,
      raw_drink_name = excluded.raw_drink_name,
      raw_drink_hash = excluded.raw_drink_hash,
      serving_volume_ml = excluded.serving_volume_ml,
      espresso_shot_count = excluded.espresso_shot_count,
      processing_status = case
        when public.visit_drink_analyses.raw_drink_hash <> excluded.raw_drink_hash
          or public.visit_drink_analyses.serving_volume_ml is distinct from excluded.serving_volume_ml
          or public.visit_drink_analyses.espresso_shot_count is distinct from excluded.espresso_shot_count
        then 'pending'
        else public.visit_drink_analyses.processing_status
      end,
      updated_at = now();

  return new;
end;
$$;

revoke all on function public.seed_visit_drink_analysis() from public, anon, authenticated;

create trigger seed_visit_drink_analysis
  after insert or update of drink_subtype, drink_type, drink_type_custom, brew_details
  on public.visits
  for each row execute function public.seed_visit_drink_analysis();

insert into public.visit_drink_analyses (
  visit_id,
  user_id,
  raw_drink_name,
  raw_drink_hash,
  serving_volume_ml,
  espresso_shot_count
)
select
  visit.id,
  visit.user_id,
  coalesce(nullif(btrim(visit.drink_subtype), ''), nullif(btrim(visit.drink_type_custom), ''), nullif(btrim(visit.drink_type), ''), 'Drink'),
  md5(lower(coalesce(nullif(btrim(visit.drink_subtype), ''), nullif(btrim(visit.drink_type_custom), ''), nullif(btrim(visit.drink_type), ''), 'Drink'))),
  case
    when (visit.brew_details ->> 'servingVolumeMilliliters') ~ '^\d+(\.\d+)?$'
      then (visit.brew_details ->> 'servingVolumeMilliliters')::numeric
  end,
  case
    when (visit.brew_details ->> 'espressoShotCount') ~ '^\d+$'
      then (visit.brew_details ->> 'espressoShotCount')::integer
  end
from public.visits visit
on conflict (visit_id) do nothing;

create or replace function public.request_visit_drink_analysis_correction(
  p_visit_id uuid,
  p_overrides jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_allowed_keys constant text[] := array[
    'canonical_family',
    'preparation',
    'temperature',
    'espresso_shot_count',
    'serving_volume_ml'
  ];
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if jsonb_typeof(coalesce(p_overrides, '{}'::jsonb)) <> 'object' then
    raise exception 'overrides must be an object' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_object_keys(coalesce(p_overrides, '{}'::jsonb)) key
    where not (key = any(v_allowed_keys))
  ) then
    raise exception 'unsupported drink-analysis override' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.visits visit
    where visit.id = p_visit_id and visit.user_id = v_actor
  ) then
    raise exception 'visit ownership required' using errcode = '42501';
  end if;

  update public.visit_drink_analyses
  set user_overrides = user_overrides || coalesce(p_overrides, '{}'::jsonb),
      processing_status = 'pending',
      estimated_caffeine_mg = null,
      caffeine_calculation_basis = null,
      caffeine_coverage = 'excluded',
      updated_at = now()
  where visit_id = p_visit_id and user_id = v_actor;
end;
$$;

revoke all on function public.request_visit_drink_analysis_correction(uuid, jsonb)
  from public, anon;
grant execute on function public.request_visit_drink_analysis_correction(uuid, jsonb)
  to authenticated;
