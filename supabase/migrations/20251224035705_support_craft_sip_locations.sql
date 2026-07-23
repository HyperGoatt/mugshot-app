-- Make cafe_id nullable to support Craft Sips (non-cafe visits)
ALTER TABLE public.visits
  ALTER COLUMN cafe_id DROP NOT NULL;

-- Add a check constraint to ensure either cafe_id or location_name is provided
-- (visits must have some location context)
ALTER TABLE public.visits
  ADD CONSTRAINT visit_has_location
  CHECK (cafe_id IS NOT NULL OR (location_name IS NOT NULL AND location_name != ''));;
