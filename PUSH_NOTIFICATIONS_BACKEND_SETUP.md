# Push Notifications Backend Setup Guide

This guide provides step-by-step instructions for setting up the backend push notification system using Supabase Edge Functions and APNs.

## ⚠️ Can I Deploy This Without APNs Yet?

**Yes!** The push notification system is designed to work even without APNs configured.

If APNs environment variables are not set, the `send-push-notification` edge function will:
- ✅ Still run successfully (returns 200 OK)
- ✅ Still allow notification rows to be inserted in the database
- ✅ Simply skip sending actual push notifications
- ✅ Log a clear message: "APNs not configured – skipping push delivery but keeping notification row"

**You can fully deploy and use the system in development even before buying an Apple Developer account.** Just configure the APNs secrets later when you're ready.

---

## Prerequisites

**For immediate deployment (APNs optional):**
- Supabase Project with Edge Functions enabled
- Service role key access

**For full push notification functionality (can be added later):**
- Apple Developer Account with:
  - APNs Authentication Key (.p8 file)
  - Team ID
  - Key ID
  - App Bundle ID

## Step 1: Generate APNs Authentication Key

1. Log in to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Go to **Keys** section
4. Click **+** to create a new key
5. Name it "Mugshot Push Notifications" (or similar)
6. Enable **Apple Push Notifications service (APNs)**
7. Click **Continue** and **Register**
8. Download the `.p8` key file (you can only download it once!)
9. Note your **Key ID** (shown on the key details page)
10. Note your **Team ID** (found in the top right of the developer portal)

## Step 2: Prepare the APNs Key

You have two options for storing the key:

### Option A: Base64 Encode (Recommended)
```bash
# On macOS/Linux
base64 -i AuthKey_XXXXXXXXXX.p8 -o key_base64.txt

# Or using openssl
openssl base64 -in AuthKey_XXXXXXXXXX.p8 -out key_base64.txt
```

### Option B: Use Raw Content
You can paste the entire `.p8` file content directly (including BEGIN/END markers).

## Step 3: Deploy the Edge Function

### 3.1 Install Supabase CLI (if not already installed)

```bash
# macOS
brew install supabase/tap/supabase

# Or using npm
npm install -g supabase
```

### 3.2 Login to Supabase

```bash
supabase login
```

### 3.3 Link Your Project

```bash
cd /path/to/your/project
supabase link --project-ref your-project-ref
```

You can find your project ref in the Supabase dashboard URL: `https://app.supabase.com/project/your-project-ref`

### 3.4 Deploy the Edge Function

The edge function code is located in `supabase/functions/send-push-notification/index.ts`.

```bash
supabase functions deploy send-push-notification
```

## Step 4: Set Edge Function Secrets

Set the required environment variables as Supabase secrets:

```bash
# Required: APNs Configuration
supabase secrets set APNS_KEY_ID="YOUR_KEY_ID"
supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID"
supabase secrets set APNS_BUNDLE_ID="com.yourcompany.mugshot"  # Your app's bundle ID
supabase secrets set APNS_KEY_CONTENT="$(cat key_base64.txt)"  # Base64 encoded key, or raw .p8 content

# Required: Supabase Configuration (usually auto-set, but verify)
supabase secrets set SUPABASE_URL="https://your-project-ref.supabase.co"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"

# Optional: Use sandbox for development
supabase secrets set APNS_USE_SANDBOX="true"  # Set to "false" for production
```

### Finding Your Service Role Key

1. Go to your Supabase project dashboard
2. Navigate to **Settings** → **API**
3. Copy the **service_role** key (⚠️ Keep this secret!)

## Step 5: Enable pg_net Extension

The trigger uses `pg_net` for async HTTP requests. It should already be enabled via migration, but verify:

```sql
-- Check if pg_net is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_net';

-- If not enabled, run:
CREATE EXTENSION IF NOT EXISTS pg_net;
```

## Step 6: Configure Database Settings

The trigger function needs to know your project URL and service role key. Set these as database settings:

```sql
-- Set your project URL (replace YOUR_PROJECT_REF with your actual project ref)
-- You can find this in your Supabase dashboard URL
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';

-- Set service role key (replace with your actual service role key from Supabase dashboard)
-- Find this in: Settings → API → service_role key
ALTER DATABASE postgres SET app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
```

**Important**: These are database-level settings. Make sure to use your actual values.

## Step 7: Create Database Trigger

The trigger will automatically call the edge function when a notification is inserted.

### 7.1 Verify Trigger Function Exists

The trigger function should already be created via migration. Verify it exists:

```sql
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'send_push_notification_trigger';
```

### 7.2 Verify Trigger Exists

```sql
SELECT tgname, tgrelid::regclass 
FROM pg_trigger 
WHERE tgname = 'on_notification_insert';
```

If the trigger doesn't exist, it was created by the migration. If you need to recreate it:

Run this SQL in your Supabase SQL Editor:

