create or replace function private.refresh_visit_screening_v1(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare payload jsonb; owner_id uuid;
begin
  select visit.user_id,case when visit.visibility in ('friends','everyone') and visit.upload_state='complete' then
    jsonb_build_object(
      'text',concat_ws(E'\n',visit.caption,to_jsonb(visit)->>'drink_type',to_jsonb(visit)->>'drink_subtype',visit.drink_type_custom,to_jsonb(visit)->>'location_name'),
      'images',coalesce((select jsonb_agg(image.url order by image.url) from (
        select nullif(visit.poster_photo_url,'') as url
        union select nullif(photo.photo_url,'') from public.visit_photos photo where photo.visit_id=visit.id
      ) image where image.url is not null),'[]'::jsonb)
    ) else null end into owner_id,payload
  from public.visits visit where visit.id=p_id;
  perform private.enqueue_screening_v1('visit',p_id,owner_id,payload);
end;
$$;

-- Recompute admitted shared text without calling the provider. Existing
-- approval is retained only if the exact screenable payload is unchanged.
do $$declare target uuid;begin
  for target in select id from public.visits where visibility in ('friends','everyone') loop
    perform private.refresh_visit_screening_v1(target);
  end loop;
end;$$;
