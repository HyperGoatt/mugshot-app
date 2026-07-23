-- Add drink_subtype column to visits table
ALTER TABLE public.visits
ADD COLUMN IF NOT EXISTS drink_subtype TEXT;

-- Add comment to document the column
COMMENT ON COLUMN public.visits.drink_subtype IS 'Optional free-text field for specific drink details (e.g., "Iced vanilla latte", "Hot matcha with oat milk")';;
