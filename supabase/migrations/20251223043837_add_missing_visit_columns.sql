-- Migration: Add missing columns to visits table
-- Description: Adds location_name, brew_method, context_type, and city_state to the visits table
-- to align with the database schema documentation and app requirements.

ALTER TABLE public.visits
ADD COLUMN IF NOT EXISTS location_name TEXT NULL,
ADD COLUMN IF NOT EXISTS brew_method TEXT NULL,
ADD COLUMN IF NOT EXISTS context_type TEXT NOT NULL DEFAULT 'Cafe',
ADD COLUMN IF NOT EXISTS city_state TEXT NULL;

-- Add comment to the columns for documentation
COMMENT ON COLUMN public.visits.location_name IS 'Location or event name for locationless visits';
COMMENT ON COLUMN public.visits.brew_method IS 'Specific brew method used (V60, Espresso, etc.)';
COMMENT ON COLUMN public.visits.context_type IS 'Context of the visit (Cafe, Home, Event, etc.)';
COMMENT ON COLUMN public.visits.city_state IS 'General location (City, State) for locationless visits';
;
