alter table public.visit_drink_analyses
  add column if not exists attempt_count integer not null default 0,
  add column if not exists last_attempt_at timestamptz,
  add column if not exists last_error_code text,
  add column if not exists next_retry_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'visit_drink_analyses_attempt_count_check'
      and conrelid = 'public.visit_drink_analyses'::regclass
  ) then
    alter table public.visit_drink_analyses
      add constraint visit_drink_analyses_attempt_count_check
      check (attempt_count >= 0);
  end if;
end
$$;

create index if not exists visit_drink_analyses_retry_idx
  on public.visit_drink_analyses(processing_status, next_retry_at, updated_at)
  where processing_status in ('pending', 'failed');

with source as (
  select
    analysis.visit_id,
    lower(regexp_replace(analysis.raw_drink_name, '[[:space:]]+', ' ', 'g')) as normalized,
    analysis.serving_volume_ml,
    analysis.espresso_shot_count,
    analysis.attempt_count
  from public.visit_drink_analyses analysis
  where analysis.processing_status = 'pending'
), classified as (
  select
    source.*,
    case
      when normalized like '%cold brew%' or normalized like '%nitro%' then 'cold_brew'
      when normalized like '%flat white%' then 'flat_white'
      when normalized like '%pour over%' or normalized like '%v60%' or normalized like '%kalita%' then 'pour_over'
      when normalized like '%french press%' then 'french_press'
      when normalized like '%hot chocolate%' or normalized like '%cocoa%' then 'hot_chocolate'
      when normalized like '%cappuccino%' then 'cappuccino'
      when normalized like '%americano%' then 'americano'
      when normalized like '%macchiato%' then 'macchiato'
      when normalized like '%cortado%' then 'cortado'
      when normalized like '%espresso%' or normalized like '%doppio%' or normalized like '%ristretto%' or normalized like '%lungo%' then 'espresso'
      when normalized like '%chemex%' then 'chemex'
      when normalized like '%aeropress%' then 'aeropress'
      when normalized like '%drip%' or normalized like '%batch brew%' or normalized like '%filter coffee%' then 'drip'
      when normalized like '%mocha%' then 'mocha'
      when normalized like '%latte%' then 'latte'
      when normalized like '%matcha%' then 'matcha'
      when normalized like '%hojicha%' then 'hojicha'
      when normalized like '%chai%' then 'chai'
      when normalized like '%tea%' then 'tea'
      else 'unknown'
    end as preparation
  from source
), resolved as (
  select
    classified.*,
    case
      when preparation in ('espresso','americano','latte','cappuccino','cortado','flat_white','mocha','macchiato') then 'espresso'
      when preparation in ('drip','pour_over','chemex','french_press','aeropress','cold_brew') then 'brewed_coffee'
      when preparation <> 'unknown' then preparation
      when normalized like '%coffee%' then 'brewed_coffee'
      else 'unknown'
    end as canonical_family,
    case
      when preparation = 'cold_brew' then 'cold_brew'
      when normalized ~ '(frozen|frappe|blended)' then 'frozen'
      when replace(normalized, 'cold foam', '') ~ '(iced|(^| )ice |(^| )cold |chilled)' then 'iced'
      else 'hot'
    end as temperature,
    case
      when normalized like '%half caf%' or normalized like '%half-caf%' then 'half_caf'
      when normalized like '%decaf%' then 'decaf'
      else 'regular'
    end as caffeine_modifier,
    coalesce(
      espresso_shot_count,
      case
        when normalized like '%single%' then 1
        when normalized like '%double%' or normalized like '%doppio%' then 2
        when normalized like '%triple%' then 3
        when normalized like '%quad%' then 4
        when preparation in ('espresso','americano','latte','cappuccino','cortado','flat_white','mocha','macchiato') then 2
        else null
      end
    ) as resolved_shots
  from classified
), referenced as (
  select
    resolved.*,
    case preparation
      when 'drip' then 95
      when 'pour_over' then 120
      when 'chemex' then 120
      when 'french_press' then 107
      when 'aeropress' then 80
      when 'cold_brew' then 200
      when 'matcha' then 70
      when 'hojicha' then 30
      when 'tea' then 47
      when 'chai' then 40
      when 'hot_chocolate' then 9
      else null
    end::numeric as reference_mg,
    case preparation
      when 'pour_over' then 300
      when 'chemex' then 300
      when 'cold_brew' then 355
      when 'drip' then 240
      when 'french_press' then 240
      when 'aeropress' then 240
      when 'matcha' then 240
      when 'hojicha' then 240
      when 'tea' then 240
      when 'chai' then 240
      when 'hot_chocolate' then 240
      else null
    end::numeric as reference_ml
  from resolved
), calculated as (
  select
    referenced.*,
    greatest(coalesce(serving_volume_ml, reference_ml), 30) as resolved_serving_ml,
    case
      when preparation in ('espresso','americano','latte','cappuccino','cortado','flat_white','mocha','macchiato')
        then round(
          (case when caffeine_modifier = 'decaf' then 6 else 63 end)
          * coalesce(resolved_shots, 2)
          * (case when caffeine_modifier = 'half_caf' then 0.5 else 1 end),
          1
        )
      when reference_mg is null then null
      when caffeine_modifier = 'decaf'
        then round(3 * greatest(coalesce(serving_volume_ml, reference_ml), 30) / 240, 1)
      else round(
        reference_mg * greatest(coalesce(serving_volume_ml, reference_ml), 30) / reference_ml
        * (case when caffeine_modifier = 'half_caf' then 0.5 else 1 end),
        1
      )
    end as estimated_mg
  from referenced
)
update public.visit_drink_analyses analysis
set parser_version = 'sql-backfill-1',
    processing_status = 'complete',
    canonical_family = calculated.canonical_family,
    preparation = calculated.preparation,
    temperature = calculated.temperature,
    caffeine_modifier = calculated.caffeine_modifier,
    espresso_shot_count = calculated.resolved_shots,
    serving_volume_ml = calculated.serving_volume_ml,
    estimated_caffeine_mg = calculated.estimated_mg,
    caffeine_calculation_basis = case
      when calculated.preparation in ('espresso','americano','latte','cappuccino','cortado','flat_white','mocha','macchiato')
        then coalesce(calculated.resolved_shots, 2)::text || ' espresso shots at the traditional average'
      when calculated.estimated_mg is not null
        then replace(calculated.preparation, '_', ' ') || ' traditional average scaled to '
          || round(calculated.resolved_serving_ml)::text || ' mL'
      else null
    end,
    caffeine_coverage = case when calculated.estimated_mg is null then 'excluded' else 'estimated' end,
    preference_signals = to_jsonb(array_remove(array[
      case when calculated.temperature <> 'hot' then 'chooses_cold_drinks' end,
      case when calculated.normalized ~ '(oat milk|almond milk|soy milk|coconut milk|whole milk|skim milk|2% milk|half and half|cream)' then 'chooses_milk_drinks' end,
      case when calculated.normalized ~ '(strawberry|cherry|orange|peach|raspberry|blueberry|vanilla|caramel|hazelnut|cinnamon|cardamom|honey|maple|lavender|rose|pistachio|chocolate)' then 'chooses_flavored_drinks' end,
      case when calculated.normalized ~ '(strawberry|cherry|orange|peach|raspberry|blueberry)' then 'chooses_fruit_flavors' end,
      case when calculated.normalized ~ '(strawberry|cherry|orange|peach|raspberry|blueberry)' then 'chooses_sweet_flavors' end,
      case when calculated.normalized ~ '(syrup|sugar|sweet|honey|caramel|vanilla)' then 'chooses_sweetened_drinks' end
    ]::text[], null)),
    confidence = case when calculated.preparation = 'unknown' then 0.25 else 0.9 end,
    provenance = 'sql_backfill',
    attempt_count = calculated.attempt_count + 1,
    last_attempt_at = now(),
    last_error_code = null,
    next_retry_at = null,
    updated_at = now()
from calculated
where analysis.visit_id = calculated.visit_id;
