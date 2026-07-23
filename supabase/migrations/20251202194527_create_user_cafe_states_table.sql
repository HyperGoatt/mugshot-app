-- Create user_cafe_states table to persist favorites and want_to_try flags
CREATE TABLE IF NOT EXISTS public.user_cafe_states (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    cafe_id uuid NOT NULL REFERENCES public.cafes(id) ON DELETE CASCADE,
    is_favorite boolean NOT NULL DEFAULT false,
    want_to_try boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    -- Ensure one state per user per cafe
    UNIQUE(user_id, cafe_id)
);

-- Create index for fast lookups by user
CREATE INDEX IF NOT EXISTS idx_user_cafe_states_user_id ON public.user_cafe_states(user_id);

-- Enable RLS
ALTER TABLE public.user_cafe_states ENABLE ROW LEVEL SECURITY;

-- RLS policies: Users can only access their own cafe states
CREATE POLICY "Users can view their own cafe states" ON public.user_cafe_states
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own cafe states" ON public.user_cafe_states
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own cafe states" ON public.user_cafe_states
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own cafe states" ON public.user_cafe_states
    FOR DELETE USING (auth.uid() = user_id);;
