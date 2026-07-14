alter table public.cafes
  add column if not exists identity_key text;

create or replace function public.set_cafe_identity_key()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  normalized_name text := lower(regexp_replace(btrim(new.name), '\s+', ' ', 'g'));
begin
  new.identity_key := case
    when nullif(btrim(new.apple_place_id), '') is not null then
      'apple:' || lower(regexp_replace(btrim(new.apple_place_id), '\s+', ' ', 'g'))
    when new.latitude is not null and new.longitude is not null then
      'geo:' || normalized_name || '|' ||
      to_char(round(new.latitude::numeric, 5), 'FM999990.00000') || '|' ||
      to_char(round(new.longitude::numeric, 5), 'FM999990.00000')
    else
      'text:' || normalized_name || '|' ||
      lower(regexp_replace(btrim(coalesce(new.address, '')), '\s+', ' ', 'g'))
  end;
  return new;
end;
$$;

revoke all on function public.set_cafe_identity_key() from public, anon, authenticated;

drop trigger if exists cafes_set_identity_key on public.cafes;
create trigger cafes_set_identity_key
before insert or update of name, address, latitude, longitude, apple_place_id, identity_key
on public.cafes
for each row execute function public.set_cafe_identity_key();

update public.cafes set identity_key = identity_key;

create temporary table mugshot_cafe_merge_map (
  duplicate_id uuid primary key,
  keeper_id uuid not null
) on commit drop;

insert into mugshot_cafe_merge_map (duplicate_id, keeper_id)
with scored as (
  select
    c.id,
    c.identity_key,
    c.created_at,
    (select count(*) from public.visits v where v.cafe_id = c.id) +
    (select count(*) from public.user_cafe_states s where s.cafe_id = c.id) as reference_count
  from public.cafes c
), ranked as (
  select
    id,
    first_value(id) over (
      partition by identity_key
      order by reference_count desc, created_at asc, id asc
    ) as keeper_id,
    row_number() over (
      partition by identity_key
      order by reference_count desc, created_at asc, id asc
    ) as identity_rank
  from scored
)
select id, keeper_id
from ranked
where identity_rank > 1;

insert into public.user_cafe_states (user_id, cafe_id, is_favorite, want_to_try)
select
  s.user_id,
  m.keeper_id,
  bool_or(s.is_favorite),
  bool_or(s.want_to_try)
from public.user_cafe_states s
join mugshot_cafe_merge_map m on m.duplicate_id = s.cafe_id
group by s.user_id, m.keeper_id
on conflict (user_id, cafe_id) do update
set
  is_favorite = public.user_cafe_states.is_favorite or excluded.is_favorite,
  want_to_try = public.user_cafe_states.want_to_try or excluded.want_to_try,
  updated_at = now();

delete from public.user_cafe_states s
using mugshot_cafe_merge_map m
where s.cafe_id = m.duplicate_id;

update public.visits v
set cafe_id = m.keeper_id
from mugshot_cafe_merge_map m
where v.cafe_id = m.duplicate_id;

delete from public.cafes c
using mugshot_cafe_merge_map m
where c.id = m.duplicate_id;

alter table public.cafes
  alter column identity_key set not null;

alter table public.cafes
  drop constraint if exists cafes_identity_key_key;

alter table public.cafes
  add constraint cafes_identity_key_key unique (identity_key);
