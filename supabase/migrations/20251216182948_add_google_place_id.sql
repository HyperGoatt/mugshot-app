-- Add google_place_id column to cafes table for PWA search integration
ALTER TABLE public.cafes ADD COLUMN google_place_id TEXT UNIQUE;

-- Create index for fast lookups by google_place_id
CREATE INDEX idx_cafes_google_place_id ON public.cafes(google_place_id);;
