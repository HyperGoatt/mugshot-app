-- Phase 3 turns journal evidence into an owner-only, explainable taste graph.
-- Order choices and sensory evaluations remain separate evidence families.

create table public.taste_signals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  signal_type text not null,
  attribute text not null,
  support_count integer not null,
  confidence numeric not null,
  average_score numeric,
  evidence_visit_ids uuid[] not null default '{}'::uuid[],
  calculation_version text not null default 'taste-signals-1',
  owner_state text not null default 'active',
  owner_label text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint taste_signals_unique_attribute unique (user_id, signal_type, attribute),
  constraint taste_signals_type_check
    check (signal_type in ('order_preference', 'sensory_evaluation')),
  constraint taste_signals_support_check check (support_count >= 1),
  constraint taste_signals_confidence_check check (confidence between 0 and 1),
  constraint taste_signals_average_check check (average_score is null or average_score between 0.5 and 5),
  constraint taste_signals_evidence_check check (cardinality(evidence_visit_ids) = support_count),
  constraint taste_signals_owner_state_check check (owner_state in ('active', 'dismissed', 'corrected')),
  constraint taste_signals_owner_label_check
    check (owner_label is null or char_length(btrim(owner_label)) between 1 and 80)
);

create index taste_signals_user_state_idx
  on public.taste_signals(user_id, owner_state, support_count desc, updated_at desc);

alter table public.taste_signals enable row level security;

revoke all on table public.taste_signals from public, anon, authenticated;
grant select on table public.taste_signals to authenticated;
grant select, insert, update, delete on table public.taste_signals to service_role;

