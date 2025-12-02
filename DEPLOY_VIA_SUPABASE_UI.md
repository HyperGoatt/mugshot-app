# Deploy Push Notification Function via Supabase Web UI

This guide walks you through deploying the `send-push-notification` edge function using **only the Supabase web dashboard** (no CLI required).

## Prerequisites

- Supabase project with Edge Functions enabled
- Access to your Supabase project dashboard
- The function code from `supabase/functions/send-push-notification/index.ts`

## Step-by-Step Instructions

### Step 1: Open Edge Functions in Supabase Dashboard

1. Go to [https://app.supabase.com](https://app.supabase.com)
2. Sign in and select your project
3. In the left sidebar, click **Edge Functions** (under "Project Settings" or in the main navigation)
   - If you don't see "Edge Functions", it may be under **Functions** or **Functions (Edge Functions)**

### Step 2: Create New Function

1. Click the **"New Function"** or **"Create Function"** button (usually top-right)
2. You'll see a function editor interface

### Step 3: Name the Function

1. In the function name field, enter: `send-push-notification`
   - This must match exactly (lowercase, hyphens allowed)
   - No spaces or special characters

### Step 4: Paste Function Code

1. Open the file `supabase/functions/send-push-notification/index.ts` in your code editor
2. Select all the code (Cmd+A / Ctrl+A)
3. Copy it (Cmd+C / Ctrl+C)
4. In the Supabase UI function editor, delete any default/template code
5. Paste your code (Cmd+V / Ctrl+V)

### Step 5: Save/Deploy the Function

1. Look for a **"Deploy"**, **"Save"**, or **"Create Function"** button (usually bottom-right or top-right)
2. Click it to deploy the function
3. Wait for deployment to complete (you should see a success message)

### Step 6: Configure Environment Variables (Secrets)

1. In the Edge Functions page, find your `send-push-notification` function
2. Click on it to open function details
3. Look for a **"Secrets"**, **"Environment Variables"**, or **"Settings"** tab/section
   - This may be in a sidebar, tabs at the top, or a settings icon

#### Set Required Secrets (Do This Now)

Click **"Add Secret"** or **"New Secret"** and add these two:

1. **Secret Name**: `SUPABASE_URL`
   - **Value**: `https://YOUR_PROJECT_REF.supabase.co`
   - Replace `YOUR_PROJECT_REF` with your actual project reference
   - You can find this in your Supabase dashboard URL or in Settings → API

2. **Secret Name**: `SUPABASE_SERVICE_ROLE_KEY`
   - **Value**: Your service role key
   - Find this in: **Settings** → **API** → **service_role** key (under "Project API keys")
   - ⚠️ Keep this secret! Never share it publicly.

#### APNs Secrets (Skip For Now - Add Later)

When you have an Apple Developer account, you'll add these secrets:

- `APNS_KEY_ID` - Your APNs Key ID
- `APNS_TEAM_ID` - Your Apple Team ID  
- `APNS_BUNDLE_ID` - Your app bundle ID (e.g., `com.yourcompany.mugshot`)
- `APNS_KEY_CONTENT` - Your .p8 key file content (base64 encoded or raw)
- `APNS_USE_SANDBOX` - Set to `"true"` for development, `"false"` for production

**For now, leave these blank.** The function will work fine without them - it will just skip sending push notifications and log a message.

### Step 7: Verify Function is Deployed

1. In the Edge Functions page, you should see `send-push-notification` listed
2. It should show status as **"Active"** or **"Deployed"**
3. You may see an **"Invoke"** or **"Test"** button - you can use this to test later

### Step 8: View Function Logs

1. Click on the `send-push-notification` function
2. Look for a **"Logs"** tab or section
3. This is where you'll see function execution logs

### Step 9: Test the Function (Optional)

To verify it's working:

1. **Via Database Trigger** (automatic):
   - Insert a test notification in your database:
   ```sql
   INSERT INTO notifications (user_id, actor_user_id, type)
   VALUES ('some-user-id'::uuid, 'some-actor-id'::uuid, 'like');
   ```
   - Check the function logs - you should see:
     - `[Push] Processing notification: ...`
     - `[Push] APNs not configured – skipping push delivery but keeping notification row.`

2. **Via Manual Invoke** (if available):
   - Click **"Invoke"** or **"Test"** button in the function details
   - Use this JSON payload:
   ```json
   {
     "id": "00000000-0000-0000-0000-000000000001",
     "user_id": "00000000-0000-0000-0000-000000000002",
     "actor_user_id": "00000000-0000-0000-0000-000000000003",
     "type": "like",
     "visit_id": null,
     "comment_id": null,
     "created_at": "2024-01-01T00:00:00Z"
   }
   ```
   - Check logs for the "APNs not configured" message

### Step 10: Verify Expected Behavior

When the function runs without APNs configured, you should see in the logs:

```
[Push] Processing notification: <id>, type: <type>, user_id: <user_id>
[Push] APNs not configured – skipping push delivery but keeping notification row.
[Push] To enable push notifications, configure APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, and APNS_KEY_CONTENT secrets.
```

And the function should return:
```json
{
  "status": "ok",
  "message": "APNs not configured; notification stored but no push sent.",
  "apns_configured": false
}
```

## Troubleshooting

### Function Not Appearing After Deploy

- Refresh the page
- Check for error messages in the UI
- Verify function name has no spaces or special characters

### Can't Find Secrets/Environment Variables Section

- Look for a **gear icon** ⚙️ or **settings icon** next to the function
- Check if there's a **"Configuration"** tab
- Some UIs have secrets in a separate **"Secrets"** page (check left sidebar)

### Function Returns Error

- Check the **Logs** tab for detailed error messages
- Verify `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are set correctly
- Make sure your project reference in the URL is correct

### Database Trigger Not Calling Function

- Verify the trigger exists: Run this SQL in the SQL Editor:
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgname = 'on_notification_insert';
  ```
- Check database settings are configured (see `PUSH_NOTIFICATIONS_BACKEND_SETUP.md` Step 6)

## Next Steps

Once deployed:

1. ✅ Function is deployed and working (without APNs)
2. ✅ Notifications will be stored in database
3. ✅ No push notifications will be sent (until APNs is configured)
4. 🔜 When ready: Add APNs secrets to enable push delivery

## Adding APNs Later

When you have an Apple Developer account:

1. Go back to Edge Functions → `send-push-notification` → Secrets
2. Add the 5 APNs secrets listed above
3. The function will automatically start sending push notifications
4. No redeployment needed - just add the secrets!

---

**That's it!** Your function is now deployed and ready to use. The database trigger will automatically call it when notifications are inserted, and it will gracefully skip push delivery until APNs is configured.

