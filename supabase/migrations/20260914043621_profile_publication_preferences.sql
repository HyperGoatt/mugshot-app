-- Version 2 distinguishes new publication from historical Friends consent.
alter table public.profile_visibility_preferences
 add column publication_policy_version integer,
 add column publication_policy_acknowledged_at timestamptz,
 add column include_historical_friends boolean not null default false;

create function public.get_profile_publication_policy_v1()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_live_account_as(auth.uid()) then raise exception 'authentication required' using errcode='28000'; end if;
 return coalesce((select jsonb_build_object('acknowledged',publication_policy_version=2 and publication_policy_acknowledged_at is not null,
 'show_friends',show_friends_on_public_profile,'include_historical',include_historical_friends)
 from public.profile_visibility_preferences where user_id=auth.uid()),jsonb_build_object('acknowledged',false,'show_friends',true,'include_historical',false));
end; $$;

create function public.acknowledge_profile_publication_v1(p_include_historical boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if not private.is_live_account_as(actor) then raise exception 'authentication required' using errcode='28000'; end if;
 insert into public.profile_visibility_preferences(user_id,show_friends_on_public_profile,publication_policy_version,publication_policy_acknowledged_at,include_historical_friends)
 values(actor,true,2,now(),coalesce(p_include_historical,false))
 on conflict(user_id) do update set publication_policy_version=2,
 publication_policy_acknowledged_at=coalesce(public.profile_visibility_preferences.publication_policy_acknowledged_at,now()),
 include_historical_friends=public.profile_visibility_preferences.include_historical_friends or coalesce(p_include_historical,false),updated_at=now();
 return public.get_profile_publication_policy_v1();
end; $$;

create or replace function private.profile_shows_friends_v1(p_owner uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select show_friends_on_public_profile and (
 (public_consent_version=1 and public_consented_at is not null) or
 (publication_policy_version=2 and publication_policy_acknowledged_at is not null))
 from public.profile_visibility_preferences where user_id=p_owner),false);
$$;

create table private.profile_publication_receipts (
 visit_id uuid primary key references public.visits(id) on delete cascade,
 author_id uuid not null references public.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table private.profile_publication_receipts enable row level security;
revoke all on private.profile_publication_receipts from public,anon,authenticated;
create function private.capture_profile_publication_v1() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.profile_visibility_preferences where user_id=new.user_id and publication_policy_version=2 and publication_policy_acknowledged_at is not null) then
 insert into private.profile_publication_receipts(visit_id,author_id) values(new.id,new.user_id) on conflict do nothing;
 end if;
 return null;
end; $$;
revoke all on function private.capture_profile_publication_v1() from public,anon,authenticated;
create trigger capture_profile_publication after insert on public.visits for each row execute function private.capture_profile_publication_v1();
create or replace function private.profile_visit_published_v1(p_visit_id uuid,p_profile_owner uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.visits v where v.id=p_visit_id
 and v.upload_state='complete' and private.screening_approved_v1('visit',v.id)
 and private.profile_owner_visible_v2(v.user_id,null)
 and private.profile_owner_visible_v2(p_profile_owner,null)
 and (v.user_id=p_profile_owner or exists(select 1 from public.visit_tags t where t.visit_id=v.id and t.tagged_user_id=p_profile_owner))
 and not private.has_active_moderation_action('visit',v.id,array['content_hidden']::text[])
 and not exists(select 1 from public.profile_tagged_post_hides h where h.visit_id=v.id and h.user_id=p_profile_owner)
 and (lower(v.visibility)='everyone' or (lower(v.visibility)='friends' and
   coalesce((select p.show_friends_on_public_profile from public.profile_visibility_preferences p where p.user_id=p_profile_owner),true)
   and exists(select 1 from public.profile_visibility_preferences author where author.user_id=v.user_id and (
     (author.public_consent_version=1 and author.public_consented_at is not null and author.show_friends_on_public_profile)
     or (author.publication_policy_version=2 and author.publication_policy_acknowledged_at is not null
       and (author.include_historical_friends or exists(select 1 from private.profile_publication_receipts receipt where receipt.visit_id=v.id and receipt.author_id=v.user_id)))
   ))
 )));
$$;

-- Expand the existing per-profile hide table to authors; other users cannot hide.
create or replace function public.set_profile_tagged_post_hidden_v1(p_visit_id uuid,p_hidden boolean default true)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if not private.is_live_account_as(actor) then raise exception 'authentication required' using errcode='28000'; end if;
 if not exists(select 1 from public.visits v where v.id=p_visit_id and v.user_id=actor)
 and not exists(select 1 from public.visit_tags t where t.visit_id=p_visit_id and t.tagged_user_id=actor) then
 raise exception 'post is unavailable' using errcode='42501'; end if;
 if coalesce(p_hidden,true) then
 insert into public.profile_tagged_post_hides(user_id,visit_id) values(actor,p_visit_id) on conflict do nothing;
 else delete from public.profile_tagged_post_hides where user_id=actor and visit_id=p_visit_id;
 end if;
 return coalesce(p_hidden,true);
end; $$;
create function public.get_profile_post_hidden_v1(p_visit_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_live_account_as(auth.uid()) then raise exception 'authentication required' using errcode='28000'; end if;
 return exists(select 1 from public.profile_tagged_post_hides where user_id=auth.uid() and visit_id=p_visit_id);
end; $$;
revoke all on function public.get_profile_publication_policy_v1(),public.acknowledge_profile_publication_v1(boolean),public.get_profile_post_hidden_v1(uuid) from public,anon;
grant execute on function public.get_profile_publication_policy_v1(),public.acknowledge_profile_publication_v1(boolean),public.get_profile_post_hidden_v1(uuid) to authenticated;

create function public.set_profile_friends_visibility_v3(p_enabled boolean)
returns boolean language plpgsql security definer set search_path='' as $$
begin
 if not private.is_live_account_as(auth.uid()) then raise exception 'authentication required' using errcode='28000'; end if;
 if p_enabled is null then raise exception 'enabled required' using errcode='22023'; end if;
 insert into public.profile_visibility_preferences(user_id,show_friends_on_public_profile) values(auth.uid(),p_enabled)
 on conflict(user_id) do update set show_friends_on_public_profile=excluded.show_friends_on_public_profile,updated_at=now();
 return p_enabled;
end; $$;
revoke all on function public.set_profile_friends_visibility_v3(boolean) from public,anon;
grant execute on function public.set_profile_friends_visibility_v3(boolean) to authenticated;
