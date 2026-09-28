-- Existing iOS clients require numeric coordinates in top_cafes. A cafe may
-- legitimately have no geocode, so omit only that optional legacy summary.
-- The cafe and its Mugshots remain in the dedicated profile collections.
create or replace function private.profile_projection_v4(
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
begin
  if not private.profile_owner_visible_v2(p_owner, p_viewer) then
    return null;
  end if;

  result := private.profile_projection_v3(p_owner, p_viewer);
  if result is null then
    return null;
  end if;

  result := jsonb_set(
    result,
    '{top_cafes}',
    coalesce((
      select jsonb_agg(cafe.value order by cafe.ordinality)
      from jsonb_array_elements(result->'top_cafes')
        with ordinality as cafe(value, ordinality)
      where jsonb_typeof(cafe.value->'latitude') = 'number'
        and jsonb_typeof(cafe.value->'longitude') = 'number'
    ), '[]'::jsonb),
    true
  );

  return jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          result - 'highlight',
          '{stats}',
          private.profile_public_stats_v1(p_owner),
          true
        ),
        '{favorite_spots}',
        private.profile_favorite_spots_v1(p_owner),
        true
      ),
      '{friends_on_profile}',
      to_jsonb(private.profile_shows_friends_v1(p_owner)),
      true
    ),
    '{profile_contract_version}',
    '4'::jsonb,
    true
  );
end;
$$;
