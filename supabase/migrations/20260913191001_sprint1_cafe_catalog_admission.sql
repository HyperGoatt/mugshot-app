begin;
-- Provenance is private operational metadata, never part of a cafe projection.
create table private.cafe_catalog_admission (
 cafe_id uuid primary key references public.cafes(id) on delete cascade,
 submitted_by uuid references public.users(id) on delete set null,
 verified_at timestamptz,
 provider text check(provider in ('apple','google'))
);
alter table private.cafe_catalog_admission enable row level security;
revoke all on private.cafe_catalog_admission from public,anon,authenticated;
create index cafe_catalog_admission_submitter on private.cafe_catalog_admission(submitted_by);
create function private.track_cafe_admission_v1() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  insert into private.cafe_catalog_admission(cafe_id,submitted_by)
  values(new.id,auth.uid());
 else
  -- Any trusted correction withdraws the previous provider attestation. The
  -- verifier may attest the new canonical snapshot in the same transaction.
  update private.cafe_catalog_admission set verified_at=null,provider=null where cafe_id=new.id;
 end if;
 return null;
end;
$$;
revoke all on function private.track_cafe_admission_v1() from public,anon,authenticated;
create trigger cafe_catalog_admission_insert after insert on public.cafes
for each row execute function private.track_cafe_admission_v1();
create trigger cafe_catalog_admission_update after update of name,address,city,country,
 latitude,longitude,apple_place_id,apple_maps_place_id,google_place_id,website_url on public.cafes
for each row execute function private.track_cafe_admission_v1();

