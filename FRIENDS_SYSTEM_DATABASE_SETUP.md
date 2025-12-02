# Friends System Database Setup

## ✅ Completed Migrations

All database schema changes have been successfully applied to your Supabase database. Here's what was created:

### 1. `friend_requests` Table

**Purpose**: Stores friend requests between users

**Schema**:
- `id` (UUID, primary key)
- `from_user_id` (UUID, foreign key to users.id)
- `to_user_id` (UUID, foreign key to users.id)
- `status` (TEXT: 'pending', 'accepted', 'rejected')
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

**Constraints**:
- Unique constraint on `(from_user_id, to_user_id, status)` to prevent duplicate pending requests
- Check constraint preventing self-requests (`from_user_id != to_user_id`)

**Indexes**:
- Index on `from_user_id`
- Index on `to_user_id`
- Index on `status`
- Index on `created_at DESC`

**RLS Policies**:
- ✅ Users can view their own incoming and outgoing friend requests
- ✅ Users can create friend requests (from themselves to others)
- ✅ Recipients can update requests sent to them (accept/reject)
- ✅ Users can delete their own pending sent requests

---

### 2. `friends` Table

**Purpose**: Stores bidirectional friendship relationships

**Schema**:
- `id` (UUID, primary key)
- `user_id` (UUID, foreign key to users.id)
- `friend_user_id` (UUID, foreign key to users.id)
- `created_at` (TIMESTAMPTZ)

**Constraints**:
- Unique constraint on `(user_id, friend_user_id)` to prevent duplicates
- Check constraint preventing self-friendship (`user_id != friend_user_id`)

**Indexes**:
- Index on `user_id`
- Index on `friend_user_id`
- Composite index on `(user_id, friend_user_id)`

**RLS Policies**:
- ✅ Users can view their own friendships
- ✅ Users can create friendships (for bidirectional entries)
- ✅ Users can delete their own friendships

**Note**: The table stores bidirectional entries - both `(A, B)` and `(B, A)` exist when users A and B are friends. This makes queries efficient in both directions.

---

### 3. Automatic Friendship Creation Trigger

**Function**: `create_friendship_on_request_accept()`

**Purpose**: Automatically creates bidirectional friendship entries when a friend request is accepted

**Behavior**:
- Triggers when a `friend_requests` status changes to 'accepted'
- Inserts two rows into `friends` table: `(from_user_id, to_user_id)` and `(to_user_id, from_user_id)`
- Uses `ON CONFLICT DO NOTHING` to handle edge cases gracefully

---

### 4. Mutual Friends RPC Function

**Function**: `get_mutual_friends(current_user_id UUID, other_user_id UUID)`

**Purpose**: Efficiently compute mutual friends between two users

**Returns**: Table with user profile information (id, display_name, username, bio, location, etc.)

**Usage**: 
```sql
SELECT * FROM get_mutual_friends(
    'current-user-uuid'::UUID,
    'other-user-uuid'::UUID
);
```

**Permissions**: Grant to `authenticated` role (users must be logged in)

---

### 5. Notifications Table Update

**Change**: Added support for friend request notification types

**New notification types allowed**:
- `friend_request`
- `friend_request_accepted`
- `new_visit_from_friend`

**Updated constraint**: The `notifications.type` check constraint now includes these new types.

---

### 6. Security Improvements

**Fixed**: All functions now have explicit `search_path` settings to prevent search path injection attacks:
- `update_updated_at_column()`
- `create_friendship_on_request_accept()`
- `get_mutual_friends()`

---

## Migration Versions

The following migrations were applied:

1. `20251124200920` - create_friend_requests_table
2. `20251124200926` - create_friends_table
3. `20251124200929` - update_notifications_for_friend_requests
4. `20251124200934` - create_friend_request_to_friends_trigger
5. `20251124200939` - create_mutual_friends_function
6. `20251124200958` - fix_function_security_search_path

---

## Testing the Schema

You can verify the tables exist and RLS is enabled:

```sql
-- Check tables
SELECT table_name, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND table_name IN ('friend_requests', 'friends');

-- Check policies
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('friend_requests', 'friends');
```

---

## Next Steps

1. ✅ **Database schema**: Complete
2. ✅ **RLS policies**: Complete
3. ✅ **Functions & triggers**: Complete
4. ⏳ **App code**: Already implemented (see implementation summary)
5. ⏳ **Testing**: Manual testing needed

The database is ready for the Friends system! All the app code has already been implemented and should work with these tables.

---

## Important Notes

- **Bidirectional Friendships**: The `friends` table stores both directions `(A→B)` and `(B→A)` for efficient querying
- **Automatic Creation**: When a friend request is accepted, the trigger automatically creates both friendship entries
- **RLS Security**: All operations are protected by Row Level Security - users can only see/modify their own data
- **Existing Follows Table**: The old `follows` table still exists but is no longer used by the app code

