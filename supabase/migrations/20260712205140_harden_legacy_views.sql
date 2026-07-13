-- Ensure legacy API views evaluate table permissions and RLS as the caller.
-- Recreating a view without SECURITY DEFINER is insufficient on modern Postgres;
-- security_invoker must be set explicitly.

alter view public.notifications_with_actor
  set (security_invoker = true);

alter view public.feedback_posts_with_counts
  set (security_invoker = true);

alter view public.feedback_comments_with_author
  set (security_invoker = true);
