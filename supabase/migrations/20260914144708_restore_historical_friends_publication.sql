-- Owner-approved policy amendment: restore already-published Friends posts.
-- Record the exact existing set, without changing audiences, consent or hides.
create table private.historical_profile_publications (
  visit_id uuid primary key references public.visits(id) on delete cascade,
  restored_at timestamptz not null default now()
);
alter table private.historical_profile_publications enable row level security;
revoke all on private.historical_profile_publications from public, anon, authenticated;
insert into private.historical_profile_publications(visit_id)
select id from public.visits where lower(visibility)='friends' and upload_state='complete';

create or replace function private.profile_visit_published_v1(p_visit_id uuid,p_profile_owner uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.visits v
  where v.id=p_visit_id and v.upload_state='complete'
   and private.screening_approved_v1('visit',v.id)
   and private.profile_owner_visible_v2(v.user_id,null)
   and private.profile_owner_visible_v2(p_profile_owner,null)
   and (v.user_id=p_profile_owner or exists(
    select 1 from public.visit_tags t where t.visit_id=v.id and t.tagged_user_id=p_profile_owner))
   and not private.has_active_moderation_action('visit',v.id,array['content_hidden']::text[])
   and not exists(select 1 from public.profile_tagged_post_hides h
    where h.visit_id=v.id and h.user_id=p_profile_owner)
   and (
    lower(v.visibility)='everyone'
    or (lower(v.visibility)='friends'
     and coalesce((select p.show_friends_on_public_profile
       from public.profile_visibility_preferences p where p.user_id=p_profile_owner),true)
     and (
      (exists(select 1 from private.historical_profile_publications h where h.visit_id=v.id)
       and coalesce((select a.show_friends_on_public_profile
        from public.profile_visibility_preferences a where a.user_id=v.user_id),true))
      or exists(select 1 from public.profile_visibility_preferences author
       where author.user_id=v.user_id and (
        (author.public_consent_version=1 and author.public_consented_at is not null
         and author.show_friends_on_public_profile)
        or (author.publication_policy_version=2 and author.publication_policy_acknowledged_at is not null
         and (author.include_historical_friends or exists(
          select 1 from private.profile_publication_receipts receipt
          where receipt.visit_id=v.id and receipt.author_id=v.user_id)))
       ))
     )
    )
   )
 );
$$;
