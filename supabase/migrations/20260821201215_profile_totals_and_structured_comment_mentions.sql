begin;

-- ---------------------------------------------------------------------------
-- Profile v3: total aggregate stats with viewer-authorized content projection
-- ---------------------------------------------------------------------------

create or replace function private.profile_projection_v3(
  p_owner uuid,
  p_viewer uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
  total_sips integer;
  total_cafes integer;
begin
  result := private.profile_projection_v2(p_owner, p_viewer);
  if result is null then
    return null;
  end if;

  select
    count(*)::integer,
    count(distinct visit.cafe_id) filter (
      where visit.cafe_id is not null
        and lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
    )::integer
  into total_sips, total_cafes
  from public.visits visit
  where visit.user_id = p_owner
    and visit.upload_state = 'complete'
    and not private.has_active_moderation_action(
      'visit', visit.id, array['content_hidden']::text[]
    );

  return jsonb_set(
    result,
    '{stats}',
    jsonb_build_object(
      'friends', coalesce((result #>> '{stats,friends}')::integer, 0),
      'sips', coalesce(total_sips, 0),
      'cafes', coalesce(total_cafes, 0)
    ),
    true
  );
end;
$$;

revoke all on function private.profile_projection_v3(uuid,uuid)
  from public, anon, authenticated;

create or replace function public.get_profile_projection_v3(
  p_user_id uuid,
  p_as_everyone boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_as_everyone and actor <> p_user_id then
    raise exception 'only the owner may preview as Everyone' using errcode = '42501';
  end if;

  result := private.profile_projection_v3(
    p_user_id,
    case when p_as_everyone then null else actor end
  );
  if result is null then
    raise exception 'profile unavailable' using errcode = 'P0002';
  end if;
  return result;
end;
$$;

create or replace function public.get_profile_share_v2(p_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
begin
  select link.owner_id into owner_id
  from public.profile_share_links link
  where length(coalesce(p_slug, '')) between 24 and 128
    and p_slug ~ '^[A-Za-z0-9_-]+$'
    and link.slug = p_slug
    and link.revoked_at is null;

  if owner_id is null then
    return null;
  end if;
  return private.profile_projection_v3(owner_id, null);
end;
$$;

revoke all on function public.get_profile_projection_v3(uuid,boolean)
  from public, anon, authenticated;
revoke all on function public.get_profile_share_v2(text)
  from public, anon, authenticated;

grant execute on function public.get_profile_projection_v3(uuid,boolean)
  to authenticated;
grant execute on function public.get_profile_share_v2(text)
  to anon, authenticated;

comment on function public.get_profile_projection_v3(uuid,boolean) is
  'Shared profile projection whose aggregate sip and cafe stats include all completed non-moderated owner content while content collections remain viewer-authorized.';
comment on function public.get_profile_share_v2(text) is
  'Opaque public profile-link projection with total aggregate stats and viewer-authorized content collections.';

-- ---------------------------------------------------------------------------
-- Structured comment mentions
-- ---------------------------------------------------------------------------

alter table public.comments
  add column if not exists mention_tokens jsonb not null default '[]'::jsonb;

alter table public.comments
  drop constraint if exists comments_mention_tokens_array_check,
  add constraint comments_mention_tokens_array_check
    check (jsonb_typeof(mention_tokens) = 'array');

revoke insert, update, delete, truncate, references, trigger
  on table public.comments from anon, authenticated;

create or replace function private.comment_contains_mention_token_v2(
  p_text text,
  p_token text
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  haystack text := lower(coalesce(p_text, ''));
  needle text := lower(coalesce(p_token, ''));
  search_from integer := 1;
  relative_position integer;
  absolute_position integer;
  before_character text;
  after_character text;
begin
  if needle = '' then
    return false;
  end if;
  loop
    relative_position := strpos(substr(haystack, search_from), needle);
    if relative_position = 0 then
      return false;
    end if;
    absolute_position := search_from + relative_position - 1;
    before_character := case
      when absolute_position <= 1 then ''
      else substr(haystack, absolute_position - 1, 1)
    end;
    after_character := substr(
      haystack,
      absolute_position + char_length(needle),
      1
    );
    if before_character !~ '[[:alnum:]_]'
       and after_character !~ '[[:alnum:]_]' then
      return true;
    end if;
    search_from := absolute_position + char_length(needle);
  end loop;
end;
$$;

revoke all on function private.comment_contains_mention_token_v2(text,text)
  from public, anon, authenticated;

create or replace function private.comment_legacy_mention_token_v2(
  p_text text,
  p_username text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select (
    regexp_match(
      coalesce(p_text, ''),
      '@\[[^]|]+\|' || coalesce(p_username, '') || '\]',
      'i'
    )
  )[1]
$$;

revoke all on function private.comment_legacy_mention_token_v2(text,text)
  from public, anon, authenticated;

create or replace function public.create_comment_v2(
  p_visit_id uuid,
  p_text text,
  p_parent_comment_id uuid default null,
  p_mentions jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result public.comments;
  requested_id uuid;
  requested_username text;
  requested_display_name text;
  requested_token text;
  requested jsonb;
  distinct_mentions uuid[] := '{}'::uuid[];
  tokens jsonb := '[]'::jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  if jsonb_typeof(coalesce(p_mentions, '[]'::jsonb)) <> 'array' then
    raise exception 'mentions must be an array' using errcode = '22023';
  end if;
  if jsonb_array_length(coalesce(p_mentions, '[]'::jsonb)) > 20 then
    raise exception 'a comment can mention at most 20 people' using errcode = '22023';
  end if;

  for requested in
    select value from jsonb_array_elements(coalesce(p_mentions, '[]'::jsonb))
  loop
    begin
      requested_id := (requested ->> 'user_id')::uuid;
    exception when others then
      raise exception 'invalid mention target' using errcode = '42501';
    end;
    requested_token := nullif(trim(requested ->> 'token'), '');

    if requested_id is null or requested_id = actor or requested_token is null then
      raise exception 'invalid mention target' using errcode = '42501';
    end if;
    if requested_id = any(distinct_mentions) then
      continue;
    end if;

    select profile.username, profile.display_name
    into requested_username, requested_display_name
    from public.users profile
    where profile.id = requested_id;

    if requested_username is null
       or (
         lower(requested_token) <> lower('@' || requested_username)
         and (
           requested_display_name is null
           or (
             lower(requested_token) <> lower(requested_display_name)
             and lower(requested_token) <> lower('@' || requested_display_name)
           )
         )
       )
       or not private.comment_contains_mention_token_v2(p_text, requested_token) then
      raise exception 'invalid mention target' using errcode = '42501';
    end if;

    if exists (
      select 1
      from jsonb_array_elements(tokens) existing
      where lower(existing ->> 'token') = lower(requested_token)
    ) then
      raise exception 'ambiguous mention token' using errcode = '22023';
    end if;

    distinct_mentions := array_append(distinct_mentions, requested_id);
    tokens := tokens || jsonb_build_array(jsonb_build_object(
      'user_id', requested_id,
      'token', requested_token
    ));
  end loop;

  result := public.create_comment(
    p_visit_id,
    p_text,
    p_parent_comment_id,
    distinct_mentions
  );

  update public.comments comment
  set mention_tokens = tokens
  where comment.id = result.id;

  return jsonb_build_object(
    'id', result.id,
    'visit_id', result.visit_id,
    'parent_comment_id', result.parent_comment_id,
    'text', result.text,
    'created_at', result.created_at,
    'mentions', tokens
  );
end;
$$;

create or replace function public.list_visit_comments_v2(p_visit_id uuid)
returns table (
  id uuid,
  user_id uuid,
  visit_id uuid,
  text text,
  created_at timestamptz,
  parent_comment_id uuid,
  author_display_name text,
  author_username text,
  author_avatar_url text,
  mentions jsonb,
  replies_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
begin
  if not private.profile_visit_visible_v2(p_visit_id, viewer) then
    raise exception 'visit unavailable' using errcode = '42501';
  end if;

  return query
  select
    comment.id,
    comment.user_id,
    comment.visit_id,
    comment.text,
    comment.created_at,
    comment.parent_comment_id,
    author.display_name,
    author.username,
    author.avatar_url,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'user_id', mentioned.id,
          'token', coalesce(
            nullif(token.value ->> 'token', ''),
            case
              when private.comment_contains_mention_token_v2(
                comment.text, '@' || mentioned.username
              ) then '@' || mentioned.username
              else private.comment_legacy_mention_token_v2(
                comment.text, mentioned.username
              )
            end
          ),
          'display_name', mentioned.display_name,
          'username', mentioned.username,
          'avatar_url', mentioned.avatar_url
        )
        order by mentioned.username
      )
      from public.comment_mentions edge
      join public.users mentioned on mentioned.id = edge.mentioned_user_id
      left join lateral (
        select value
        from jsonb_array_elements(comment.mention_tokens) value
        where value ->> 'user_id' = mentioned.id::text
        limit 1
      ) token on true
      where edge.comment_id = comment.id
        and private.profile_owner_visible_v2(mentioned.id, viewer)
        and (
          (
            token.value is not null
            and private.comment_contains_mention_token_v2(
              comment.text, token.value ->> 'token'
            )
          )
          or private.comment_contains_mention_token_v2(
            comment.text, '@' || mentioned.username
          )
          or private.comment_legacy_mention_token_v2(
            comment.text, mentioned.username
          ) is not null
        )
    ), '[]'::jsonb),
    (
      select count(*)::integer
      from public.comments reply
      where reply.parent_comment_id = comment.id
        and reply.removed_at is null
        and not private.has_active_moderation_action(
          'comment', reply.id, array['content_hidden']::text[]
        )
        and private.profile_owner_visible_v2(reply.user_id, viewer)
    )
  from public.comments comment
  join public.users author on author.id = comment.user_id
  where comment.visit_id = p_visit_id
    and comment.removed_at is null
    and not private.has_active_moderation_action(
      'comment', comment.id, array['content_hidden']::text[]
    )
    and private.profile_owner_visible_v2(comment.user_id, viewer)
  order by comment.created_at, comment.id;
end;
$$;

revoke all on function public.create_comment_v2(uuid,text,uuid,jsonb)
  from public, anon, authenticated;
revoke all on function public.list_visit_comments_v2(uuid)
  from public, anon, authenticated;

grant execute on function public.create_comment_v2(uuid,text,uuid,jsonb)
  to authenticated;
grant execute on function public.list_visit_comments_v2(uuid)
  to anon, authenticated;

comment on function public.create_comment_v2(uuid,text,uuid,jsonb) is
  'Creates a comment and validates each selected account ID against its exact visible display-name or handle token before creating mention relationships.';
comment on function public.list_visit_comments_v2(uuid) is
  'Returns viewer-authorized comments with current author identity and structured mention metadata; anonymous callers may read comments only for Everyone posts.';

commit;
