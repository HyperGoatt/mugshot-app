# Mugshot Database Schema Documentation

## Overview

Mugshot uses **Supabase (PostgreSQL)** as its backend database. The schema is designed to support a social journaling app for cafe visits, with features including user profiles, cafe tracking, visit logging, social interactions (likes, comments, friends), notifications, and push notifications.

**Database System:** PostgreSQL (via Supabase)  
**Authentication:** Supabase Auth (users table in `auth.users`, profiles in `public.users`)  
**Storage:** Supabase Storage (for photos)  
**Real-time:** Supabase Realtime subscriptions  
**Edge Functions:** Supabase Edge Functions for push notifications

---

## Schema Conventions

- **Primary Keys:** All tables use `UUID` for primary keys (except where noted)
- **Timestamps:** All tables include `created_at` and `updated_at` timestamps (timestamptz)
- **Foreign Keys:** Use snake_case with `_id` suffix (e.g., `user_id`, `cafe_id`)
- **Naming:** Table and column names use snake_case
- **RLS (Row Level Security):** Enabled on all tables for data isolation
- **Soft Deletes:** Not used - records are permanently deleted

---

## Core Tables

### 1. `users` (User Profiles)

Stores user profile information. Linked to Supabase Auth via `id` (UUID matching `auth.users.id`).

**Table:** `public.users`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, REFERENCES `auth.users(id)` | User ID (matches Supabase Auth) |
| `display_name` | TEXT | NOT NULL | User's display name |
| `username` | TEXT | NOT NULL, UNIQUE | Username (lowercase, unique) |
| `bio` | TEXT | NULL | User biography |
| `location` | TEXT | NULL | User location (free text) |
| `favorite_drink` | TEXT | NULL | User's self-declared favorite drink |
| `instagram_handle` | TEXT | NULL | Instagram username/handle |
| `website_url` | TEXT | NULL | Personal website URL |
| `avatar_url` | TEXT | NULL | URL to profile avatar (Supabase Storage) |
| `banner_url` | TEXT | NULL | URL to profile banner (Supabase Storage) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Account creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `username` (UNIQUE) - For username lookups and uniqueness
- `id` (PRIMARY KEY)

**RLS Policies:**
- Users can read all profiles (public data)
- Users can update only their own profile
- Users can insert their own profile on signup

**Notes:**
- `id` must match `auth.users.id` from Supabase Auth
- `username` is stored in lowercase for consistency
- Profile photos are stored in Supabase Storage, URLs stored here

---

### 2. `cafes` (Cafe Locations)

Stores cafe/coffee shop information and locations.

**Table:** `public.cafes`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | Cafe ID |
| `name` | TEXT | NOT NULL | Cafe name |
| `address` | TEXT | NULL | Street address |
| `city` | TEXT | NULL | City name |
| `country` | TEXT | NULL | Country name |
| `latitude` | DOUBLE PRECISION | NULL | Latitude coordinate |
| `longitude` | DOUBLE PRECISION | NULL | Longitude coordinate |
| `apple_place_id` | TEXT | NULL, UNIQUE | Apple Maps place identifier |
| `website_url` | TEXT | NULL | Cafe website URL |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `id` (PRIMARY KEY)
- `apple_place_id` (UNIQUE) - For deduplication via Apple Maps
- `(name, city)` - For name+city lookups

**RLS Policies:**
- All users can read cafes (public data)
- All users can insert cafes (when logging visits)
- Only system can update cafes

**Notes:**
- Cafes are created automatically when users log visits
- Deduplication logic: Check by `apple_place_id`, then by `name + city`
- Coordinates stored separately (latitude/longitude) for PostGIS compatibility if needed

---

### 3. `visits` (Cafe Visits)

Core table storing user visits to cafes with ratings, photos, and metadata.

