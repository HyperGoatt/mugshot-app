-- Add parent_comment_id to support threaded replies
ALTER TABLE public.comments
ADD COLUMN parent_comment_id UUID DEFAULT NULL REFERENCES public.comments(id) ON DELETE CASCADE;

-- Create index for efficient reply fetching
CREATE INDEX idx_comments_parent_comment_id ON public.comments(parent_comment_id);

-- Create index for efficient visit + parent comment queries
CREATE INDEX idx_comments_visit_parent ON public.comments(visit_id, parent_comment_id);

COMMENT ON COLUMN public.comments.parent_comment_id IS 'References parent comment for threaded replies. NULL means top-level comment.';;