```sql
-- Function to call the edge function when a notification is created
CREATE OR REPLACE FUNCTION public.send_push_notification_trigger()
RETURNS TRIGGER AS $$
DECLARE
  payload jsonb;
  response http_response;
BEGIN
  -- Build the payload with notification data
  payload := jsonb_build_object(
    'id', NEW.id,
    'user_id', NEW.user_id,
    'actor_user_id', NEW.actor_user_id,
    'type', NEW.type,
    'visit_id', NEW.visit_id,
    'comment_id', NEW.comment_id,
    'created_at', NEW.created_at
  );

  -- Call the edge function via HTTP
  -- Note: This uses Supabase's internal HTTP extension
  -- You may need to enable the http extension first:
  -- CREATE EXTENSION IF NOT EXISTS http;
  
  SELECT * INTO response
  FROM http_post(
    'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push-notification',
    payload::text,
    'application/json',
    ARRAY[
      http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)),
      http_header('Content-Type', 'application/json')
    ]
  );

  -- Log the response (optional)
  RAISE NOTICE 'Push notification trigger response: %', response;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the notification insert
    RAISE WARNING 'Failed to trigger push notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS on_notification_insert ON public.notifications;
CREATE TRIGGER on_notification_insert
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.send_push_notification_trigger();
```

### 7.3 Alternative: Manual Trigger Creation (if needed)

If `http` extension is not available, use Supabase's `pg_net` extension:

```sql
-- Enable pg_net extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Function using pg_net
CREATE OR REPLACE FUNCTION public.send_push_notification_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- Schedule the edge function call via pg_net
  PERFORM
    net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
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
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to trigger push notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS on_notification_insert ON public.notifications;
CREATE TRIGGER on_notification_insert
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.send_push_notification_trigger();
```

### 7.4 Alternative: Direct HTTP Call (if pg_net unavailable)

If neither extension works, use this simpler approach that calls the function directly:

```sql
CREATE OR REPLACE FUNCTION public.send_push_notification_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- Use Supabase's built-in function to call edge functions
  -- This requires the function to be publicly accessible or use anon key
  PERFORM
    http_request(
      'POST',
      'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push-notification',
      jsonb_build_object(
        'id', NEW.id,
        'user_id', NEW.user_id,
        'actor_user_id', NEW.actor_user_id,
        'type', NEW.type,
        'visit_id', NEW.visit_id,
        'comment_id', NEW.comment_id,
        'created_at', NEW.created_at
      )::text,
      'application/json',
      jsonb_build_object(
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
      )
    );
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to trigger push notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Important**: Replace `YOUR_PROJECT_REF` and `YOUR_SERVICE_ROLE_KEY` with your actual values.

## Step 8: Update Notification Types (if needed)

If your database uses different notification types than the iOS app expects, update the mapping in the edge function's `mapNotificationType` function, or update the database constraint to match.

Current mapping:
- Database `friend_request_accepted` → iOS `friend_accept`
- All other types map 1:1

## Step 9: Test the System

### 9.1 Test Token Registration

1. Sign in to the iOS app
2. Check Xcode console for `[Push] Device token registered successfully`
3. Verify in Supabase: `SELECT * FROM user_devices WHERE user_id = 'your-user-id'`

### 9.2 Test Push Notification

1. Create a test notification in Supabase:
```sql
INSERT INTO notifications (user_id, actor_user_id, type, visit_id)
VALUES (
  'target-user-id',
  'actor-user-id',
  'like',
  'visit-id'  -- optional
);
```

2. Check edge function logs:
```bash
supabase functions logs send-push-notification
```

3. Verify the notification appears on the device

### 9.3 Test Different Notification Types

Test each notification type:
- `like`
- `comment`
- `friend_request`
- `friend_request_accepted`
- `new_visit_from_friend`

## Step 10: Production Checklist

Before going to production:

- [ ] Set `APNS_USE_SANDBOX="false"` in edge function secrets
- [ ] Verify APNs key has production access
- [ ] Test with production APNs endpoint
- [ ] Monitor edge function logs for errors
- [ ] Set up error alerting (Supabase dashboard → Edge Functions → Logs)
- [ ] Verify RLS policies allow service role to read `user_devices`
- [ ] Test notification delivery with real devices

## Troubleshooting

### Edge Function Not Being Called

1. Check trigger exists: `SELECT * FROM pg_trigger WHERE tgname = 'on_notification_insert';`
2. Check function exists: `SELECT * FROM pg_proc WHERE proname = 'send_push_notification_trigger';`
3. Test trigger manually:
```sql
SELECT send_push_notification_trigger();
```

### APNs Authentication Errors

1. Verify key ID, team ID, and bundle ID are correct
2. Check key content is properly formatted (PEM format)
3. Verify key has APNs enabled in Apple Developer Portal
4. Check edge function logs for detailed error messages

### Notifications Not Received

1. Verify device token is in `user_devices` table
2. Check device has notifications enabled
3. Verify app is using production/sandbox endpoint correctly
4. Check APNs delivery status in Apple Developer Portal (if available)

### JWT Generation Errors

If you see JWT errors, you may need to use a different JWT library or approach. The edge function uses the `jose` library, but you can modify it to use a different method if needed.

## Alternative: Using Third-Party Services

If you prefer not to manage APNs directly, you can use services like:
- **OneSignal**: Free tier available, easy setup
- **Firebase Cloud Messaging**: Google's push service
- **Pusher Beams**: Simple push notification service

These services typically provide webhook endpoints you can call from your trigger instead of the edge function.

## Security Notes

- ⚠️ Never commit `.p8` keys or service role keys to version control
- ✅ Use Supabase secrets for all sensitive configuration
- ✅ Keep service role key secure (only use in backend)
- ✅ Regularly rotate APNs keys if compromised
- ✅ Monitor edge function logs for suspicious activity

## Next Steps

Once the backend is set up:
1. Test end-to-end notification flow
2. Monitor edge function performance
3. Set up error alerting
4. Consider adding notification preferences/user settings
5. Implement notification batching for multiple notifications

