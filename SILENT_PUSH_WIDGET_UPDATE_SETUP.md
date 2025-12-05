# Silent Push Notifications for Widget Updates

This document describes how to set up automatic widget updates when friends post new visits, using silent push notifications.

## Overview

When a user posts a new visit, we send **silent push notifications** to all their friends. These notifications:
- Don't show any visible alert, sound, or badge
- Wake the iOS app briefly in the background
- Trigger the app to fetch latest friend visits and update the widget

## Architecture

```
Friend posts visit → Supabase DB → Database Webhook → Edge Function → APNs (silent push)
                                                                          ↓
iOS Widget ← Widget Data Sync ← DataManager ← PushNotificationManager ← iOS App (background)
```

## Setup Steps

### 1. Deploy the Edge Function

Deploy the `notify-friends-new-visit` Edge Function to your Supabase project:

```bash
cd supabase/functions
supabase functions deploy notify-friends-new-visit
```

### 2. Configure APNs Secrets

Set the required secrets for APNs authentication (same as `send-push-notification`):

```bash
supabase secrets set APNS_KEY_ID="your_key_id"
supabase secrets set APNS_TEAM_ID="your_team_id"
supabase secrets set APNS_BUNDLE_ID="co.mugshot.app"
supabase secrets set APNS_KEY_CONTENT="base64_encoded_p8_key"
supabase secrets set APNS_USE_SANDBOX="true"  # Use "false" for production
```

### 3. Create Database Webhook

Go to **Supabase Dashboard → Database → Webhooks** and create a new webhook:

| Setting | Value |
|---------|-------|
| **Name** | `notify-friends-on-new-visit` |
| **Table** | `visits` |
| **Events** | ☑️ Insert |
| **Type** | Supabase Edge Function |
| **Function** | `notify-friends-new-visit` |
| **HTTP Headers** | (Optional) Add `Authorization: Bearer <service_role_key>` if needed |

#### Webhook Payload Format

The webhook will send this payload to the Edge Function:

```json
{
  "type": "INSERT",
  "table": "visits",
  "record": {
    "id": "uuid-of-visit",
    "user_id": "uuid-of-author",
    "cafe_id": "uuid-of-cafe",
    "visibility": "everyone",
    "created_at": "2024-01-15T10:30:00Z"
  },
  "schema": "public",
  "old_record": null
}
```

### 4. iOS App Configuration

#### Enable Background Modes

In Xcode, ensure your app has the "Remote notifications" background mode enabled:

1. Select your app target
2. Go to **Signing & Capabilities**
3. Add **Background Modes** if not present
4. Check **Remote notifications**

#### Info.plist

Ensure your `Info.plist` includes:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### 5. Test the Integration

#### Test Scenario

1. **User A** (@joe) and **User B** (@coffeelovingKev) are friends
2. **User B** posts a new visit
3. **User A's** device should:
   - Receive a silent push notification
   - Fetch latest friend visits in background
   - Update the widget data
   - Widget should show User B's new visit

#### Debug Logging

Check Xcode console for these log messages:

```
[AppDelegate] 📱 Received SILENT push for widget update
[Push] 📱 Processing silent push for widget update
[Push] Silent push details - visit_id: xxx, author_id: xxx
[Push] Fetching latest friend visits...
[Push] Syncing widget data...
[Push] Reloading widget timelines...
✅ [Push] Widget update complete - friend visits refreshed
```

#### Edge Function Logs

Check Supabase Edge Function logs:

```
[SilentPush] Processing new visit: xxx by user xxx...
[SilentPush] Found 5 friends to notify
[SilentPush] Sending to 3 devices
[SilentPush] Sent 3/3 silent pushes successfully
```

## Silent Push Payload Format

The Edge Function sends this silent push payload:

```json
{
  "aps": {
    "content-available": 1
  },
  "type": "widget_update",
  "visit_id": "uuid-of-new-visit",
  "author_id": "uuid-of-author",
  "action": "refresh_friend_visits"
}
```

Key characteristics:
- `content-available: 1` marks it as a silent/background notification
- No `alert`, `sound`, or `badge` fields
- `apns-push-type: background` header
- `apns-priority: 5` (low priority, required for silent)

## iOS Background Limitations

### Important Notes

1. **Background execution time is limited** - iOS gives ~30 seconds max
2. **Silent pushes are rate-limited** - iOS may throttle if too many are sent
3. **Low Power Mode** - Silent pushes may be delayed or dropped
4. **App must be launched at least once** after install to receive pushes

### Best Practices

- Keep background work minimal and fast
- Handle failures gracefully
- Don't rely on silent push for critical updates
- Regular app opens will also sync widget data (fallback)

## Troubleshooting

### Widget Not Updating

1. **Check device token** - Ensure user's device is registered in `user_devices` table
2. **Check friends table** - Verify friendship exists between users
3. **Check APNs config** - Verify all APNS_* secrets are set correctly
4. **Check logs** - Look at Edge Function logs for errors
5. **Check iOS logs** - Look for `[Push]` logs in Xcode console

### Silent Push Not Received

1. **Background refresh disabled** - User may have disabled background app refresh
2. **App killed by user** - Swipe-to-kill prevents background wakeups
3. **Low Power Mode** - May delay/prevent silent notifications
4. **Throttling** - Too many silent pushes may be rate-limited

### APNs Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `BadDeviceToken` | Invalid or expired token | Remove token from DB, user will re-register |
| `Unregistered` | App uninstalled | Remove token from DB |
| `InvalidProviderToken` | JWT auth failed | Check APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_CONTENT |
| `TooManyRequests` | Rate limited | Reduce push frequency |

## Manual Testing via API

You can trigger the Edge Function directly for testing:

```bash
curl -X POST "https://your-project.supabase.co/functions/v1/notify-friends-new-visit" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "author_id": "uuid-of-test-user",
    "visit_id": "uuid-of-test-visit",
    "visibility": "everyone"
  }'
```

## Related Files

- `supabase/functions/notify-friends-new-visit/index.ts` - Edge Function
- `testMugshot/testMugshotApp.swift` - AppDelegate handling
- `testMugshot/Services/PushNotificationManager.swift` - Silent push handler
- `testMugshot/Services/DataManager.swift` - Widget sync logic
- `MugshotWidgets/Widgets/FriendsLatestSipsWidget.swift` - Widget implementation

