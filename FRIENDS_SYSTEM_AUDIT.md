# Friends System Audit Report

## Executive Summary

The Mugshot Friends system has solid foundations but suffers from **state synchronization issues** that can cause inconsistent UI states across the app. The core backend operations work correctly, but local caching and state updates are fragmented.

---

## Database Schema ✅

**Status: GOOD** – No changes needed

### Tables:
- `friend_requests`: Tracks pending/accepted/rejected friend requests
  - Columns: id, from_user_id, to_user_id, status, created_at, updated_at
  - Unique constraint on (from_user_id, to_user_id, status)
  
- `friends`: Bidirectional friendship records
  - Columns: id, user_id, friend_user_id, created_at
  - Two rows per friendship (A→B and B→A)

- `follows`: Legacy table (unused in current implementation)

---

## Service Layer ✅

**Status: GOOD** – Core operations work correctly

### SupabaseSocialGraphService
Provides all necessary operations:
- ✅ `sendFriendRequest` - Creates pending request
- ✅ `acceptFriendRequest` - Updates request + creates bidirectional friends
- ✅ `rejectFriendRequest` - Marks request as rejected
- ✅ `cancelFriendRequest` - Deletes pending request
- ✅ `fetchFriends` - Gets friend IDs for a user
- ✅ `removeFriend` - Deletes bidirectional friendship
- ✅ `checkFriendshipStatus` - Returns current status (none/outgoing/incoming/friends)

---

## Issues Found ⚠️

### 1. Fragmented State Management

**Problem**: `AppData.friendsSupabaseUserIds` is the single source of truth but is updated inconsistently.

**Where it's updated**:
- ✅ `acceptFriendRequest()` - Updates immediately
- ✅ `refreshFeed(scope: .friends)` - Fetches from backend
- ✅ `refreshFriendsList()` - Explicit refresh method
- ⚠️ `removeFriend()` - Updates but doesn't trigger dependent refreshes
- ❌ `sendFriendRequest()` - Doesn't update (OK, not friends yet)
- ❌ `cancelFriendRequest()` - Doesn't update (OK, but should trigger UI refresh)

