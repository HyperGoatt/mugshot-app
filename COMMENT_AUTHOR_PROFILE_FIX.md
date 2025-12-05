# Comment Author Profile Data Fix

## Issue Summary

When viewing a friend's comments on their posts, the UI was not displaying proper author information:

### Problems:
1. **Comment author showed "@friend"** instead of actual display name
2. **Reply indicator showed user ID** `@71500CA8-A989-4416-B716-C160325C79BA` instead of display name
3. **Avatar not loading** for comment authors (only showing initials)

### Root Cause:
The backend queries were fetching comments but **not joining with the `users` table** to get author profile data (display_name, username, avatar_url). The app models also didn't include fields to store this data.

---

## Changes Made

### 1. Backend Query Updates (`SupabaseVisitService.swift`)

#### `fetchComments(visitId:)` Query
**Before:**
```swift
URLQueryItem(name: "select", value: "*,comment_likes(*)")
```

**After:**
```swift
URLQueryItem(name: "select", value: "*,comment_likes(*),author:users!comments_user_id_fkey(id,display_name,username,avatar_url)")
```

**Impact**: Comments now include author profile data via PostgreSQL join.

#### `baseSelectQuery(limit:)` Query  
**Before:**
```swift
let selectValue = "*,cafe:cafe_id(*),visit_photos(*),likes(*),comments(*,comment_likes(*)),author:users!visits_user_id_fkey(...)"
```

**After:**
```swift
let selectValue = "*,cafe:cafe_id(*),visit_photos(*),likes(*),comments(*,comment_likes(*),author:users!comments_user_id_fkey(id,display_name,username,avatar_url)),author:users!visits_user_id_fkey(...)"
```

**Impact**: Feed and visit detail queries now fetch comment author data upfront.

---

### 2. Model Updates

#### `RemoteComment` (`RemoteSocialModels.swift`)
**Added fields:**
```swift
var author: RemoteUserProfile?  // New: Author profile from Supabase join

enum CodingKeys: String, CodingKey {
    // ... existing keys ...
    case author = "author"  // New
}
```

**Updated decoder:**
```swift
init(from decoder: Decoder) throws {
    // ... existing decoding ...
    author = try container.decodeIfPresent(RemoteUserProfile.self, forKey: .author)
}
```

---

#### `Comment` (`Visit.swift`)
**Added fields:**
```swift
var authorDisplayName: String?
var authorUsername: String?
var authorAvatarURL: String?

enum CodingKeys: String, CodingKey {
    // ... existing keys ...
    case authorDisplayName, authorUsername, authorAvatarURL  // New
}
```

**Updated init:**
```swift
init(
    // ... existing params ...
    authorDisplayName: String? = nil,
    authorUsername: String? = nil,
    authorAvatarURL: String? = nil
) {
    // ... existing assignments ...
    self.authorDisplayName = authorDisplayName
    self.authorUsername = authorUsername
    self.authorAvatarURL = authorAvatarURL
}
```

**Updated decoder:**
```swift
init(from decoder: Decoder) throws {
    // ... existing decoding ...
    authorDisplayName = try container.decodeIfPresent(String.self, forKey: .authorDisplayName)
    authorUsername = try container.decodeIfPresent(String.self, forKey: .authorUsername)
    authorAvatarURL = try container.decodeIfPresent(String.self, forKey: .authorAvatarURL)
}
```

**Updated encoder:**
```swift
func encode(to encoder: Encoder) throws {
    // ... existing encoding ...
    try container.encodeIfPresent(authorDisplayName, forKey: .authorDisplayName)
    try container.encodeIfPresent(authorUsername, forKey: .authorUsername)
    try container.encodeIfPresent(authorAvatarURL, forKey: .authorAvatarURL)
}
```

---

### 3. Data Mapping (`DataManager.swift`)

**Updated comment mapping from RemoteComment to Comment:**
```swift
let comments = (remote.comments ?? []).map { remoteComment -> Comment in
    // ... existing mapping ...
    return Comment(
        // ... existing params ...
        authorDisplayName: remoteComment.author?.displayName,  // New
        authorUsername: remoteComment.author?.username,        // New
        authorAvatarURL: remoteComment.author?.avatarURL       // New
    )
}
```

**Impact**: Author profile data now flows from Supabase → RemoteComment → Comment → UI.

---

### 4. UI Updates (`VisitDetailComponents.swift`)

Updated **both** `ThreadedCommentRow` and `InlineCommentRow`:

#### Avatar URL
**Before:**
```swift
private var commenterRemoteAvatarURL: String? {
    guard isCurrentUserComment else { return nil }
    return dataManager.appData.currentUserAvatarURL
}
```

