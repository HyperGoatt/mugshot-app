# notify-friends-new-visit

Sends silent push notifications to all friends when a user posts a new visit.
This enables automatic widget updates without showing visible notifications.

## Purpose

When a user posts a new visit, this function:
1. Fetches all friends of the visit author
2. Gets device tokens for those friends
3. Sends silent APNs notifications to trigger widget updates

## Trigger

This function is triggered by a **Database Webhook** on the `visits` table INSERT event.

## Payload Format

### From Database Webhook

```json
{
  "type": "INSERT",
  "table": "visits",
  "record": {
    "id": "uuid",
    "user_id": "uuid",
    "cafe_id": "uuid",
    "visibility": "everyone",
    "created_at": "timestamp"
  }
}
```

### Direct API Call

```json
{
  "author_id": "uuid",
  "visit_id": "uuid",
  "visibility": "everyone"
}
```

## Required Secrets

Same as `send-push-notification`:
- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_BUNDLE_ID`
- `APNS_KEY_CONTENT`
- `APNS_USE_SANDBOX`

## Response

```json
{
  "success": true,
  "friends_count": 5,
  "devices_count": 3,
  "sent": 3,
  "failed": 0
}
```

## Silent Push Payload Sent to iOS

```json
{
  "aps": {
    "content-available": 1
  },
  "type": "widget_update",
  "visit_id": "uuid",
  "author_id": "uuid",
  "action": "refresh_friend_visits"
}
```

