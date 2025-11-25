# Push Notification System Implementation

## Overview

This document describes the push notification system implementation for Mugshot iOS app. The system integrates with Supabase for device token management and APNs for push delivery.

## Architecture

### Components

1. **Supabase `user_devices` Table**
   - Stores device push tokens per user
   - RLS policies ensure users can only manage their own devices
   - Unique constraint on `(user_id, push_token)` prevents duplicates

2. **SupabaseUserDeviceService**
   - Handles token upsert/delete operations
   - Located in `testMugshot/Services/Supabase/SupabaseUserDeviceService.swift`

3. **PushNotificationManager**
   - Manages APNs registration and authorization
   - Handles notification routing and deep linking
   - Located in `testMugshot/Services/PushNotificationManager.swift`

4. **PushNotificationPayload**
   - Parses notification payloads from APNs
   - Maps to in-app navigation targets
   - Located in `testMugshot/Models/PushNotificationPayload.swift`

5. **AppDelegate Integration**
   - Handles APNs callbacks (token registration, notification receipt)
   - Located in `testMugshot/testMugshotApp.swift`

## Push Notification Payload Format

When sending push notifications from the backend (Supabase Edge Function or external service), use this payload format:

```json
{
  "aps": {
    "alert": {
      "title": "Notification Title",
      "body": "Notification message"
    },
    "sound": "default",
    "badge": 1
  },
  "type": "like" | "comment" | "new_visit_from_friend" | "friend_request" | "friend_accept" | "friend_join",
  "actor_username": "username",
  "actor_avatar_url": "https://...",
  "visit_id": "uuid-string" (optional, for visit-related notifications),
  "friend_user_id": "uuid-string" (optional, for friend-related notifications),
  "cafe_name": "Cafe Name" (optional, for visit-related notifications),
  "tap_action": "visit_detail" | "friend_profile" | "friends_feed" | "notifications"
}
```

### Notification Types

- `new_visit_from_friend`: Friend posted a new visit
- `like`: Someone liked your visit
- `comment`: Someone commented on your visit
- `friend_request`: Someone sent you a friend request
- `friend_accept`: Someone accepted your friend request
- `friend_join`: A friend joined Mugshot (optional)

### Tap Actions

- `visit_detail`: Navigate to visit detail screen (requires `visit_id`)
- `friend_profile`: Navigate to friend's profile (requires `friend_user_id`)
- `friends_feed`: Navigate to Friends feed tab
- `notifications`: Open notifications center

## iOS-Side Flow

### Registration Flow

1. User signs in or completes profile setup
2. `DataManager.registerPushNotificationsIfNeeded()` is called
3. `PushNotificationManager.requestAuthorizationAndRegister()` requests permissions
4. If granted, `UIApplication.shared.registerForRemoteNotifications()` is called
5. AppDelegate receives device token via `didRegisterForRemoteNotifications(deviceToken:)`
6. Token is sent to Supabase via `SupabaseUserDeviceService.upsertDeviceToken()`

### Notification Handling

#### App in Foreground
- Notification is received via `UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:)`
- Badge is updated, notification is logged
- No banner shown (can be enhanced in future)

#### App in Background/Closed
- User taps notification
- `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:)` is called
- Payload is parsed and routed to appropriate screen via `TabCoordinator`

## Deep Linking

Navigation targets are handled by `TabCoordinator`:

- **Visit Detail**: Switches to Feed tab, finds visit, navigates to detail
- **Friend Profile**: Switches to appropriate tab, shows profile sheet
- **Friends Feed**: Switches to Feed tab, sets scope to "Friends"
- **Notifications**: Opens notifications center sheet

## Backend Integration (TODO)

The actual push delivery from Supabase is not yet implemented. To complete the system:

1. Create a Supabase Edge Function or use a third-party service (OneSignal, Firebase, etc.)
2. Set up a database trigger on `notifications` table insert
3. Query `user_devices` table for target user's tokens
4. Send push notification via APNs with the payload format above

Example trigger (PostgreSQL):

```sql
-- This is a placeholder - actual implementation depends on your push service
CREATE OR REPLACE FUNCTION send_push_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- TODO: Implement actual push sending logic
  -- 1. Query user_devices for NEW.user_id
  -- 2. Call APNs or third-party service
  -- 3. Use payload format documented above
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_notification_insert
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION send_push_notification();
```

## Testing

### Manual Testing Steps

1. **Token Registration**
   - Sign in to the app
   - Check Xcode console for `[Push] Device token registered successfully`
   - Verify token appears in Supabase `user_devices` table

2. **Notification Receipt**
   - Send a test notification via APNs (using device token)
   - Verify app handles notification correctly:
     - Foreground: Badge updates, no banner
     - Background: Tapping notification navigates to correct screen
     - Closed: App launches and navigates to correct screen

3. **Deep Linking**
   - Test each `tap_action` type
   - Verify navigation works correctly for all scenarios

## Logging

All push notification operations are logged with `[Push]` prefix:
- `[Push] Requesting notification authorization...`
- `[Push] Device token registered successfully`
- `[Push] Notification received in foreground`
- `[Push] Routing to visit detail: ...`

## Future Enhancements

- In-app notification banner when app is in foreground
- Notification grouping/batching
- Rich notifications with images
- Notification actions (quick reply, etc.)
- Notification preferences/settings

