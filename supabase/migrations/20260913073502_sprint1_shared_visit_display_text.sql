begin;
-- Only user-visible labels are text. Never serialize rating objects wholesale:
-- scores, weights, internal IDs and unexpected nested fields are excluded.
create function private.visit_rating_screening_text_v1(p_ratings jsonb,p_categories jsonb)
returns text language sql immutable set search_path='' as $$
  select string_agg(label,E'\n' order by label) from (
    select key as label from jsonb_object_keys(
      case when jsonb_typeof(p_ratings)='object' then p_ratings else '{}'::jsonb end
    ) key
    union
    select item->>'name' from jsonb_array_elements(
      case when jsonb_typeof(p_categories)='array' then p_categories else '[]'::jsonb end
    ) item where jsonb_typeof(item->'name')='string'
  ) labels;
$$;
revoke all on function private.visit_rating_screening_text_v1(jsonb,jsonb) from public,anon,authenticated;

create or replace function private.refresh_visit_screening_v1(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare payload jsonb; owner_id uuid;
begin
  select visit.user_id,case when visit.visibility in ('friends','everyone') and visit.upload_state='complete' then
    jsonb_build_object(
      'text',concat_ws(E'\n',visit.caption,to_jsonb(visit)->>'drink_type',to_jsonb(visit)->>'drink_subtype',visit.drink_type_custom,to_jsonb(visit)->>'location_name',to_jsonb(visit)->>'city_state',
        private.visit_rating_screening_text_v1(to_jsonb(visit)->'ratings',to_jsonb(visit)->'category_scores')),
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

commit;
