-- People discovery v1. Private identity material never enters the exposed
-- schema; all client access is caller-bound and explicitly granted below.

create table private.discovery_preferences (
  user_id uuid primary key references public.users(id) on delete cascade,
  email_discoverable boolean not null default false,
  suggestions_enabled boolean not null default false,
  mutual_explanations_enabled boolean not null default false,
  consent_version integer,
  consented_at timestamptz,
  version bigint not null default 1,
  updated_at timestamptz not null default now()
);

create table private.discovery_identifiers (
  user_id uuid not null references public.users(id) on delete cascade,
  kind text not null check (kind in ('email')),
  digest text not null check (digest ~ '^[a-f0-9]{64}$'),
  key_version integer not null check (key_version > 0),
  verified_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (user_id, kind),
  unique (kind, digest, key_version)
);

create table private.discovery_keys (
  purpose text not null,
  key_version integer not null check (key_version > 0),
  key_material bytea not null check (octet_length(key_material) = 32),
  created_at timestamptz not null default now(),
  retired_at timestamptz,
  primary key (purpose, key_version)
);

create table private.discovery_capabilities (
  capability text primary key check (capability in (
    'contact_matching','invitations','suggestions','first_week_prompt'
  )),
  enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

insert into private.discovery_capabilities(capability,enabled) values
  ('contact_matching',false),('invitations',false),
  ('suggestions',false),('first_week_prompt',false);

insert into private.discovery_keys(purpose, key_version, key_material)
values ('friend_invite', 1, extensions.gen_random_bytes(32));

create table private.discovery_suppressions (
  viewer_id uuid not null references public.users(id) on delete cascade,
  candidate_id uuid not null references public.users(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '90 days'),
  created_at timestamptz not null default now(),
  primary key (viewer_id, candidate_id),
  check (viewer_id <> candidate_id)
);

create table private.friend_invites (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  request_nonce uuid not null,
  token_digest text not null unique check (token_digest ~ '^[a-f0-9]{64}$'),
  code_digest text not null unique check (code_digest ~ '^[a-f0-9]{64}$'),
  bearer_seed bytea not null check (octet_length(bearer_seed) = 32),
  key_version integer not null default 1 check (key_version > 0),
  code text not null check (code ~ '^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days'),
  revoked_at timestamptz,
  unique (owner_id, request_nonce)
);

create table private.friend_discovery_state (
  user_id uuid primary key references public.users(id) on delete cascade,
  prompt_consumed_at timestamptz,
  prompt_outcome text check (prompt_outcome in ('shown', 'dismissed', 'opened')),
  first_friend_at timestamptz,
  first_friend_source text check (first_friend_source in (
    'search', 'suggestion', 'contacts', 'profile_link', 'invite_link',
    'invite_code', 'shared_post', 'shared_list', 'first_week', 'legacy'
  )),
  updated_at timestamptz not null default now()
);

create table private.friend_request_attributions (
  request_id uuid primary key references public.friend_requests(id) on delete cascade,
  actor_id uuid not null references public.users(id) on delete cascade,
  source text not null check (source in (
    'search', 'suggestion', 'contacts', 'profile_link', 'invite_link',
    'invite_code', 'shared_post', 'shared_list', 'first_week'
  )),
  invite_id uuid references private.friend_invites(id) on delete set null,
  request_nonce uuid not null,
  created_at timestamptz not null default now(),
  unique (actor_id, request_nonce)
);

create table private.contact_match_budgets (
  user_id uuid not null references public.users(id) on delete cascade,
  window_start timestamptz not null,
  calls integer not null default 0 check (calls >= 0),
  addresses integer not null default 0 check (addresses >= 0),
  primary key (user_id, window_start)
);

create table private.discovery_action_budgets (
  user_id uuid not null references public.users(id) on delete cascade,
  action text not null check (action in ('search','invite_create','invite_code_failure','friend_request')),
  window_start timestamptz not null,
  attempts integer not null default 0 check (attempts >= 0),
  primary key (user_id, action, window_start)
);

alter table private.discovery_preferences enable row level security;
alter table private.discovery_keys enable row level security;
alter table private.discovery_capabilities enable row level security;
alter table private.discovery_identifiers enable row level security;
alter table private.discovery_suppressions enable row level security;
alter table private.friend_invites enable row level security;
alter table private.friend_discovery_state enable row level security;
alter table private.friend_request_attributions enable row level security;
alter table private.contact_match_budgets enable row level security;
alter table private.discovery_action_budgets enable row level security;

revoke all on private.discovery_preferences, private.discovery_identifiers,
  private.discovery_keys,
  private.discovery_capabilities,
  private.discovery_suppressions, private.friend_invites,
  private.friend_discovery_state, private.friend_request_attributions,
  private.contact_match_budgets, private.discovery_action_budgets
  from public, anon, authenticated;

create index discovery_suppressions_expiry_idx
  on private.discovery_suppressions (viewer_id, expires_at, candidate_id);
create index friend_invites_owner_expiry_idx
  on private.friend_invites (owner_id, expires_at desc);
create index friend_invites_cleanup_idx
  on private.friend_invites (expires_at) where revoked_at is null;
create index contact_match_budgets_cleanup_idx
  on private.contact_match_budgets (window_start);
create index discovery_action_budgets_cleanup_idx
  on private.discovery_action_budgets (window_start);

create function private.consume_discovery_action_v1(
  p_user_id uuid, p_action text, p_max_attempts integer, p_window interval
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare bucket timestamptz; current_attempts integer;
begin
  if p_user_id is null or p_action not in ('search','invite_create','invite_code_failure','friend_request')
     or p_max_attempts < 1 or p_window <= interval '0 seconds' then
    return false;
  end if;
  bucket := date_bin(p_window, now(), timestamptz '2001-01-01 00:00:00+00');
  delete from private.discovery_action_budgets
    where window_start < now() - interval '2 days';
  insert into private.discovery_action_budgets as budget(
    user_id, action, window_start, attempts
  ) values (p_user_id, p_action, bucket, 1)
  on conflict(user_id, action, window_start) do update
    set attempts = budget.attempts + 1
  returning attempts into current_attempts;
  return current_attempts <= p_max_attempts;
end;
$$;
revoke all on function private.consume_discovery_action_v1(uuid,text,integer,interval)
  from public, anon, authenticated;

create function private.discovery_capability_enabled_v1(p_capability text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select enabled from private.discovery_capabilities
    where capability = p_capability),false);
$$;
revoke all on function private.discovery_capability_enabled_v1(text)
  from public, anon, authenticated;

create function public.get_people_discovery_capabilities_v1()
returns table (
  contact_matching boolean, invitations boolean,
  suggestions boolean, first_week_prompt boolean
)
language sql stable security definer set search_path = '' as $$
  select private.discovery_capability_enabled_v1('contact_matching'),
    private.discovery_capability_enabled_v1('invitations'),
    private.discovery_capability_enabled_v1('suggestions'),
    private.discovery_capability_enabled_v1('first_week_prompt');
$$;

create function public.service_people_discovery_enabled_v1(p_capability text)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.discovery_capability_enabled_v1(p_capability);
$$;

create function private.discovery_preferences_for_v1(p_user_id uuid)
returns private.discovery_preferences
language plpgsql stable security definer set search_path = '' as $$
declare result private.discovery_preferences;
begin
  select * into result from private.discovery_preferences where user_id = p_user_id;
  if not found then
    result.user_id := p_user_id;
    result.email_discoverable := false;
    result.suggestions_enabled := false;
    result.mutual_explanations_enabled := false;
    result.version := 0;
  end if;
  return result;
end;
$$;
revoke all on function private.discovery_preferences_for_v1(uuid)
  from public, anon, authenticated;

create function public.get_discovery_preferences_v1()
returns table (
  email_discoverable boolean,
  suggestions_enabled boolean,
  mutual_explanations_enabled boolean,
  consent_version integer,
  version bigint,
  has_discovery_email boolean
)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := auth.uid(); preference private.discovery_preferences;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  preference := private.discovery_preferences_for_v1(actor);
  return query select preference.email_discoverable,
    preference.suggestions_enabled, preference.mutual_explanations_enabled,
    preference.consent_version, preference.version,
    exists(select 1 from private.discovery_identifiers identifier
      where identifier.user_id = actor and identifier.kind = 'email');
end;
$$;

create function public.set_discovery_preferences_v1(
  p_email_discoverable boolean,
  p_suggestions_enabled boolean,
  p_mutual_explanations_enabled boolean,
  p_consent_version integer,
  p_expected_version bigint default null
)
returns table (
  email_discoverable boolean,
  suggestions_enabled boolean,
  mutual_explanations_enabled boolean,
  consent_version integer,
  version bigint,
  has_discovery_email boolean
)
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result private.discovery_preferences;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_consent_version <> 1 then raise exception 'unsupported consent version' using errcode = '22023'; end if;
  insert into private.discovery_preferences as preference (
    user_id, email_discoverable, suggestions_enabled,
    mutual_explanations_enabled, consent_version, consented_at, version, updated_at
  ) values (
    actor, p_email_discoverable, p_suggestions_enabled,
    p_mutual_explanations_enabled, p_consent_version, now(), 1, now()
  ) on conflict (user_id) do update set
    email_discoverable = excluded.email_discoverable,
    suggestions_enabled = excluded.suggestions_enabled,
    mutual_explanations_enabled = excluded.mutual_explanations_enabled,
    consent_version = excluded.consent_version,
    consented_at = now(), version = preference.version + 1, updated_at = now()
  where p_expected_version is null or preference.version = p_expected_version
  returning * into result;
  if not found then raise exception 'discovery preferences changed' using errcode = '40001'; end if;
  if not result.email_discoverable then
    delete from private.discovery_identifiers
      where user_id = actor and kind = 'email';
  end if;
  return query select result.email_discoverable, result.suggestions_enabled,
    result.mutual_explanations_enabled, result.consent_version, result.version,
    exists(select 1 from private.discovery_identifiers identifier
      where identifier.user_id = actor and identifier.kind = 'email');
end;
$$;

create function public.service_set_discovery_email_v1(
  p_user_id uuid, p_digest text, p_key_version integer, p_verified_at timestamptz
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_user_id is null or p_digest !~ '^[a-f0-9]{64}$' or p_key_version <= 0 then
    raise exception 'invalid discovery identifier' using errcode = '22023';
  end if;
  if not exists (
    select 1 from private.discovery_preferences preference
    where preference.user_id = p_user_id and preference.email_discoverable
      and preference.consent_version = 1
  ) then
    delete from private.discovery_identifiers where user_id = p_user_id and kind = 'email';
    return;
  end if;
  insert into private.discovery_identifiers as identifier (
    user_id, kind, digest, key_version, verified_at
  ) values (p_user_id, 'email', p_digest, p_key_version, p_verified_at)
  on conflict (user_id, kind) do update set
    digest = excluded.digest, key_version = excluded.key_version,
    verified_at = excluded.verified_at, created_at = now();
end;
$$;

create function public.service_match_discovery_digests_v1(
  p_actor_id uuid, p_digests text[], p_key_version integer
)
returns table (
  digest text, id uuid, display_name text, username text, avatar_url text,
  friendship_state text, mutual_friend_count bigint
)
language sql stable security definer set search_path = '' as $$
  select identifier.digest, profile.id, profile.display_name, profile.username,
    profile.avatar_url,
    case
      when private.confirmed_friends(p_actor_id, profile.id) then 'friends'
      when exists(select 1 from public.friend_requests request
        where request.from_user_id = p_actor_id and request.to_user_id = profile.id
          and request.status = 'pending') then 'outgoing'
      when exists(select 1 from public.friend_requests request
        where request.from_user_id = profile.id and request.to_user_id = p_actor_id
          and request.status = 'pending') then 'incoming'
      else 'none'
    end,
    (select count(*) from public.friends mine join public.friends theirs
      on theirs.user_id = profile.id and theirs.friend_user_id = mine.friend_user_id
      join private.discovery_preferences mutual_preference
        on mutual_preference.user_id = mine.friend_user_id
       and mutual_preference.mutual_explanations_enabled
       where mine.user_id = p_actor_id
        and not private.blocked_between(p_actor_id, mine.friend_user_id))
  from private.discovery_identifiers identifier
  join private.discovery_preferences preference on preference.user_id = identifier.user_id
    and preference.email_discoverable and preference.consent_version = 1
  join public.users profile on profile.id = identifier.user_id
  where p_actor_id is not null and identifier.kind = 'email'
    and identifier.key_version = p_key_version
    and identifier.digest = any(coalesce(p_digests, '{}'::text[]))
    and profile.id <> p_actor_id
    and private.can_view_user_as(profile.id, p_actor_id);
$$;

create function public.consume_contact_match_budget_v1(p_address_count integer)
returns boolean language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); hour_start timestamptz := date_trunc('hour', now());
  current_calls integer; daily_addresses bigint;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_address_count < 1 or p_address_count > 200 then return false; end if;
  delete from private.contact_match_budgets where window_start < now() - interval '2 days';
  insert into private.contact_match_budgets as budget (user_id, window_start, calls, addresses)
    values(actor, hour_start, 1, p_address_count)
    on conflict (user_id, window_start) do update set
      calls = budget.calls + 1, addresses = budget.addresses + excluded.addresses
    returning calls into current_calls;
  select sum(addresses) into daily_addresses from private.contact_match_budgets
    where user_id = actor and window_start >= now() - interval '24 hours';
  return current_calls <= 10 and coalesce(daily_addresses, 0) <= 1000;
end;
$$;

create function public.search_people_v2(
  p_query text, p_limit integer default 20,
  p_after_rank integer default null, p_after_score real default null,
  p_after_username text default null, p_after_id uuid default null
)
returns table (
  id uuid, display_name text, username text, bio text, location text,
  favorite_drink text, avatar_url text, banner_url text,
  friendship_state text, mutual_friend_count bigint,
  rank_bucket integer, match_score real
)
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); normalized text;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  normalized := regexp_replace(trim(coalesce(p_query,'')), '^@', '');
  if length(normalized) < 1 or length(normalized) > 100 then
    raise exception 'invalid search query' using errcode = '22023';
  end if;
  if not private.consume_discovery_action_v1(actor,'search',60,interval '1 hour') then
    raise exception 'search rate limit exceeded' using errcode = 'P0001';
  end if;
  return query select * from public.search_users(
    normalized, least(greatest(p_limit, 1), 20),
    p_after_rank, p_after_score, p_after_username, p_after_id
  );
