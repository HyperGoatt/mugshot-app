-- Create function to trigger push notifications via edge function
-- This uses Supabase's pg_net extension to call the edge function

-- Function to call the edge function when a notification is created
CREATE OR REPLACE FUNCTION public.send_push_notification_trigger()
RETURNS TRIGGER AS $$
DECLARE
  edge_function_url text;
  service_role_key text;
  project_url text;
BEGIN
  -- Get the Supabase project URL
  -- In production, you should set this as a database setting or use a constant
  -- For now, we'll construct it from the current database
  -- You may need to replace this with your actual project URL
  project_url := current_setting('app.settings.supabase_url', true);

  -- If not set, construct from database name (fallback)
  IF project_url IS NULL OR project_url = '' THEN
    -- Extract project ref from database name if possible
    -- Otherwise, you'll need to set this manually
    project_url := 'https://YOUR_PROJECT_REF.supabase.co';
  END IF;

  edge_function_url := project_url || '/functions/v1/send-push-notification';

  -- Get service role key from settings (you'll need to set this)
  service_role_key := current_setting('app.settings.service_role_key', true);

  -- If pg_net is available, use it (preferred method)
  BEGIN
    PERFORM
      net.http_post(
        url := edge_function_url,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || COALESCE(service_role_key, 'YOUR_SERVICE_ROLE_KEY')
        ),
        body := jsonb_build_object(
          'id', NEW.id,
          'user_id', NEW.user_id,
          'actor_user_id', NEW.actor_user_id,
          'type', NEW.type,
          'visit_id', NEW.visit_id,
          'comment_id', NEW.comment_id,
          'created_at', NEW.created_at
        )::text
      );
  EXCEPTION
    WHEN OTHERS THEN
      -- If pg_net fails, log and continue (notification insert should still succeed)
      RAISE WARNING 'pg_net not available or failed: %. Push notification may not be sent.', SQLERRM;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.send_push_notification_trigger() TO authenticated;

-- Create the trigger
DROP TRIGGER IF EXISTS on_notification_insert ON public.notifications;
CREATE TRIGGER on_notification_insert
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.send_push_notification_trigger();

-- Add comment for documentation
COMMENT ON FUNCTION public.send_push_notification_trigger() IS
  'Triggers push notification via edge function when a notification is inserted. Requires edge function to be deployed and configured with APNs secrets.';;
