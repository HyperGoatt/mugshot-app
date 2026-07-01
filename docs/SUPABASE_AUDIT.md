# Supabase Audit

Date: 2026-06-30

Project inspected read-only: `Mugshot-App`

Project ref: `quskamnfwglctqewwfln`

Database: Postgres 17.6.1, region `us-east-2`

## Executive Summary

The Supabase project is real and much more complete than the current iOS app wiring. It has auth-linked users, cafes, visits, visit photos, likes, comments, notifications, friends, friend requests, device tokens, storage buckets, Edge Functions, analytics, and rating templates.

The iOS app now uses this project only for Phase 2A auth/session/profile bootstrap. There is still no storage upload, visit repository, backend feed repository, device registration, or local migration source in the repo.

Before connecting private beta users, fix or formally accept the security findings below. The most urgent issue is that a database trigger action appears to contain an embedded bearer token for invoking an Edge Function. I did not copy the token into this file.

Phase 2A update: the native iOS app now uses Supabase for auth/session restore and current-user `public.users` profile bootstrap only. It still does not insert visits, upload photos, read backend feed data, register devices, or call notification functions.

See also:

- `docs/PHASE_2A_AUTH_PROFILE_BOOTSTRAP.md`
- `docs/LOCAL_CONFIG_SETUP.md`
- `docs/SUPABASE_SECURITY_BACKLOG.md`

## Phase 2A Profile Contract Verified

The iOS app targets `public.users`, not `profiles`.

Verified profile facts:

- `public.users.id` is the primary key and references `auth.users.id`.
- Required client-visible fields are `id`, `display_name`, and `username`.
- Optional mapped fields include `bio`, `location`, `favorite_drink`, `instagram_handle`, `avatar_url`, `banner_url`, and `website_url`.
- `auth.users` has an insert trigger that calls `handle_new_user()` and creates the matching `public.users` row.
- `handle_new_user()` uses a fixed `search_path`, inserts required profile fields, and uses `ON CONFLICT(id) DO NOTHING`.

Native bootstrap behavior:

- Fetch `public.users` by the authenticated user id.
- If no row exists, upsert a minimal row for the authenticated user using RLS.
- Map the resulting `public.users` row into the app's local `User` model so existing tabs continue to work.

## Data Counts Observed

| Table | Rows |
| --- | ---: |
| `auth.users` | 4 |
| `public.users` | 4 |
| `public.cafes` | 30 |
| `public.visits` | 15 |
| `public.visit_photos` | 46 |
| `public.likes` | 11 |
| `public.comments` | 10 |
| `public.notifications` | 14 |
| `public.friend_requests` | 6 |
| `public.friends` | 6 |
| `public.follows` | 0 |
| `public.user_cafe_states` | 10 |
| `public.user_devices` | 0 |
| `public.rating_templates` | 0 |
| `public.system_rating_templates` | 14 |
| `public.analytics_events` | 3799 |

This looks like a small real/dev dataset, not an empty schema.

## Tables And Columns

