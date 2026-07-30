begin;

-- Opaque public share links are deliberately separate from visit IDs. The
-- table is sealed from client roles; callers can only use the narrow RPCs
-- below, and every anonymous read re-evaluates current visibility,
-- publication, account, and moderation state.

create table public.visit_share_links (
  visit_id uuid primary key
    references public.visits(id) on delete cascade,
  owner_id uuid not null
    references public.users(id) on delete cascade,
  slug text not null unique
    check (slug ~ '^[A-Za-z0-9_-]{24,128}$'),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index visit_share_links_owner_created_idx
  on public.visit_share_links(owner_id, created_at desc);

alter table public.visit_share_links enable row level security;
revoke all on table public.visit_share_links from public, anon, authenticated;

create table public.visit_share_link_metrics (
  visit_id uuid primary key
    references public.visits(id) on delete cascade,
  landing_visits bigint not null default 0 check (landing_visits >= 0),
  app_opens bigint not null default 0 check (app_opens >= 0),
  updated_at timestamptz not null default now()
);

alter table public.visit_share_link_metrics enable row level security;
revoke all on table public.visit_share_link_metrics from public, anon, authenticated;

create or replace function public.create_visit_share_link_v1(
  p_visit_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  existing_slug text;
  generated_slug text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and visit.user_id = actor
      and private.is_public_visit_discoverable_v3(visit.id)
  ) then
    raise exception 'visit is not available for public sharing'
      using errcode = '42501';
  end if;

  select link.slug
  into existing_slug
  from public.visit_share_links link
  where link.visit_id = p_visit_id
    and link.owner_id = actor
    and link.revoked_at is null;

  if existing_slug is not null then
    return existing_slug;
  end if;

  loop
    generated_slug := encode(extensions.gen_random_bytes(24), 'hex');
    begin
      insert into public.visit_share_links (
        visit_id, owner_id, slug, created_at, revoked_at
      )
      values (p_visit_id, actor, generated_slug, now(), null)
      on conflict (visit_id) do update
        set slug = excluded.slug,
            owner_id = excluded.owner_id,
            created_at = excluded.created_at,
            revoked_at = null
        where public.visit_share_links.owner_id = actor;
      exit;
    exception when unique_violation then
      -- The random slug collided. Generate a fresh value without exposing any
      -- relationship between the public slug and the visit UUID.
    end;
  end loop;

  return generated_slug;
end;
$$;

create or replace function public.get_visit_share_slug_v1(
  p_visit_id uuid
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select link.slug
  from public.visit_share_links link
  where link.visit_id = p_visit_id
    and link.owner_id = auth.uid()
    and link.revoked_at is null
    and private.is_public_visit_discoverable_v3(link.visit_id);
$$;

create or replace function public.revoke_visit_share_link_v1(
  p_visit_id uuid
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  update public.visit_share_links link
  set revoked_at = now()
  where link.visit_id = p_visit_id
    and link.owner_id = auth.uid()
    and link.revoked_at is null
  returning true;
$$;

create or replace function public.get_public_mugshot_share_v1(
  p_slug text
)
returns table (
  visit_id uuid,
  slug text,
  author_name text,
  author_username text,
  drink_name text,
  context_name text,
  rating double precision,
  caption text,
  cover_photo_url text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    visit.id,
    link.slug,
    coalesce(nullif(btrim(author.display_name), ''), author.username),
    author.username,
    coalesce(
      nullif(btrim(visit.drink_subtype), ''),
      nullif(btrim(visit.drink_type_custom), ''),
      nullif(btrim(visit.drink_type), ''),
      'Coffee memory'
    ),
    case
      when visit.cafe_id is not null
        then coalesce(nullif(btrim(cafe.name), ''), 'Cafe')
      when lower(coalesce(visit.context_type, '')) = 'home' then 'Home'
      when lower(coalesce(visit.context_type, '')) = 'recipe' then 'Recipe'
      else 'Elsewhere'
    end,
    visit.overall_score::double precision,
    nullif(btrim(visit.caption), ''),
    nullif(btrim(visit.poster_photo_url), ''),
    visit.created_at
  from public.visit_share_links link
  join public.visits visit on visit.id = link.visit_id
  join public.users author on author.id = visit.user_id
  left join public.cafes cafe on cafe.id = visit.cafe_id
  where length(coalesce(p_slug, '')) between 24 and 128
    and p_slug ~ '^[A-Za-z0-9_-]+$'
    and link.slug = p_slug
    and link.revoked_at is null
    and private.is_public_visit_discoverable_v3(visit.id);
$$;

create or replace function public.record_public_mugshot_share_event_v1(
  p_slug text,
  p_event_name text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_visit_id uuid;
begin
  if p_event_name not in ('landing_visit', 'app_open')
     or length(coalesce(p_slug, '')) not between 24 and 128
     or p_slug !~ '^[A-Za-z0-9_-]+$' then
    return false;
  end if;

  select link.visit_id
  into target_visit_id
  from public.visit_share_links link
  where link.slug = p_slug
    and link.revoked_at is null
    and private.is_public_visit_discoverable_v3(link.visit_id);

  if target_visit_id is null then
    return false;
  end if;

  insert into public.visit_share_link_metrics (
    visit_id, landing_visits, app_opens, updated_at
  )
  values (
    target_visit_id,
    case when p_event_name = 'landing_visit' then 1 else 0 end,
    case when p_event_name = 'app_open' then 1 else 0 end,
    now()
  )
  on conflict (visit_id) do update
    set landing_visits = public.visit_share_link_metrics.landing_visits
          + case when p_event_name = 'landing_visit' then 1 else 0 end,
        app_opens = public.visit_share_link_metrics.app_opens
          + case when p_event_name = 'app_open' then 1 else 0 end,
        updated_at = now();

  return true;
end;
$$;

revoke all on function public.create_visit_share_link_v1(uuid) from public;
revoke all on function public.get_visit_share_slug_v1(uuid) from public;
revoke all on function public.revoke_visit_share_link_v1(uuid) from public;
revoke all on function public.get_public_mugshot_share_v1(text) from public;
revoke all on function public.record_public_mugshot_share_event_v1(text,text)
  from public;

grant execute on function public.create_visit_share_link_v1(uuid)
  to authenticated;
grant execute on function public.get_visit_share_slug_v1(uuid)
  to authenticated;
grant execute on function public.revoke_visit_share_link_v1(uuid)
  to authenticated;
grant execute on function public.get_public_mugshot_share_v1(text)
  to anon, authenticated;
grant execute on function public.record_public_mugshot_share_event_v1(text,text)
  to anon, authenticated;

comment on table public.visit_share_links is
  'Sealed owner-created opaque links for public Mugshots. Anonymous reads are available only through the moderation-aware allowlisted projection.';
comment on function public.get_public_mugshot_share_v1(text) is
  'Anonymous-safe public Mugshot projection. Never returns private notes, precise locations, recipe fields, Passport evidence, or underlying visit rows.';

-- Advance the single client capability manifest atomically with the new RPCs.
create or replace function public.get_backend_capabilities_v1()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'contract_version', 1,
    'schema_release', '2026-07-23-post-publish-share-hub',
    'capabilities', jsonb_build_object(
      'taste_passport',
        to_regprocedure('public.get_taste_passport_v1(uuid)') is not null,
      'taste_passport_audience',
        to_regprocedure('public.get_taste_passport_visibility_v1()') is not null
        and to_regprocedure('public.set_taste_passport_visibility_v1(text,uuid)') is not null,
      'independent_recipe_visibility',
        to_regprocedure('public.get_recipe_projection_for_visit_v1(uuid)') is not null
        and to_regprocedure('public.get_recipe_identity_for_visit_v1(uuid)') is not null,
      'visit_tags',
        to_regprocedure('public.list_visible_visit_tags_v1(uuid)') is not null,
      'shared_mugshots',
        to_regprocedure('public.get_shared_memory_projection_v1(uuid)') is not null,
      'public_mugshot_sharing',
        to_regprocedure('public.create_visit_share_link_v1(uuid)') is not null
        and to_regprocedure('public.get_visit_share_slug_v1(uuid)') is not null
        and to_regprocedure('public.revoke_visit_share_link_v1(uuid)') is not null
        and to_regprocedure('public.get_public_mugshot_share_v1(text)') is not null
        and to_regprocedure(
          'public.record_public_mugshot_share_event_v1(text,text)'
        ) is not null,
      'activity_center',
        to_regprocedure(
          'public.list_activity_events_v1(integer,timestamp with time zone,uuid)'
        ) is not null
        and to_regprocedure('public.activity_unread_count_v1()') is not null
        and to_regprocedure('public.mark_activity_read_v1(uuid)') is not null,
      'notification_preferences',
        to_regprocedure('public.get_notification_preferences_v1()') is not null
        and to_regprocedure(
          'public.set_notification_preferences_v1(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean)'
        ) is not null,
      'push_registration',
        to_regprocedure('public.register_user_device_v2(uuid,text,text)') is not null
        and to_regprocedure(
          'public.claim_user_device_installation_v2(uuid,text,text)'
        ) is not null,
      'social_safety',
        to_regprocedure(
          'public.submit_report_v2(uuid,public.report_reason,text,uuid,text)'
        ) is not null
        and to_regprocedure('public.block_user_v2(uuid,boolean)') is not null,
      'moderation_transparency',
        to_regprocedure('public.get_my_enforcement_state_v1()') is not null
        and to_regprocedure('public.get_report_receipt_v1(uuid)') is not null,
      'collaborative_cafe_lists',
        to_regprocedure('public.list_cafe_lists_v2()') is not null
        and to_regprocedure('public.get_cafe_list_v2(uuid)') is not null
        and to_regprocedure('public.respond_cafe_list_invitation_v2(uuid,text)') is not null,
      'account_deletion_v3',
        to_regprocedure(
          'public.begin_account_deletion_step_up_v3(uuid,uuid,uuid,text,text)'
        ) is not null
        and to_regprocedure(
          'public.prepare_account_deletion_v3(uuid,uuid,uuid,text,text,uuid,text)'
        ) is not null
        and to_regprocedure(
          'public.acknowledge_account_deletion_completion_v3(uuid,text,text)'
        ) is not null
    )
  );
$$;

revoke all on function public.get_backend_capabilities_v1() from public;
grant execute on function public.get_backend_capabilities_v1() to anon, authenticated;

commit;
