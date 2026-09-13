-- Screen every free-text field exposed by the canonical post projection.
-- Private posts and private raw notes never enter this payload.
create function private.canonical_post_screening_text_v1(p_visit uuid)
returns text language sql stable security definer set search_path='' as $$
 select concat_ws(E'\n',
   case when v.brew_method_visible then v.brew_method end,
   case when v.equipment_visible then v.equipment end,
   case when r.raw_note_visibility in ('friends','everyone') then r.sip_raw_note end,
   case when r.raw_note_visibility in ('friends','everyone') then r.context_raw_note end,
   (select string_agg(item->>'name',E'\n' order by ordinal)
    from jsonb_array_elements(coalesce(r.context_criteria,'[]'::jsonb)) with ordinality c(item,ordinal))
 ) from public.visits v left join public.visit_v3_reflections r on r.visit_id=v.id
 where v.id=p_visit and v.visibility in ('friends','everyone') and v.upload_state='complete';
$$;
revoke all on function private.canonical_post_screening_text_v1(uuid) from public,anon,authenticated;

create or replace function private.refresh_visit_screening_v1(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare payload jsonb; owner_id uuid;
begin
  select visit.user_id,case when visit.visibility in ('friends','everyone') and visit.upload_state='complete' then
    jsonb_build_object(
      'text',concat_ws(E'\n',visit.caption,to_jsonb(visit)->>'drink_type',to_jsonb(visit)->>'drink_subtype',visit.drink_type_custom,to_jsonb(visit)->>'location_name',to_jsonb(visit)->>'city_state',
        private.visit_rating_screening_text_v1(to_jsonb(visit)->'ratings',to_jsonb(visit)->'category_scores'),
        private.canonical_post_screening_text_v1(visit.id)),
      'images',coalesce((select jsonb_agg(image.url order by image.url) from (
        select nullif(visit.poster_photo_url,'') as url
        union select nullif(photo.photo_url,'') from public.visit_photos photo where photo.visit_id=visit.id
      ) image where image.url is not null),'[]'::jsonb)
    ) else null end into owner_id,payload
  from public.visits visit where visit.id=p_id;
  perform private.enqueue_screening_v1('visit',p_id,owner_id,payload);
end;
$$;
create function private.refresh_reflection_screening_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then perform private.refresh_visit_screening_v1(old.visit_id);
 else perform private.refresh_visit_screening_v1(new.visit_id);end if;
 return null;
end;
$$;
revoke all on function private.refresh_reflection_screening_v1() from public,anon,authenticated;
create trigger screening_reflection_change after insert or update or delete on public.visit_v3_reflections
for each row execute function private.refresh_reflection_screening_v1();

-- Preserve the canonical criterion contract while excluding arbitrary extra
-- JSON keys from this outward projection and the associated provider input.
create function private.canonical_post_criteria_v1(p_criteria jsonb)
returns jsonb language sql immutable set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
  'id',item->'id','name',item->'name','score',item->'score','weight',item->'weight',
  'sortOrder',item->'sortOrder','relevanceOverride',item->'relevanceOverride'
 )) order by ordinal),'[]'::jsonb)
 from jsonb_array_elements(coalesce(p_criteria,'[]'::jsonb)) with ordinality c(item,ordinal);
$$;
revoke all on function private.canonical_post_criteria_v1(jsonb) from public,anon,authenticated;
do $$
declare source text;
begin
 source:=pg_get_functiondef('public.get_canonical_post_v1(uuid,text)'::regprocedure);
 if strpos(source,'''criteria'', reflection.context_criteria')=0 then raise exception 'canonical source drift';end if;
 execute replace(source,'''criteria'', reflection.context_criteria','''criteria'', private.canonical_post_criteria_v1(reflection.context_criteria)');
 source:=pg_get_functiondef('public.enrich_discovery_candidates_v1(jsonb)'::regprocedure);
 if strpos(source,'from public.cafes candidate')=0 then raise exception 'enrichment source drift';end if;
 -- Apply to the relation before the existing OR match conditions.
 source:=replace(source,'from public.cafes candidate','from (select * from public.cafes c where private.can_read_cafe_catalog_as(c.id,actor)) candidate');
 source:=replace(source,'and visit.upload_state = ''complete''','and visit.upload_state = ''complete'' and private.is_public_visit_discoverable_v3(visit.id)');
 execute source;
end;
$$;
select private.refresh_visit_screening_v1(id) from public.visits;
