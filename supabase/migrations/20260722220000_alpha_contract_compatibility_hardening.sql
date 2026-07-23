-- Preserve least-privilege client contracts after the alpha privacy cutover.

begin;

-- Supabase's default function privileges may grant EXECUTE to app roles at
-- creation time. Storage writes are signed-in only even though the wrapper is
-- also caller-bound internally.
revoke all on function public.can_write_account_storage(uuid)
  from public, anon;
grant execute on function public.can_write_account_storage(uuid)
  to authenticated;

-- V1 remains a compatibility surface for older app builds. Reuse the sealed,
-- caller-bound V2 export instead of reopening raw visit columns that were
-- intentionally removed from the Data API. The historical V1 shape is kept,
-- while the source collections come from the complete owner export.
create or replace function public.build_owner_data_export()
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  export_v2 jsonb;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  export_v2 := public.build_owner_data_export_v2();

  return jsonb_build_object(
    'schema_version', 1,
    'generated_at', export_v2 -> 'generated_at',
    'profile', coalesce(export_v2 -> 'profile', '{}'::jsonb),
    'journal_entries', coalesce(export_v2 -> 'journal_entries', '[]'::jsonb),
    'private_notes', coalesce(export_v2 -> 'private_notes', '[]'::jsonb),
    'visit_photos', coalesce(export_v2 -> 'visit_photos', '[]'::jsonb),
    'drink_analyses', coalesce(export_v2 -> 'drink_analyses', '[]'::jsonb),
    'journal_bookmarks', coalesce(export_v2 -> 'journal_bookmarks', '[]'::jsonb),
    'recipe_identities', coalesce(export_v2 -> 'recipe_identities', '[]'::jsonb),
    'taste_signals', coalesce(export_v2 -> 'taste_signals', '[]'::jsonb),
    'cafe_lists', coalesce(
      export_v2 #> '{collaboration,owned_cafe_lists}',
      '[]'::jsonb
    ),
    'friendships', coalesce(export_v2 #> '{social,friendships}', '[]'::jsonb),
    'friend_requests', coalesce(
      export_v2 #> '{social,friend_requests}',
      '[]'::jsonb
    ),
    'capture_preferences', coalesce(
      export_v2 #> '{preferences,capture}',
      '{}'::jsonb
    ),
    'reflection_preferences', coalesce(
      export_v2 #> '{preferences,reflection}',
      '{}'::jsonb
    ),
    'tasting_lens_snapshots', coalesce(
      export_v2 #> '{tasting,sensory_snapshots}',
      '[]'::jsonb
    ),
    'tasting_lens_public_projections', coalesce(
      export_v2 #> '{tasting,public_projections}',
      '[]'::jsonb
    ),
    'tasting_lens_preferences', coalesce(
      export_v2 #> '{tasting,preferences}',
      '{}'::jsonb
    ),
    'tasting_lens_corrections', coalesce(
      export_v2 #> '{tasting,corrections}',
      '[]'::jsonb
    ),
    'media_references', coalesce(export_v2 -> 'media_references', '[]'::jsonb)
  );
end;
$$;

revoke all on function public.build_owner_data_export()
  from public, anon, authenticated;
grant execute on function public.build_owner_data_export()
  to authenticated;

comment on function public.build_owner_data_export() is
  'Schema-v1 compatibility projection backed by the caller-bound V2 owner export.';

commit;
