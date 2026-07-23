-- Add equipment and visibility columns to visits table for Craft Sip
ALTER TABLE public.visits
ADD COLUMN IF NOT EXISTS equipment text,
ADD COLUMN IF NOT EXISTS brew_method_visible boolean NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS equipment_visible boolean NOT NULL DEFAULT true;;
