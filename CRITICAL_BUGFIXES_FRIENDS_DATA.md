# Critical Bug Fixes - Friend's Visit Data Visibility

## Issues Identified

### Issue 1: Friend's Visit Images Not Showing
When Kev (user) viewed his friend Joe's visits:
- Feed showed no image placeholder
- Detail view showed "No photos" message
- Images existed in database but weren't being returned by Supabase

### Issue 2: Comments and Likes Not Syncing Between Users
When Kev viewed Joe's visits:
- Comments showed as 0 (but Joe could see them when logged in as Joe)
- Likes showed as 0 (but Joe could see them when logged in as Joe)
- Data existed in database but RLS policies blocked access

## Root Cause

The Row Level Security (RLS) policies on three critical tables were using the old `follows` table to check friendships, but the app uses the `friends` table (bidirectional friendships).

**Affected Tables:**
1. `visit_photos` - blocked friends from seeing each other's photos
2. `likes` - blocked friends from seeing likes on each other's posts
3. `comments` - blocked friends from seeing comments on each other's posts

**Old Policy Logic (INCORRECT):**
```sql
EXISTS (
  SELECT 1 FROM follows f 
  WHERE f.follower_id = auth.uid() 
  AND f.followee_id = v.user_id
)
```

**New Policy Logic (CORRECT):**
```sql
EXISTS (
  SELECT 1 FROM friends f 
  WHERE f.user_id = auth.uid() 
  AND f.friend_user_id = v.user_id
)
```

## Fixes Applied

### 1. Dropped Old Policies
Removed policies that referenced the `follows` table:
- `"Visit photos follow visit visibility"` on `visit_photos`
- `"Likes visible when visit is visible"` on `likes`
- `"Comments visible when visit is visible"` on `comments`

### 2. Created New Policies Using `friends` Table

#### visit_photos Policy
**Name:** `"Visit photos visible based on visit visibility and friendships"`

**Logic:**
- ✅ Everyone can see photos on public visits (`visibility = 'everyone'`)
- ✅ Visit owner can always see their own photos
- ✅ Friends can see photos on friends-only visits (`visibility = 'friends'`)
  - Checks bidirectional `friends` table: `user_id = auth.uid() AND friend_user_id = v.user_id`

#### likes Policy
**Name:** `"Likes visible based on visit visibility and friendships"`

**Logic:**
- ✅ Users can always see their own likes
- ✅ Everyone can see likes on public visits
- ✅ Visit owner can see all likes on their posts
- ✅ Friends can see likes on friends-only visits

#### comments Policy
**Name:** `"Comments visible based on visit visibility and friendships"`

**Logic:**
- ✅ Users can always see their own comments
- ✅ Everyone can see comments on public visits
- ✅ Visit owner can see all comments on their posts
- ✅ Friends can see comments on friends-only visits

#### Bonus: Comment Updates
Added missing policy: `"Users can update their own comments"`
- Allows users to edit their own comments (required for the edit feature)

## Verification

### Before Fix (Kev viewing Joe's post):
```
Feed: No image shown
Detail: "No photos"
Likes: 0
Comments: 0
```

### After Fix (Kev viewing Joe's post):
```
Feed: Images visible
Detail: Photos carousel working
Likes: Correct count + ability to see who liked
Comments: All comments visible + can reply
```

## Technical Details

### Friends Table Structure
The `friends` table uses a bidirectional pattern:
```sql
CREATE TABLE friends (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),      -- The "owner" of this friendship row
  friend_user_id UUID REFERENCES users(id), -- The friend
  created_at TIMESTAMPTZ
);
```

When User A and User B become friends, TWO rows are created:
1. `user_id = A, friend_user_id = B`
2. `user_id = B, friend_user_id = A`

This allows efficient queries: "Get all my friends" = `SELECT * FROM friends WHERE user_id = current_user`

### Policy Pattern
All three policies follow this visibility hierarchy:

```sql
1. Public visits (visibility = 'everyone')
   → EVERYONE can see photos/likes/comments

2. Owner's own visits
   → OWNER can always see their own data

3. Friends-only visits (visibility = 'friends')
   → FRIENDS can see photos/likes/comments
   → Checked via: EXISTS (SELECT 1 FROM friends WHERE user_id = viewer AND friend_user_id = post_owner)

4. Private visits (visibility = 'private')
   → ONLY OWNER can see
```

## Impact

✅ **Fixed**: Friends can now see each other's visit photos in feed and detail views
✅ **Fixed**: Friends can see likes on each other's visits
✅ **Fixed**: Friends can see and reply to comments on each other's visits
✅ **Added**: Users can now edit their own comments (UPDATE policy)

## Files Changed
- **Supabase Database**: RLS policies on `visit_photos`, `likes`, `comments` tables
- **No iOS code changes required** - this was purely a backend RLS configuration issue

## Testing Checklist

- [x] Kev can see Joe's visit photos in feed
- [x] Kev can see Joe's visit photos in detail view
- [x] Kev can see likes count on Joe's visits
- [x] Kev can see who liked Joe's visits
- [x] Kev can see comments on Joe's visits
- [x] Kev can reply to comments on Joe's visits
- [x] Joe can edit his own comments
- [x] Public visits remain visible to everyone
- [x] Private visits remain visible only to owner

## Related Documentation
- See Supabase RLS docs: https://supabase.com/docs/guides/auth/row-level-security
- Friends system implementation: `FRIENDS_SYSTEM_SUMMARY.md`

---

**Date Fixed**: December 2024  
**Fixed By**: Performance audit follow-up  
**Severity**: Critical - blocked core social features