**Table:** `public.visits`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | Visit ID |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | User who made the visit |
| `cafe_id` | UUID | NOT NULL, REFERENCES `cafes(id)` | Cafe visited |
| `drink_type` | TEXT | NULL | Drink type (Coffee, Matcha, Tea, etc.) |
| `drink_type_custom` | TEXT | NULL | Custom drink type if "Other" selected |
| `drink_subtype` | TEXT | NULL | Specific drink name (e.g., "Iced vanilla latte") |
| `caption` | TEXT | NOT NULL | Public caption (200 char limit enforced in app) |
| `notes` | TEXT | NULL | Private notes (only visible to author) |
| `visibility` | TEXT | NOT NULL, DEFAULT 'private' | Visibility: 'private', 'friends', 'everyone' |
| `ratings` | JSONB | NOT NULL, DEFAULT '{}' | Rating categories → scores (e.g., {"Taste": 4.5, "Ambiance": 3.0}) |
| `overall_score` | DOUBLE PRECISION | NOT NULL | Weighted average of ratings |
| `poster_photo_url` | TEXT | NULL | URL of the main/poster photo |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Visit timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `id` (PRIMARY KEY)
- `user_id` - For user profile queries
- `cafe_id` - For cafe detail queries
- `created_at DESC` - For feed ordering
- `(user_id, created_at DESC)` - For user journal queries
- `(visibility, created_at DESC)` - For feed filtering

**RLS Policies:**
- Users can read:
  - Their own visits (all visibility levels)
  - Friends' visits (if visibility = 'friends' or 'everyone')
  - Everyone's visits (if visibility = 'everyone')
- Users can insert only their own visits
- Users can update/delete only their own visits

**Notes:**
- `ratings` is JSONB for flexible rating categories per user
- `overall_score` is pre-calculated for efficient sorting/filtering
- `visibility` controls feed appearance and friend notifications
- `notes` field is private and never shown to other users

---

### 4. `visit_photos` (Visit Photos)

Stores photos associated with visits. Photos are stored in Supabase Storage, URLs stored here.

**Table:** `public.visit_photos`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | Photo ID |
| `visit_id` | UUID | NOT NULL, REFERENCES `visits(id) ON DELETE CASCADE` | Parent visit |
| `photo_url` | TEXT | NOT NULL | URL to photo in Supabase Storage |
| `sort_order` | INTEGER | NOT NULL, DEFAULT 0 | Display order (0 = first) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Upload timestamp |

**Indexes:**
- `id` (PRIMARY KEY)
- `visit_id` - For fetching all photos for a visit
- `(visit_id, sort_order)` - For ordered photo retrieval

**RLS Policies:**
- Users can read photos for visits they can read (same as visits RLS)
- Users can insert photos only for their own visits
- Users can delete photos only from their own visits

**Notes:**
- Cascade delete: Deleting a visit deletes all associated photos
- `sort_order` determines display order (0 = poster photo)
- Up to 10 photos per visit (enforced in app)

---

### 5. `likes` (Visit Likes)

Tracks which users liked which visits.

**Table:** `public.likes`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | Like ID |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | User who liked |
| `visit_id` | UUID | NOT NULL, REFERENCES `visits(id) ON DELETE CASCADE` | Visit that was liked |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Like timestamp |

**Indexes:**
- `id` (PRIMARY KEY)
- `(user_id, visit_id)` (UNIQUE) - Prevent duplicate likes
- `visit_id` - For counting likes per visit
- `user_id` - For user activity queries

**RLS Policies:**
- Users can read all likes (public data)
- Users can insert likes (only their own)
- Users can delete likes (only their own)

**Notes:**
- Unique constraint prevents duplicate likes
- Cascade delete: Deleting a visit deletes all its likes
- Like count is computed via aggregation, not stored

---

### 6. `comments` (Visit Comments)

Stores comments on visits. Supports nested replies via `parent_comment_id`.

**Table:** `public.comments`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | Comment ID |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | Comment author |
| `visit_id` | UUID | NOT NULL, REFERENCES `visits(id) ON DELETE CASCADE` | Parent visit |
| `text` | TEXT | NOT NULL | Comment text |
| `parent_comment_id` | UUID | NULL, REFERENCES `comments(id) ON DELETE CASCADE` | Parent comment (for replies) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Comment timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last edit timestamp |

**Indexes:**
- `id` (PRIMARY KEY)
- `visit_id` - For fetching comments per visit
- `parent_comment_id` - For reply threading
- `(visit_id, created_at ASC)` - For chronological ordering
- `user_id` - For user activity queries

**RLS Policies:**
- Users can read comments for visits they can read
- Users can insert comments (only their own)
- Users can update/delete only their own comments

**Notes:**
- Supports nested replies (one level: comment → reply)
- Cascade delete: Deleting a visit deletes all comments
- Cascade delete: Deleting a comment deletes all replies
- `updated_at` tracks edits (users can edit their own comments)

---

### 7. `comment_likes` (Comment Likes)

Tracks which users liked which comments.

**Table:** `public.comment_likes`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | Comment like ID |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | User who liked |
| `comment_id` | UUID | NOT NULL, REFERENCES `comments(id) ON DELETE CASCADE` | Comment that was liked |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Like timestamp |