| Table | RLS | Important columns |
| --- | --- | --- |
| `users` | enabled | `id`, `display_name`, `username`, `bio`, `location`, `favorite_drink`, `instagram_handle`, `avatar_url`, `banner_url`, `website_url`, `created_at`, `updated_at` |
| `cafes` | enabled | `id`, `name`, `address`, `city`, `country`, `latitude`, `longitude`, `apple_place_id`, `google_place_id`, `website_url`, `created_at`, `updated_at` |
| `visits` | enabled | `id`, `user_id`, `cafe_id`, `drink_type`, `drink_type_custom`, `drink_subtype`, `caption`, `notes`, `visibility`, `ratings`, `category_scores`, `overall_score`, `poster_photo_url`, `context_type`, `location_name`, `city_state`, `brew_method`, `equipment`, `brew_method_visible`, `equipment_visible`, `rating_template_id`, `rating_template_type`, `created_at`, `updated_at` |
| `visit_photos` | enabled | `id`, `visit_id`, `photo_url`, `sort_order`, `created_at` |
| `rating_templates` | enabled | `id`, `user_id`, `template_json`, `template_name`, `preferred_drink_type`, `preferred_brew_method`, `created_at`, `updated_at` |
| `system_rating_templates` | enabled | `id`, `template_name`, `applies_to_drink_type`, `applies_to_brew_method`, `category_list`, `is_system_default`, `sort_order`, `created_at`, `updated_at` |
| `user_cafe_states` | enabled | `id`, `user_id`, `cafe_id`, `is_favorite`, `want_to_try`, `created_at`, `updated_at` |
| `likes` | enabled | `id`, `user_id`, `visit_id`, `created_at` |
| `comments` | enabled | `id`, `user_id`, `visit_id`, `text`, `parent_comment_id`, `created_at` |
| `comment_likes` | enabled | `id`, `comment_id`, `user_id`, `created_at` |
| `friend_requests` | enabled | `id`, `from_user_id`, `to_user_id`, `status`, `created_at`, `updated_at` |
| `friends` | enabled | `id`, `user_id`, `friend_user_id`, `created_at` |
| `follows` | enabled | `follower_id`, `followee_id`, `created_at` |
| `notifications` | enabled | `id`, `user_id`, `actor_user_id`, `type`, `visit_id`, `comment_id`, `created_at`, `read_at` |
| `user_devices` | enabled | `id`, `user_id`, `push_token`, `platform`, `created_at`, `updated_at` |
| `analytics_events` | enabled | `id`, `user_id`, `event_name`, `event_properties`, `created_at` |
| `user_brew_settings` | enabled | `id`, `user_id`, `setting_type`, `value`, `usage_count`, `last_used_at`, `created_at` |
| `feedback_posts` | enabled | `id`, `user_id`, `title`, `body`, `category`, `created_at`, `updated_at` |
| `feedback_votes` | enabled | `id`, `user_id`, `post_id`, `vote_type`, `created_at` |
| `feedback_comments` | enabled | `id`, `user_id`, `post_id`, `parent_comment_id`, `text`, `created_at` |

Missing expected tables by exact name:

- `profiles` does not exist. The project uses `users`.
- `visit_ratings` does not exist. Ratings live in JSON columns on `visits`.
- `rating_categories` does not exist. Category lists live in `rating_templates.template_json` and `system_rating_templates.category_list`.
- `favorites` does not exist. Favorites live in `user_cafe_states.is_favorite`.
- `want_to_try` does not exist as a table. It lives in `user_cafe_states.want_to_try`.
- `friendships` does not exist by that name. The project uses `friends`, `friend_requests`, and `follows`.
- `notification_preferences` does not exist.
- `device_tokens` does not exist. The project uses `user_devices.push_token`.

## Relationships

Major relationships observed:

- `users.id` references `auth.users.id`.
- `visits.user_id` references `users.id`.
- `visits.cafe_id` references `cafes.id`.
- `visit_photos.visit_id` references `visits.id`.
- `likes.user_id` references `users.id`; `likes.visit_id` references `visits.id`.
- `comments.user_id` references `users.id`; `comments.visit_id` references `visits.id`; `comments.parent_comment_id` references `comments.id`.
- `notifications.user_id` and `notifications.actor_user_id` reference `users.id`; notifications can also reference `visits` and `comments`.
- `friend_requests.from_user_id` and `friend_requests.to_user_id` reference `users.id`.
- `friends.user_id` and `friends.friend_user_id` reference `users.id`.
- `follows.follower_id` and `follows.followee_id` reference `users.id`.
- `user_cafe_states.user_id` references `users.id`; `user_cafe_states.cafe_id` references `cafes.id`.

## RLS Policy Summary

All public app tables inspected have RLS enabled.

The policy model appears to be:

- Cafes are readable by everyone. Authenticated users can insert/update cafes.
- Users can insert/update their own user row. Authenticated users can read public profiles.
- Visits are readable when public, owned by the current user, or visible to friends through the `friends` table.
- Visit owners can insert/update/delete their own visits.
- Photos, likes, and comments follow visit visibility and ownership.
- Notifications are only readable/updateable/deletable by the target user; inserts are tied to actor user.
- Friend requests are visible to sender/recipient; recipients update them; sender can create/cancel pending requests.
- `friends` has broad read access and insert/delete policies around involved users.
- User cafe states and brew settings are owner-only.
- System rating templates are public-readable.

Policy risks:

- Some policies still use `auth.role() = 'authenticated'`, which Supabase now flags as a weaker/older pattern than policy `TO authenticated` plus ownership predicates.
- Several policies use `auth.uid()` directly in predicates, which advisors flagged for performance. At scale these should use `(select auth.uid())`.
- `friends` is world-readable. This may be intentional for discovery, but it is a product privacy decision.

## Storage

Buckets:

| Bucket | Public | File limit | MIME types |
| --- | --- | ---: | --- |
| `profile-media` | yes | 5 MB | jpeg, png, webp |
| `visit-photos` | yes | 10 MB | jpeg, png, gif, webp, heic |

Storage policies:

- `profile-media`: public select; users can upload/update/delete under their own auth uid folder.
- `visit-photos`: authenticated users can upload; users can delete their own folder objects; select is based on visit visibility.

Storage risks:

- Advisor warns that `profile-media` public select allows listing public profile image objects. Public buckets can serve public URLs without granting broad object listing.
- The iOS app currently does not upload to either bucket.

## Edge Functions

| Function | JWT required | Status | Purpose | Notes |
| --- | --- | --- | --- | --- |
| `notify-friends-on-new-visit` | yes | active | Silent APNs/background push updates when a new visit is created | Uses APNs secrets from environment. Appears to query `friends.friend_id`, but the table column is `friend_user_id`, so this likely fails until updated. |
| `pwa-search-cafes` | no | active | Public Google Places text search helper | CORS allows `*`; no JWT required. This may be fine for a public PWA endpoint, but it can expose quota/cost if abused. |
| `pwa-nearby-cafes` | no | active | Public Google Places nearby helper | Same public/no-JWT and quota concern. |

## Database Functions And Triggers

Functions observed:

- `handle_new_user()` - security definer.
- `create_friendship_on_request_accept()` - security definer.
- `get_mutual_friends(current_user_id uuid, other_user_id uuid)` - security definer.
- `get_cafe_aggregate_stats(p_cafe_id uuid)` - security definer.
- `send_push_notification_trigger()` - security definer.
- `set_updated_at()`, `update_updated_at_column()`, `update_user_devices_updated_at()` - update timestamp helpers.

Triggers observed:

- `users`, `cafes`, `visits`, `rating_templates`, `friend_requests`, `user_devices`: update timestamp triggers.
- `friend_requests`: accepted request trigger creates friendships.
- `notifications`: insert trigger sends push notification.
- `visits`: insert trigger calls the `notify-friends-on-new-visit` Edge Function.

Critical trigger issue:

- The `visits` insert trigger action contains an embedded bearer token in the function call. I did not copy it here. Treat this as sensitive. Before beta, rotate the exposed token and replace the trigger invocation with a safer secret management pattern.

## Views

Views observed:

- `notifications_with_actor`
- `feedback_posts_with_counts`
- `feedback_comments_with_author`

Advisor flags these views as security-definer views. Review whether they should use `security_invoker = true` or be otherwise protected.

## Migrations

Remote migrations exist, but no migration files are present in this repo.

Observed migration history:

- `20251118164645_create_users_and_rating_templates`
- `20251118220830_phase_b_core_social_tables`
- `20251121172921_create_profile_media_bucket`
- `20251121172925_create_profile_media_storage_policies`
- `20251124200920_create_friend_requests_table`
- `20251124200926_create_friends_table`
- `20251124200929_update_notifications_for_friend_requests`
- `20251124200934_create_friend_request_to_friends_trigger`
- `20251124200939_create_mutual_friends_function`
- `20251124200958_fix_function_security_search_path`
- `20251124221953_create_user_devices_table`
- `20251124223547_create_push_notification_trigger`
- `20251124223554_enable_pg_net_for_push_notifications`
- `20251126131357_notifications_with_actor_view`
- `20251128040818_allow_users_public_profile_read`
- `20251202051605_create_cafe_aggregate_stats_function`
- `20251202055958_fix_cafe_aggregate_stats_null_drink_type`
- `20251202194527_create_user_cafe_states_table`
- `20251204230021_add_drink_subtype_column`
- `20251204232959_update_cafe_stats_use_drink_subtype`
- `20251204234153_add_comment_parent_relationship`
- `20251204234156_create_comment_likes_table`
- `20251206233223_create_feedback_board_tables`
- Several later migrations have blank names, including versions on 2025-12-16, 2025-12-17, 2025-12-24, and 2025-12-31.
- `20251223043837_add_missing_visit_columns`

Recommendation: pull/export the remote migration history into the repo before making schema changes.

## Advisor Findings To Address Before Beta

Security:

- Security-definer views: `notifications_with_actor`, `feedback_posts_with_counts`, `feedback_comments_with_author`.
- Mutable search path warnings: `update_user_devices_updated_at`, `send_push_notification_trigger`, `set_updated_at`.
- `pg_net` extension installed in public schema.
- Public bucket listing risk on `profile-media`.
- Public/anon executable security-definer functions: `create_friendship_on_request_accept`, `get_cafe_aggregate_stats`, `get_mutual_friends`, `handle_new_user`, `send_push_notification_trigger`.
- Leaked password protection disabled in Supabase Auth.

Performance:

- Several unindexed foreign keys, including `visits.cafe_id`, `comments.user_id`, `notifications.actor_user_id`, `notifications.comment_id`, `notifications.visit_id`, `rating_templates.user_id`, and `user_cafe_states.cafe_id`.
- Many RLS policies re-evaluate `auth.uid()` per row.
- Multiple permissive policies on `visits`, `visit_photos`, and `user_devices`.
- Many unused indexes, likely because the project has little traffic so far. Do not drop these until real query patterns are known.

## Frontend / Backend Mismatches

| Frontend expectation | Supabase reality | Needed bridge |
| --- | --- | --- |
| `User` stored locally with `username`, `location`, `bio`, optional avatar path | `users` table linked to `auth.users` with profile media URLs | Add auth/profile repository and map app `User` to `users`. |
| `Cafe` has `isFavorite` and `wantToTry` booleans | Cafe identity in `cafes`; per-user state in `user_cafe_states` | Split shared cafe identity from user-specific saved state. |
| `Cafe` uses Apple Maps URL/category | Supabase has `apple_place_id` and `google_place_id`, but not local `mapItemURL`/`placeCategory` exactly | Decide Apple vs Google place identity strategy. |
| `Visit.photos` is `[String]` local keys | `visit_photos.photo_url` plus `visits.poster_photo_url` | Upload to Storage first, then persist URLs. |
| `Visit.ratings` is `[String: Double]` | `visits.ratings` JSON, `category_scores` JSON, and rating template tables | Choose canonical rating payload and migrate app model. |
| Likes are `likeCount` plus `likedByUserIds` on `Visit` | `likes` is a separate table | Fetch aggregate count and current user's like state. |
| Comments are nested inside `Visit` | `comments` is a separate table with threaded replies | Fetch comments separately or join in a view/RPC. |
| Friends are only visibility labels | `friends`, `friend_requests`, and `follows` exist | Build real friends services and screens. |
| Notifications missing in app | `notifications`, views, device tokens, push functions exist | Add notification surface and token registration after security cleanup. |

## Safe Next Backend Work

1. Rotate/revoke the embedded bearer token in the visit insert trigger and replace the trigger invocation safely.
2. Export/pull migrations into the repo so schema changes can be reviewed.
3. Fix the `notify-friends-on-new-visit` function's friendship column mismatch.
4. Add Supabase Swift client wiring in iOS behind a small repository layer.
5. Implement one backend-backed journey before expanding social/notification surfaces.
