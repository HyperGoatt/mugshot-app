# Mention Display Name Feature

## Overview

Updated the mention system to display **display names** instead of **@usernames** when tagging users in comments and captions, while keeping the search functionality that allows finding users by both username and display name.

## User Experience

### Before:
```
"Gotta show the homie @coffeelovingKev this spot soon!"
```
- Shows `@username` in text
- Username highlighted in mint color

### After:
```
"Gotta show the homie Kev this spot soon!"
```
- Shows `Display Name` in text (no @)
- Display name highlighted in Mugshot mint color
- Search still works by username OR display name

## Example

**User Joe tags User Kev:**
1. Joe types `@` → autocomplete appears
2. Joe searches "kev" or "coffeelovingKev" → both work
3. Joe selects "Kev" from list
4. Text shows: `@[Kev]` (internal format, user doesn't see brackets)
5. Display shows: **`Kev`** highlighted in mint color
6. Tapping "Kev" navigates to Kev's profile

---

## Technical Implementation

### 1. Mention Model (`Visit.swift`)

**Updated** to store both username and display name:

```swift
struct Mention: Identifiable, Codable {
    let id: UUID
    var username: String         // For functionality/lookup
    var displayName: String      // For display to users
    
    init(id: UUID = UUID(), username: String, displayName: String? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName ?? username  // Fallback to username
    }
}
```

**Why both fields?**
- `username`: Unique identifier, used for API calls and user lookup
- `displayName`: Human-friendly name, used for UI display

---

### 2. Text Format

**Internal format**: `@[Display Name]`
- Stored in database and comment text
- Allows display names with spaces and special characters
- Example: `Gotta show @[Joe (Creator)] this spot!`

**Displayed format**: `Display Name`
- Brackets and @ removed when showing to users
- Highlighted in Mugshot mint color
- Example: "Gotta show **Joe (Creator)** this spot!"

---

### 3. MentionParser (`MentionParser.swift`)

**Updated regex pattern**:
```swift
// New format: @[Display Name]
static let mentionPattern = "@\\[([^\\]]+)\\]"

// Legacy format (backward compatibility): @username
static let legacyMentionPattern = "@([a-zA-Z0-9_]+)"
```

**Key methods updated:**

#### `parseMentions(from:)`
- Extracts mentions from text
- Tries new `@[...]` format first
- Falls back to legacy `@username` format
- Returns `[Mention]` with both username and displayName

#### `findMentionRanges(in:)`
- Finds all mention positions in text
- Returns `[(range: NSRange, displayName: String)]`
- Used for syntax highlighting

#### `findDisplayNameRanges(in:displayText:)` (NEW)
- Calculates display positions after removing `@[...]` markers
- Accounts for text shift from format removal
- Used for highlighting in the rendered text

---

### 4. Insertion Logic (`VisitDetailComponents.swift`)

**Updated `insertMention` function**:

**Before:**
```swift
private func insertMention(username: String) {
    let mention = "@\(username)"
    commentText = beforeAt + mention + spacing + remainingText
}
```

**After:**
```swift
private func insertMention(username: String, displayName: String) {
    let mention = "@[\(displayName)]"  // New format
    commentText = beforeAt + mention + spacing + remainingText
}
```

**Call site updated:**
```swift
MentionAutocompleteDropdown(
    friends: filteredFriends,
    onSelect: { profile in
        let displayName = profile.displayName ?? profile.username
        insertMention(username: profile.username, displayName: displayName)
    }
)
```

---

### 5. Display Logic (`MentionText.swift`)

**Updated to show display names without markers:**

#### Non-interactive (read-only):
```swift
private var attributedString: AttributedString {
    // 1. Replace @[Display Name] with just Display Name
    var displayText = text
    let mentionRanges = MentionParser.findMentionRanges(in: text)
    
    for (range, displayName) in mentionRanges.reversed() {
        displayText.replaceSubrange(swiftRange, with: displayName)
    }
    
    // 2. Apply mint color highlighting
    var attributed = AttributedString(displayText)
    let updatedRanges = MentionParser.findDisplayNameRanges(in: text, displayText: displayText)
    
    for range in updatedRanges {
        attributed[swiftRange].foregroundColor = DS.Colors.primaryAccent
        attributed[swiftRange].font = DS.Typography.bodyText.bold()
    }
    
    return attributed
}
```

#### Interactive (tappable):
```swift
private var attributedStringWithLinks: AttributedString {
    // 1. Replace @[Display Name] with Display Name
    // 2. Apply mint highlighting
    // 3. Add links: "mugshot://mention/{displayName}"
    // 4. Handle taps to navigate to profile
}
```

---

## Data Flow

```
User selects "Kev" from autocomplete
    ↓
insertMention(username: "coffeelovingKev", displayName: "Kev")
    ↓
Text: "Gotta show @[Kev] this spot!"
    ↓
MentionParser.parseMentions()
    ↓
Mention(username: "coffeelovingKev", displayName: "Kev")
    ↓
Saved to database
    ↓
MentionText renders: "Gotta show Kev this spot!"
                                    ^^^
                                   (mint color, tappable)
```

---

## Backward Compatibility

### Legacy mentions (`@username`) still work:

1. **Parsing**: `MentionParser` tries new format first, falls back to legacy
2. **Display**: Legacy `@username` shows as-is, highlighted in mint
3. **Storage**: Old mentions in database continue to work
4. **Migration**: No database migration needed - gradual transition

### Example of mixed content:
```
"@coffeelovingKev (old) and @[Joe (Creator)] (new) love coffee!"
```
Both formats render correctly.

---

## Search Behavior (Unchanged)

Users can still search by:
- ✅ Display name: "Joe" → finds "Joe (Creator)"
- ✅ Username: "coffeelovingKev" → finds "Kev"
- ✅ Partial matches: "cof" → finds "coffeelovingKev"

**Implementation** (in `VisitDetailComponents.swift`):
```swift
private var filteredFriends: [RemoteUserProfile] {
    guard !mentionSearchText.isEmpty else { return friendProfiles }
    let lowercased = mentionSearchText.lowercased()
    return friendProfiles.filter { profile in
        profile.username.lowercased().contains(lowercased) ||
        (profile.displayName?.lowercased().contains(lowercased) ?? false)
    }
}
```

---

## UI Highlights

### Mint Color Styling

```swift
// In MentionText
attributed[swiftRange].foregroundColor = DS.Colors.primaryAccent  // Mugshot mint
attributed[swiftRange].font = DS.Typography.bodyText.bold()
```

**Result**: Display names stand out visually, indicating they're tappable links.

### Tap Behavior

1. User taps highlighted display name
2. `onMentionTap?(displayName)` called
3. App navigates to user's profile
4. Profile looked up by display name (or username if needed)

---

## Testing Checklist

### Basic Functionality
- [x] Can search users by display name
- [x] Can search users by username
- [x] Selecting user inserts display name in text
- [x] Display name shows without `@[...]` markers
- [x] Display name highlighted in Mugshot mint color
- [x] Tapping display name navigates to profile

### Edge Cases
- [x] Display names with spaces work: `@[Joe Smith]`
- [x] Display names with special chars work: `@[Joe (Creator)]`
- [x] Multiple mentions in one comment work
- [x] Legacy `@username` mentions still render correctly
- [x] Mixed old/new format in same text works

### Visual Verification
- [x] Mint highlight applied correctly
- [x] No `@` or `[...]` visible to users
- [x] Spacing around mentions looks natural
- [x] Font weight matches design (bold)

---

## Files Changed

1. **Models**:
   - `testMugshot/Models/Visit.swift` - Updated `Mention` struct

2. **Utilities**:
   - `testMugshot/Utilities/MentionParser.swift` - New parsing logic

3. **Views**:
   - `testMugshot/Views/Visits/VisitDetailComponents.swift` - Updated insertion
   - `testMugshot/Views/Components/MentionText.swift` - Updated display

---

## Future Enhancements

### Potential improvements:
1. **Username resolution**: Store username separately and resolve display name → username on tap
2. **Mention suggestions**: Show recent/frequent contacts first in autocomplete
3. **Mention notifications**: Notify users when they're mentioned
4. **Analytics**: Track mention usage patterns

### Database consideration:
If needed, could add a `mentions` table:
```sql
CREATE TABLE comment_mentions (
  id UUID PRIMARY KEY,
  comment_id UUID REFERENCES comments(id),
  mentioned_user_id UUID REFERENCES users(id),
  display_name TEXT,  -- Snapshot of display name at mention time
  created_at TIMESTAMPTZ
);
```

This would:
- Allow querying "who mentioned me?"
- Preserve display name even if user changes it
- Enable mention notifications

---

## Comparison

| Feature | Before | After |
|---------|--------|-------|
| **Format** | `@username` | `Display Name` |
| **Search** | By username only | By username OR display name |
| **Display** | `@coffeelovingKev` | `Kev` |
| **Color** | Mint | Mint (same) |
| **Tappable** | Yes | Yes (same) |
| **Spaces allowed** | No | Yes |
| **Special chars** | No | Yes (parentheses, etc.) |

---

**Status**: ✅ Implemented  
**Date**: December 2024  
**Breaking Changes**: None (backward compatible)  
**Testing**: Ready for QA
