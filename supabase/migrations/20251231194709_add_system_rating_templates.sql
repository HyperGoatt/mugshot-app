-- ===========================================
-- SYSTEM RATING TEMPLATES (app-wide defaults)
-- ===========================================
CREATE TABLE public.system_rating_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_name text NOT NULL,
  applies_to_drink_type text NOT NULL,
  applies_to_brew_method text,
  category_list jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_system_default boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- RLS: everyone can read system templates
ALTER TABLE public.system_rating_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view system templates"
ON public.system_rating_templates
FOR SELECT
USING (true);

-- ===========================================
-- UPDATE USER RATING TEMPLATES (add mappings)
-- ===========================================
-- Add preferred mappings and template name
ALTER TABLE public.rating_templates
ADD COLUMN IF NOT EXISTS template_name text,
ADD COLUMN IF NOT EXISTS preferred_drink_type text,
ADD COLUMN IF NOT EXISTS preferred_brew_method text;

-- ===========================================
-- UPDATE VISITS TABLE (add template tracking)
-- ===========================================
ALTER TABLE public.visits
ADD COLUMN IF NOT EXISTS rating_template_id uuid,
ADD COLUMN IF NOT EXISTS rating_template_type text DEFAULT 'system',
ADD COLUMN IF NOT EXISTS category_scores jsonb DEFAULT '[]'::jsonb;

-- ===========================================
-- ANALYTICS EVENTS TABLE
-- ===========================================
CREATE TABLE public.analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  event_name text NOT NULL,
  event_properties jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Index for efficient querying
CREATE INDEX idx_analytics_events_user_id ON public.analytics_events(user_id);
CREATE INDEX idx_analytics_events_event_name ON public.analytics_events(event_name);
CREATE INDEX idx_analytics_events_created_at ON public.analytics_events(created_at);

-- RLS: users can only insert their own events, service role can read all
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own events"
ON public.analytics_events
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own events"
ON public.analytics_events
FOR SELECT
USING (auth.uid() = user_id);

-- ===========================================
-- SEED SYSTEM RATING TEMPLATES (V1 defaults)
-- ===========================================

-- Coffee - Generic
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Coffee Ratings', 'coffee', NULL, '["Aroma", "Body", "Acidity", "Sweetness", "Finish"]'::jsonb, 0);

-- Coffee - Espresso
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Espresso Ratings', 'coffee', 'espresso', '["Crema", "Body", "Balance", "Sweetness", "Finish"]'::jsonb, 1);

-- Coffee - Latte
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Latte Ratings', 'coffee', 'latte', '["Milk Texture", "Balance", "Temperature", "Presentation", "Overall Flavor"]'::jsonb, 2);

-- Coffee - Cappuccino
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Cappuccino Ratings', 'coffee', 'cappuccino', '["Foam Quality", "Espresso Balance", "Temperature", "Presentation"]'::jsonb, 3);

-- Coffee - Pour Over
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Pour Over Ratings', 'coffee', 'pour_over', '["Clarity", "Sweetness", "Acidity", "Body", "Finish"]'::jsonb, 4);

-- Coffee - Drip
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Drip Coffee Ratings', 'coffee', 'drip', '["Consistency", "Body", "Acidity", "Flavor Notes", "Finish"]'::jsonb, 5);

-- Coffee - French Press
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('French Press Ratings', 'coffee', 'french_press', '["Body", "Richness", "Oils", "Sediment", "Finish"]'::jsonb, 6);

-- Coffee - Cold Brew
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Cold Brew Ratings', 'coffee', 'cold_brew', '["Smoothness", "Sweetness", "Strength", "Refreshing", "Finish"]'::jsonb, 7);

-- Coffee - Aeropress
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Aeropress Ratings', 'coffee', 'aeropress', '["Clarity", "Body", "Acidity", "Sweetness", "Complexity"]'::jsonb, 8);

-- Matcha
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Matcha Ratings', 'matcha', NULL, '["Color", "Froth", "Umami", "Bitterness Balance", "Smoothness"]'::jsonb, 10);

-- Tea
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Tea Ratings', 'tea', NULL, '["Aroma", "Flavor Clarity", "Body", "Astringency", "Finish"]'::jsonb, 11);

-- Hojicha
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Hojicha Ratings', 'hojicha', NULL, '["Roast Character", "Sweetness", "Body", "Warmth", "Finish"]'::jsonb, 12);

-- Chai
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('Chai Ratings', 'chai', NULL, '["Spice Balance", "Sweetness", "Milk Integration", "Warmth", "Finish"]'::jsonb, 13);

-- General (Other)
INSERT INTO public.system_rating_templates (template_name, applies_to_drink_type, applies_to_brew_method, category_list, sort_order)
VALUES ('General Ratings', 'other', NULL, '["Presentation", "Taste", "Balance", "Value"]'::jsonb, 20);;
