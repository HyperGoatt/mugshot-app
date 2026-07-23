-- Create function to handle new user profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, display_name, username)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data ->> 'displayName', split_part(new.email, '@', 1)),
    COALESCE(
      new.raw_user_meta_data ->> 'username',
      lower(regexp_replace(split_part(new.email, '@', 1), '[^a-z0-9]', '', 'g')) || '_' || substr(new.id::text, 1, 4)
    )
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

-- Create trigger to fire on new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();;
