-- Create table for storing user's saved brew settings
CREATE TABLE public.user_brew_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  setting_type text NOT NULL, -- 'setup', 'brew_method', 'equipment'
  value text NOT NULL,
  usage_count integer NOT NULL DEFAULT 1,
  last_used_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(user_id, setting_type, value)
);

-- Enable RLS
ALTER TABLE public.user_brew_settings ENABLE ROW LEVEL SECURITY;

-- Users can only view their own settings
CREATE POLICY "Users can view their own brew settings"
ON public.user_brew_settings
FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own settings
CREATE POLICY "Users can insert their own brew settings"
ON public.user_brew_settings
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own settings
CREATE POLICY "Users can update their own brew settings"
ON public.user_brew_settings
FOR UPDATE
USING (auth.uid() = user_id);

-- Users can delete their own settings
CREATE POLICY "Users can delete their own brew settings"
ON public.user_brew_settings
FOR DELETE
USING (auth.uid() = user_id);

-- Create index for faster lookups
CREATE INDEX idx_user_brew_settings_user_type ON public.user_brew_settings(user_id, setting_type);
CREATE INDEX idx_user_brew_settings_usage ON public.user_brew_settings(user_id, setting_type, usage_count DESC);;
