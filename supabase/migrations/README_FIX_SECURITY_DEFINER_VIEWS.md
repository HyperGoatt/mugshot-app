# Fix SECURITY DEFINER Views Migration

## Overview

This migration removes `SECURITY DEFINER` from three database views to ensure they respect Row Level Security (RLS) policies based on the querying user's context, rather than running with elevated privileges that could bypass security.

## Affected Views

1. `public.notifications_with_actor` - Joins notifications with user profiles
2. `public.feedback_posts_with_counts` - Aggregates vote and comment counts for feedback posts
3. `public.feedback_comments_with_author` - Joins feedback comments with user profiles

## Migration File

**File:** `20250101_fix_security_definer_views.sql`

## How to Apply

### Option 1: Via Supabase SQL Editor (Recommended)

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** (in the left sidebar)
3. Click **New Query**
4. Open the file `supabase/migrations/20250101_fix_security_definer_views.sql`
5. Copy and paste the entire SQL content into the SQL Editor
6. Click **Run** or press `Cmd+Enter` / `Ctrl+Enter`
7. Verify the execution was successful (you should see "Success" message)

### Option 2: Via Supabase CLI

If you have the Supabase CLI set up:

```bash
cd /Users/joe.rosso/Documents/mugshot-app
supabase db push
```

Or apply the migration directly:

```bash
supabase db execute -f supabase/migrations/20250101_fix_security_definer_views.sql
```

## What This Migration Does

1. **Drops** the existing views (if they exist)
2. **Recreates** them without `SECURITY DEFINER`
3. The views now use `SECURITY INVOKER` (the default), which means:
   - Queries run with the **querying user's** permissions
   - RLS policies are enforced based on the **calling user's** context
   - No privilege escalation - users can only see data they're authorized to see

## Testing the Migration

After applying the migration, test each view to ensure RLS is properly enforced:

### Test 1: notifications_with_actor

**As authenticated user:**
```sql
-- Should only return notifications for the current user
SELECT * FROM notifications_with_actor 
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 10;
```

**As anonymous user:**
```sql
-- Should return no rows (or be blocked by RLS)
SELECT * FROM notifications_with_actor;
```

**Expected Result:** Users can only see their own notifications. Anonymous users should see nothing (or get a permission error).

### Test 2: feedback_posts_with_counts

**As authenticated user:**
```sql
-- Should return all feedback posts (if RLS allows public read)
SELECT id, title, vote_score, comment_count 
FROM feedback_posts_with_counts 
ORDER BY created_at DESC
LIMIT 10;
```

**Expected Result:** Should return feedback posts according to RLS policies (likely public read is allowed).

### Test 3: feedback_comments_with_author

**As authenticated user:**
```sql
-- Should return comments for a specific post
SELECT * FROM feedback_comments_with_author 
WHERE post_id = 'some-post-id'::uuid
ORDER BY created_at ASC;
```

**Expected Result:** Should return comments according to RLS policies (likely public read is allowed).

## Verification Checklist

- [ ] Migration executed successfully without errors
- [ ] `notifications_with_actor` view exists and is accessible
- [ ] `feedback_posts_with_counts` view exists and is accessible
- [ ] `feedback_comments_with_author` view exists and is accessible
- [ ] Test queries return expected results
- [ ] RLS is enforced (users can only see authorized data)
- [ ] App functionality works correctly (test in iOS app)

## Rollback (If Needed)

If you need to rollback this migration, you would need to recreate the views with `SECURITY DEFINER`. However, this is **not recommended** as it reintroduces the security vulnerability.

If rollback is absolutely necessary:

```sql
-- WARNING: This reintroduces the security issue!
-- Only use if absolutely necessary for troubleshooting

DROP VIEW IF EXISTS public.notifications_with_actor;
CREATE VIEW public.notifications_with_actor 
WITH (security_definer = true) AS
SELECT 
  n.*,
  u.username AS actor_username,
  u.display_name AS actor_display_name,
  u.avatar_url AS actor_avatar_url
FROM public.notifications n
LEFT JOIN public.users u ON n.actor_user_id = u.id;

-- Repeat for other views...
```

## Security Benefits

After this migration:

1. ✅ **No RLS Bypass** - Views respect user permissions
2. ✅ **No Privilege Escalation** - Queries run with caller's permissions
3. ✅ **Better Auditability** - Behavior is predictable based on user context
4. ✅ **Compliance** - Meets security best practices for database views

## Notes

- The views should work identically to before, but now with proper RLS enforcement
- No application code changes are required - the views maintain the same structure
- Performance should be similar, as RLS policies should use existing indexes
- Ensure all underlying tables have appropriate RLS policies enabled

## Related Files

- Migration SQL: `supabase/migrations/20250101_fix_security_definer_views.sql`
- Documentation: `DATABASE_SCHEMA.md` (updated with view details)
- Service Usage:
  - `testMugshot/Services/Supabase/SupabaseNotificationService.swift`
  - `testMugshot/Services/Supabase/SupabaseFeedbackService.swift`