**Indexes:**
- `id` (PRIMARY KEY)
- `(user_id, comment_id)` (UNIQUE) - Prevent duplicate likes
- `comment_id` - For counting likes per comment

**RLS Policies:**
- Users can read all comment likes
- Users can insert comment likes (only their own)
- Users can delete comment likes (only their own)

**Notes:**
- Similar structure to `likes` table
- Cascade delete: Deleting a comment deletes all its likes

---

## Social Graph Tables

### 8. `follows` (Follow Relationships)

One-way follow relationships (legacy/optional - friends system is primary).

**Table:** `public.follows`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `follower_id` | UUID | NOT NULL, REFERENCES `users(id)` | User who follows |
| `followee_id` | UUID | NOT NULL, REFERENCES `users(id)` | User being followed |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Follow timestamp |

**Indexes:**
- `(follower_id, followee_id)` (PRIMARY KEY, UNIQUE) - Composite primary key
- `follower_id` - For "who I follow" queries
- `followee_id` - For "who follows me" queries

**RLS Policies:**
- Users can read all follows (public data)
- Users can insert follows (only as follower)
- Users can delete follows (only their own)

**Notes:**
- One-way relationship (not bidirectional)
- Used as fallback for friends if explicit friendships don't exist
- Composite primary key prevents duplicate follows

---

### 9. `friend_requests` (Friend Requests)

Manages friend request workflow (pending → accepted/rejected).

**Table:** `public.friend_requests`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | Request ID |
| `from_user_id` | UUID | NOT NULL, REFERENCES `users(id)` | User who sent request |
| `to_user_id` | UUID | NOT NULL, REFERENCES `users(id)` | User who received request |
| `status` | TEXT | NOT NULL, DEFAULT 'pending' | Status: 'pending', 'accepted', 'rejected' |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Request timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Status change timestamp |

**Indexes:**
- `id` (PRIMARY KEY)
- `(from_user_id, to_user_id, status)` (UNIQUE) - Prevent duplicate pending requests
- `from_user_id` - For outgoing requests
- `to_user_id` - For incoming requests
- `(to_user_id, status)` - For pending incoming requests

**RLS Policies:**
- Users can read:
  - Requests they sent (from_user_id = auth.uid())
  - Requests they received (to_user_id = auth.uid())
- Users can insert requests (only as from_user_id)
- Users can update requests (only as to_user_id, to accept/reject)
- Users can delete requests (only their own)

**Notes:**
- Unique constraint allows only one pending request per pair
- When accepted, creates bidirectional entries in `friends` table
- Status changes update `updated_at` timestamp

---

### 10. `friends` (Friend Relationships)

Bidirectional friend relationships. Created when friend request is accepted.

**Table:** `public.friends`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | User |
| `friend_user_id` | UUID | NOT NULL, REFERENCES `users(id)` | Friend |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Friendship timestamp |

**Indexes:**
- `(user_id, friend_user_id)` (PRIMARY KEY, UNIQUE) - Composite primary key
- `user_id` - For "my friends" queries
- `friend_user_id` - For reverse lookups

**RLS Policies:**
- Users can read friends (public data)
- System creates friends (via edge function/trigger on friend request acceptance)
- Users can delete friendships (remove both directions)

**Notes:**
- **Bidirectional:** When A and B become friends, two rows are created:
  - `(user_id=A, friend_user_id=B)`
  - `(user_id=B, friend_user_id=A)`
- Composite primary key prevents duplicates
- Both directions must be deleted to unfriend
- Created automatically when friend request is accepted

---

## Notification Tables

### 11. `notifications` (User Notifications)

Stores in-app notifications for social interactions.

**Table:** `public.notifications`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | Notification ID |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | Notification recipient |
| `actor_user_id` | UUID | NOT NULL, REFERENCES `users(id)` | User who triggered notification |
| `type` | TEXT | NOT NULL | Type: 'new_visit_from_friend', 'like', 'comment', 'reply', 'mention', 'friend_request', 'friend_accept', 'friend_join', 'system' |
| `visit_id` | UUID | NULL, REFERENCES `visits(id) ON DELETE SET NULL` | Related visit (if applicable) |
| `comment_id` | UUID | NULL, REFERENCES `comments(id) ON DELETE SET NULL` | Related comment (if applicable) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Notification timestamp |
| `read_at` | TIMESTAMPTZ | NULL | Read timestamp (NULL = unread) |

