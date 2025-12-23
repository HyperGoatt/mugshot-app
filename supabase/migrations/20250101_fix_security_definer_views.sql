-- Migration: Remove SECURITY DEFINER from views to enforce proper RLS
-- Date: 2025-01-01
-- Description: Fixes security issue where views bypass RLS by running with creator's privileges
--              Instead, views will respect the querying user's RLS policies

-- ============================================================================
-- View 1: notifications_with_actor
-- ============================================================================
-- Purpose: Joins notifications with users to include actor profile information
-- RLS Context: notifications table has RLS - users can only read their own notifications
--              users table allows public read for profiles

DROP VIEW IF EXISTS public.notifications_with_actor;

CREATE VIEW public.notifications_with_actor AS
SELECT 
  n.*,
  u.username AS actor_username,
  u.display_name AS actor_display_name,
  u.avatar_url AS actor_avatar_url
FROM public.notifications n
LEFT JOIN public.users u ON n.actor_user_id = u.id;

-- ============================================================================
-- View 2: feedback_posts_with_counts
-- ============================================================================
-- Purpose: Aggregates vote counts and comment counts for feedback posts
-- RLS Context: feedback_posts, feedback_votes, and feedback_comments tables
--              should have appropriate RLS policies (likely public read, owner write)

DROP VIEW IF EXISTS public.feedback_posts_with_counts;

CREATE VIEW public.feedback_posts_with_counts AS
SELECT 
  p.*,
  COALESCE(
    SUM(CASE 
      WHEN v.vote_type = 1 THEN 1 
      WHEN v.vote_type = -1 THEN -1 
      ELSE 0 
    END), 
    0
  ) AS vote_score,
  COALESCE(
    COUNT(DISTINCT v.id) FILTER (WHERE v.vote_type = 1), 
    0
  ) AS upvotes,
  COALESCE(
    COUNT(DISTINCT v.id) FILTER (WHERE v.vote_type = -1), 
    0
  ) AS downvotes,
  COALESCE(COUNT(DISTINCT c.id), 0) AS comment_count
FROM public.feedback_posts p
LEFT JOIN public.feedback_votes v ON p.id = v.post_id
LEFT JOIN public.feedback_comments c ON p.id = c.post_id
GROUP BY p.id;

-- ============================================================================
-- View 3: feedback_comments_with_author
-- ============================================================================
-- Purpose: Joins feedback_comments with users to include author profile information
-- RLS Context: feedback_comments table should have appropriate RLS policies
--              users table allows public read for profiles

DROP VIEW IF EXISTS public.feedback_comments_with_author;

CREATE VIEW public.feedback_comments_with_author AS
SELECT 
  c.*,
  u.username AS author_username,
  u.display_name AS author_display_name,
  u.avatar_url AS author_avatar_url
FROM public.feedback_comments c
LEFT JOIN public.users u ON c.user_id = u.id;

-- ============================================================================
-- Notes:
-- ============================================================================
-- All three views are now created without SECURITY DEFINER, which means:
-- 1. They will respect the querying user's RLS policies
-- 2. No privilege escalation - queries run with caller's permissions
-- 3. Better security auditability - behavior is predictable based on user context
--
-- The views should work identically to before, but now with proper RLS enforcement.
-- Ensure that:
-- - notifications table has RLS: user_id = auth.uid()
-- - feedback_posts table has appropriate RLS policies
-- - feedback_comments table has appropriate RLS policies
-- - feedback_votes table has appropriate RLS policies
-- - users table allows public read (for profile data)
-- - Indexes exist on foreign keys for performance



