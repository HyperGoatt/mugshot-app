-- Update handle_new_user to better handle username conflicts
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  base_username TEXT;
  final_username TEXT;
  suffix INT := 0;
BEGIN
  -- Generate base username
  base_username := COALESCE(
    new.raw_user_meta_data ->> 'username',
    lower(regexp_replace(split_part(new.email, '@', 1), '[^a-z0-9]', '', 'g')) || '_' || substr(new.id::text, 1, 4)
  );
  final_username := base_username;

  -- Check for username uniqueness and add suffix if needed
  WHILE EXISTS (SELECT 1 FROM public.users WHERE username = final_username) LOOP
    suffix := suffix + 1;
    final_username := base_username || suffix::text;
  END LOOP;

  INSERT INTO public.users (id, display_name, username)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data ->> 'displayName', split_part(new.email, '@', 1)),
    final_username
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN new;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't block signup
  RAISE WARNING 'handle_new_user failed for user %: %', new.id, SQLERRM;
  RETURN new;
END;
$$;;