**Where it's consumed**:
- Feed filtering (`getFeedVisits`)
- Map Sip Squad mode (cafe filtering)
- Profile friend counts
- Widgets (friends' latest sips)

**Impact**: If the set is stale, friends-only content may leak to non-friends or vice versa.

---

### 2. Pending Request Tracking is Brittle

**Problem**: `AppData.outgoingRequestsByUserId` and `incomingRequestsByUserId` are only populated during `fetchFriendRequests()`.

**What should happen**:
- After `sendFriendRequest()` → add to `outgoingRequestsByUserId`
- After `acceptFriendRequest()` → remove from `incomingRequestsByUserId`
- After `cancelFriendRequest()` → remove from `outgoingRequestsByUserId`
- After `rejectFriendRequest()` → remove from `incomingRequestsByUserId`

**What actually happens**:
- ✅ `sendFriendRequest()` updates `outgoingRequestsByUserId`
- ⚠️ `acceptFriendRequest()` removes from `incomingRequestsByUserId` (but inconsistently)
- ✅ `cancelFriendRequest()` attempts to remove from `outgoingRequestsByUserId`
- ❌ `rejectFriendRequest()` doesn't update tracking dictionaries

**Impact**: UI shows stale states (e.g., "Request Sent" when request was rejected by recipient).

---

### 3. No Local Status Cache

**Problem**: `checkFriendshipStatus()` hits the backend every time it's called.

**Where it's called**:
- FriendsHubView search results (batch)
- PeopleSearchResultsPanel (batch)
- OtherUserProfileView (on profile load)
- FriendSearchResultRow (after actions)

**Impact**: 
- Network overhead
- UI flickers while loading
- Race conditions between status checks and state mutations

**Solution needed**: Local cache that's invalidated on friend actions.

---

### 4. Inconsistent Refresh Patterns

**Problem**: Different views refresh friends list differently.

**Refresh patterns**:
- FriendRequestRow: Calls `refreshFriendsList()` + `onRequestAction()` callback
- FriendSearchResultRow: Calls `refreshFriendsList()` + `onStatusChanged()` callback
- OtherUserProfileView: Calls `refreshFriendsList()` + `loadFriendsList()`
- FriendsHubView: Relies on callback from child components

**Missing refreshes**:
- After removing a friend, feed doesn't auto-refresh
- After accepting a request, Sip Squad mode doesn't refresh pins
- Widget data not refreshed consistently

---

### 5. Error Handling is Basic

**Current state**:
- Errors logged to console
- Generic error messages (if any) shown to user
- No retry logic
- No optimistic UI updates with rollback

**Examples**:
- If `acceptFriendRequest()` fails, UI might show "Friends" but backend disagrees
- Network failures during friend removal leave UI in inconsistent state
- Duplicate request errors not surfaced clearly

---

## Where Friendship State is Used

### 1. Profile Views
- **ProfileTabView** (own profile):
  - Shows friends count from `friendsSupabaseUserIds.count`
  - Opens FriendsHubView
  
- **OtherUserProfileView**:
  - Checks `checkFriendshipStatus()` on load
  - Shows action button based on status
  - Updates status after actions

**Issues**: Status can be stale if other user sent a request in another session.

---

### 2. Friends Hub & Lists
- **FriendsHubView**:
  - Search tab shows friendship status for each result
  - Friends tab shows confirmed friends
  - Requests tab shows incoming/outgoing requests

- **FriendsListView**:
  - Fetches friends on load
  - Shows alphabetically sorted list

**Issues**: Lists don't auto-refresh when returning from another view.

---

### 3. People Search
- **Map Tab > People Search**:
  - Uses `PeopleSearchResultsPanel`
  - Shows friendship status for each result
  - Inline friend request actions

**Issues**: Status checks are batched well but not cached.

---

### 4. Feed Filtering
- **FeedTabView**:
  - Friends scope uses `getFeedVisits(scope: .friends)`
  - Filters by `friendsSupabaseUserIds`

**Issues**: If friend list is stale, wrong posts appear.

---

### 5. Map Sip Squad Mode
- **MapTabView**:
  - Uses `friendsSupabaseUserIds` to filter cafes
  - Aggregates ratings from user + friends

**Issues**: Adding/removing friends doesn't refresh map pins immediately.

---

### 6. Widgets
- **FriendsLatestSipsWidget**:
  - Uses `friendsSupabaseUserIds` to show friends' recent visits

**Issues**: Widget refresh is triggered inconsistently.

---

## Recommended Fixes

### Phase 1: Centralize State Management (HIGH PRIORITY)

1. **Create a FriendsManager** helper in DataManager:
   ```swift
   // Consolidated methods:
   - refreshFriendsState() // Fetches friends + requests, updates all caches
   - invalidateFriendshipCache(for userId) // Clear local status cache
   - broadcastFriendsChanged() // Notify all views to refresh
   ```

2. **Update every friend action** to call `refreshFriendsState()`:
   - sendFriendRequest → update pending, broadcast
   - acceptFriendRequest → update friends, clear pending, broadcast
   - rejectFriendRequest → update pending, broadcast
   - cancelFriendRequest → update pending, broadcast
   - removeFriend → update friends, broadcast

---

### Phase 2: Add Local Status Cache (MEDIUM PRIORITY)

1. **Cache friendship statuses** in AppData:
   ```swift
   var friendshipStatusCache: [String: (status: FriendshipStatus, timestamp: Date)] = [:]
   ```

2. **Invalidate on actions**:
   - Clear cache entry for affected users
   - Set TTL (e.g., 5 minutes) for stale cache cleanup

---

### Phase 3: Improve Error Handling (MEDIUM PRIORITY)

1. **Add user-facing error states**:
   - Network failures: "Check your connection"
   - Duplicate requests: "Request already sent"
   - Generic: "Something went wrong, please try again"

2. **Add retry logic** for transient failures

3. **Optimistic updates** with rollback:
   - Show "Friends" immediately, revert if backend fails

---

### Phase 4: Comprehensive Testing (LOW PRIORITY but IMPORTANT)

1. **Manual test flows**:
   - Send request → Accept → Remove → Re-add
   - Send request → Cancel → Resend
   - Receive request → Reject → Sender tries again
   - Logout/login → State persists correctly

2. **Race condition tests**:
   - Both users send requests simultaneously
   - Accept request while other user cancels
   - Remove friend while viewing their profile

---

## Files to Modify

### Core Logic:
- `testMugshot/Services/DataManager.swift` - Add centralized refresh methods
- `testMugshot/Models/AppData.swift` - Add status cache

### Views:
- `testMugshot/Views/Friends/FriendsHubView.swift` - Subscribe to broadcasts
- `testMugshot/Views/Friends/FriendsListView.swift` - Subscribe to broadcasts
- `testMugshot/Views/Profile/OtherUserProfileView.swift` - Use cached status
- `testMugshot/Views/Profile/ProfileTabView.swift` - Subscribe to friend count changes
- `testMugshot/Views/Feed/FeedTabView.swift` - Refresh feed on friend changes
- `testMugshot/Views/Map/MapTabView.swift` - Refresh pins on friend changes

---

## Success Criteria

✅ Friend actions (add, accept, reject, remove) **always** result in consistent UI state  
✅ Friends list matches backend state within 1 second of any action  
✅ Feed filtering shows correct posts (no leaks)  
✅ Map Sip Squad mode shows correct pins  
✅ Friend counts are accurate everywhere  
✅ Errors are surfaced to users with actionable messages  
✅ No stale "Request Sent" or "Friends" states after backend changes  

---

## Implementation Priority

1. **IMMEDIATE**: Fix pending request dictionary updates (low effort, high impact)
2. **IMMEDIATE**: Add `refreshFriendsState()` and call after every action
3. **SHORT-TERM**: Add local status cache
4. **SHORT-TERM**: Improve error messages
5. **LONG-TERM**: Optimistic updates + rollback