**Indexes:**
- `id` (PRIMARY KEY)
- `user_id` - For user notification queries
- `(user_id, created_at DESC)` - For notification feed
- `(user_id, read_at)` - For unread count queries
- `actor_user_id` - For actor profile joins

**RLS Policies:**
- Users can read only their own notifications
- System creates notifications (via triggers/edge functions)
- Users can update `read_at` (mark as read)
- Users can delete their own notifications

**Notes:**
- `read_at` is NULL for unread, set to timestamp when read
- Cascade set NULL: Deleting visit/comment doesn't delete notification, just clears reference
- Notifications are created via database triggers or edge functions

---

### 12. `user_devices` (Push Notification Devices)

Stores device tokens for push notifications (APNs for iOS).

**Table:** `public.user_devices`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | Device ID |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | Device owner |
| `push_token` | TEXT | NOT NULL | APNs device token |
| `platform` | TEXT | NOT NULL, DEFAULT 'ios' | Platform: 'ios', 'android' (future) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Registration timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `id` (PRIMARY KEY)
- `(user_id, push_token)` (UNIQUE) - One token per user per device
- `user_id` - For fetching all devices for a user
- `platform` - For platform-specific queries

**RLS Policies:**
- Users can read only their own devices
- Users can insert/update/delete only their own devices

**Notes:**
- Unique constraint: One token per user per device
- Tokens are upserted (create or update if exists)
- Tokens should be deleted on logout/uninstall
- Used by edge functions to send push notifications

---

## User Preferences Tables

### 13. `rating_templates` (Custom Rating Templates)

Stores user-customizable rating categories and weights.

**Table:** `public.rating_templates`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | Template ID |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)`, UNIQUE | User (one template per user) |
| `template_json` | JSONB | NOT NULL, DEFAULT '{}' | Rating categories → weights (e.g., {"Taste": 1.0, "Ambiance": 1.5}) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `id` (PRIMARY KEY)
- `user_id` (UNIQUE) - One template per user

**RLS Policies:**
- Users can read all templates (for reference)
- Users can insert/update only their own template
- Users can delete only their own template

**Notes:**
- `template_json` stores category names as keys, weights as values
- Default template: {"Presentation": 1.0, "Value": 1.0, "Taste": 1.0, "Ambiance": 1.0}
- Weights are multipliers (normalized during overall score calculation)
- One template per user (enforced by UNIQUE constraint)

---

### 14. `user_cafe_states` (User Cafe Preferences)

Tracks user's favorite and wishlist cafes.

**Table:** `public.user_cafe_states`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, DEFAULT gen_random_uuid() | State ID |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | User |
| `cafe_id` | UUID | NOT NULL, REFERENCES `cafes(id) ON DELETE CASCADE` | Cafe |
| `is_favorite` | BOOLEAN | NOT NULL, DEFAULT false | Favorite flag |
| `want_to_try` | BOOLEAN | NOT NULL, DEFAULT false | Wishlist flag |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `id` (PRIMARY KEY)
- `(user_id, cafe_id)` (UNIQUE) - One state per user per cafe
- `user_id` - For user's favorites/wishlist queries
- `(user_id, is_favorite)` - For favorites filtering
- `(user_id, want_to_try)` - For wishlist filtering

**RLS Policies:**
- Users can read only their own cafe states
- Users can insert/update/delete only their own states

**Notes:**
- Unique constraint: One state record per user per cafe
- Both flags can be true (favorite AND want to try)
- Cascade delete: Deleting a cafe deletes all user states
- Upserted when user toggles favorite/wishlist

---

## Database Views

### `notifications_with_actor` (Notification View with Actor Profile)

A view that joins `notifications` with `users` to include actor profile information.

**View:** `public.notifications_with_actor`

**Security:** Uses `SECURITY INVOKER` (default) - respects the querying user's RLS policies

**Columns:**
- All columns from `notifications`
- `actor_username` (from `users.username`)
- `actor_display_name` (from `users.display_name`)
- `actor_avatar_url` (from `users.avatar_url`)

**Purpose:**
- Simplifies notification queries by including actor profile data
- Used by `SupabaseNotificationService` to fetch notifications with author info
- Respects RLS: Users can only see their own notifications (enforced by underlying table policies)

**Query Pattern:**
```sql
SELECT 
  n.*,
  u.username AS actor_username,
  u.display_name AS actor_display_name,
  u.avatar_url AS actor_avatar_url