end;
$$;

create function public.get_people_suggestions_v1(p_limit integer default 10)
returns table (
  id uuid, display_name text, username text, avatar_url text,
  friendship_state text, mutual_friend_count bigint,
  reason text, ranking_version text
)
language sql stable security definer set search_path = '' as $$
  with actor as (select auth.uid() id), candidates as (
    select tag.added_by candidate_id, 0 priority, 'shared_mugshot'::text reason
    from actor join public.visit_companions tag on tag.companion_user_id = actor.id
    where private.can_view_visit_as(tag.visit_id, actor.id)
    union all
    select other.user_id, 1, 'shared_list'
    from actor
    join public.cafe_list_members mine on mine.user_id = actor.id
      and mine.invitation_status = 'accepted'
    join public.cafe_list_members other on other.list_id = mine.list_id
      and other.invitation_status = 'accepted' and other.user_id <> actor.id
    union all
    select theirs.user_id, 2, 'mutual_friends'
    from actor
    join public.friends mine on mine.user_id = actor.id
    join public.friends theirs on theirs.friend_user_id = mine.friend_user_id
      and theirs.user_id <> actor.id
  ), eligible as (
    select candidate.candidate_id, min(candidate.priority) priority,
      (array_agg(candidate.reason order by candidate.priority))[1] reason
    from candidates candidate cross join actor
    join private.discovery_preferences preference
      on preference.user_id = candidate.candidate_id and preference.suggestions_enabled
    where candidate.candidate_id <> actor.id
      and private.discovery_capability_enabled_v1('suggestions')
      and private.can_view_user_as(candidate.candidate_id, actor.id)
      and not private.confirmed_friends(actor.id, candidate.candidate_id)
      and not exists(select 1 from public.friend_requests request
        where request.status = 'pending'
          and least(request.from_user_id, request.to_user_id) = least(actor.id, candidate.candidate_id)
          and greatest(request.from_user_id, request.to_user_id) = greatest(actor.id, candidate.candidate_id))
      and not exists(select 1 from private.discovery_suppressions suppression
        where suppression.viewer_id = actor.id
          and suppression.candidate_id = candidate.candidate_id
          and suppression.expires_at > now())
    group by candidate.candidate_id
  ), ranked as (
    select eligible.*, profile.display_name, profile.username, profile.avatar_url,
      (select count(*) from public.friends mine join public.friends theirs
        on theirs.user_id = eligible.candidate_id
       and theirs.friend_user_id = mine.friend_user_id
       join private.discovery_preferences mutual_preference
        on mutual_preference.user_id = mine.friend_user_id
       and mutual_preference.mutual_explanations_enabled
       where mine.user_id = actor.id
         and not private.blocked_between(actor.id, mine.friend_user_id)) mutual_count
    from eligible join public.users profile on profile.id = eligible.candidate_id
    cross join actor
  )
  select ranked.candidate_id, ranked.display_name, ranked.username, ranked.avatar_url,
    'none'::text, ranked.mutual_count,
    case when ranked.reason = 'mutual_friends' and ranked.mutual_count = 0
      then null else ranked.reason end, 'people_v1'::text
  from ranked where ranked.reason <> 'mutual_friends' or ranked.mutual_count > 0
  order by ranked.priority, ranked.mutual_count desc, ranked.candidate_id
  limit least(greatest(p_limit, 1), 20);
