# Testing Guide: Friend's Data Visibility Fix

## What Was Fixed

✅ **RLS Policies Updated** - The Row Level Security policies for `visit_photos`, `likes`, and `comments` tables now correctly use the `friends` table instead of the deprecated `follows` table.

## Test Data Confirmed

### Users
- **Joe** (Creator): `71500ca8-a989-4416-b716-c160325c79ba` (@joe)
- **Kev**: `55d277a2-6a14-401f-bf38-8d9c43bbc70b` (@coffeelovingKev)

### Friendship Status
✅ Bidirectional friendship exists:
- Kev → Joe (created 2025-12-05 02:11:57)
- Joe → Kev (created 2025-12-05 02:33:34)

### Test Visit (Joe's Prophet Coffee post)
**Visit ID**: `5e83b381-0065-42ca-967a-9298b2e13a3f`
- **Caption**: "First time being at Prophet east side! I am a stubby Stan and can't wait to go back 🤌🏽"
- **Visibility**: friends
- **Photos**: 6 images
- **Likes**: 0
- **Comments**: 1 (by Joe)

## Testing Steps

### 1. Test in iOS App

#### Step 1: Sign in as Kev
- Username: `coffeelovingKev`
- Use Kev's credentials

#### Step 2: Navigate to Feed
- Go to Feed tab
- Select "Friends" filter
- Find Joe's Prophet Coffee post

#### Step 3: Verify Feed Display
✅ **Expected Results**:
- [ ] Post card shows 6 photos carousel
- [ ] Can swipe through all 6 images
- [ ] Rating badge shows 4.2 stars
- [ ] Like button shows correct count
- [ ] Comment button shows "1" comment

❌ **Before Fix**:
- No image placeholder shown
- Post looked broken

#### Step 4: Open Detail View
- Tap on Joe's post to open detail view

✅ **Expected Results**:
- [ ] All 6 photos displayed in carousel
- [ ] Can zoom/pan images
- [ ] "No photos" message does NOT appear
- [ ] Like count visible and accurate
- [ ] Comments section shows Joe's comment
- [ ] Can reply to Joe's comment

❌ **Before Fix**:
- Showed "No photos" message
- Likes showed 0
- Comments showed 0

### 2. Test Other Visits

Navigate to other Joe posts and verify:
- Visit to "The Harbinger Cafe & Bakery" (5 photos, 1 like, 1 comment)
- Visit to another cafe (4 photos, 1 like, 1 comment)

All should display photos, likes, and comments correctly.

### 3. Test Privacy Boundaries

#### Public Posts (visibility = 'everyone')
- [ ] Can see posts from non-friends if they're public
- [ ] Can see photos, likes, comments on public posts

#### Friends-Only Posts (visibility = 'friends')
- [x] Can see Joe's friends-only posts (Kev is Joe's friend)
- [ ] Cannot see friends-only posts from non-friends

#### Private Posts (visibility = 'private')
- [ ] Cannot see private posts from anyone except yourself

### 4. Test as Joe (Reverse Direction)

Sign out and sign in as Joe:
- [ ] Can see Kev's visits in feed
- [ ] Can see Kev's photos
- [ ] Can see likes/comments on Kev's posts

This tests the bidirectional friendship.

## Manual Database Verification (Optional)

If you want to verify the fix at the database level:

```sql
-- Check RLS policies are in place
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('visit_photos', 'likes', 'comments')
ORDER BY tablename, policyname;
```

Expected policies:
- ✅ `visit_photos`: "Visit photos visible based on visit visibility and friendships"
- ✅ `likes`: "Likes visible based on visit visibility and friendships"
- ✅ `comments`: "Comments visible based on visit visibility and friendships"

## Troubleshooting

### If images still don't show:

1. **Check friendship exists**:
   ```sql
   SELECT * FROM friends 
   WHERE user_id = 'kev-id' AND friend_user_id = 'joe-id'
      OR user_id = 'joe-id' AND friend_user_id = 'kev-id';
   ```

2. **Check visit visibility**:
   ```sql
   SELECT id, caption, visibility, user_id 
   FROM visits 
   WHERE user_id = 'joe-id'
   ORDER BY created_at DESC
   LIMIT 5;
   ```

3. **Check photos exist**:
   ```sql
   SELECT visit_id, COUNT(*) as photo_count
   FROM visit_photos
   WHERE visit_id IN (SELECT id FROM visits WHERE user_id = 'joe-id')
   GROUP BY visit_id;
   ```

4. **Force app data refresh**:
   - Sign out of app
   - Sign back in
   - This forces a fresh data fetch from Supabase

### If likes/comments don't show:

1. **Check likes**:
   ```sql
   SELECT l.*, u.username as liker
   FROM likes l
   JOIN users u ON l.user_id = u.id
   WHERE l.visit_id = 'visit-id';
   ```

2. **Check comments**:
   ```sql
   SELECT c.*, u.username as commenter
   FROM comments c
   JOIN users u ON c.user_id = u.id
   WHERE c.visit_id = 'visit-id';
   ```

## Success Criteria

The fix is successful when:
- ✅ Kev can see all 6 photos on Joe's Prophet Coffee post
- ✅ Kev can see the comment count (1) on the post
- ✅ Kev can read Joe's comment in detail view
- ✅ Kev can reply to comments on Joe's posts
- ✅ Like counts are accurate
- ✅ All of Joe's other visits show photos correctly
- ✅ The reverse works (Joe can see Kev's posts)

## What Changed

**Database Changes Only** - No iOS code changes required!

The fix involved updating 3 RLS policies in Supabase to check the `friends` table instead of the `follows` table:

1. **visit_photos** policy
2. **likes** policy  
3. **comments** policy

All three now correctly implement the friendship check:
```sql
EXISTS (
  SELECT 1 FROM friends 
  WHERE user_id = current_user 
  AND friend_user_id = post_owner
)
```

## Related Docs
- Full fix documentation: `CRITICAL_BUGFIXES_FRIENDS_DATA.md`
- Friends system: `FRIENDS_SYSTEM_SUMMARY.md`
- Supabase RLS: https://supabase.com/docs/guides/auth/row-level-security

---

**Status**: ✅ Fixed - Ready for testing  
**Date**: December 2024
