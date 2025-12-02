# Send Push Notification Edge Function

This Supabase Edge Function sends push notifications to iOS devices via APNs when notifications are created in the database.

## ⚠️ APNs Configuration is Optional

**You can deploy this function without APNs configured!**

If APNs secrets are not set, the function will:
- ✅ Still run successfully (returns 200 OK)
- ✅ Allow notification rows to be inserted
- ✅ Log: "APNs not configured – skipping push delivery but keeping notification row"
- ✅ Return: `{ "status": "ok", "message": "APNs not configured; notification stored but no push sent." }`

**Deploy now, add APNs secrets later when you have an Apple Developer account.**

---

## Setup Instructions

### 1. Deploy the Function

```bash
supabase functions deploy send-push-notification
```

### 2. Set Required Secrets

**Required (set these now):**
```bash
# Supabase Configuration
supabase secrets set SUPABASE_URL="https://your-project-ref.supabase.co"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
```

**APNs Configuration (optional - can skip for now):**
```bash
# Only set these when you have an Apple Developer account
supabase secrets set APNS_KEY_ID="YOUR_KEY_ID"
supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID"
supabase secrets set APNS_BUNDLE_ID="com.yourcompany.mugshot"
supabase secrets set APNS_KEY_CONTENT="$(cat path/to/your/key.p8 | base64)"
supabase secrets set APNS_USE_SANDBOX="true"  # "false" for production
```

**Note:** Without APNs secrets, the function will work but won't send push notifications. It will gracefully skip APNs and return successfully.

### 3. Update Database Trigger

The trigger function needs to know your project URL and service role key. Update the function:

```sql
-- Set your project URL (replace YOUR_PROJECT_REF)
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';

-- Set service role key (replace YOUR_SERVICE_ROLE_KEY)
ALTER DATABASE postgres SET app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
```

**Note**: These settings are database-level and will persist. Make sure to use your actual values.

### 4. Test the Function

Test manually:

```sql
-- Insert a test notification
INSERT INTO notifications (user_id, actor_user_id, type, visit_id)
VALUES (
  'target-user-id'::uuid,
  'actor-user-id'::uuid,
  'like',
  'visit-id'::uuid  -- optional
);
```

Check function logs:

```bash
supabase functions logs send-push-notification --follow
```

## Function Details

### Input

The function receives a JSON payload from the database trigger:

```json
{
  "id": "uuid",
  "user_id": "uuid",
  "actor_user_id": "uuid",
  "type": "like" | "comment" | "friend_request" | etc.,
  "visit_id": "uuid" | null,
  "comment_id": "uuid" | null,
  "created_at": "timestamp"
}
```

### Process

1. Fetches user's iOS device tokens from `user_devices` table
2. Fetches actor user info (username, avatar) from `users` table
3. Fetches visit info (cafe name) if `visit_id` is present
4. Maps notification type to iOS-friendly format
5. Determines tap action based on notification type
6. Builds APNs payload
7. Sends push notification to all user's iOS devices

### Output

```json
{
  "success": true,
  "sent": 2,
  "failed": 0
}
```

## APNs Configuration

### Getting Your APNs Key

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles** → **Keys**
3. Create a new key with **Apple Push Notifications service (APNs)** enabled
4. Download the `.p8` file (you can only download once!)
5. Note the **Key ID** and your **Team ID**

### Key Format

The `APNS_KEY_CONTENT` secret can be:
- Base64 encoded key content
- Raw `.p8` file content (including BEGIN/END markers)

The function will handle both formats.

## Troubleshooting

### Function Not Being Called

1. Check trigger exists: `SELECT * FROM pg_trigger WHERE tgname = 'on_notification_insert';`
2. Check function logs: `supabase functions logs send-push-notification`
3. Test trigger manually (see SQL above)

### APNs Errors

Common errors:
- **401 Unauthorized**: Check Key ID, Team ID, and key content
- **403 Forbidden**: Key doesn't have APNs enabled or wrong bundle ID
- **400 Bad Request**: Invalid payload format

Check edge function logs for detailed error messages.

### JWT Errors

If you see JWT generation errors, the `jose` library import may be failing. The function uses:

```typescript
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";
```

If this fails, you may need to:
1. Check Deno version compatibility
2. Use a different JWT library
3. Pre-generate JWTs and store them

## Production Checklist

- [ ] Set `APNS_USE_SANDBOX="false"`
- [ ] Verify APNs key has production access
- [ ] Test with production APNs endpoint
- [ ] Monitor function logs
- [ ] Set up error alerting
- [ ] Verify database trigger is working
- [ ] Test with real devices

## Security

- Never commit `.p8` keys to version control
- Use Supabase secrets for all sensitive data
- Keep service role key secure
- Regularly rotate APNs keys if needed
- Monitor function logs for suspicious activity