create policy "Owners can read their taste signals"
  on public.taste_signals
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.refresh_taste_signals(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_refresh_at timestamptz := clock_timestamp();
begin
  if p_user_id is null then
    return;
  end if;

  with order_evidence as (
    select
      analysis.user_id,
      'order_preference'::text as signal_type,
      signal.value as attribute,
      analysis.visit_id,
      null::numeric as score
    from public.visit_drink_analyses analysis
    cross join lateral jsonb_array_elements_text(analysis.preference_signals) signal(value)
    where analysis.user_id = p_user_id
      and analysis.processing_status = 'complete'
      and btrim(signal.value) <> ''
  ), category_evidence as (
    select
      visit.user_id,
      'sensory_evaluation'::text as signal_type,
      lower(regexp_replace(btrim(category.value ->> 'name'), '[^a-zA-Z0-9]+', '_', 'g')) as attribute,
      visit.id as visit_id,
      (category.value ->> 'score')::numeric as score
    from public.visits visit
    cross join lateral jsonb_array_elements(coalesce(visit.category_scores, '[]'::jsonb)) category(value)
    where visit.user_id = p_user_id
      and visit.upload_state = 'complete'
      and jsonb_typeof(category.value) = 'object'
      and coalesce(category.value ->> 'name', '') <> ''
      and coalesce(category.value ->> 'score', '') ~ '^\d+(\.\d+)?$'
      and (category.value ->> 'score')::numeric between 0.5 and 5
      and lower(btrim(category.value ->> 'name')) not in ('overall', 'how was it?')
  ), legacy_sensory_evidence as (
    select
      visit.user_id,
      'sensory_evaluation'::text as signal_type,
      lower(regexp_replace(btrim(rating.key), '[^a-zA-Z0-9]+', '_', 'g')) as attribute,
      visit.id as visit_id,
      rating.value::numeric as score
    from public.visits visit
    cross join lateral jsonb_each_text(coalesce(visit.ratings, '{}'::jsonb)) rating(key, value)
    where visit.user_id = p_user_id
      and visit.upload_state = 'complete'
      and jsonb_array_length(coalesce(visit.category_scores, '[]'::jsonb)) = 0
      and rating.value ~ '^\d+(\.\d+)?$'
      and rating.value::numeric between 0.5 and 5
      and lower(btrim(rating.key)) not in ('overall', 'how was it?')
  ), evidence as (
    select * from order_evidence
    union all
    select * from category_evidence
    union all
    select * from legacy_sensory_evidence
  ), calculated as (
    select
      evidence.user_id,
      evidence.signal_type,
      evidence.attribute,
      count(distinct evidence.visit_id)::integer as support_count,
      least(1::numeric, count(distinct evidence.visit_id)::numeric / 8) as confidence,
      case when evidence.signal_type = 'sensory_evaluation' then avg(evidence.score) end as average_score,
      array_agg(distinct evidence.visit_id order by evidence.visit_id) as evidence_visit_ids
    from evidence
    where evidence.attribute <> ''
    group by evidence.user_id, evidence.signal_type, evidence.attribute
  )
  insert into public.taste_signals (
    user_id,
    signal_type,
    attribute,
    support_count,
    confidence,
    average_score,
    evidence_visit_ids,
    calculation_version,
    updated_at
  )
  select
    calculated.user_id,
    calculated.signal_type,
    calculated.attribute,
    calculated.support_count,
    calculated.confidence,
    calculated.average_score,
    calculated.evidence_visit_ids,
    'taste-signals-1',
    v_refresh_at
  from calculated
  on conflict (user_id, signal_type, attribute) do update
  set support_count = excluded.support_count,
      confidence = excluded.confidence,
      average_score = excluded.average_score,
      evidence_visit_ids = excluded.evidence_visit_ids,
      calculation_version = excluded.calculation_version,
      updated_at = excluded.updated_at;

  delete from public.taste_signals signal
  where signal.user_id = p_user_id
    and signal.updated_at < v_refresh_at;
end;
$$;

revoke all on function public.refresh_taste_signals(uuid) from public, anon, authenticated;
grant execute on function public.refresh_taste_signals(uuid) to service_role;

create or replace function public.refresh_taste_signals_after_visit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_taste_signals(old.user_id);
    return old;
  end if;
  perform public.refresh_taste_signals(new.user_id);
  if tg_op = 'UPDATE' and new.user_id is distinct from old.user_id then
    perform public.refresh_taste_signals(old.user_id);
  end if;
  return new;
end;
$$;

create or replace function public.refresh_taste_signals_after_analysis()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_taste_signals(old.user_id);
    return old;
  end if;
  perform public.refresh_taste_signals(new.user_id);
  if tg_op = 'UPDATE' and new.user_id is distinct from old.user_id then
    perform public.refresh_taste_signals(old.user_id);
  end if;
  return new;
end;
$$;

revoke all on function public.refresh_taste_signals_after_visit() from public, anon, authenticated;
revoke all on function public.refresh_taste_signals_after_analysis() from public, anon, authenticated;

create trigger refresh_taste_signals_after_visit
  after insert or update of ratings, category_scores, upload_state, user_id or delete
  on public.visits
  for each row execute function public.refresh_taste_signals_after_visit();

create trigger refresh_taste_signals_after_analysis
  after insert or update of preference_signals, processing_status, user_id or delete
  on public.visit_drink_analyses
  for each row execute function public.refresh_taste_signals_after_analysis();

create or replace function public.set_taste_signal_owner_state(
  p_signal_id uuid,
  p_state text,
  p_label text default null
)
returns public.taste_signals
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_result public.taste_signals;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_state not in ('active', 'dismissed', 'corrected') then
    raise exception 'unsupported taste signal state' using errcode = '22023';
  end if;
  if p_state = 'corrected' and nullif(btrim(coalesce(p_label, '')), '') is null then
    raise exception 'corrected taste signals require a label' using errcode = '22023';
  end if;

  update public.taste_signals signal
  set owner_state = p_state,
      owner_label = case when p_state = 'corrected' then btrim(p_label) else null end,
      updated_at = now()
  where signal.id = p_signal_id
    and signal.user_id = v_actor
  returning signal.* into v_result;

  if v_result.id is null then
    raise exception 'taste signal ownership required' using errcode = '42501';
  end if;
  return v_result;
end;
$$;

revoke all on function public.set_taste_signal_owner_state(uuid,text,text) from public, anon;
grant execute on function public.set_taste_signal_owner_state(uuid,text,text) to authenticated;

do $$
declare
  owner_row record;
begin
  for owner_row in select id from auth.users loop
    perform public.refresh_taste_signals(owner_row.id);
  end loop;
end;
$$;

-- Keep the existing ranked feed contract while making every Your Mix result
-- explain its primary evidence source.
drop function public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid);

