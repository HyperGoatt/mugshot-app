begin;
-- Catalog text displayed beside shared content is client-supplied until its
-- provenance is verified. Screen it with that content, never private-only use.
create function private.cafe_screening_text_v1(p_cafe uuid)
returns text language sql stable security definer set search_path='' as $$
  select concat_ws(E'\n',c.name,c.address,c.city,to_jsonb(c)->>'country',
    c.website_url)
  from public.cafes c where c.id=p_cafe;
$$;
create function private.subject_cafe_screening_text_v1(p_kind text,p_id uuid)
returns text language plpgsql stable security definer set search_path='' as $$
declare result text;
begin
  if p_kind='visit' then
    select private.cafe_screening_text_v1(cafe_id) into result from public.visits where id=p_id;
  elsif p_kind='user' then
    select string_agg(private.cafe_screening_text_v1(cafe_id),E'\n' order by position)
    into result from public.profile_favorite_spots where user_id=p_id;
  elsif p_kind='list_item' then
    select private.cafe_screening_text_v1(cafe_id) into result from public.cafe_list_items where id=p_id;
  elsif p_kind='recommendation' then
    select private.cafe_screening_text_v1(target_cafe_id) into result
    from public.trusted_recommendations where id=p_id and target_kind='cafe';
  end if;
  return result;
end;
$$;
revoke all on function private.cafe_screening_text_v1(uuid),
private.subject_cafe_screening_text_v1(text,uuid) from public,anon,authenticated;

create or replace function private.enqueue_screening_v1(p_kind text, p_id uuid, p_owner uuid, p_payload jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare cafe_text text;
begin
  -- Null means no longer outward-facing or deleted. Withdraw any active lease.
  if p_payload is null then
    delete from private.screening_jobs where subject_kind=p_kind and subject_id=p_id;
    return;
  end if;
  if jsonb_typeof(p_payload) <> 'object'
     or (p_payload - array['text','images']::text[]) <> '{}'::jsonb
     or jsonb_typeof(p_payload->'text') is distinct from 'string'
     or jsonb_typeof(p_payload->'images') is distinct from 'array'
     or jsonb_array_length(p_payload->'images') > 12
     or octet_length(p_payload::text) > 65536 then
    raise exception 'invalid screening payload' using errcode='22023';
  end if;
  cafe_text:=private.subject_cafe_screening_text_v1(p_kind,p_id);
  if nullif(btrim(cafe_text),'') is not null then
    p_payload:=jsonb_set(p_payload,'{text}',to_jsonb(concat_ws(E'\n',p_payload->>'text',cafe_text)));
    if octet_length(p_payload::text)>65536 then
      raise exception 'invalid screening payload' using errcode='22023';
    end if;
  end if;
  insert into private.screening_jobs(subject_kind,subject_id,owner_id,payload)
    values(p_kind,p_id,p_owner,p_payload)
  on conflict(subject_kind,subject_id) do update set
    owner_id=excluded.owner_id, payload=excluded.payload, revision=gen_random_uuid(),
    state='pending', reason=null, evidence='{}'::jsonb, attempts=0,
    available_at=now(), lease_token=null, lease_until=null, appeal_requested_at=null,
    updated_at=now()
  where private.screening_jobs.payload is distinct from excluded.payload
     or private.screening_jobs.owner_id is distinct from excluded.owner_id;
  -- Structured-only rows with no shared text or images need no provider call.
  if btrim(p_payload->>'text')='' and p_payload->'images'='[]'::jsonb then
    update private.screening_jobs set state='approved',reason='no_screenable_content',
      lease_token=null,lease_until=null,updated_at=now()
      where subject_kind=p_kind and subject_id=p_id and state='pending';
  end if;
end;
$$;

create function private.refresh_cafe_dependents_screening_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
  if private.cafe_screening_text_v1(new.id) is not distinct from
    concat_ws(E'\n',old.name,old.address,old.city,to_jsonb(old)->>'country',
      old.website_url) then return null;end if;
  for target in select id from public.visits where cafe_id=new.id loop
    perform private.refresh_visit_screening_v1(target);
  end loop;
  for target in select distinct user_id from public.profile_favorite_spots where cafe_id=new.id loop
    perform private.refresh_profile_screening_v1(target);
  end loop;
  for target in select id from public.cafe_list_items where cafe_id=new.id loop
    perform private.refresh_collection_screening_v1('list_item',target);
  end loop;
  for target in select id from public.trusted_recommendations where target_kind='cafe' and target_cafe_id=new.id loop
    perform private.refresh_collection_screening_v1('recommendation',target);
  end loop;
  return null;
end;
$$;
revoke all on function private.refresh_cafe_dependents_screening_v1() from public,anon,authenticated;
create trigger screening_cafe_correction after update on public.cafes
for each row execute function private.refresh_cafe_dependents_screening_v1();

-- Rebuild from source fields once; do not append repeatedly to stored snapshots.
select private.refresh_visit_screening_v1(id) from public.visits;
select private.refresh_profile_screening_v1(id) from public.users;
select private.refresh_collection_screening_v1('list_item',id) from public.cafe_list_items;
select private.refresh_collection_screening_v1('recommendation',id) from public.trusted_recommendations;
commit;
