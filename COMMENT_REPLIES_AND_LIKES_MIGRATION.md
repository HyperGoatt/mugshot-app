# Comment Replies and Likes Database Setup

## Overview

This document describes the database changes needed to support:
1. **Reply threads** - Comments can reply to other comments
2. **Comment likes** - Users can like comments

---

## Migration 1: Add Reply Thread Support to Comments

### Changes to `comments` Table

Add a new column to support parent-child relationships:

```sql
-- Migration: add_comment_parent_relationship
-- Description: Add parent_comment_id to support threaded replies

ALTER TABLE public.comments
ADD COLUMN parent_comment_id UUID DEFAULT NULL REFERENCES public.comments(id) ON DELETE CASCADE;

-- Create index for efficient reply fetching
CREATE INDEX idx_comments_parent_comment_id ON public.comments(parent_comment_id);

-- Create index for efficient visit + parent comment queries
CREATE INDEX idx_comments_visit_parent ON public.comments(visit_id, parent_comment_id);

COMMENT ON COLUMN public.comments.parent_comment_id IS 'References parent comment for threaded replies. NULL means top-level comment.';
```

**Schema After Migration**:
- `parent_comment_id` (UUID, nullable, foreign key to comments.id)
  - `NULL` = top-level comment
  - `UUID` = reply to that comment
- `ON DELETE CASCADE` = when parent comment is deleted, replies are also deleted
- Indexes for efficient querying

---

## Migration 2: Create Comment Likes Table

### New `comment_likes` Table

Create a new table similar to the existing `likes` table but for comments:

```sql
-- Migration: create_comment_likes_table
-- Description: Create table to track likes on comments

CREATE TABLE public.comment_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES public.comments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Prevent duplicate likes
    CONSTRAINT unique_comment_like UNIQUE(comment_id, user_id),
    
    -- Prevent self-liking (optional - can be enabled if desired)
    -- CONSTRAINT no_self_like CHECK (user_id != (SELECT user_id FROM comments WHERE id = comment_id))
);

-- Indexes for efficient querying
CREATE INDEX idx_comment_likes_comment_id ON public.comment_likes(comment_id);
CREATE INDEX idx_comment_likes_user_id ON public.comment_likes(user_id);
CREATE INDEX idx_comment_likes_created_at ON public.comment_likes(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Policy 1: Anyone can view comment likes (for like counts)
CREATE POLICY "Anyone can view comment likes"
ON public.comment_likes
FOR SELECT
USING (true);

-- Policy 2: Authenticated users can like comments
CREATE POLICY "Users can create their own comment likes"
ON public.comment_likes
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy 3: Users can unlike their own comments
CREATE POLICY "Users can delete their own comment likes"
ON public.comment_likes
FOR DELETE
USING (auth.uid() = user_id);

COMMENT ON TABLE public.comment_likes IS 'Tracks which users liked which comments';
```

**Schema**:
- `id` (UUID, primary key)
- `comment_id` (UUID, foreign key to comments.id)
- `user_id` (UUID, foreign key to auth.users.id)
- `created_at` (TIMESTAMPTZ)
- Unique constraint on `(comment_id, user_id)` - one like per user per comment
- Cascading deletes when comment or user is deleted

**RLS Policies**:
- ✅ Anyone can view likes (needed for like counts)
- ✅ Authenticated users can create likes for themselves
- ✅ Users can delete their own likes

---

## Database Functions (Optional but Recommended)

### Function: Get Comment Like Count

```sql
-- Function to efficiently get like count for a comment
CREATE OR REPLACE FUNCTION get_comment_like_count(comment_id_param UUID)
RETURNS BIGINT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COUNT(*) FROM public.comment_likes WHERE comment_id = comment_id_param;
$$;

GRANT EXECUTE ON FUNCTION get_comment_like_count TO authenticated, anon;
```

### Function: Check if User Liked Comment