create function public.ranked_feed(
  p_scope text default 'ranked',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_limit integer default 20,
  p_after_score double precision default null,
  p_after_created_at timestamptz default null,
  p_after_id uuid default null
)
returns table (
  visit_id uuid, user_id uuid, cafe_id uuid, caption text, drink_name text,
  overall_score double precision, poster_photo_url text, created_at timestamptz,
  author_display_name text, author_username text, author_avatar_url text,
  cafe_name text, like_count bigint, comment_count bigint,
  feed_score double precision, ranking_reason text, reason_type text
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() viewer), base as (
    select v.*,u.display_name,u.username,u.avatar_url,c.name cafe_name,c.latitude,c.longitude,
      (select count(*) from public.likes l where l.visit_id=v.id) likes,
      (select count(*) from public.comments cm where cm.visit_id=v.id) comments,
      case when private.confirmed_friends(i.viewer,v.user_id) then 1.0 when v.user_id=i.viewer then 1.0 else .35 end relationship,
      exp(-extract(epoch from (now()-v.created_at))/86400/14) recency,
      case when p_latitude between -90 and 90 and p_longitude between -180 and 180 and c.latitude is not null then
        greatest(0,1-(6371*2*asin(sqrt(power(sin(radians(c.latitude-p_latitude)/2),2)+cos(radians(p_latitude))*cos(radians(c.latitude))*power(sin(radians(c.longitude-p_longitude)/2),2))))/100)
      end geo,
      exists(select 1 from public.visits mine where mine.user_id=i.viewer and coalesce(mine.drink_subtype,mine.drink_type)=coalesce(v.drink_subtype,v.drink_type)) affinity,
      exists(select 1 from public.user_cafe_states saved where saved.user_id=i.viewer and saved.cafe_id=v.cafe_id and (saved.is_favorite or saved.want_to_try)) saved_match,
      exists(
        select 1
        from public.taste_signals mine
        join public.taste_signals theirs
          on theirs.signal_type=mine.signal_type and theirs.attribute=mine.attribute
        where mine.user_id=i.viewer and theirs.user_id=v.user_id
          and mine.owner_state<>'dismissed' and theirs.owner_state<>'dismissed'
          and mine.support_count>=3 and theirs.support_count>=3
      ) taste_match
    from public.visits v cross join input i join public.users u on u.id=v.user_id
    left join public.cafes c on c.id=v.cafe_id
    where private.can_view_visit_as(v.id,i.viewer)
      and case p_scope when 'friends' then private.confirmed_friends(i.viewer,v.user_id)
                       when 'everyone' then v.visibility='everyone'
                       when 'ranked' then true else false end
  ), scored as (
    select b.*, (.32*relationship + .23*recency + .13*least((likes+comments*2)::double precision/10,1)
      + .12*(case when affinity then 1 else 0 end)
      + .10*(case when taste_match then 1 else 0 end)
      + coalesce(.10*geo,0))
      / (case when geo is null then .90 else 1 end) score
    from base b
  )
  select s.id,s.user_id,s.cafe_id,s.caption,coalesce(s.drink_subtype,s.drink_type),s.overall_score,
    s.poster_photo_url,s.created_at,s.display_name,s.username,s.avatar_url,s.cafe_name,s.likes,s.comments,s.score,
    case when s.relationship=1 and s.user_id<>(select viewer from input) then 'A sip from your friend'
         when s.taste_match then 'Matches patterns in your Taste Identity'
         when s.saved_match then 'From a cafe you saved'
         when s.affinity then 'Inspired by drinks in your journal'
         else 'A recent sip from the Mugshot community' end,
    case when s.relationship=1 and s.user_id<>(select viewer from input) then 'friend_activity'
         when s.taste_match then 'taste_match'
         when s.saved_match then 'saved_cafe'
         when s.affinity then 'journal_evidence'
         else 'recent_community' end
  from scored s
  where p_after_score is null or (s.score,s.created_at,s.id)<(p_after_score,p_after_created_at,p_after_id)
  order by s.score desc,s.created_at desc,s.id desc
  limit least(greatest(p_limit,1),50);
$$;

revoke all on function public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid)
  from public, anon;
grant execute on function public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid)
  to authenticated;