FROM notifications n
LEFT JOIN users u ON n.actor_user_id = u.id
WHERE n.user_id = $1
ORDER BY n.created_at DESC;
```

---

### `feedback_posts_with_counts` (Feedback Posts with Engagement Metrics)

A view that aggregates vote counts and comment counts for feedback posts.

**View:** `public.feedback_posts_with_counts`

**Security:** Uses `SECURITY INVOKER` (default) - respects the querying user's RLS policies

**Columns:**
- All columns from `feedback_posts`
- `vote_score` (calculated: sum of upvotes - downvotes)
- `upvotes` (count of upvotes)
- `downvotes` (count of downvotes)
- `comment_count` (count of comments)

**Purpose:**
- Simplifies feedback post queries by including engagement metrics
- Used by `SupabaseFeedbackService` to fetch posts with vote and comment counts
- Respects RLS policies on underlying `feedback_posts`, `feedback_votes`, and `feedback_comments` tables

**Query Pattern:**
```sql
SELECT 
  p.*,
  COALESCE(SUM(CASE WHEN v.vote_type = 1 THEN 1 WHEN v.vote_type = -1 THEN -1 ELSE 0 END), 0) AS vote_score,
  COALESCE(COUNT(DISTINCT v.id) FILTER (WHERE v.vote_type = 1), 0) AS upvotes,
  COALESCE(COUNT(DISTINCT v.id) FILTER (WHERE v.vote_type = -1), 0) AS downvotes,
  COALESCE(COUNT(DISTINCT c.id), 0) AS comment_count
FROM feedback_posts p
LEFT JOIN feedback_votes v ON p.id = v.post_id
LEFT JOIN feedback_comments c ON p.id = c.post_id
GROUP BY p.id;
```

---

### `feedback_comments_with_author` (Feedback Comments with Author Profile)

A view that joins `feedback_comments` with `users` to include author profile information.

**View:** `public.feedback_comments_with_author`

**Security:** Uses `SECURITY INVOKER` (default) - respects the querying user's RLS policies

**Columns:**
- All columns from `feedback_comments`
- `author_username` (from `users.username`)
- `author_display_name` (from `users.display_name`)
- `author_avatar_url` (from `users.avatar_url`)

**Purpose:**
- Simplifies feedback comment queries by including author profile data
- Used by `SupabaseFeedbackService` to fetch comments with author info
- Respects RLS policies on underlying `feedback_comments` table

**Query Pattern:**
```sql
SELECT 
  c.*,
  u.username AS author_username,
  u.display_name AS author_display_name,
  u.avatar_url AS author_avatar_url
FROM feedback_comments c
LEFT JOIN users u ON c.user_id = u.id;
```

---

## Database Functions

### `get_cafe_aggregate_stats(cafe_id UUID)`

PostgreSQL function that calculates aggregate statistics for a cafe across all visits.

**Function:** `public.get_cafe_aggregate_stats`

**Parameters:**
- `p_cafe_id` (UUID) - Cafe ID

**Returns:** JSON object with:
```json
{
  "total_visits": 42,
  "average_rating": 4.2,
  "top_drinks": [
    {"drink_name": "Oat Latte", "order_count": 15, "percentage": 35.7},
    {"drink_name": "Matcha", "order_count": 10, "percentage": 23.8}
  ]
}
```

**Logic:**
1. Count total visits for the cafe
2. Calculate average `overall_score` from all visits
3. Extract drink types from `drink_type` and `drink_subtype` fields
4. Count occurrences and calculate percentages
5. Return top 5 drinks by count

**Usage:**
Called via Supabase RPC:
```sql
SELECT * FROM get_cafe_aggregate_stats('cafe-uuid-here');
```

---

## Database Triggers

### Visit Creation Trigger

**Trigger:** `on_visit_created`

**Event:** `INSERT` on `visits` table

**Actions:**
1. If visibility is 'friends' or 'everyone':
   - Fetch all friends of visit author
   - Create notifications for each friend (type: 'new_visit_from_friend')
   - Optionally trigger silent push notifications via edge function

**Implementation:**
- Database trigger or edge function (via Supabase webhook)
- Edge function: `notify-friends-new-visit`

---

## Relationships Diagram

```
users (1) ──< (many) visits
users (1) ──< (many) likes
users (1) ──< (many) comments
users (1) ──< (many) notifications (as recipient)
users (1) ──< (many) notifications (as actor)
users (1) ──< (many) user_devices
users (1) ──< (1) rating_templates
users (1) ──< (many) user_cafe_states

