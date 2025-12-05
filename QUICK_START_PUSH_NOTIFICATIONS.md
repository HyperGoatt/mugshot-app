# Quick Start: Push Notifications Backend

This is a condensed guide for setting up push notifications. For detailed instructions, see `PUSH_NOTIFICATIONS_BACKEND_SETUP.md`.

## ⚠️ Deploy Without APNs?

**Yes!** You can deploy the edge function now without APNs configured. It will work fine - notifications will be stored but no push will be sent until you add APNs secrets later.

---

## Prerequisites Checklist

**Required for deployment:**
- [ ] Supabase project (Edge Functions enabled)
- [ ] Service role key access

**Optional (can add later):**
- [ ] Apple Developer Account
- [ ] APNs Authentication Key (.p8 file)
- [ ] Key ID, Team ID, Bundle ID

## 5-Minute Setup

### 1. Get APNs Key from Apple Developer Portal
- Go to https://developer.apple.com/account/
- Certificates → Keys → Create new key
- Enable "Apple Push Notifications service (APNs)"
- Download `.p8` file (only once!)
- Note Key ID and Team ID

### 2. Deploy Edge Function

```bash
# From project root
supabase functions deploy send-push-notification
```

### 3. Set Secrets

**Required secrets (set these now):**
```bash
supabase secrets set SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
```

**APNs secrets (can skip for now, add later when you have Apple Developer account):**
```bash
# Base64 encode your .p8 key
base64 -i AuthKey_XXXXXXXXXX.p8 -o key_base64.txt

# Set APNs secrets (skip these until you have Apple Developer account)
supabase secrets set APNS_KEY_ID="YOUR_KEY_ID"
supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID"
supabase secrets set APNS_BUNDLE_ID="com.yourcompany.mugshot"
supabase secrets set APNS_KEY_CONTENT="$(cat key_base64.txt)"
supabase secrets set APNS_USE_SANDBOX="true"  # "false" for production
```

**Note:** Without APNs secrets, the function will still work but won't send push notifications. It will log "APNs not configured" and return successfully.

### 4. Configure Database

```sql
-- Set project URL and service role key
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';
ALTER DATABASE postgres SET app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
```

### 5. Verify Setup

```sql
-- Check trigger exists
SELECT tgname FROM pg_trigger WHERE tgname = 'on_notification_insert';

-- Test with a notification insert
INSERT INTO notifications (user_id, actor_user_id, type)
VALUES ('user-id'::uuid, 'actor-id'::uuid, 'like');
```

### 6. Check Logs

```bash
supabase functions logs send-push-notification --follow
```

## Troubleshooting

**Function not called?**
- Check trigger exists (SQL above)
- Verify database settings are set
- Check function logs

**APNs errors?**
- Verify Key ID, Team ID, Bundle ID
- Check key content is correct
- Ensure key has APNs enabled

**No notifications received?**
- Verify device token in `user_devices` table
- Check device has notifications enabled
- Verify sandbox vs production endpoint

## Next Steps

1. Test with real device
2. Switch to production (`APNS_USE_SANDBOX="false"`)
3. Monitor function logs
4. Set up error alerting

For detailed instructions, see `PUSH_NOTIFICATIONS_BACKEND_SETUP.md`.