create function private.can_read_cafe_catalog_as(p_cafe uuid,p_viewer uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select
 exists(select 1 from private.cafe_catalog_admission a where a.cafe_id=p_cafe and a.verified_at is not null)
 or ((p_viewer is null or private.is_live_account_as(p_viewer)) and (
  exists(select 1 from private.cafe_catalog_admission a where a.cafe_id=p_cafe and a.submitted_by=p_viewer)
  or exists(select 1 from public.visits v where v.cafe_id=p_cafe
    and private.can_view_visit_as(v.id,p_viewer))
  or exists(select 1 from public.user_cafe_states s where s.cafe_id=p_cafe and s.user_id=p_viewer)
  or exists(select 1 from public.profile_favorite_spots s where s.cafe_id=p_cafe
    and private.profile_owner_visible_v2(s.user_id,p_viewer))
  or exists(select 1 from public.cafe_list_items i join public.cafe_lists l on l.id=i.list_id
    where i.cafe_id=p_cafe and private.can_view_cafe_list_items_as(l.id,p_viewer)
    and (i.contributor_id=p_viewer or l.visibility='private' or private.screening_approved_v1('list_item',i.id)))
  or exists(select 1 from public.trusted_recommendations r where r.target_kind='cafe'
    and r.target_cafe_id=p_cafe and r.status<>'dismissed'
    and (r.sender_id=p_viewer or (r.recipient_id=p_viewer and private.screening_approved_v1('recommendation',r.id)))
    and not private.blocked_between(r.sender_id,r.recipient_id))
 ));
$$;
revoke all on function private.can_read_cafe_catalog_as(uuid,uuid) from public,anon,authenticated;
create function public.can_read_cafe_catalog_v1(p_cafe uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select private.can_read_cafe_catalog_as(p_cafe,auth.uid());
$$;
revoke all on function public.can_read_cafe_catalog_v1(uuid) from public;
grant execute on function public.can_read_cafe_catalog_v1(uuid) to anon,authenticated;
drop policy if exists "Cafes are readable by everyone" on public.cafes;
create policy "Cafe catalog authorized contexts" on public.cafes for select to anon,authenticated
using(public.can_read_cafe_catalog_v1(id));
drop policy if exists "Authenticated users can write cafes" on public.cafes;
create policy "Live accounts can submit cafes" on public.cafes for insert to authenticated
with check(public.is_live_account(auth.uid()));

-- Referencing a guessed hidden UUID must not manufacture an owner read path.
create function private.guard_cafe_reference_v1() returns trigger
language plpgsql security definer set search_path='' as $$
declare target uuid; previous uuid;
begin
 if tg_table_name='trusted_recommendations' then
  if new.target_kind<>'cafe' then return new;end if;
  target:=new.target_cafe_id;
  if tg_op='UPDATE' then previous:=old.target_cafe_id;end if;
 else
  target:=new.cafe_id;
  if tg_op='UPDATE' then previous:=old.cafe_id;end if;
 end if;
 if auth.uid() is not null and target is not null and target is distinct from previous
 and not private.can_read_cafe_catalog_as(target,auth.uid()) then
  raise exception 'cafe unavailable' using errcode='42501';
 end if;
 return new;
end;
$$;
revoke all on function private.guard_cafe_reference_v1() from public,anon,authenticated;
create trigger guard_cafe_reference before insert or update of cafe_id on public.visits
for each row execute function private.guard_cafe_reference_v1();
create trigger guard_cafe_reference before insert or update of cafe_id on public.user_cafe_states
for each row execute function private.guard_cafe_reference_v1();
create trigger guard_cafe_reference before insert or update of cafe_id on public.cafe_list_items
for each row execute function private.guard_cafe_reference_v1();
create trigger guard_cafe_reference before insert or update of cafe_id on public.profile_favorite_spots
for each row execute function private.guard_cafe_reference_v1();
create trigger guard_cafe_reference before insert or update of target_cafe_id,target_kind on public.trusted_recommendations
for each row execute function private.guard_cafe_reference_v1();

-- A manual location belongs to its submitter until it has an authorized shared
-- context. Do not collide with another person's private same-name location.
create function private.scope_manual_cafe_identity_v1() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is not null and nullif(btrim(new.apple_maps_place_id),'') is null
 and nullif(btrim(new.google_place_id),'') is null and nullif(btrim(new.apple_place_id),'') is null then
  new.identity_key:='manual:'||auth.uid()::text||':'||new.identity_key;
 end if;
 return new;
end;
$$;
revoke all on function private.scope_manual_cafe_identity_v1() from public,anon,authenticated;
create trigger cafes_zz_manual_identity before insert on public.cafes
for each row execute function private.scope_manual_cafe_identity_v1();

create table private.cafe_verification_limits (
 actor_id uuid primary key references public.users(id) on delete cascade,
 window_start timestamptz not null, attempts integer not null check(attempts between 1 and 30)
);
alter table private.cafe_verification_limits enable row level security;
revoke all on private.cafe_verification_limits from public,anon,authenticated;
create function public.reserve_cafe_verification_v1(p_actor uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare reserved uuid;
begin
 if not private.is_live_account_as(p_actor) then return false;end if;
 insert into private.cafe_verification_limits as limits(actor_id,window_start,attempts)
 values(p_actor,now(),1) on conflict(actor_id) do update set
 window_start=case when limits.window_start < now()-interval '1 hour' then now() else limits.window_start end,
 attempts=case when limits.window_start < now()-interval '1 hour' then 1 else limits.attempts+1 end
 where limits.window_start < now()-interval '1 hour' or limits.attempts<30
 returning actor_id into reserved;
 return reserved is not null;
end;
$$;
create function public.accept_verified_cafe_v1(p_actor uuid,p_provider text,p_place_id text,p_place jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target public.cafes; lat double precision;lon double precision;
begin
 if not private.is_live_account_as(p_actor) then raise exception 'account unavailable' using errcode='42501';end if;
 if p_provider not in ('apple','google') or p_provider is null
 or p_place_id is null or (length(p_place_id)>256 or p_place_id !~ '^[A-Za-z0-9_-]+$')
 or jsonb_typeof(p_place) is distinct from 'object'
 or p_place-array['name','address','city','country','latitude','longitude']::text[] <> '{}'::jsonb
 or length(btrim(p_place->>'name')) not between 1 and 300
 or length(btrim(p_place->>'address')) not between 1 and 2000
 or p_place->>'name' is null or p_place->>'address' is null then
 raise exception 'invalid place' using errcode='22023';end if;
 lat:=(p_place->>'latitude')::double precision;lon:=(p_place->>'longitude')::double precision;
 if lat is null or lon is null or not(lat between -90 and 90) or not(lon between -180 and 180) then
 raise exception 'invalid coordinates' using errcode='22023';end if;
 -- Serialize same-provider creation and correction, preserving existing IDs.
 perform pg_advisory_xact_lock(hashtextextended('cafe:'||p_provider||':'||p_place_id,0));
 select * into target from public.cafes where
 (p_provider='apple' and apple_maps_place_id=p_place_id) or
 (p_provider='google' and google_place_id=p_place_id) for update;
 if target.id is null then
  insert into public.cafes(name,address,city,country,latitude,longitude,apple_maps_place_id,google_place_id)
  values(p_place->>'name',p_place->>'address',p_place->>'city',p_place->>'country',lat,lon,
   case when p_provider='apple' then p_place_id end,case when p_provider='google' then p_place_id end)
  returning * into target;
 else
  update public.cafes set name=p_place->>'name',address=p_place->>'address',city=p_place->>'city',
   country=p_place->>'country',latitude=lat,longitude=lon,website_url=null,apple_place_id=null,
   apple_maps_place_id=case when p_provider='apple' then p_place_id end,
   google_place_id=case when p_provider='google' then p_place_id end
  where id=target.id returning * into target;
 end if;
 insert into private.cafe_catalog_admission(cafe_id,submitted_by,verified_at,provider)
 values(target.id,p_actor,now(),p_provider) on conflict(cafe_id) do update
 set verified_at=excluded.verified_at,provider=excluded.provider;
 return to_jsonb(target);
end;
$$;
revoke all on function public.reserve_cafe_verification_v1(uuid),
public.accept_verified_cafe_v1(uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.reserve_cafe_verification_v1(uuid),
public.accept_verified_cafe_v1(uuid,text,text,jsonb) to service_role;

-- The two legacy catalog-wide definer RPCs must use the same admission gate.
-- Exact source assertions prevent an accidental broad replacement on drift.
do $$
declare definition text; target regprocedure;
begin
 target:='public.resolve_cafe_summary(text,double precision,double precision,text)'::regprocedure;
 definition:=pg_get_functiondef(target);
 if position('where i.viewer is not null' in definition)=0 then raise exception 'resolve source drift';end if;
 definition:=replace(definition,'where i.viewer is not null','where i.viewer is not null and private.can_read_cafe_catalog_as(c.id,i.viewer)');
 execute definition;
 select p.oid::regprocedure into strict target from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='discover_cafes';
 definition:=pg_get_functiondef(target);
 if position('where i.viewer is not null and c.latitude' in definition)=0 then raise exception 'discover source drift';end if;
 definition:=replace(definition,'where i.viewer is not null and c.latitude','where i.viewer is not null and private.can_read_cafe_catalog_as(c.id,i.viewer) and c.latitude');
 execute definition;
end;
$$;
commit;
