-- Feedback Posts table
CREATE TABLE public.feedback_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('bug', 'feature', 'general')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Feedback Votes table (upvote/downvote)
CREATE TABLE public.feedback_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.feedback_posts(id) ON DELETE CASCADE,
    vote_type SMALLINT NOT NULL CHECK (vote_type IN (1, -1)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, post_id)
);

-- Feedback Comments table
CREATE TABLE public.feedback_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.feedback_posts(id) ON DELETE CASCADE,
    parent_comment_id UUID REFERENCES public.feedback_comments(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for performance
CREATE INDEX idx_feedback_posts_user_id ON public.feedback_posts(user_id);
CREATE INDEX idx_feedback_posts_category ON public.feedback_posts(category);
CREATE INDEX idx_feedback_posts_created_at ON public.feedback_posts(created_at DESC);
CREATE INDEX idx_feedback_votes_post_id ON public.feedback_votes(post_id);
CREATE INDEX idx_feedback_votes_user_id ON public.feedback_votes(user_id);
CREATE INDEX idx_feedback_comments_post_id ON public.feedback_comments(post_id);
CREATE INDEX idx_feedback_comments_parent ON public.feedback_comments(parent_comment_id);

-- Enable RLS
ALTER TABLE public.feedback_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback_comments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for feedback_posts
CREATE POLICY "Anyone can view feedback posts" ON public.feedback_posts
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own feedback posts" ON public.feedback_posts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own feedback posts" ON public.feedback_posts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own feedback posts" ON public.feedback_posts
    FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for feedback_votes
CREATE POLICY "Anyone can view feedback votes" ON public.feedback_votes
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own votes" ON public.feedback_votes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own votes" ON public.feedback_votes
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own votes" ON public.feedback_votes
    FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for feedback_comments
CREATE POLICY "Anyone can view feedback comments" ON public.feedback_comments
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own comments" ON public.feedback_comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own comments" ON public.feedback_comments
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own comments" ON public.feedback_comments
    FOR DELETE USING (auth.uid() = user_id);

-- View: feedback_posts_with_counts (joins posts with vote totals and comment counts)
CREATE OR REPLACE VIEW public.feedback_posts_with_counts AS
SELECT
    fp.id,
    fp.user_id,
    fp.title,
    fp.body,
    fp.category,
    fp.created_at,
    fp.updated_at,
    u.username AS author_username,
    u.display_name AS author_display_name,
    u.avatar_url AS author_avatar_url,
    COALESCE(SUM(fv.vote_type), 0)::INTEGER AS vote_score,
    COUNT(DISTINCT CASE WHEN fv.vote_type = 1 THEN fv.id END)::INTEGER AS upvotes,
    COUNT(DISTINCT CASE WHEN fv.vote_type = -1 THEN fv.id END)::INTEGER AS downvotes,
    COUNT(DISTINCT fc.id)::INTEGER AS comment_count
FROM public.feedback_posts fp
LEFT JOIN public.users u ON fp.user_id = u.id
LEFT JOIN public.feedback_votes fv ON fp.id = fv.post_id
LEFT JOIN public.feedback_comments fc ON fp.id = fc.post_id
GROUP BY fp.id, fp.user_id, fp.title, fp.body, fp.category, fp.created_at, fp.updated_at,
         u.username, u.display_name, u.avatar_url;

-- View: feedback_comments_with_author (joins comments with user profile info)
CREATE OR REPLACE VIEW public.feedback_comments_with_author AS
SELECT
    fc.id,
    fc.user_id,
    fc.post_id,
    fc.parent_comment_id,
    fc.text,
    fc.created_at,
    u.username AS author_username,
    u.display_name AS author_display_name,
    u.avatar_url AS author_avatar_url
FROM public.feedback_comments fc
LEFT JOIN public.users u ON fc.user_id = u.id;;