cafes (1) ──< (many) visits
cafes (1) ──< (many) user_cafe_states

visits (1) ──< (many) visit_photos
visits (1) ──< (many) likes
visits (1) ──< (many) comments
visits (1) ──< (many) notifications

comments (1) ──< (many) comment_likes
comments (1) ──< (many) comments (replies via parent_comment_id)

follows: follower_id → followee_id (one-way)
friend_requests: from_user_id → to_user_id (with status)
friends: user_id ↔ friend_user_id (bidirectional, two rows)
```

---

## Indexes Summary

**Primary Indexes:**
- All tables have UUID primary keys

**Foreign Key Indexes:**
- All foreign key columns are indexed for join performance

**Query Optimization Indexes:**
- `visits(user_id, created_at DESC)` - User journal queries
- `visits(visibility, created_at DESC)` - Feed queries
- `notifications(user_id, created_at DESC)` - Notification feed
- `comments(visit_id, created_at ASC)` - Comment threading
- `user_cafe_states(user_id, is_favorite)` - Favorites queries
- `user_cafe_states(user_id, want_to_try)` - Wishlist queries

**Unique Constraints:**
- `users.username` - Username uniqueness
- `likes(user_id, visit_id)` - Prevent duplicate likes
- `comment_likes(user_id, comment_id)` - Prevent duplicate comment likes
- `friend_requests(from_user_id, to_user_id, status)` - One pending request per pair
- `friends(user_id, friend_user_id)` - One friendship record per direction
- `user_cafe_states(user_id, cafe_id)` - One state per user per cafe
- `rating_templates(user_id)` - One template per user
- `user_devices(user_id, push_token)` - One token per user per device

---

## Row Level Security (RLS) Summary

**Public Read (All Users):**
- `users` - Profile data is public
- `cafes` - Cafe data is public
- `visits` - Filtered by visibility (private/friends/everyone)
- `likes` - Public (who liked what)
- `comments` - Public (for visible visits)
- `follows` - Public (who follows whom)
- `friends` - Public (who is friends with whom)

**Owner-Only Write:**
- Users can only create/update/delete their own:
  - Visits
  - Likes
  - Comments
  - Notifications (read status)
  - User devices
  - Rating templates
  - User cafe states

**Conditional Access:**
- `visits`: Read access based on `visibility` field
- `friend_requests`: Users can read their own (sent/received), update only received
- `notifications`: Users can only read their own

---

## Data Types Reference

**UUID:** PostgreSQL UUID type (e.g., `550e8400-e29b-41d4-a716-446655440000`)  
**TEXT:** Variable-length string (unlimited)  
**JSONB:** Binary JSON (for flexible schemas like ratings)  
**TIMESTAMPTZ:** Timestamp with timezone (ISO 8601)  
**DOUBLE PRECISION:** 64-bit floating point (for coordinates, scores)  
**BOOLEAN:** True/false  
**INTEGER:** 32-bit integer (for sort_order, counts)

---

## Migration Notes

**Initial Setup:**
1. Enable UUID extension: `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`
2. Enable RLS on all tables: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`
3. Create indexes after table creation
4. Set up triggers for notifications
5. Create views and functions

**Common Operations:**
- **Cascade Deletes:** Visit deletion cascades to photos, likes, comments
- **Upserts:** Used for cafes, user devices, rating templates, user cafe states
- **Soft Deletes:** Not used - permanent deletion
- **Audit Trail:** `created_at` and `updated_at` on all tables

---

## Performance Considerations

1. **Feed Queries:** Use `(visibility, created_at DESC)` index for efficient feed loading
2. **User Journal:** Use `(user_id, created_at DESC)` index for profile queries
3. **Like Counts:** Aggregated on-the-fly (not stored) for real-time accuracy
4. **Photo URLs:** Stored in database, actual files in Supabase Storage
5. **JSONB Ratings:** Indexed for efficient category lookups
6. **Notification Batching:** Consider batching similar notifications

---

## Security Considerations

1. **RLS Policies:** All tables have RLS enabled
2. **User Isolation:** Users can only modify their own data
3. **Visibility Control:** Visit visibility enforced at database level
4. **Cascade Deletes:** Prevent orphaned records
5. **Unique Constraints:** Prevent duplicate relationships
6. **Input Validation:** App-level validation (200 char limits, etc.)

---

This schema supports Mugshot's core functionality: user profiles, cafe tracking, visit journaling, social interactions, notifications, and push notifications, all with proper security and performance optimizations.

