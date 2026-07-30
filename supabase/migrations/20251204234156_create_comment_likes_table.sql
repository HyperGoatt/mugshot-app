-- Create table to track likes on comments
CREATE TABLE public.comment_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES public.comments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Prevent duplicate likes
    CONSTRAINT unique_comment_like UNIQUE(comment_id, user_id)
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

COMMENT ON TABLE public.comment_likes IS 'Tracks which users liked which comments';;
