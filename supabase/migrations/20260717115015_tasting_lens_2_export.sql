-- Extend the existing account export. This remains security-invoker so table
-- RLS is the final guard even if a future export query is edited incorrectly.
create or replace function public.build_owner_data_export()
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  return jsonb_build_object(
    'schema_version', 1,
    'generated_at', now(),
    'profile', coalesce((select to_jsonb(profile) from public.users profile where profile.id = actor), '{}'::jsonb),
    'journal_entries', coalesce((select jsonb_agg(to_jsonb(visit) order by visit.created_at, visit.id) from public.visits visit where visit.user_id = actor), '[]'::jsonb),
    'private_notes', coalesce((select jsonb_agg(to_jsonb(note) order by note.created_at, note.visit_id) from public.visit_private_notes note where note.user_id = actor), '[]'::jsonb),
    'visit_photos', coalesce((select jsonb_agg(to_jsonb(photo) order by photo.created_at, photo.sort_order) from public.visit_photos photo join public.visits visit on visit.id = photo.visit_id where visit.user_id = actor), '[]'::jsonb),
    'drink_analyses', coalesce((select jsonb_agg(to_jsonb(analysis) order by analysis.created_at, analysis.visit_id) from public.visit_drink_analyses analysis where analysis.user_id = actor), '[]'::jsonb),
    'journal_bookmarks', coalesce((select jsonb_agg(to_jsonb(bookmark) order by bookmark.created_at, bookmark.visit_id) from public.visit_bookmarks bookmark where bookmark.user_id = actor), '[]'::jsonb),
    'recipe_identities', coalesce((select jsonb_agg(to_jsonb(identity) || jsonb_build_object('versions', coalesce((select jsonb_agg(to_jsonb(version) order by version.version_number) from public.recipe_versions version where version.recipe_identity_id = identity.id), '[]'::jsonb)) order by identity.created_at, identity.id) from public.recipe_identities identity where identity.user_id = actor), '[]'::jsonb),
    'taste_signals', coalesce((select jsonb_agg(to_jsonb(signal) order by signal.updated_at, signal.id) from public.taste_signals signal where signal.user_id = actor), '[]'::jsonb),
    'cafe_lists', coalesce((select jsonb_agg(to_jsonb(listing) || jsonb_build_object('items', coalesce((select jsonb_agg(to_jsonb(item) order by item.position, item.created_at, item.id) from public.cafe_list_items item where item.list_id = listing.id), '[]'::jsonb), 'members', coalesce((select jsonb_agg(to_jsonb(member) order by member.created_at, member.user_id) from public.cafe_list_members member where member.list_id = listing.id), '[]'::jsonb)) order by listing.created_at, listing.id) from public.cafe_lists listing where listing.owner_id = actor), '[]'::jsonb),
    'friendships', coalesce((select jsonb_agg(to_jsonb(friendship) order by friendship.created_at, friendship.id) from public.friends friendship where friendship.user_id = actor or friendship.friend_user_id = actor), '[]'::jsonb),
    'friend_requests', coalesce((select jsonb_agg(to_jsonb(request) order by request.created_at, request.id) from public.friend_requests request where request.from_user_id = actor or request.to_user_id = actor), '[]'::jsonb),
    'capture_preferences', coalesce((select to_jsonb(preference) from public.user_capture_preferences preference where preference.user_id = actor), '{}'::jsonb),
    'reflection_preferences', coalesce((select to_jsonb(preference) from public.user_reflection_preferences preference where preference.user_id = actor), '{}'::jsonb),
    'tasting_lens_snapshots', coalesce((select jsonb_agg(to_jsonb(snapshot) order by snapshot.created_at, snapshot.visit_id) from public.visit_sensory_snapshots snapshot where snapshot.user_id = actor), '[]'::jsonb),
    'tasting_lens_public_projections', coalesce((select jsonb_agg(to_jsonb(projection) order by projection.created_at, projection.visit_id) from public.visit_sensory_public_projections projection where projection.user_id = actor), '[]'::jsonb),
    'tasting_lens_preferences', coalesce((select to_jsonb(preference) from public.tasting_lens_preferences preference where preference.user_id = actor), '{}'::jsonb),
    'tasting_lens_corrections', coalesce((select jsonb_agg(to_jsonb(correction) order by correction.created_at, correction.id) from public.tasting_lens_corrections correction where correction.user_id = actor), '[]'::jsonb),
    'media_references', coalesce((select jsonb_agg(distinct media.url) from (select photo.photo_url as url from public.visit_photos photo join public.visits visit on visit.id = photo.visit_id where visit.user_id = actor union all select profile.avatar_url from public.users profile where profile.id = actor and profile.avatar_url is not null union all select profile.banner_url from public.users profile where profile.id = actor and profile.banner_url is not null) media where media.url is not null and btrim(media.url) <> ''), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.build_owner_data_export() from public, anon;
grant execute on function public.build_owner_data_export() to authenticated;