**After:**
```swift
private var commenterRemoteAvatarURL: String? {
    if isCurrentUserComment {
        return dataManager.appData.currentUserAvatarURL
    }
    // Use author avatar URL from comment if available
    return comment.authorAvatarURL
}
```

#### Initials
**Before:**
```swift
private var commenterInitials: String {
    if let user = dataManager.appData.currentUser, user.id == comment.userId {
        return String(user.displayNameOrUsername.prefix(1)).uppercased()
    }
    return "U"  // Generic fallback
}
```

**After:**
```swift
private var commenterInitials: String {
    if let user = dataManager.appData.currentUser, user.id == comment.userId {
        return String(user.displayNameOrUsername.prefix(1)).uppercased()
    }
    // Use author display name from comment if available
    if let displayName = comment.authorDisplayName, !displayName.isEmpty {
        return String(displayName.prefix(1)).uppercased()
    }
    return "U"
}
```

#### Display Name
**Before:**
```swift
private var commenterUsername: String {
    if let user = dataManager.appData.currentUser, user.id == comment.userId {
        return "@\(user.username)"
    }
    return "@friend"  // Generic placeholder
}
```

**After:**
```swift
private var commenterUsername: String {
    if let user = dataManager.appData.currentUser, user.id == comment.userId {
        return user.displayName
    }
    // Use author display name from comment if available
    if let displayName = comment.authorDisplayName, !displayName.isEmpty {
        return displayName
    }
    return "Unknown"
}
```

#### Reply Indicator
**Before:**
```swift
Text("Replying to @\(replyingTo.supabaseUserId ?? "user")")
```
*Showed raw UUID: `@71500CA8-A989-4416-B716-C160325C79BA`*

**After:**
```swift
let replyToName = replyingTo.authorDisplayName ?? replyingTo.authorUsername ?? "someone"
Text("Replying to \(replyToName)")
```
*Shows display name: `Replying to Joe (Creator)`*

---

## Results

### Before Fix:
```
Comment author: "@friend"
Avatar: Generic "U" initials
Reply indicator: "Replying to @71500CA8-A989-4416-B716-C160325C79BA"
```

### After Fix:
```
Comment author: "Joe (Creator)"
Avatar: Loads actual avatar image from Supabase Storage
Reply indicator: "Replying to Joe (Creator)"
```

---

## Technical Details

### PostgreSQL Foreign Key Join
The query uses Supabase's relationship syntax:
```
author:users!comments_user_id_fkey(id,display_name,username,avatar_url)
```

This:
- Follows the `comments.user_id → users.id` foreign key
- Returns author data nested under `author` key
- Maps to `RemoteUserProfile` type

### Data Flow
```
Supabase (comments + users join)
    ↓
RemoteComment.author: RemoteUserProfile?
    ↓
Comment.authorDisplayName/authorUsername/authorAvatarURL
    ↓
UI (ThreadedCommentRow / InlineCommentRow)
```

### Backward Compatibility
- All new fields are **optional** (`String?`)
- Decoder uses `decodeIfPresent` - won't fail on old data
- UI has fallbacks: "Unknown" for missing names, "U" for missing initials

---

## Testing Checklist

- [x] Comment shows author's display name (not "@friend")
- [x] Comment avatar loads from Supabase Storage
- [x] Initials use author's first name letter
- [x] Reply indicator shows display name (not user ID)
- [x] Works for all comments (top-level and replies)
- [x] Works in both ThreadedCommentRow and InlineCommentRow
- [x] Current user's own comments still work correctly
- [x] Backward compatible with old cached data

---

## Files Changed

1. **Models**:
   - `testMugshot/Models/Remote/RemoteSocialModels.swift` - Added `author` to `RemoteComment`
   - `testMugshot/Models/Visit.swift` - Added author fields to `Comment`

2. **Services**:
   - `testMugshot/Services/Supabase/SupabaseVisitService.swift` - Updated queries to join users table
   - `testMugshot/Services/DataManager.swift` - Map author data from remote to local

3. **Views**:
   - `testMugshot/Views/Visits/VisitDetailComponents.swift` - Updated UI to use author data

---

## Related Fixes
- See `CRITICAL_BUGFIXES_FRIENDS_DATA.md` for RLS policy fixes
- See `TEST_FRIENDS_DATA_FIX.md` for testing guide

---

**Status**: ✅ Fixed  
**Date**: December 2024  
**Severity**: High - Broken UX for social features  
**Breaking Changes**: None (backward compatible)
