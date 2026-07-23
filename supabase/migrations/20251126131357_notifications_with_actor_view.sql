create or replace view public.notifications_with_actor as
select
  n.id,
  n.user_id,
  n.actor_user_id,
  n.type,
  n.visit_id,
  n.comment_id,
  n.created_at,
  n.read_at,
  u.username      as actor_username,
  u.display_name  as actor_display_name,
  u.avatar_url    as actor_avatar_url
from public.notifications n
left join public.users u on u.id = n.actor_user_id;;