$$;

create function public.dismiss_people_suggestion_v1(p_candidate_id uuid, p_undo boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_candidate_id is null or p_candidate_id = actor then
    raise exception 'invalid suggestion' using errcode = '22023';
  end if;
  if p_undo then
    delete from private.discovery_suppressions
      where viewer_id = actor and candidate_id = p_candidate_id;
  else
    insert into private.discovery_suppressions(viewer_id, candidate_id, expires_at)
      values(actor, p_candidate_id, now() + interval '90 days')
      on conflict (viewer_id, candidate_id) do update set
        expires_at = excluded.expires_at, created_at = now();
  end if;
end;
$$;

create function public.get_people_hub_v1(p_page_size integer default 20)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare page_size integer := least(greatest(p_page_size,1),20);
  incoming jsonb := '[]'::jsonb; outgoing jsonb := '[]'::jsonb;
  friend_rows jsonb := '[]'::jsonb; suggestion_rows jsonb := '[]'::jsonb;
  partial_errors jsonb := '{}'::jsonb;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode='28000'; end if;
  begin
    select coalesce(jsonb_agg(to_jsonb(row_value)),'[]'::jsonb) into incoming
      from public.list_social_connections('incoming',page_size) row_value;
  exception when others then partial_errors := partial_errors || '{"requests":"unavailable"}'::jsonb;
  end;
  begin
    select coalesce(jsonb_agg(to_jsonb(row_value)),'[]'::jsonb) into outgoing
      from public.list_social_connections('outgoing',page_size) row_value;
  exception when others then partial_errors := partial_errors || '{"sent":"unavailable"}'::jsonb;
  end;
  begin
    select coalesce(jsonb_agg(to_jsonb(row_value)),'[]'::jsonb) into friend_rows
      from public.list_social_connections('friends',page_size) row_value;
  exception when others then partial_errors := partial_errors || '{"friends":"unavailable"}'::jsonb;
  end;
  begin
    select coalesce(jsonb_agg(to_jsonb(row_value)),'[]'::jsonb) into suggestion_rows
      from public.get_people_suggestions_v1(page_size) row_value;
  exception when others then partial_errors := partial_errors || '{"suggestions":"unavailable"}'::jsonb;
  end;
  return jsonb_build_object(
    'requests',incoming,'sent',outgoing,'friends',friend_rows,
    'suggestions',suggestion_rows,'partial_errors',partial_errors
  );
end;
$$;

create function private.base32_v1(p_value bytea, p_length integer)
returns text language plpgsql immutable security invoker set search_path = '' as $$
declare alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; result text := '';
  index_value integer; i integer;
begin
  if p_length < 1 or octet_length(p_value) < p_length then return null; end if;
  for i in 0..p_length - 1 loop
    index_value := get_byte(p_value, i) % length(alphabet);
    result := result || substr(alphabet, index_value + 1, 1);
  end loop;
  return result;
end;
$$;
revoke all on function private.base32_v1(bytea,integer) from public, anon, authenticated;

create function private.friend_invite_material_v1(p_seed bytea, p_key_version integer)
returns table (token text, code text)
language plpgsql stable security definer set search_path = '' as $$
declare key_bytes bytea; token_bytes bytea; code_bytes bytea; compact_code text;
begin
  select key_material into key_bytes from private.discovery_keys
    where purpose = 'friend_invite' and key_version = p_key_version
      and retired_at is null;
  if key_bytes is null then
    raise exception 'invite key unavailable' using errcode = '55000';
  end if;
  token_bytes := extensions.hmac(p_seed || convert_to('token-v1','utf8'), key_bytes, 'sha256');
  code_bytes := extensions.hmac(p_seed || convert_to('code-v1','utf8'), key_bytes, 'sha256');
  token := rtrim(translate(encode(token_bytes, 'base64'), '+/', '-_'), '=');
  compact_code := private.base32_v1(code_bytes, 12);
  code := substr(compact_code,1,4)||'-'||substr(compact_code,5,4)||'-'||substr(compact_code,9,4);
  return next;
end;
$$;
revoke all on function private.friend_invite_material_v1(bytea,integer)
  from public, anon, authenticated;

create function public.create_friend_invite_v1(p_request_nonce uuid)
returns table (invite_id uuid, token text, code text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); existing private.friend_invites; seed bytea;
  token_value text; code_value text; material record; attempt integer;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_request_nonce is null then raise exception 'request nonce required' using errcode = '22023'; end if;
  if not private.discovery_capability_enabled_v1('invitations') then
    raise exception 'invitations unavailable' using errcode = '55000';
  end if;
  select * into existing from private.friend_invites
    where owner_id = actor and request_nonce = p_request_nonce for update;
  if found and existing.revoked_at is null and existing.expires_at > now() then
    select * into material from private.friend_invite_material_v1(
      existing.bearer_seed, existing.key_version
    );
    token_value := material.token;
    return query select existing.id, token_value, existing.code, existing.expires_at;
    return;
  end if;
  if not private.consume_discovery_action_v1(actor,'invite_create',20,interval '1 day') then
    raise exception 'invite rate limit exceeded' using errcode = 'P0001';
  end if;
  for attempt in 1..5 loop
    seed := extensions.gen_random_bytes(32);
    select * into material from private.friend_invite_material_v1(seed, 1);
    token_value := material.token;
    code_value := material.code;
    begin
      insert into private.friend_invites(
        owner_id, request_nonce, token_digest, code_digest,
        bearer_seed, key_version, code
      ) values (
        actor, p_request_nonce, encode(extensions.digest(token_value, 'sha256'),'hex'),
        encode(extensions.digest(replace(code_value,'-',''), 'sha256'),'hex'), seed, 1, code_value
      ) returning * into existing;
      return query select existing.id, token_value, existing.code, existing.expires_at;
      return;
    exception when unique_violation then
      select * into existing from private.friend_invites
        where owner_id = actor and request_nonce = p_request_nonce;
      if found and existing.revoked_at is null and existing.expires_at > now() then
        select * into material from private.friend_invite_material_v1(
          existing.bearer_seed, existing.key_version
        );
        return query select existing.id, material.token, existing.code, existing.expires_at;
        return;
      end if;
    end;
  end loop;
  raise exception 'invite collision; retry' using errcode = '40001';
end;
$$;

create function public.revoke_friend_invite_v1(p_invite_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '28000'; end if;
  update private.friend_invites set revoked_at = coalesce(revoked_at, now())
    where id = p_invite_id and owner_id = auth.uid();
  if not found then raise exception 'invite unavailable' using errcode = '42501'; end if;
end;
$$;

create function private.friend_invite_from_secret_v1(p_secret text)
returns private.friend_invites language plpgsql stable security definer set search_path = '' as $$
declare result private.friend_invites; normalized text := upper(replace(trim(p_secret),'-',''));
begin
  if not private.discovery_capability_enabled_v1('invitations') then return null; end if;
  if p_secret ~ '^[A-Za-z0-9_-]{40,64}$' then
    select * into result from private.friend_invites invite
      where invite.token_digest = encode(extensions.digest(p_secret,'sha256'),'hex');
  elsif normalized ~ '^[A-Z2-9]{12}$' then
    select * into result from private.friend_invites invite
      where invite.code_digest = encode(extensions.digest(normalized,'sha256'),'hex');
  end if;
  if result.id is null or result.revoked_at is not null or result.expires_at <= now() then
    return null;
  end if;
  return result;
end;
$$;
revoke all on function private.friend_invite_from_secret_v1(text) from public, anon, authenticated;

create function public.get_friend_invite_landing_v1(p_secret text)
returns table (display_name text, username text, avatar_url text, expires_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare invite private.friend_invites; projection jsonb;
begin
  invite := private.friend_invite_from_secret_v1(p_secret);
  if invite.id is null then return; end if;
  projection := public.get_profile_link_v1('@'||(
    select lower(profile.username) from public.users profile where profile.id = invite.owner_id
  ));
  if projection is null then return; end if;
  return query select projection#>>'{profile,display_name}',
    projection#>>'{profile,username}', projection#>>'{profile,avatar_url}', invite.expires_at;
end;
$$;

create function public.resolve_friend_invite_v1(p_secret text)
returns table (
  invite_id uuid, user_id uuid, display_name text, username text, avatar_url text,
  friendship_state text, expires_at timestamptz
)
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); invite private.friend_invites;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  invite := private.friend_invite_from_secret_v1(p_secret);
  if invite.id is null then
    if upper(replace(trim(p_secret),'-','')) ~ '^[A-Z2-9]{12}$'
       and not private.consume_discovery_action_v1(
         actor,'invite_code_failure',10,interval '15 minutes'
       ) then
      raise exception 'invite resolution rate limit exceeded' using errcode = 'P0001';
    end if;
    return;
  end if;
  if invite.owner_id = actor
     or not private.can_view_user_as(invite.owner_id, actor) then return; end if;
  return query select invite.id, profile.id, profile.display_name, profile.username,
    profile.avatar_url,
    case
      when private.confirmed_friends(actor, profile.id) then 'friends'
      when exists(select 1 from public.friend_requests request
        where request.from_user_id=actor and request.to_user_id=profile.id and request.status='pending') then 'outgoing'
      when exists(select 1 from public.friend_requests request
        where request.from_user_id=profile.id and request.to_user_id=actor and request.status='pending') then 'incoming'
      else 'none'
    end,
    invite.expires_at
  from public.users profile where profile.id = invite.owner_id;
end;
$$;

create function public.send_friend_request_v2(
  p_target_user_id uuid, p_source text, p_request_nonce uuid,
  p_invite_id uuid default null
)
returns public.friend_requests language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.friend_requests;
begin
  if actor is null then raise exception 'authentication required' using errcode='28000'; end if;
  if p_source not in ('search','suggestion','contacts','profile_link','invite_link',
    'invite_code','shared_post','shared_list','first_week') or p_request_nonce is null then
    raise exception 'invalid request attribution' using errcode='22023';
  end if;
  if p_source in ('invite_link','invite_code') then
    if p_invite_id is null or not exists (
      select 1 from private.friend_invites invite
      where invite.id = p_invite_id and invite.owner_id = p_target_user_id
        and invite.revoked_at is null and invite.expires_at > now()
    ) then
      raise exception 'invalid invitation attribution' using errcode='22023';
    end if;
  elsif p_invite_id is not null then
    raise exception 'unexpected invitation attribution' using errcode='22023';
  end if;
  select request.* into result from private.friend_request_attributions attribution
    join public.friend_requests request on request.id = attribution.request_id
    where attribution.actor_id=actor and attribution.request_nonce=p_request_nonce;
  if found then return result; end if;
  if not private.consume_discovery_action_v1(actor,'friend_request',30,interval '1 day') then
    raise exception 'friend request rate limit exceeded' using errcode = 'P0001';
  end if;
  result := public.send_friend_request(p_target_user_id);
  insert into private.friend_request_attributions(
    request_id, actor_id, source, invite_id, request_nonce
  ) values(result.id, actor, p_source, p_invite_id, p_request_nonce)
  on conflict do nothing;
  return result;
end;
$$;

create function public.respond_friend_request_v2(p_request_id uuid, p_accept boolean)
returns public.friend_requests language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.friend_requests; attributed_source text;
begin
  if actor is null then raise exception 'authentication required' using errcode='28000'; end if;
  result := public.respond_friend_request(p_request_id, p_accept);
  if coalesce(p_accept,false) and result.status = 'accepted' then
    select source into attributed_source from private.friend_request_attributions
      where request_id = result.id;
    insert into private.friend_discovery_state(
      user_id, first_friend_at, first_friend_source, updated_at
    ) values (
      result.from_user_id, now(), coalesce(attributed_source,'legacy'), now()
    ) on conflict(user_id) do update set
      first_friend_at = coalesce(private.friend_discovery_state.first_friend_at,excluded.first_friend_at),
      first_friend_source = coalesce(private.friend_discovery_state.first_friend_source,excluded.first_friend_source),
      updated_at = now();
    insert into private.friend_discovery_state(
      user_id, first_friend_at, first_friend_source, updated_at
    ) values (
      result.to_user_id, now(), coalesce(attributed_source,'legacy'), now()
    ) on conflict(user_id) do update set
      first_friend_at = coalesce(private.friend_discovery_state.first_friend_at,excluded.first_friend_at),
      first_friend_source = coalesce(private.friend_discovery_state.first_friend_source,excluded.first_friend_source),
      updated_at = now();
  end if;
  return result;
end;
$$;

create function public.people_prompt_eligibility_v1()
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null
    and private.discovery_capability_enabled_v1('first_week_prompt')
    and exists(select 1 from auth.users account
      where account.id=auth.uid() and account.created_at >= now()-interval '7 days')
    and exists(select 1 from public.visits visit
      where visit.user_id=auth.uid() and lower(visit.visibility) <> 'private'
        and visit.upload_state='complete')
    and not exists(select 1 from public.friends friend where friend.user_id=auth.uid())
    and not exists(select 1 from private.friend_discovery_state state
      where state.user_id=auth.uid() and state.prompt_consumed_at is not null);
$$;

create function public.consume_people_prompt_v1(p_outcome text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode='28000'; end if;
  if p_outcome not in ('shown','dismissed','opened') then
    raise exception 'invalid prompt outcome' using errcode='22023';
  end if;
  insert into private.friend_discovery_state(user_id,prompt_consumed_at,prompt_outcome)
    values(auth.uid(),now(),p_outcome)
    on conflict(user_id) do update set
      prompt_consumed_at=coalesce(private.friend_discovery_state.prompt_consumed_at,excluded.prompt_consumed_at),
      prompt_outcome=excluded.prompt_outcome,updated_at=now();
end;
$$;

revoke all on function public.get_discovery_preferences_v1(),
  public.get_people_discovery_capabilities_v1(),
  public.set_discovery_preferences_v1(boolean,boolean,boolean,integer,bigint),
  public.search_people_v2(text,integer,integer,real,text,uuid),
  public.get_people_suggestions_v1(integer),
  public.get_people_hub_v1(integer),
  public.dismiss_people_suggestion_v1(uuid,boolean),
  public.create_friend_invite_v1(uuid), public.revoke_friend_invite_v1(uuid),
  public.resolve_friend_invite_v1(text),
  public.send_friend_request_v2(uuid,text,uuid,uuid),
  public.respond_friend_request_v2(uuid,boolean),
  public.people_prompt_eligibility_v1(), public.consume_people_prompt_v1(text)
  from public, anon;
grant execute on function public.get_discovery_preferences_v1(),
  public.get_people_discovery_capabilities_v1(),
  public.set_discovery_preferences_v1(boolean,boolean,boolean,integer,bigint),
  public.search_people_v2(text,integer,integer,real,text,uuid),
  public.get_people_suggestions_v1(integer),
  public.get_people_hub_v1(integer),
  public.dismiss_people_suggestion_v1(uuid,boolean),
  public.create_friend_invite_v1(uuid), public.revoke_friend_invite_v1(uuid),
  public.resolve_friend_invite_v1(text),
  public.send_friend_request_v2(uuid,text,uuid,uuid),
  public.respond_friend_request_v2(uuid,boolean),
  public.people_prompt_eligibility_v1(), public.consume_people_prompt_v1(text)
  to authenticated;

revoke all on function public.service_set_discovery_email_v1(uuid,text,integer,timestamptz),
  public.service_match_discovery_digests_v1(uuid,text[],integer),
  public.service_people_discovery_enabled_v1(text),
  public.consume_contact_match_budget_v1(integer)
  from public, anon, authenticated;
grant execute on function public.service_set_discovery_email_v1(uuid,text,integer,timestamptz),
  public.service_match_discovery_digests_v1(uuid,text[],integer),
  public.service_people_discovery_enabled_v1(text)
  to service_role;
grant execute on function public.consume_contact_match_budget_v1(integer)
  to authenticated;

revoke all on function public.get_friend_invite_landing_v1(text) from public;
grant execute on function public.get_friend_invite_landing_v1(text) to anon, authenticated;
