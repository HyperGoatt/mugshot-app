-- Stable keyset pagination for the global visible-visit feed. The cafe-leading
-- index serves cafe detail; this index serves created_at/id feed cursors.
create index if not exists visits_complete_created_id_idx
  on public.visits (created_at desc, id desc)
  include (user_id, cafe_id, visibility, overall_score)
  where upload_state = 'complete';
;
