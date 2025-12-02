<!-- 4340f5b2-7377-47d7-abfe-ffd1d141aba4 0ca8cb35-1141-4175-8b95-2b672c483421 -->
# Fix Comment Not Appearing Until Refresh

## Problem Analysis

The `addComment()` function in `VisitDetailView.swift` has a guard statement that silently exits if `currentUser` or `supabaseUserId` is nil:

```swift
guard !trimmed.isEmpty,
      let currentUser = dataManager.appData.currentUser,
      let supabaseUserId = dataManager.appData.supabaseUserId else {
    return  // Silent failure - no feedback
}
```

Even if the guard passes, there may be issues with:

1. The `@State` mutation not triggering a re-render
2. The `.onChange` handler overwriting the optimistic comment before it renders

## Files to Modify

- `testMugshot/Views/Visits/VisitDetailView.swift`

## Implementation

### 1. Add Debug Logging

Add print statements to trace why comments aren't appearing:

```swift
private func addComment() {
    let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
    
    print("📝 [Comment] addComment called - text: '\(trimmed)'")
    print("📝 [Comment] currentUser: \(dataManager.appData.currentUser != nil)")
    print("📝 [Comment] supabaseUserId: \(dataManager.appData.supabaseUserId != nil)")
    
    guard !trimmed.isEmpty else {
        print("📝 [Comment] ❌ Empty text, returning")
        return
    }
    
    guard let currentUser = dataManager.appData.currentUser else {
        print("📝 [Comment] ❌ currentUser is nil, returning")
        return
    }
    
    guard let supabaseUserId = dataManager.appData.supabaseUserId else {
        print("📝 [Comment] ❌ supabaseUserId is nil, returning")
        return
    }
    
    print("📝 [Comment] ✅ Creating optimistic comment")
    // ... rest of function
}
```

### 2. Force State Update

Ensure the `@State` mutation properly triggers re-render by creating a new array:

```swift
// Instead of:
visit.comments.append(optimisticComment)

// Use:
var updatedComments = visit.comments
updatedComments.append(optimisticComment)
visit.comments = updatedComments  // Full reassignment triggers re-render
```

### 3. Add User Feedback for Failures

Show an alert or toast if the comment can't be posted due to missing user data.

### To-dos

- [ ] Simplify header: inline nav title, icon+text Cancel button
- [ ] Create DrinkTypePillSelector with horizontal scrolling chips
- [ ] Redesign PhotoUploaderCard empty state and thumbnail layout
- [ ] Add quick-rate stars + collapsible category detail to RatingsCard
- [ ] Simplify to single CaptionField, move Notes to More Options
- [ ] Replace VisibilitySelector with compact segmented control
- [ ] Create MoreOptionsSection with collapsed Notes field
- [ ] Update SaveVisitButton copy and add disabled helper text
- [ ] Remove duplicate titles, add section labels, fix spacing