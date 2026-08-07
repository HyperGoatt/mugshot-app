-- Support every discovery V1 foreign key used for cascades, moderation,
-- ownership cleanup, and attribution lookups. These indexes are additive and
-- do not expose any table through the Data API.

create index if not exists discovery_interactions_cafe_idx
  on public.discovery_interactions (cafe_id)
  where cafe_id is not null;

create index if not exists discovery_interactions_source_list_idx
  on public.discovery_interactions (source_list_id)
  where source_list_id is not null;

create index if not exists mugshot_discovery_attributions_cafe_idx
  on public.mugshot_discovery_attributions (cafe_id);

create index if not exists mugshot_discovery_attributions_interaction_idx
  on public.mugshot_discovery_attributions (interaction_id)
  where interaction_id is not null;

create index if not exists cafe_list_share_links_creator_idx
  on public.cafe_list_share_links (created_by);

create index if not exists cafe_list_comments_author_idx
  on public.cafe_list_comments (user_id);

create index if not exists cafe_list_comments_deleted_by_idx
  on public.cafe_list_comments (deleted_by)
  where deleted_by is not null;

create index if not exists cafe_list_comment_reports_reporter_idx
  on public.cafe_list_comment_reports (reporter_id);