```sql
-- Function to check if a user liked a comment
CREATE OR REPLACE FUNCTION has_user_liked_comment(comment_id_param UUID, user_id_param UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS(
        SELECT 1 FROM public.comment_likes 
        WHERE comment_id = comment_id_param AND user_id = user_id_param
    );
$$;

GRANT EXECUTE ON FUNCTION has_user_liked_comment TO authenticated, anon;
```

---

## Updated Comment Count Logic

When counting comments for a visit, you'll want to count ALL comments (including replies):

```sql
-- This query already works correctly since all comments have visit_id
SELECT COUNT(*) FROM comments WHERE visit_id = 'visit-uuid';
```

To get only top-level comments:
```sql
SELECT COUNT(*) FROM comments WHERE visit_id = 'visit-uuid' AND parent_comment_id IS NULL;
```

To get reply count for a specific comment:
```sql
SELECT COUNT(*) FROM comments WHERE parent_comment_id = 'comment-uuid';
```

---

## Migration Order

Apply these migrations in order:

1. **add_comment_parent_relationship** - Adds reply support to comments table
2. **create_comment_likes_table** - Creates comment likes table with RLS policies

---

## Testing the Schema

### Verify Tables and Columns

```sql
-- Check comments table has new column
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'comments' 
AND column_name = 'parent_comment_id';

-- Check comment_likes table exists
SELECT table_name, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND table_name = 'comment_likes';

-- Check indexes
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename IN ('comments', 'comment_likes')
AND schemaname = 'public';
```

### Verify RLS Policies

```sql
-- Check comment_likes policies
SELECT tablename, policyname, cmd, qual
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'comment_likes';
```

---

## App Integration Notes

### Updated Comment Model

The `Comment` struct needs:
- `parent_comment_id: UUID?` - for reply threading
- `likeCount: Int` - total likes
- `isLikedByCurrentUser: Bool` - has current user liked it
- `replyCount: Int` - number of replies (optional, for "View X replies" UI)

### Updated RemoteComment Model

The `RemoteComment` struct needs:
- `parentCommentId: UUID?` - for reply threading
- `likes: [RemoteCommentLike]?` - array of likes (from join)

### Service Layer Updates

The `SupabaseVisitService` needs new methods:
- `addCommentLike(commentId:userId:)` - Like a comment
- `removeCommentLike(commentId:userId:)` - Unlike a comment
- `addReply(visitId:parentCommentId:text:userId:)` - Add a reply to a comment

### UI Updates

- Display replies indented under parent comments
- Show "Reply" button on comments
- Show like button (heart icon) with count
- Show "View X replies" / "Hide replies" toggle for long threads

---

## Data Migration Considerations

### Existing Comments

All existing comments will have `parent_comment_id = NULL`, making them top-level comments. No data migration needed - they'll work automatically.

### Backward Compatibility

The changes are fully backward compatible:
- Old comments work as top-level comments
- Comment count queries still work
- No breaking changes to existing functionality

---

## Performance Considerations

### Indexes Created

1. `idx_comments_parent_comment_id` - Fast lookup of replies for a comment
2. `idx_comments_visit_parent` - Fast lookup of comments + filtering by parent
3. `idx_comment_likes_comment_id` - Fast like count aggregation
4. `idx_comment_likes_user_id` - Fast user like lookups
5. `idx_comment_likes_created_at` - Fast chronological ordering

### Query Optimization

For feed queries, fetch comments with likes in a single query:

```sql
SELECT 
    c.*,
    COUNT(cl.id) as like_count,
    COALESCE(
        (SELECT true FROM comment_likes WHERE comment_id = c.id AND user_id = auth.uid()),
        false
    ) as is_liked_by_current_user
FROM comments c
LEFT JOIN comment_likes cl ON cl.comment_id = c.id
WHERE c.visit_id = 'visit-uuid'
GROUP BY c.id
ORDER BY c.created_at ASC;
```

---

## Next Steps

1. ✅ Design schema (this document)
2. ⏳ Apply migrations to Supabase database
3. ⏳ Update Swift models
4. ⏳ Update service layer
5. ⏳ Build UI components
6. ⏳ Test functionality

