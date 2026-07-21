-- Cafe Sessions keeps a physical cafe visit distinct from the sips recorded
-- during it. Sip enjoyment remains on visits.overall_score. Cafe experience,
-- return intent, reorder intent, and responsible place learning live in
-- separate, explicitly related records.
--
-- This migration is additive. Existing visits remain valid with a NULL
-- cafe_session_id, and no historical visit is inferred into a session.

create or replace function public.derive_cafe_next_move(
  p_return_intention text,
  p_reorder_intention text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_return_intention is null
      or p_reorder_intention is null
      or p_return_intention = 'maybe'
      or p_reorder_intention = 'maybe'
      then 'not_sure_yet'
    when p_return_intention = 'yes' and p_reorder_intention = 'yes'
      then 'come_back_for_this'
    when p_return_intention = 'yes' and p_reorder_intention = 'no'
      then 'come_back_try_another'
    when p_return_intention = 'no' and p_reorder_intention = 'yes'
      then 'this_drink_elsewhere'
    when p_return_intention = 'no' and p_reorder_intention = 'no'
      then 'probably_not_again'
    else 'not_sure_yet'
  end;
$$;

create or replace function public.cafe_dimension_ids_are_valid(p_ids text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    p_ids is not null
    and cardinality(p_ids) <= 6
    and array_position(p_ids, null) is null
    and p_ids <@ array[
      'atmosphere',
      'music_sound',
      'hospitality',
      'menu_value',
      'comfort_practicality',
      'community_character'
    ]::text[]
    and cardinality(p_ids) = (
      select count(distinct dimension_id)
      from unnest(p_ids) dimension_id
    );
$$;

create or replace function public.cafe_context_overlays_are_valid(
  p_overlays text[]
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    p_overlays is not null
    and cardinality(p_overlays) <= 2
    and array_position(p_overlays, null) is null
    and p_overlays <@ array['outdoor', 'busy_queue']::text[]
    and cardinality(p_overlays) = (
      select count(distinct overlay)
      from unnest(p_overlays) overlay
    );
$$;

create or replace function public.cafe_descriptor_ids_are_valid(p_ids text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    p_ids is not null
    and cardinality(p_ids) <= 12
    and array_position(p_ids, null) is null
    and cardinality(p_ids) = (
      select count(distinct descriptor_id)
      from unnest(p_ids) descriptor_id
    )
    and not exists (
      select 1
      from unnest(p_ids) descriptor_id
      where descriptor_id !~
        '^cafe\.descriptor\.[a-z0-9][a-z0-9_.-]{0,107}$'
    );
$$;

create or replace function public.cafe_pulse_responses_are_valid(p_responses jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  response jsonb;
  response_state text;
  response_impact text;
  dimension_id text;
  observation_id text;
  descriptor_ids text[];
begin
  if jsonb_typeof(p_responses) <> 'array'
     or jsonb_array_length(p_responses) > 120 then
    return false;
  end if;

  for response in
    select value from jsonb_array_elements(p_responses)
  loop
    if jsonb_typeof(response) <> 'object' then
      return false;
    end if;

    dimension_id := response ->> 'dimensionID';
    if dimension_id is null
       or not public.cafe_dimension_ids_are_valid(array[dimension_id]) then
      return false;
    end if;

    observation_id := response ->> 'observationID';
    if observation_id is not null
       and observation_id !~
         '^cafe\.observation\.[a-z0-9][a-z0-9_.-]{0,107}$' then
      return false;
    end if;

    response_state := coalesce(response ->> 'state', 'observed');
    response_impact := response ->> 'impact';
    if response_state = 'observed' then
      if response_impact not in ('lifted', 'neutral', 'detracted') then
        return false;
      end if;
    elsif response_state in ('not_observed', 'not_relevant') then
      if response_impact is not null then
        return false;
      end if;
    else
      return false;
    end if;

    if response ? 'descriptorIDs' then
      if jsonb_typeof(response -> 'descriptorIDs') <> 'array' then
        return false;
      end if;

      select coalesce(array_agg(value), '{}'::text[])
      into descriptor_ids
      from jsonb_array_elements_text(response -> 'descriptorIDs');

      if not public.cafe_descriptor_ids_are_valid(descriptor_ids) then
        return false;
      end if;
    end if;
  end loop;

  return true;
exception
  when others then
    return false;
end;
$$;

revoke all on function public.derive_cafe_next_move(text, text)
  from public, anon, authenticated;
revoke all on function public.cafe_dimension_ids_are_valid(text[])
  from public, anon, authenticated;
revoke all on function public.cafe_context_overlays_are_valid(text[])
  from public, anon, authenticated;
revoke all on function public.cafe_descriptor_ids_are_valid(text[])
  from public, anon, authenticated;
revoke all on function public.cafe_pulse_responses_are_valid(jsonb)
  from public, anon, authenticated;

grant execute on function public.derive_cafe_next_move(text, text)
  to authenticated, service_role;
grant execute on function public.cafe_dimension_ids_are_valid(text[])
  to service_role;
grant execute on function public.cafe_context_overlays_are_valid(text[])
  to service_role;
grant execute on function public.cafe_descriptor_ids_are_valid(text[])
  to service_role;
grant execute on function public.cafe_pulse_responses_are_valid(jsonb)
  to service_role;

create table public.cafe_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  primary_visit_id uuid references public.visits(id) on delete set null,
  status text not null default 'draft'
    check (status in ('draft', 'active', 'complete', 'abandoned')),
  visibility text not null default 'private'
    check (visibility in ('private', 'friends', 'everyone')),
  visit_mode text
    check (
      visit_mode is null
      or visit_mode in (
        'grab_and_go',
        'stay_a_while',
        'work_study',
        'social',
        'food_focused',
        'other'
      )
    ),
  context_overlays text[] not null default '{}',
  return_intention text
    check (return_intention is null or return_intention in ('yes', 'maybe', 'no')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cafe_sessions_identity_unique unique (id, user_id),
  constraint cafe_sessions_cafe_identity_unique unique (id, user_id, cafe_id),
  constraint cafe_sessions_context_overlays_valid
    check (public.cafe_context_overlays_are_valid(context_overlays)),
  constraint cafe_sessions_time_order check (
    ended_at is null or ended_at >= started_at
  ),
  constraint cafe_sessions_status_end_coherence check (
    status in ('draft', 'active') or ended_at is not null
  )
);

alter table public.visits
  add column if not exists cafe_session_id uuid,
  add column if not exists cafe_session_order smallint,
  add column if not exists cafe_session_role text;

alter table public.visits
  add constraint visits_cafe_session_id_fkey
  foreign key (cafe_session_id)
  references public.cafe_sessions(id)
  on delete no action
  deferrable initially deferred;

alter table public.visits
  add constraint visits_cafe_session_fields_coherent
  check (
    (
      cafe_session_id is null
      and cafe_session_order is null
      and cafe_session_role is null
    )
    or (
      cafe_session_id is not null
      and cafe_session_order is not null
      and cafe_session_order >= 0
      and cafe_session_role in ('primary', 'secondary')
      and cafe_id is not null
      and lower(btrim(context_type)) is not distinct from 'cafe'
    )
  );

alter table public.visits
  add constraint visits_session_identity_unique
  unique (id, cafe_session_id, user_id);

create unique index visits_cafe_session_order_unique
  on public.visits(cafe_session_id, cafe_session_order)
  where cafe_session_id is not null;

create unique index visits_cafe_session_primary_unique
  on public.visits(cafe_session_id)
  where cafe_session_role = 'primary';

create index visits_cafe_session_owner_idx
  on public.visits(cafe_session_id, user_id, cafe_session_order)
  where cafe_session_id is not null;

create table public.cafe_sip_intentions (
  visit_id uuid primary key,
  session_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  reorder_intention text not null
    check (reorder_intention in ('yes', 'maybe', 'no')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cafe_sip_intentions_visit_session_owner_fk
    foreign key (visit_id, session_id, user_id)
    references public.visits(id, cafe_session_id, user_id)
    on delete cascade
    deferrable initially deferred,
  constraint cafe_sip_intentions_session_owner_fk
    foreign key (session_id, user_id)
    references public.cafe_sessions(id, user_id)
    on delete cascade
    deferrable initially deferred
);

create table public.cafe_experience_snapshots (
  session_id uuid primary key,
  snapshot_id uuid not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  schema_version integer not null,
  bundle_id text not null,
  bundle_content_version text not null,
  depth text not null check (depth in ('quick', 'guided', 'deep')),
  cafe_rating numeric(2, 1),
  repeat_comparison text
    check (
      repeat_comparison is null
      or repeat_comparison in ('same', 'better', 'worse', 'different')
    ),
  responses jsonb not null,
  own_words text not null default '',
  return_intention text
    check (return_intention is null or return_intention in ('yes', 'maybe', 'no')),
  primary_reorder_intention text
    check (
      primary_reorder_intention is null
      or primary_reorder_intention in ('yes', 'maybe', 'no')
    ),
  next_move text not null,
  snapshot_payload jsonb not null,
  payload_hash text not null,
  created_at timestamptz not null,
  stored_at timestamptz not null default now(),
  constraint cafe_experience_snapshots_owner_identity_unique
    unique (snapshot_id, user_id),
  constraint cafe_experience_snapshots_cafe_identity_unique
    unique (snapshot_id, user_id, cafe_id),
  constraint cafe_experience_snapshots_session_identity_unique
    unique (session_id, snapshot_id, user_id),
  constraint cafe_experience_snapshots_session_owner_cafe_fk
    foreign key (session_id, user_id, cafe_id)
    references public.cafe_sessions(id, user_id, cafe_id)
    on delete cascade
    deferrable initially deferred,
  constraint cafe_experience_snapshots_schema_version_positive
    check (schema_version > 0),
  constraint cafe_experience_snapshots_bundle_id_nonempty
    check (length(btrim(bundle_id)) > 0),
  constraint cafe_experience_snapshots_bundle_version_nonempty
    check (length(btrim(bundle_content_version)) > 0),
  constraint cafe_experience_snapshots_rating_half_step check (
    cafe_rating is null
    or (
      cafe_rating between 1 and 5
      and cafe_rating * 2 = trunc(cafe_rating * 2)
    )
  ),
  constraint cafe_experience_snapshots_responses_valid
    check (public.cafe_pulse_responses_are_valid(responses)),
  constraint cafe_experience_snapshots_own_words_length
    check (char_length(own_words) <= 20000),
  constraint cafe_experience_snapshots_payload_object
    check (jsonb_typeof(snapshot_payload) = 'object'),
  constraint cafe_experience_snapshots_payload_hash_format
    check (payload_hash ~ '^[0-9a-f]{64}$'),
  constraint cafe_experience_snapshots_payload_identity_matches check (
    (snapshot_payload ->> 'id')::uuid
      is not distinct from snapshot_id
    and (snapshot_payload ->> 'sessionID')::uuid
      is not distinct from session_id
    and (snapshot_payload ->> 'ownerUserID')::uuid
      is not distinct from user_id
    and (snapshot_payload ->> 'cafeID')::uuid
      is not distinct from cafe_id
  ),
  constraint cafe_experience_snapshots_payload_schema_matches
    check (
      (snapshot_payload ->> 'schemaVersion')::integer
        is not distinct from schema_version
    ),
  constraint cafe_experience_snapshots_payload_depth_matches
    check (
      snapshot_payload ->> 'depth'
        is not distinct from depth
    ),
  constraint cafe_experience_snapshots_payload_rating_matches
    check (
      (snapshot_payload ->> 'cafeRating')::numeric
        is not distinct from cafe_rating
    ),
  constraint cafe_experience_snapshots_payload_repeat_matches check (
    snapshot_payload ->> 'repeatComparison'
      is not distinct from repeat_comparison
  ),
  constraint cafe_experience_snapshots_payload_context_object check (
    jsonb_typeof(snapshot_payload -> 'visitContext')
      is not distinct from 'object'
  ),
  constraint cafe_experience_snapshots_payload_observations_array check (
    jsonb_typeof(snapshot_payload -> 'observations')
      is not distinct from 'array'
  ),
  constraint cafe_experience_snapshots_payload_words_match check (
    coalesce(snapshot_payload ->> 'ownWords', '') = own_words
  ),
  constraint cafe_experience_snapshots_payload_intentions_match check (
    snapshot_payload ->> 'returnIntention'
      is not distinct from return_intention
  ),
  constraint cafe_experience_snapshots_next_move_matches check (
    next_move = public.derive_cafe_next_move(
      return_intention,
      primary_reorder_intention
    )
  )
);

create table public.cafe_experience_corrections (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  snapshot_id uuid not null,
  target_id text not null,
  reason text not null
    check (
      reason in (
        'not_useful',
        'selected_by_mistake',
        'not_relevant',
        'other'
      )
    ),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint cafe_experience_corrections_snapshot_owner_fk
    foreign key (snapshot_id, user_id)
    references public.cafe_experience_snapshots(snapshot_id, user_id)
    on delete cascade,
  constraint cafe_experience_corrections_target_nonempty
    check (length(btrim(target_id)) > 0),
  constraint cafe_experience_corrections_metadata_object
    check (jsonb_typeof(metadata) = 'object')
);

create table public.cafe_experience_public_projections (
  session_id uuid primary key,
  snapshot_id uuid,
  primary_visit_id uuid references public.visits(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  schema_version integer not null default 1,
  includes_cafe_rating boolean not null default false,
  includes_next_move boolean not null default false,
  cafe_rating numeric(2, 1),
  next_move text
    check (
      next_move is null
      or
      next_move in (
        'come_back_for_this',
        'come_back_try_another',
        'this_drink_elsewhere',
        'probably_not_again',
        'not_sure_yet'
      )
    ),
  dimension_ids text[] not null default '{}',
  descriptor_ids text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cafe_experience_public_projection_snapshot_identity_fk
    foreign key (session_id, snapshot_id, user_id)
    references public.cafe_experience_snapshots(
      session_id,
      snapshot_id,
      user_id
    )
    on delete cascade,
  constraint cafe_experience_public_projection_session_cafe_fk
    foreign key (session_id, user_id, cafe_id)
    references public.cafe_sessions(id, user_id, cafe_id)
    on delete cascade
    deferrable initially deferred,
  constraint cafe_experience_public_projection_schema_positive
    check (schema_version > 0),
  constraint cafe_experience_public_projection_rating_half_step check (
    cafe_rating is null
    or (
      cafe_rating between 1 and 5
      and cafe_rating * 2 = trunc(cafe_rating * 2)
    )
  ),
  constraint cafe_experience_public_projection_rating_opt_in check (
    includes_cafe_rating = (cafe_rating is not null)
  ),
  constraint cafe_experience_public_projection_next_move_opt_in check (
    includes_next_move = (next_move is not null)
  ),
  constraint cafe_experience_public_projection_not_empty check (
    includes_cafe_rating
    or includes_next_move
    or cardinality(dimension_ids) > 0
    or cardinality(descriptor_ids) > 0
  ),
  constraint cafe_experience_public_projection_snapshot_scope check (
    snapshot_id is not null
    or (
      includes_next_move
      and not includes_cafe_rating
      and cafe_rating is null
      and cardinality(dimension_ids) = 0
      and cardinality(descriptor_ids) = 0
    )
  ),
  constraint cafe_experience_public_projection_dimensions_valid
    check (public.cafe_dimension_ids_are_valid(dimension_ids)),
  constraint cafe_experience_public_projection_descriptors_valid
    check (public.cafe_descriptor_ids_are_valid(descriptor_ids))
);

create table public.cafe_experience_signals (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  signal_scope text not null
    check (
      signal_scope in (
        'cafe_relationship',
        'general_preference',
        'strong_preference'
      )
    ),
  attribute text not null,
  sentiment text not null
    check (sentiment in ('positive', 'negative', 'neutral')),
  confidence numeric(4, 3) not null
    check (confidence between 0 and 1),
  support_count integer not null check (support_count >= 1),
  cafe_count integer not null check (cafe_count >= 1),
  calculation_version text not null,
  owner_state text not null default 'active'
    check (owner_state in ('active', 'dismissed', 'corrected')),
  owner_label text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cafe_experience_signals_identity_unique
    unique (id, user_id),
  constraint cafe_experience_signals_attribute_unique
    unique (user_id, signal_scope, attribute),
  constraint cafe_experience_signals_attribute_nonempty
    check (length(btrim(attribute)) between 1 and 120),
  constraint cafe_experience_signals_version_nonempty
    check (length(btrim(calculation_version)) between 1 and 80),
  constraint cafe_experience_signals_owner_label_valid
    check (
      owner_label is null
      or char_length(btrim(owner_label)) between 1 and 80
    ),
  constraint cafe_experience_signals_evidence_threshold check (
    (
      signal_scope = 'cafe_relationship'
      and cafe_count = 1
    )
    or (
      signal_scope = 'general_preference'
      and support_count >= 3
      and cafe_count >= 2
    )
    or (
      signal_scope = 'strong_preference'
      and support_count >= 5
      and cafe_count >= 3
    )
  )
);

create table public.cafe_experience_signal_evidence (
  signal_id uuid not null,
  session_id uuid not null,
  snapshot_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  evidence_key text not null,
  evidence_kind text not null
    check (
      evidence_kind in (
        'lifted_observation',
        'detracted_observation',
        'repeat_comparison',
        'explicit_intent'
      )
    ),
  dimension_id text,
  descriptor_id text,
  impact text check (impact is null or impact in ('lifted', 'detracted')),
  created_at timestamptz not null default now(),
  primary key (signal_id, session_id, evidence_key),
  constraint cafe_experience_signal_evidence_signal_owner_fk
    foreign key (signal_id, user_id)
    references public.cafe_experience_signals(id, user_id)
    on delete cascade,
  constraint cafe_experience_signal_evidence_snapshot_cafe_fk
    foreign key (snapshot_id, user_id, cafe_id)
    references public.cafe_experience_snapshots(snapshot_id, user_id, cafe_id)
    on delete cascade,
  constraint cafe_experience_signal_evidence_session_snapshot_fk
    foreign key (session_id, snapshot_id, user_id)
    references public.cafe_experience_snapshots(
      session_id,
      snapshot_id,
      user_id
    )
    on delete cascade,
  constraint cafe_experience_signal_evidence_key_nonempty
    check (length(btrim(evidence_key)) between 1 and 160),
  constraint cafe_experience_signal_evidence_dimension_valid check (
    dimension_id is null
    or public.cafe_dimension_ids_are_valid(array[dimension_id])
  ),
  constraint cafe_experience_signal_evidence_descriptor_valid check (
    descriptor_id is null
    or public.cafe_descriptor_ids_are_valid(array[descriptor_id])
  ),
  constraint cafe_experience_signal_evidence_impact_coherent check (
    (
      evidence_kind = 'lifted_observation'
      and impact = 'lifted'
    )
    or (
      evidence_kind = 'detracted_observation'
      and impact = 'detracted'
    )
    or (
      evidence_kind in ('repeat_comparison', 'explicit_intent')
      and impact is null
    )
  )
);

create index cafe_sessions_owner_cafe_history_idx
  on public.cafe_sessions(user_id, cafe_id, started_at desc, id desc)
  where status in ('active', 'complete');
create index cafe_sessions_cafe_history_idx
  on public.cafe_sessions(cafe_id, started_at desc, id desc)
  where status in ('active', 'complete');
create index cafe_sessions_primary_visit_idx
  on public.cafe_sessions(primary_visit_id)
  where primary_visit_id is not null;
create index cafe_sip_intentions_owner_session_idx
  on public.cafe_sip_intentions(user_id, session_id, created_at);
create index cafe_sip_intentions_session_owner_idx
  on public.cafe_sip_intentions(session_id, user_id);
create index cafe_sessions_cafe_fk_idx
  on public.cafe_sessions(cafe_id);
create index cafe_experience_snapshots_owner_cafe_history_idx
  on public.cafe_experience_snapshots(
    user_id,
    cafe_id,
    created_at desc,
    session_id
  );
create index cafe_experience_snapshots_cafe_fk_idx
  on public.cafe_experience_snapshots(cafe_id);
create index cafe_experience_corrections_owner_snapshot_idx
  on public.cafe_experience_corrections(
    user_id,
    snapshot_id,
    created_at desc
  );
create index cafe_experience_corrections_snapshot_owner_idx
  on public.cafe_experience_corrections(snapshot_id, user_id);
create index cafe_experience_public_projection_cafe_history_idx
  on public.cafe_experience_public_projections(
    cafe_id,
    created_at desc,
    session_id
  );
create index cafe_experience_public_projection_owner_idx
  on public.cafe_experience_public_projections(
    user_id,
    created_at desc,
    session_id
  );
create index cafe_experience_public_projection_primary_visit_idx
  on public.cafe_experience_public_projections(primary_visit_id)
  where primary_visit_id is not null;
create index cafe_experience_signals_owner_state_idx
  on public.cafe_experience_signals(
    user_id,
    owner_state,
    updated_at desc
  );
create index cafe_experience_signal_evidence_owner_cafe_idx
  on public.cafe_experience_signal_evidence(
    user_id,
    cafe_id,
    created_at desc
  );
create index cafe_experience_signal_evidence_snapshot_idx
  on public.cafe_experience_signal_evidence(snapshot_id, user_id);
create index cafe_experience_signal_evidence_session_snapshot_idx
  on public.cafe_experience_signal_evidence(
    session_id,
    snapshot_id,
    user_id
  );
create index cafe_experience_signal_evidence_cafe_fk_idx
  on public.cafe_experience_signal_evidence(cafe_id);

create trigger set_cafe_sessions_updated_at
  before update on public.cafe_sessions
  for each row execute function public.set_updated_at();
create trigger set_cafe_sip_intentions_updated_at
  before update on public.cafe_sip_intentions
  for each row execute function public.set_updated_at();
create trigger set_cafe_experience_projection_updated_at
  before update on public.cafe_experience_public_projections
  for each row execute function public.set_updated_at();
create trigger set_cafe_experience_signals_updated_at
  before update on public.cafe_experience_signals
  for each row execute function public.set_updated_at();

create or replace function public.reject_cafe_experience_history_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Cafe experience history is append-only'
    using errcode = '55000';
end;
$$;

revoke all on function public.reject_cafe_experience_history_mutation()
  from public, anon, authenticated;

create trigger keep_cafe_experience_snapshots_immutable
  before update on public.cafe_experience_snapshots
  for each row execute function public.reject_cafe_experience_history_mutation();

create trigger keep_cafe_experience_corrections_immutable
  before update on public.cafe_experience_corrections
  for each row execute function public.reject_cafe_experience_history_mutation();

create or replace function public.enforce_cafe_session_visit_contract()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.cafe_sessions%rowtype;
begin
  if new.cafe_session_id is null then
    if new.cafe_session_order is not null
       or new.cafe_session_role is not null then
      raise exception 'session order and role require a cafe session'
        using errcode = '23514';
    end if;
    return new;
  end if;

  select session.*
  into target
  from public.cafe_sessions session
  where session.id = new.cafe_session_id;

  if not found then
    raise exception 'cafe session not found' using errcode = '23503';
  end if;
  if target.user_id <> new.user_id then
    raise exception 'visit and cafe session owners must match'
      using errcode = '23514';
  end if;
  if target.cafe_id <> new.cafe_id then
    raise exception 'visit and cafe session cafes must match'
      using errcode = '23514';
  end if;
  if lower(btrim(new.context_type)) is distinct from 'cafe' then
    raise exception 'only cafe-context sips can join a cafe session'
      using errcode = '23514';
  end if;
  if target.visibility <> new.visibility then
    raise exception 'all sips in a cafe session must share one audience'
      using errcode = '23514';
  end if;
  if target.status = 'abandoned' then
    raise exception 'an abandoned cafe session cannot accept sips'
      using errcode = '55000';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_cafe_session_visit_contract()
  from public, anon, authenticated;

create trigger enforce_cafe_session_visit_contract
  before insert or update of
    cafe_session_id,
    cafe_session_order,
    cafe_session_role,
    user_id,
    cafe_id,
    context_type,
    visibility
  on public.visits
  for each row execute function public.enforce_cafe_session_visit_contract();

create or replace function public.reconcile_cafe_session_after_visit_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.cafe_sessions%rowtype;
  replacement_visit_id uuid;
begin
  if old.cafe_session_id is null then
    return old;
  end if;

  select session.*
  into target
  from public.cafe_sessions session
  where session.id = old.cafe_session_id
  for update;

  if not found then
    return old;
  end if;

  select visit.id
  into replacement_visit_id
  from public.visits visit
  where visit.cafe_session_id = old.cafe_session_id
  order by visit.cafe_session_order, visit.created_at, visit.id
  limit 1;

  if replacement_visit_id is null then
    delete from public.cafe_sessions
    where id = old.cafe_session_id;
    return old;
  end if;

  -- Abandoned drafts are intentionally frozen. If their primary is removed,
  -- leave the remaining incomplete sips unpromoted until they are deleted.
  if target.status = 'abandoned' then
    if old.cafe_session_role = 'primary'
       or target.primary_visit_id is null
       or target.primary_visit_id = old.id then
      update public.cafe_sessions
      set primary_visit_id = null
      where id = old.cafe_session_id;
    end if;
    return old;
  end if;

  if old.cafe_session_role = 'primary'
     or target.primary_visit_id is null
     or target.primary_visit_id = old.id then
    update public.visits
    set cafe_session_role = 'secondary'
    where cafe_session_id = old.cafe_session_id
      and cafe_session_role = 'primary';

    update public.visits
    set cafe_session_role = 'primary'
    where id = replacement_visit_id;

    update public.cafe_sessions
    set primary_visit_id = replacement_visit_id
    where id = old.cafe_session_id;

    update public.cafe_experience_public_projections
    set primary_visit_id = replacement_visit_id,
        next_move = case
          when includes_next_move then public.derive_cafe_next_move(
            target.return_intention,
            (
              select intention.reorder_intention
              from public.cafe_sip_intentions intention
              where intention.visit_id = replacement_visit_id
            )
          )
          else null
        end
    where session_id = old.cafe_session_id;
  end if;

  return old;
end;
$$;

revoke all on function public.reconcile_cafe_session_after_visit_delete()
  from public, anon, authenticated;

create trigger reconcile_cafe_session_after_visit_delete
  after delete on public.visits
  for each row execute function public.reconcile_cafe_session_after_visit_delete();

alter table public.cafe_sessions enable row level security;
alter table public.cafe_sessions force row level security;
alter table public.cafe_sip_intentions enable row level security;
alter table public.cafe_sip_intentions force row level security;
alter table public.cafe_experience_snapshots enable row level security;
alter table public.cafe_experience_snapshots force row level security;
alter table public.cafe_experience_corrections enable row level security;
alter table public.cafe_experience_corrections force row level security;
alter table public.cafe_experience_public_projections enable row level security;
alter table public.cafe_experience_public_projections force row level security;
alter table public.cafe_experience_signals enable row level security;
alter table public.cafe_experience_signals force row level security;
alter table public.cafe_experience_signal_evidence enable row level security;
alter table public.cafe_experience_signal_evidence force row level security;

revoke all on table public.cafe_sessions
  from public, anon, authenticated;
revoke all on table public.cafe_sip_intentions
  from public, anon, authenticated;
revoke all on table public.cafe_experience_snapshots
  from public, anon, authenticated;
revoke all on table public.cafe_experience_corrections
  from public, anon, authenticated;
revoke all on table public.cafe_experience_public_projections
  from public, anon, authenticated;
revoke all on table public.cafe_experience_signals
  from public, anon, authenticated;
revoke all on table public.cafe_experience_signal_evidence
  from public, anon, authenticated;

grant select on table public.cafe_sessions to authenticated;
grant select on table public.cafe_sip_intentions to authenticated;
grant select on table public.cafe_experience_snapshots to authenticated;
grant select on table public.cafe_experience_corrections to authenticated;
grant select on table public.cafe_experience_public_projections
  to authenticated;
grant select on table public.cafe_experience_signals to authenticated;
grant select on table public.cafe_experience_signal_evidence
  to authenticated;

-- Existing app builds retain their full legacy visit write contract, while
-- session linkage remains RPC-only. Removing the table-level write grants is
-- necessary because a table-level grant overrides column-level restrictions.
revoke insert, update on table public.visits from authenticated;
grant insert (
  id,
  user_id,
  cafe_id,
  drink_type,
  drink_type_custom,
  caption,
  notes,
  visibility,
  ratings,
  overall_score,
  poster_photo_url,
  created_at,
  updated_at,
  drink_subtype,
  location_name,
  brew_method,
  context_type,
  city_state,
  equipment,
  brew_method_visible,
  equipment_visible,
  rating_template_id,
  rating_template_type,
  category_scores,
  upload_state,
  brew_details,
  recipe_version_id
) on table public.visits to authenticated;
grant update (
  id,
  user_id,
  cafe_id,
  drink_type,
  drink_type_custom,
  caption,
  notes,
  visibility,
  ratings,
  overall_score,
  poster_photo_url,
  created_at,
  updated_at,
  drink_subtype,
  location_name,
  brew_method,
  context_type,
  city_state,
  equipment,
  brew_method_visible,
  equipment_visible,
  rating_template_id,
  rating_template_type,
  category_scores,
  upload_state,
  brew_details,
  recipe_version_id
) on table public.visits to authenticated;

grant select, insert, update, delete
  on table public.cafe_sessions,
    public.cafe_sip_intentions,
    public.cafe_experience_snapshots,
    public.cafe_experience_corrections,
    public.cafe_experience_public_projections,
    public.cafe_experience_signals,
    public.cafe_experience_signal_evidence
  to service_role;

create policy "Owners read cafe sessions"
  on public.cafe_sessions
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners read cafe sip intentions"
  on public.cafe_sip_intentions
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners read full Cafe Pulse snapshots"
  on public.cafe_experience_snapshots
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners read Cafe Pulse corrections"
  on public.cafe_experience_corrections
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Visible primary sips expose only Cafe Pulse projections"
  on public.cafe_experience_public_projections
  for select to authenticated
  using (
    primary_visit_id is not null
    and public.can_view_visit(primary_visit_id, (select auth.uid()))
  );

create policy "Owners read cafe experience signals"
  on public.cafe_experience_signals
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners read cafe experience signal evidence"
  on public.cafe_experience_signal_evidence
  for select to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.get_cafe_sessions_capability_v1()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'schema_version', 1,
    'features', jsonb_build_object(
      'cafe_sessions', true,
      'cafe_pulse', true,
      'multi_sip', true,
      'immutable_snapshots', true,
      'lossy_public_projections', true,
      'owner_export_v2', true,
      'batch_cafe_summaries', true,
      'independent_share_fields', true,
      'session_safe_finalization', true
    ),
    'community_minimum_users', 3,
    'community_minimum_sessions', 5
  )
  where (select auth.uid()) is not null;
$$;

create or replace function public.ensure_cafe_session_v1(
  p_session_id uuid,
  p_cafe_id uuid,
  p_started_at timestamptz default null,
  p_visit_mode text default null,
  p_context_overlays text[] default '{}',
  p_visibility text default 'private'
)
returns public.cafe_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.cafe_sessions%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_session_id is null or p_cafe_id is null then
    raise exception 'session and cafe identifiers are required'
      using errcode = '22023';
  end if;
  if p_visibility not in ('private', 'friends', 'everyone') then
    raise exception 'invalid session visibility' using errcode = '22023';
  end if;
  if p_visit_mode is not null
     and p_visit_mode not in (
       'grab_and_go',
       'stay_a_while',
       'work_study',
       'social',
       'food_focused',
       'other'
     ) then
    raise exception 'invalid cafe visit mode' using errcode = '22023';
  end if;
  if not public.cafe_context_overlays_are_valid(
       coalesce(p_context_overlays, '{}'::text[])
     ) then
    raise exception 'invalid cafe visit context' using errcode = '22023';
  end if;

  insert into public.cafe_sessions (
    id,
    user_id,
    cafe_id,
    visibility,
    visit_mode,
    context_overlays,
    started_at
  )
  values (
    p_session_id,
    actor,
    p_cafe_id,
    p_visibility,
    p_visit_mode,
    coalesce(p_context_overlays, '{}'::text[]),
    coalesce(p_started_at, now())
  )
  on conflict (id) do nothing;

  select session.*
  into target
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor
  for update;

  if not found then
    raise exception 'cafe session is unavailable' using errcode = '42501';
  end if;
  -- These creation fields are write-once. Existing sessions may be resumed by
  -- a later sip whose compact reference intentionally carries only identity.
  if target.cafe_id is distinct from p_cafe_id then
    raise exception 'session retry changed cafe identity'
      using errcode = '22023';
  end if;
  if target.status = 'abandoned' then
    raise exception 'abandoned cafe sessions cannot be resumed'
      using errcode = '55000';
  end if;

  return target;
end;
$$;

create or replace function public.attach_visit_to_cafe_session_v1(
  p_session_id uuid,
  p_visit_id uuid,
  p_order smallint,
  p_role text default 'secondary'
)
returns public.visits
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_session public.cafe_sessions%rowtype;
  target_visit public.visits%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_order is null or p_order < 0 then
    raise exception 'session order must be nonnegative' using errcode = '22023';
  end if;
  if p_role not in ('primary', 'secondary') then
    raise exception 'invalid session sip role' using errcode = '22023';
  end if;

  select session.*
  into target_session
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor
  for update;

  if not found or target_session.status = 'abandoned' then
    raise exception 'active cafe session not found' using errcode = '42501';
  end if;

  select visit.*
  into target_visit
  from public.visits visit
  where visit.id = p_visit_id
    and visit.user_id = actor
  for update;

  if not found then
    raise exception 'sip not found' using errcode = '42501';
  end if;
  if target_visit.cafe_id is distinct from target_session.cafe_id
     or lower(btrim(target_visit.context_type)) is distinct from 'cafe' then
    raise exception 'sip does not belong to this cafe session'
      using errcode = '23514';
  end if;
  if target_visit.cafe_session_id is not null
     and target_visit.cafe_session_id <> p_session_id then
    raise exception 'sip already belongs to another cafe session'
      using errcode = '23505';
  end if;
  if target_visit.cafe_session_id = p_session_id
     and target_visit.cafe_session_role = 'primary'
     and p_role = 'secondary' then
    raise exception 'use another sip when replacing the session primary'
      using errcode = '23514';
  end if;

  if target_visit.cafe_session_id = p_session_id
     and target_visit.cafe_session_order = p_order
     and target_visit.cafe_session_role = p_role then
    return target_visit;
  end if;
  if target_session.status = 'complete' and p_role = 'primary' then
    raise exception 'a completed cafe session keeps its primary sip'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.visits occupied
    where occupied.cafe_session_id = p_session_id
      and occupied.cafe_session_order = p_order
      and occupied.id <> p_visit_id
  ) then
    raise exception 'session order is already occupied' using errcode = '23505';
  end if;

  if p_role = 'primary' then
    update public.visits
    set cafe_session_role = 'secondary'
    where cafe_session_id = p_session_id
      and cafe_session_role = 'primary'
      and id <> p_visit_id;
  elsif target_session.primary_visit_id is null then
    raise exception 'a cafe session needs a primary sip before secondary sips'
      using errcode = '23514';
  end if;

  update public.visits
  set cafe_session_id = p_session_id,
      cafe_session_order = p_order,
      cafe_session_role = p_role,
      visibility = target_session.visibility
  where id = p_visit_id
  returning * into target_visit;

  if p_role = 'primary' then
    update public.cafe_sessions
    set primary_visit_id = p_visit_id,
        status = case
          when status = 'draft' then 'active'
          else status
        end
    where id = p_session_id;
  end if;

  return target_visit;
end;
$$;

create or replace function public.finalize_cafe_session_sip_v1(
  p_session_id uuid,
  p_visit_id uuid
)
returns public.visits
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_session public.cafe_sessions%rowtype;
  target_visit public.visits%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select session.*
  into target_session
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor
  for update;

  if not found or target_session.status = 'abandoned' then
    raise exception 'active cafe session not found' using errcode = '42501';
  end if;

  select visit.*
  into target_visit
  from public.visits visit
  where visit.id = p_visit_id
    and visit.user_id = actor
    and visit.cafe_session_id = p_session_id
  for update;

  if not found then
    raise exception 'sip is not part of this cafe session'
      using errcode = '23514';
  end if;

  if target_visit.upload_state = 'complete' then
    return target_visit;
  end if;

  update public.visits
  set upload_state = 'complete'
  where id = p_visit_id
    and user_id = actor
    and cafe_session_id = p_session_id
  returning * into target_visit;

  return target_visit;
end;
$$;

create or replace function public.set_cafe_session_intentions_v1(
  p_session_id uuid,
  p_visit_id uuid,
  p_return_intention text,
  p_reorder_intention text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_session public.cafe_sessions%rowtype;
  derived_next_move text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if (
       p_return_intention is not null
       and p_return_intention not in ('yes', 'maybe', 'no')
     )
     or (
       p_reorder_intention is not null
       and p_reorder_intention not in ('yes', 'maybe', 'no')
     ) then
    raise exception 'invalid return or reorder intention'
      using errcode = '22023';
  end if;

  select session.*
  into target_session
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor
  for update;

  if not found then
    raise exception 'cafe session not found' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and visit.cafe_session_id = p_session_id
      and visit.user_id = actor
  ) then
    raise exception 'sip is not part of this cafe session'
      using errcode = '23514';
  end if;

  update public.cafe_sessions
  set return_intention = p_return_intention
  where id = p_session_id;

  if p_reorder_intention is null then
    delete from public.cafe_sip_intentions
    where visit_id = p_visit_id
      and session_id = p_session_id
      and user_id = actor;
  else
    insert into public.cafe_sip_intentions (
      visit_id,
      session_id,
      user_id,
      reorder_intention
    )
    values (
      p_visit_id,
      p_session_id,
      actor,
      p_reorder_intention
    )
    on conflict (visit_id) do update
    set reorder_intention = excluded.reorder_intention,
        updated_at = now()
    where public.cafe_sip_intentions.session_id = excluded.session_id
      and public.cafe_sip_intentions.user_id = excluded.user_id;
  end if;

  derived_next_move := public.derive_cafe_next_move(
    p_return_intention,
    p_reorder_intention
  );

  if target_session.primary_visit_id = p_visit_id then
    update public.cafe_experience_public_projections
    set next_move = case
      when includes_next_move then derived_next_move
      else null
    end
    where session_id = p_session_id;
  end if;

  return jsonb_build_object(
    'session_id', p_session_id,
    'visit_id', p_visit_id,
    'return_intention', p_return_intention,
    'reorder_intention', p_reorder_intention,
    'next_move', derived_next_move
  );
end;
$$;

create or replace function public.record_cafe_experience_v1(
  p_session_id uuid,
  p_snapshot_id uuid,
  p_schema_version integer,
  p_bundle_id text,
  p_bundle_content_version text,
  p_depth text,
  p_cafe_rating numeric,
  p_repeat_comparison text,
  p_responses jsonb,
  p_own_words text,
  p_return_intention text,
  p_primary_reorder_intention text,
  p_snapshot_payload jsonb,
  p_payload_hash text,
  p_created_at timestamptz
)
returns public.cafe_experience_snapshots
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_session public.cafe_sessions%rowtype;
  existing public.cafe_experience_snapshots%rowtype;
  primary_visit uuid;
  derived_next_move text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select session.*
  into target_session
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor
  for update;

  if not found or target_session.status = 'abandoned' then
    raise exception 'active cafe session not found' using errcode = '42501';
  end if;

  primary_visit := target_session.primary_visit_id;
  if p_primary_reorder_intention is not null and primary_visit is null then
    raise exception 'primary reorder intent requires a primary sip'
      using errcode = '23514';
  end if;

  derived_next_move := public.derive_cafe_next_move(
    p_return_intention,
    p_primary_reorder_intention
  );

  insert into public.cafe_experience_snapshots (
    session_id,
    snapshot_id,
    user_id,
    cafe_id,
    schema_version,
    bundle_id,
    bundle_content_version,
    depth,
    cafe_rating,
    repeat_comparison,
    responses,
    own_words,
    return_intention,
    primary_reorder_intention,
    next_move,
    snapshot_payload,
    payload_hash,
    created_at
  )
  values (
    p_session_id,
    p_snapshot_id,
    actor,
    target_session.cafe_id,
    p_schema_version,
    p_bundle_id,
    p_bundle_content_version,
    p_depth,
    p_cafe_rating,
    p_repeat_comparison,
    p_responses,
    coalesce(p_own_words, ''),
    p_return_intention,
    p_primary_reorder_intention,
    derived_next_move,
    p_snapshot_payload,
    p_payload_hash,
    p_created_at
  )
  on conflict (session_id) do nothing;

  select snapshot.*
  into existing
  from public.cafe_experience_snapshots snapshot
  where snapshot.session_id = p_session_id
    and snapshot.user_id = actor;

  if not found then
    raise exception 'Cafe Pulse snapshot is unavailable'
      using errcode = '42501';
  end if;
  if existing.snapshot_id is distinct from p_snapshot_id
     or existing.schema_version is distinct from p_schema_version
     or existing.bundle_id is distinct from p_bundle_id
     or existing.bundle_content_version
       is distinct from p_bundle_content_version
     or existing.depth is distinct from p_depth
     or existing.cafe_rating is distinct from p_cafe_rating
     or existing.repeat_comparison is distinct from p_repeat_comparison
     or existing.responses is distinct from p_responses
     or existing.own_words is distinct from coalesce(p_own_words, '')
     or existing.return_intention is distinct from p_return_intention
     or existing.primary_reorder_intention
       is distinct from p_primary_reorder_intention
     or existing.next_move is distinct from derived_next_move
     or existing.snapshot_payload is distinct from p_snapshot_payload
     or existing.payload_hash is distinct from p_payload_hash
     or existing.created_at is distinct from p_created_at then
    raise exception 'Cafe Pulse retry changed immutable history'
      using errcode = '23505';
  end if;

  update public.cafe_sessions
  set return_intention = p_return_intention
  where id = p_session_id;

  if primary_visit is not null then
    if p_primary_reorder_intention is null then
      delete from public.cafe_sip_intentions
      where visit_id = primary_visit
        and session_id = p_session_id
        and user_id = actor;
    else
      insert into public.cafe_sip_intentions (
        visit_id,
        session_id,
        user_id,
        reorder_intention
      )
      values (
        primary_visit,
        p_session_id,
        actor,
        p_primary_reorder_intention
      )
      on conflict (visit_id) do update
      set reorder_intention = excluded.reorder_intention,
          updated_at = now()
      where public.cafe_sip_intentions.session_id = excluded.session_id
        and public.cafe_sip_intentions.user_id = excluded.user_id;
    end if;
  end if;

  return existing;
end;
$$;

create or replace function public.publish_cafe_session_v1(
  p_session_id uuid,
  p_visibility text,
  p_share_cafe_summary boolean default false,
  p_share_cafe_rating boolean default false,
  p_share_next_move boolean default false,
  p_dimension_ids text[] default '{}',
  p_descriptor_ids text[] default '{}',
  p_ended_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_session public.cafe_sessions%rowtype;
  target_snapshot public.cafe_experience_snapshots%rowtype;
  primary_reorder text;
  next_move text;
  snapshot_found boolean := false;
  snapshot_required boolean := false;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_visibility not in ('private', 'friends', 'everyone') then
    raise exception 'invalid session visibility' using errcode = '22023';
  end if;
  if not public.cafe_dimension_ids_are_valid(
       coalesce(p_dimension_ids, '{}'::text[])
     )
     or not public.cafe_descriptor_ids_are_valid(
       coalesce(p_descriptor_ids, '{}'::text[])
     ) then
    raise exception 'invalid Cafe Pulse public projection'
      using errcode = '22023';
  end if;

  select session.*
  into target_session
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor
  for update;

  if not found or target_session.status = 'abandoned' then
    raise exception 'active cafe session not found' using errcode = '42501';
  end if;
  if target_session.primary_visit_id is null
     or not exists (
       select 1
       from public.visits visit
       where visit.id = target_session.primary_visit_id
         and visit.user_id = actor
         and visit.cafe_session_id = p_session_id
         and visit.upload_state = 'complete'
     ) then
    raise exception 'a completed primary sip is required before publishing'
      using errcode = '23514';
  end if;

  update public.cafe_sessions
  set visibility = p_visibility,
      status = 'complete',
      ended_at = case
        when status = 'complete' and ended_at is not null then ended_at
        else greatest(
          started_at,
          coalesce(p_ended_at, now())
        )
      end
  where id = p_session_id
  returning * into target_session;

  update public.visits
  set visibility = p_visibility
  where cafe_session_id = p_session_id
    and user_id = actor;

  if p_share_cafe_summary
     and p_visibility <> 'private'
     and (
       p_share_cafe_rating
       or p_share_next_move
       or cardinality(coalesce(p_dimension_ids, '{}'::text[])) > 0
       or cardinality(coalesce(p_descriptor_ids, '{}'::text[])) > 0
     ) then
    select snapshot.*
    into target_snapshot
    from public.cafe_experience_snapshots snapshot
    where snapshot.session_id = p_session_id
      and snapshot.user_id = actor;

    snapshot_found := found;
    snapshot_required :=
      p_share_cafe_rating
      or cardinality(coalesce(p_dimension_ids, '{}'::text[])) > 0
      or cardinality(coalesce(p_descriptor_ids, '{}'::text[])) > 0;

    if snapshot_required and not snapshot_found then
      raise exception 'cafe stars and observations require a Cafe Pulse snapshot'
        using errcode = '23514';
    end if;
    if p_share_cafe_rating and target_snapshot.cafe_rating is null then
      raise exception 'sharing cafe stars requires a cafe rating'
        using errcode = '23514';
    end if;

    select intention.reorder_intention
    into primary_reorder
    from public.cafe_sip_intentions intention
    where intention.visit_id = target_session.primary_visit_id
      and intention.user_id = actor;

    next_move := public.derive_cafe_next_move(
      target_session.return_intention,
      primary_reorder
    );

    insert into public.cafe_experience_public_projections (
      session_id,
      snapshot_id,
      primary_visit_id,
      user_id,
      cafe_id,
      schema_version,
      includes_cafe_rating,
      includes_next_move,
      cafe_rating,
      next_move,
      dimension_ids,
      descriptor_ids
    )
    values (
      p_session_id,
      target_snapshot.snapshot_id,
      target_session.primary_visit_id,
      actor,
      target_session.cafe_id,
      coalesce(target_snapshot.schema_version, 1),
      p_share_cafe_rating,
      p_share_next_move,
      case when p_share_cafe_rating then target_snapshot.cafe_rating end,
      case when p_share_next_move then next_move end,
      coalesce(p_dimension_ids, '{}'::text[]),
      coalesce(p_descriptor_ids, '{}'::text[])
    )
    on conflict (session_id) do update
    set snapshot_id = excluded.snapshot_id,
        primary_visit_id = excluded.primary_visit_id,
        schema_version = excluded.schema_version,
        includes_cafe_rating = excluded.includes_cafe_rating,
        includes_next_move = excluded.includes_next_move,
        cafe_rating = excluded.cafe_rating,
        next_move = excluded.next_move,
        dimension_ids = excluded.dimension_ids,
        descriptor_ids = excluded.descriptor_ids,
        updated_at = now()
    where public.cafe_experience_public_projections.user_id =
      excluded.user_id;
  else
    delete from public.cafe_experience_public_projections
    where session_id = p_session_id
      and user_id = actor;
  end if;

  return jsonb_build_object(
    'session_id', target_session.id,
    'status', target_session.status,
    'visibility', target_session.visibility,
    'primary_visit_id', target_session.primary_visit_id,
    'cafe_summary_shared',
      p_share_cafe_summary
      and p_visibility <> 'private'
      and (
        p_share_cafe_rating
        or p_share_next_move
        or cardinality(coalesce(p_dimension_ids, '{}'::text[])) > 0
        or cardinality(coalesce(p_descriptor_ids, '{}'::text[])) > 0
      ),
    'cafe_rating_shared',
      p_share_cafe_summary
      and p_visibility <> 'private'
      and p_share_cafe_rating,
    'next_move_shared',
      p_share_cafe_summary
      and p_visibility <> 'private'
      and p_share_next_move
  );
end;
$$;

create or replace function public.append_cafe_session_sip_v1(
  p_session_id uuid,
  p_visit_id uuid,
  p_order smallint,
  p_reorder_intention text default null
)
returns public.visits
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_session public.cafe_sessions%rowtype;
  target_visit public.visits%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_order is null or p_order <= 0 then
    raise exception 'secondary sip order must be positive'
      using errcode = '22023';
  end if;
  if p_reorder_intention is not null
     and p_reorder_intention not in ('yes', 'maybe', 'no') then
    raise exception 'invalid reorder intention' using errcode = '22023';
  end if;

  select session.*
  into target_session
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor
  for update;

  if not found or target_session.status <> 'complete'
     or target_session.primary_visit_id is null then
    raise exception 'completed cafe session not found'
      using errcode = '42501';
  end if;

  select visit.*
  into target_visit
  from public.visits visit
  where visit.id = p_visit_id
    and visit.user_id = actor
  for update;

  if not found
     or target_visit.upload_state <> 'complete'
     or target_visit.cafe_id is distinct from target_session.cafe_id
     or lower(btrim(target_visit.context_type)) is distinct from 'cafe' then
    raise exception 'completed sip does not belong to this cafe session'
      using errcode = '23514';
  end if;
  if target_visit.cafe_session_id is not null
     and target_visit.cafe_session_id <> p_session_id then
    raise exception 'sip already belongs to another cafe session'
      using errcode = '23505';
  end if;
  if target_visit.cafe_session_id = p_session_id
     and target_visit.cafe_session_role = 'primary' then
    raise exception 'the primary sip cannot be appended as a secondary sip'
      using errcode = '23514';
  end if;
  if exists (
    select 1
    from public.visits occupied
    where occupied.cafe_session_id = p_session_id
      and occupied.cafe_session_order = p_order
      and occupied.id <> p_visit_id
  ) then
    raise exception 'session order is already occupied' using errcode = '23505';
  end if;

  update public.visits
  set cafe_session_id = p_session_id,
      cafe_session_order = p_order,
      cafe_session_role = 'secondary',
      visibility = target_session.visibility
  where id = p_visit_id
  returning * into target_visit;

  update public.cafe_sessions
  set ended_at = greatest(
    coalesce(ended_at, started_at),
    target_visit.created_at
  )
  where id = p_session_id;

  if p_reorder_intention is null then
    delete from public.cafe_sip_intentions
    where visit_id = p_visit_id
      and session_id = p_session_id
      and user_id = actor;
  else
    insert into public.cafe_sip_intentions (
      visit_id,
      session_id,
      user_id,
      reorder_intention
    )
    values (
      p_visit_id,
      p_session_id,
      actor,
      p_reorder_intention
    )
    on conflict (visit_id) do update
    set reorder_intention = excluded.reorder_intention,
        updated_at = now()
    where public.cafe_sip_intentions.session_id = excluded.session_id
      and public.cafe_sip_intentions.user_id = excluded.user_id;
  end if;

  return target_visit;
end;
$$;

create or replace function public.set_cafe_session_audience_v1(
  p_session_id uuid,
  p_visibility text
)
returns public.cafe_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.cafe_sessions%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_visibility not in ('private', 'friends', 'everyone') then
    raise exception 'invalid session visibility' using errcode = '22023';
  end if;

  select session.*
  into target
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor
  for update;

  if not found then
    raise exception 'cafe session not found' using errcode = '42501';
  end if;

  update public.cafe_sessions
  set visibility = p_visibility
  where id = p_session_id
  returning * into target;

  update public.visits
  set visibility = p_visibility
  where cafe_session_id = p_session_id
    and user_id = actor;

  if p_visibility = 'private' then
    delete from public.cafe_experience_public_projections
    where session_id = p_session_id
      and user_id = actor;
  end if;

  return target;
end;
$$;

create or replace function public.append_cafe_experience_correction_v1(
  p_correction_id uuid,
  p_snapshot_id uuid,
  p_target_id text,
  p_reason text,
  p_metadata jsonb default '{}'::jsonb
)
returns public.cafe_experience_corrections
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.cafe_experience_corrections%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  insert into public.cafe_experience_corrections (
    id,
    user_id,
    snapshot_id,
    target_id,
    reason,
    metadata
  )
  values (
    p_correction_id,
    actor,
    p_snapshot_id,
    p_target_id,
    p_reason,
    coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict (id) do nothing;

  select correction.*
  into target
  from public.cafe_experience_corrections correction
  where correction.id = p_correction_id
    and correction.user_id = actor;

  if not found then
    raise exception 'Cafe Pulse correction is unavailable'
      using errcode = '42501';
  end if;
  if target.snapshot_id <> p_snapshot_id
     or target.target_id <> p_target_id
     or target.reason <> p_reason
     or target.metadata <> coalesce(p_metadata, '{}'::jsonb) then
    raise exception 'correction retry changed append-only history'
      using errcode = '23505';
  end if;

  return target;
end;
$$;

create or replace function public.set_cafe_experience_signal_owner_state_v1(
  p_signal_id uuid,
  p_owner_state text,
  p_owner_label text default null
)
returns public.cafe_experience_signals
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.cafe_experience_signals%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_owner_state not in ('active', 'dismissed', 'corrected') then
    raise exception 'invalid signal owner state' using errcode = '22023';
  end if;

  update public.cafe_experience_signals
  set owner_state = p_owner_state,
      owner_label = nullif(btrim(p_owner_label), '')
  where id = p_signal_id
    and user_id = actor
  returning * into target;

  if not found then
    raise exception 'cafe experience signal not found'
      using errcode = '42501';
  end if;

  return target;
end;
$$;

create or replace function public.abandon_cafe_session_v1(
  p_session_id uuid
)
returns public.cafe_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.cafe_sessions%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select session.*
  into target
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor
  for update;

  if not found then
    raise exception 'cafe session not found' using errcode = '42501';
  end if;
  if target.status = 'abandoned' then
    return target;
  end if;
  if exists (
    select 1
    from public.visits visit
    where visit.cafe_session_id = p_session_id
      and visit.user_id = actor
      and visit.upload_state = 'complete'
  ) then
    raise exception 'a session with a completed sip cannot be abandoned'
      using errcode = '55000';
  end if;

  update public.cafe_sessions
  set status = 'abandoned',
      ended_at = greatest(started_at, now())
  where id = p_session_id
    and user_id = actor
  returning * into target;

  return target;
end;
$$;

create or replace function public.delete_cafe_session_sip_v1(
  p_session_id uuid,
  p_visit_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_session public.cafe_sessions%rowtype;
  remaining_primary uuid;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select session.*
  into target_session
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor
  for update;

  if not found then
    return jsonb_build_object(
      'session_id', p_session_id,
      'deleted_visit_id', p_visit_id,
      'already_absent', true,
      'session_deleted', true,
      'primary_visit_id', null
    );
  end if;

  delete from public.visits
  where id = p_visit_id
    and cafe_session_id = p_session_id
    and user_id = actor;
  if not found then
    return jsonb_build_object(
      'session_id', p_session_id,
      'deleted_visit_id', p_visit_id,
      'already_absent', true,
      'session_deleted', false,
      'primary_visit_id', target_session.primary_visit_id
    );
  end if;

  select session.primary_visit_id
  into remaining_primary
  from public.cafe_sessions session
  where session.id = p_session_id
    and session.user_id = actor;

  return jsonb_build_object(
    'session_id', p_session_id,
    'deleted_visit_id', p_visit_id,
    'already_absent', false,
    'session_deleted', not found,
    'primary_visit_id', remaining_primary
  );
end;
$$;

create or replace function public.get_cafe_session_summary_v1(
  p_session_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  is_owner boolean;
  visible_sip_count integer;
  target_session public.cafe_sessions%rowtype;
  projection public.cafe_experience_public_projections%rowtype;
  primary_visit uuid;
  rating numeric;
  primary_next_move text;
  sips jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select count(*)
  into visible_sip_count
  from public.visits visit
  where visit.cafe_session_id = p_session_id;

  if visible_sip_count = 0 then
    raise exception 'visible cafe session not found' using errcode = '42501';
  end if;

  select session.*
  into target_session
  from public.cafe_sessions session
  where session.id = p_session_id;
  is_owner := found;

  select public_projection.*
  into projection
  from public.cafe_experience_public_projections public_projection
  where public_projection.session_id = p_session_id;

  primary_visit := coalesce(
    target_session.primary_visit_id,
    projection.primary_visit_id,
    (
      select visit.id
      from public.visits visit
      where visit.cafe_session_id = p_session_id
        and visit.cafe_session_role = 'primary'
      order by visit.cafe_session_order, visit.id
      limit 1
    )
  );

  if is_owner then
    select snapshot.cafe_rating
    into rating
    from public.cafe_experience_snapshots snapshot
    where snapshot.session_id = p_session_id;

    primary_next_move := public.derive_cafe_next_move(
      target_session.return_intention,
      (
        select intention.reorder_intention
        from public.cafe_sip_intentions intention
        where intention.visit_id = primary_visit
      )
    );
  else
    rating := projection.cafe_rating;
    primary_next_move := projection.next_move;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'visit_id', visit.id,
        'order', visit.cafe_session_order,
        'role', visit.cafe_session_role,
        'drink_type', visit.drink_type,
        'drink_subtype', visit.drink_subtype,
        'sip_rating', visit.overall_score,
        'caption', visit.caption,
        'poster_photo_url', visit.poster_photo_url,
        'created_at', visit.created_at,
        'next_move',
          case
            when is_owner then public.derive_cafe_next_move(
              target_session.return_intention,
              intention.reorder_intention
            )
            when visit.id = projection.primary_visit_id
              then projection.next_move
            else null
          end
      )
      order by visit.cafe_session_order, visit.created_at, visit.id
    ),
    '[]'::jsonb
  )
  into sips
  from public.visits visit
  left join public.cafe_sip_intentions intention
    on intention.visit_id = visit.id
  where visit.cafe_session_id = p_session_id;

  return jsonb_build_object(
    'schema_version', 1,
    'session_id', p_session_id,
    'cafe_id', coalesce(
      target_session.cafe_id,
      projection.cafe_id,
      (
        select visit.cafe_id
        from public.visits visit
        where visit.cafe_session_id = p_session_id
        limit 1
      )
    ),
    'primary_visit_id', primary_visit,
    'sip_count', visible_sip_count,
    'cafe_rating', rating,
    'next_move', primary_next_move,
    'status', case when is_owner then target_session.status else 'complete' end,
    'sips', sips
  );
end;
$$;

create or replace function public.get_cafe_experience_summary_v1(
  p_cafe_id uuid,
  p_scope text default 'personal'
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  session_count bigint := 0;
  rated_session_count bigint := 0;
  contributor_count bigint := 0;
  average_rating numeric;
  latest_next_move text;
  relationship_stage text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_cafe_id is null then
    raise exception 'cafe identifier is required' using errcode = '22023';
  end if;
  if p_scope not in ('personal', 'friends', 'community') then
    raise exception 'invalid cafe summary scope' using errcode = '22023';
  end if;

  if p_scope = 'personal' then
    select
      count(*)::bigint,
      count(snapshot.cafe_rating)::bigint,
      avg(snapshot.cafe_rating),
      count(distinct session.user_id)::bigint
    into
      session_count,
      rated_session_count,
      average_rating,
      contributor_count
    from public.cafe_sessions session
    left join public.cafe_experience_snapshots snapshot
      on snapshot.session_id = session.id
    where session.user_id = actor
      and session.cafe_id = p_cafe_id
      and (
        session.status = 'complete'
        or (
          session.status = 'active'
          and exists (
            select 1
            from public.visits primary_sip
            where primary_sip.id = session.primary_visit_id
              and primary_sip.user_id = actor
              and primary_sip.cafe_session_id = session.id
              and primary_sip.upload_state = 'complete'
          )
        )
      );

    select public.derive_cafe_next_move(
      session.return_intention,
      intention.reorder_intention
    )
    into latest_next_move
    from public.cafe_sessions session
    left join public.cafe_sip_intentions intention
      on intention.visit_id = session.primary_visit_id
    where session.user_id = actor
      and session.cafe_id = p_cafe_id
      and (
        session.status = 'complete'
        or (
          session.status = 'active'
          and exists (
            select 1
            from public.visits primary_sip
            where primary_sip.id = session.primary_visit_id
              and primary_sip.user_id = actor
              and primary_sip.cafe_session_id = session.id
              and primary_sip.upload_state = 'complete'
          )
        )
      )
    order by session.started_at desc, session.id desc
    limit 1;

    relationship_stage := case
      when rated_session_count = 1 then 'first_impression'
      when rated_session_count = 2 then 'emerging_view'
      when rated_session_count >= 3 then 'trend'
      else null
    end;
  elsif p_scope = 'friends' then
    with eligible as (
      select projection.*
      from public.cafe_experience_public_projections projection
      where projection.cafe_id = p_cafe_id
        and projection.includes_cafe_rating
        and projection.cafe_rating is not null
        and projection.user_id <> actor
        and public.is_confirmed_friend(actor, projection.user_id)
    ), per_user as (
      select
        eligible.user_id,
        avg(eligible.cafe_rating) user_average,
        count(*) user_sessions
      from eligible
      group by eligible.user_id
    )
    select
      coalesce(sum(per_user.user_sessions), 0)::bigint,
      coalesce(sum(per_user.user_sessions), 0)::bigint,
      avg(per_user.user_average),
      count(*)::bigint
    into
      session_count,
      rated_session_count,
      average_rating,
      contributor_count
    from per_user;
  else
    with eligible as (
      select projection.*
      from public.cafe_experience_public_projections projection
      join public.visits visit
        on visit.id = projection.primary_visit_id
      where projection.cafe_id = p_cafe_id
        and projection.includes_cafe_rating
        and projection.cafe_rating is not null
        and visit.visibility = 'everyone'
        and visit.upload_state = 'complete'
    ), per_user as (
      select
        eligible.user_id,
        avg(eligible.cafe_rating) user_average,
        count(*) user_sessions
      from eligible
      group by eligible.user_id
    ), aggregate as (
      select
        coalesce(sum(per_user.user_sessions), 0)::bigint sessions,
        avg(per_user.user_average) rating,
        count(*)::bigint contributors
      from per_user
    )
    select
      aggregate.sessions,
      aggregate.sessions,
      case
        when aggregate.contributors >= 3 and aggregate.sessions >= 5
          then aggregate.rating
        else null
      end,
      aggregate.contributors
    into
      session_count,
      rated_session_count,
      average_rating,
      contributor_count
    from aggregate;
  end if;

  return jsonb_build_object(
    'schema_version', 1,
    'cafe_id', p_cafe_id,
    'scope', p_scope,
    'physical_session_count', coalesce(session_count, 0),
    'rated_session_count', coalesce(rated_session_count, 0),
    'contributor_count', coalesce(contributor_count, 0),
    'average_cafe_rating', average_rating,
    'latest_next_move', latest_next_move,
    'relationship_stage', relationship_stage,
    'community_threshold_met',
      case
        when p_scope = 'community'
          then coalesce(contributor_count, 0) >= 3
            and coalesce(rated_session_count, 0) >= 5
        else true
      end
  );
end;
$$;

create or replace function public.get_cafe_experience_summaries_v1(
  p_cafe_ids uuid[],
  p_scope text default 'personal'
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_cafe_ids is null or cardinality(p_cafe_ids) > 100 then
    raise exception 'batch cafe summaries require at most 100 cafe identifiers'
      using errcode = '22023';
  end if;
  if array_position(p_cafe_ids, null) is not null then
    raise exception 'batch cafe identifiers cannot contain null'
      using errcode = '22023';
  end if;
  if p_scope not in ('personal', 'friends', 'community') then
    raise exception 'invalid cafe summary scope' using errcode = '22023';
  end if;

  select coalesce(
    jsonb_agg(
      public.get_cafe_experience_summary_v1(
        requested.cafe_id,
        p_scope
      )
      order by requested.ordinality
    ),
    '[]'::jsonb
  )
  into result
  from unnest(p_cafe_ids) with ordinality
    requested(cafe_id, ordinality);

  return result;
end;
$$;

create or replace function public.build_owner_data_export_v2()
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  base_export jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  base_export := public.build_owner_data_export();

  return base_export
    || jsonb_build_object(
      'schema_version', 2,
      'cafe_sessions', coalesce((
        select jsonb_agg(
          to_jsonb(session)
          order by session.started_at, session.id
        )
        from public.cafe_sessions session
        where session.user_id = actor
      ), '[]'::jsonb),
      'cafe_sip_intentions', coalesce((
        select jsonb_agg(
          to_jsonb(intention)
          order by intention.created_at, intention.visit_id
        )
        from public.cafe_sip_intentions intention
        where intention.user_id = actor
      ), '[]'::jsonb),
      'cafe_experience_snapshots', coalesce((
        select jsonb_agg(
          to_jsonb(snapshot)
          order by snapshot.created_at, snapshot.session_id
        )
        from public.cafe_experience_snapshots snapshot
        where snapshot.user_id = actor
      ), '[]'::jsonb),
      'cafe_experience_corrections', coalesce((
        select jsonb_agg(
          to_jsonb(correction)
          order by correction.created_at, correction.id
        )
        from public.cafe_experience_corrections correction
        where correction.user_id = actor
      ), '[]'::jsonb),
      'cafe_experience_public_projections', coalesce((
        select jsonb_agg(
          to_jsonb(projection)
          order by projection.created_at, projection.session_id
        )
        from public.cafe_experience_public_projections projection
        where projection.user_id = actor
      ), '[]'::jsonb),
      'cafe_experience_signals', coalesce((
        select jsonb_agg(
          to_jsonb(signal)
          order by signal.updated_at, signal.id
        )
        from public.cafe_experience_signals signal
        where signal.user_id = actor
      ), '[]'::jsonb),
      'cafe_experience_signal_evidence', coalesce((
        select jsonb_agg(
          to_jsonb(evidence)
          order by evidence.created_at,
            evidence.signal_id,
            evidence.session_id
        )
        from public.cafe_experience_signal_evidence evidence
        where evidence.user_id = actor
      ), '[]'::jsonb)
    );
end;
$$;

revoke all on function public.get_cafe_sessions_capability_v1()
  from public, anon, authenticated;
revoke all on function public.ensure_cafe_session_v1(
  uuid,
  uuid,
  timestamptz,
  text,
  text[],
  text
) from public, anon, authenticated;
revoke all on function public.attach_visit_to_cafe_session_v1(
  uuid,
  uuid,
  smallint,
  text
) from public, anon, authenticated;
revoke all on function public.finalize_cafe_session_sip_v1(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.set_cafe_session_intentions_v1(
  uuid,
  uuid,
  text,
  text
) from public, anon, authenticated;
revoke all on function public.record_cafe_experience_v1(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  numeric,
  text,
  jsonb,
  text,
  text,
  text,
  jsonb,
  text,
  timestamptz
) from public, anon, authenticated;
revoke all on function public.publish_cafe_session_v1(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  text[],
  text[],
  timestamptz
) from public, anon, authenticated;
revoke all on function public.append_cafe_session_sip_v1(
  uuid,
  uuid,
  smallint,
  text
) from public, anon, authenticated;
revoke all on function public.set_cafe_session_audience_v1(uuid, text)
  from public, anon, authenticated;
revoke all on function public.append_cafe_experience_correction_v1(
  uuid,
  uuid,
  text,
  text,
  jsonb
) from public, anon, authenticated;
revoke all on function public.set_cafe_experience_signal_owner_state_v1(
  uuid,
  text,
  text
) from public, anon, authenticated;
revoke all on function public.abandon_cafe_session_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.delete_cafe_session_sip_v1(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.get_cafe_session_summary_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.get_cafe_experience_summary_v1(uuid, text)
  from public, anon, authenticated;
revoke all on function public.get_cafe_experience_summaries_v1(uuid[], text)
  from public, anon, authenticated;
revoke all on function public.build_owner_data_export_v2()
  from public, anon, authenticated;

grant execute on function public.get_cafe_sessions_capability_v1()
  to authenticated;
grant execute on function public.ensure_cafe_session_v1(
  uuid,
  uuid,
  timestamptz,
  text,
  text[],
  text
) to authenticated;
grant execute on function public.attach_visit_to_cafe_session_v1(
  uuid,
  uuid,
  smallint,
  text
) to authenticated;
grant execute on function public.finalize_cafe_session_sip_v1(uuid, uuid)
  to authenticated;
grant execute on function public.set_cafe_session_intentions_v1(
  uuid,
  uuid,
  text,
  text
) to authenticated;
grant execute on function public.record_cafe_experience_v1(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  numeric,
  text,
  jsonb,
  text,
  text,
  text,
  jsonb,
  text,
  timestamptz
) to authenticated;
grant execute on function public.publish_cafe_session_v1(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  text[],
  text[],
  timestamptz
) to authenticated;
grant execute on function public.append_cafe_session_sip_v1(
  uuid,
  uuid,
  smallint,
  text
) to authenticated;
grant execute on function public.set_cafe_session_audience_v1(uuid, text)
  to authenticated;
grant execute on function public.append_cafe_experience_correction_v1(
  uuid,
  uuid,
  text,
  text,
  jsonb
) to authenticated;
grant execute on function public.set_cafe_experience_signal_owner_state_v1(
  uuid,
  text,
  text
) to authenticated;
grant execute on function public.abandon_cafe_session_v1(uuid)
  to authenticated;
grant execute on function public.delete_cafe_session_sip_v1(uuid, uuid)
  to authenticated;
grant execute on function public.get_cafe_session_summary_v1(uuid)
  to authenticated;
grant execute on function public.get_cafe_experience_summary_v1(uuid, text)
  to authenticated;
grant execute on function public.get_cafe_experience_summaries_v1(
  uuid[],
  text
) to authenticated;
grant execute on function public.build_owner_data_export_v2()
  to authenticated;

-- A Cafe Session is one feed story. Secondary sips remain available from the
-- session detail and drink history, but cannot become duplicate feed roots.
create or replace function public.ranked_feed(
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
  with input as (
    select auth.uid() viewer
  ), base as (
    select
      visit.*,
      author.display_name,
      author.username,
      author.avatar_url,
      cafe.name cafe_name,
      cafe.latitude,
      cafe.longitude,
      (select count(*) from public.likes likes where likes.visit_id = visit.id) likes,
      (select count(*) from public.comments comments where comments.visit_id = visit.id) comments,
      case
        when visit.user_id = input.viewer then .85
        when private.confirmed_friends(input.viewer, visit.user_id) then 1.0
        else .15
      end trust,
      exp(-extract(epoch from (now() - visit.created_at)) / 86400 / 12) recency,
      case
        when p_latitude between -90 and 90 and p_longitude between -180 and 180
             and cafe.latitude is not null and cafe.longitude is not null then
          greatest(0, 1 - (
            6371 * 2 * asin(sqrt(
              power(sin(radians(cafe.latitude - p_latitude) / 2), 2)
              + cos(radians(p_latitude)) * cos(radians(cafe.latitude))
              * power(sin(radians(cafe.longitude - p_longitude) / 2), 2)
            ))
          ) / 50)
      end geo,
      exists (
        select 1
        from public.user_cafe_states saved
        where saved.user_id = input.viewer
          and saved.cafe_id = visit.cafe_id
          and (saved.is_favorite or saved.want_to_try)
      ) saved_match,
      exists (
        select 1
        from public.visits mine
        where mine.user_id = input.viewer
          and mine.upload_state = 'complete'
          and coalesce(mine.drink_subtype, mine.drink_type_custom, mine.drink_type)
              = coalesce(visit.drink_subtype, visit.drink_type_custom, visit.drink_type)
      ) journal_affinity,
      visit.user_id <> input.viewer and exists (
        select 1
        from public.taste_signals mine
        join public.taste_signals theirs
          on theirs.signal_type = mine.signal_type
         and theirs.attribute = mine.attribute
        where mine.user_id = input.viewer
          and theirs.user_id = visit.user_id
          and mine.owner_state <> 'dismissed'
          and theirs.owner_state <> 'dismissed'
          and mine.support_count >= 3
          and theirs.support_count >= 3
      ) taste_match
    from public.visits visit
    cross join input
    join public.users author on author.id = visit.user_id
    left join public.cafes cafe on cafe.id = visit.cafe_id
    where input.viewer is not null
      and visit.upload_state = 'complete'
      and (
        visit.cafe_session_id is null
        or visit.cafe_session_role = 'primary'
      )
      and private.can_view_visit_as(visit.id, input.viewer)
      and case p_scope
        when 'friends' then visit.user_id = input.viewer
          or (visit.visibility in ('friends', 'everyone') and private.confirmed_friends(input.viewer, visit.user_id))
        when 'everyone' then visit.visibility = 'everyone'
        when 'ranked' then true
        else false
      end
  ), diversified as (
    select base.*,
      row_number() over (partition by base.user_id order by base.created_at desc, base.id desc) author_rank,
      row_number() over (partition by base.cafe_id order by base.created_at desc, base.id desc) cafe_rank,
      row_number() over (
        partition by coalesce(base.drink_subtype, base.drink_type_custom, base.drink_type)
        order by base.created_at desc, base.id desc
      ) drink_rank
    from base
  ), scored as (
    select diversified.*,
      greatest(0,
        .35 * diversified.recency
        + .25 * diversified.trust
        + .15 * (case when diversified.taste_match then 1 else 0 end)
        + .10 * greatest(case when diversified.saved_match then 1 else 0 end, coalesce(diversified.geo, 0))
        + .10 * (case when diversified.journal_affinity then 1 else 0 end)
        + .05 * least((diversified.likes + diversified.comments * 2)::double precision / 10, 1)
        - least(greatest(diversified.author_rank - 1, 0), 2) * .035
        - least(greatest(diversified.cafe_rank - 1, 0), 2) * .020
        - least(greatest(diversified.drink_rank - 1, 0), 2) * .015
      ) score
    from diversified
  )
  select
    scored.id, scored.user_id, scored.cafe_id, scored.caption,
    coalesce(scored.drink_subtype, scored.drink_type_custom, scored.drink_type),
    scored.overall_score, scored.poster_photo_url, scored.created_at,
    scored.display_name, scored.username, scored.avatar_url, scored.cafe_name,
    scored.likes, scored.comments,
    case when p_scope = 'ranked' then scored.score else 1::double precision end,
    case
      when p_scope <> 'ranked' then null
      when scored.user_id <> (select viewer from input) and scored.trust = 1 then 'A recent sip from your friend'
      when scored.taste_match then 'Matches patterns in your tasting passport'
      when scored.saved_match then 'From a cafe you saved'
      when coalesce(scored.geo, 0) >= .65 then 'A sip from a cafe near you'
      when scored.journal_affinity then 'Inspired by drinks in your journal'
      else 'A recent sip from the Mugshot community'
    end,
    case
      when p_scope <> 'ranked' then null
      when scored.user_id <> (select viewer from input) and scored.trust = 1 then 'friend_activity'
      when scored.taste_match then 'taste_match'
      when scored.saved_match then 'saved_cafe'
      when coalesce(scored.geo, 0) >= .65 then 'nearby_cafe'
      when scored.journal_affinity then 'journal_evidence'
      else 'recent_community'
    end
  from scored
  where case
    when p_scope = 'ranked' then
      p_after_score is null
      or (scored.score, scored.created_at, scored.id) < (p_after_score, p_after_created_at, p_after_id)
    else
      p_after_created_at is null
      or (scored.created_at, scored.id) < (p_after_created_at, p_after_id)
  end
  order by
    case when p_scope = 'ranked' then scored.score end desc,
    scored.created_at desc,
    scored.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

revoke all on function public.ranked_feed(
  text,
  double precision,
  double precision,
  integer,
  double precision,
  timestamptz,
  uuid
) from public, anon, authenticated;
grant execute on function public.ranked_feed(
  text,
  double precision,
  double precision,
  integer,
  double precision,
  timestamptz,
  uuid
) to authenticated;
