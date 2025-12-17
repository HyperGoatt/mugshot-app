---
name: Fix Comment Not Appearing Until Refresh
overview: ""
todos:
  - id: 8946d1eb-86ba-433a-a115-4204c4e7766f
    content: "Simplify header: inline nav title, icon+text Cancel button"
    status: pending
  - id: ba7dc34b-1437-4cf9-8305-b3cc1cf8fce2
    content: Create DrinkTypePillSelector with horizontal scrolling chips
    status: pending
  - id: 5edefdee-2179-4fb1-bb26-fa5094464f76
    content: Redesign PhotoUploaderCard empty state and thumbnail layout
    status: pending
  - id: faa4c0bd-e1c8-4632-8060-4d6e65331e1b
    content: Add quick-rate stars + collapsible category detail to RatingsCard
    status: pending
  - id: fdab0d6f-60dd-40f3-b0e1-2a24ccabf219
    content: Simplify to single CaptionField, move Notes to More Options
    status: pending
  - id: d7b9d5b2-fa34-4b41-8514-6f561968e05c
    content: Replace VisibilitySelector with compact segmented control
    status: pending
  - id: 640ed097-c792-4e60-825a-cb8382a0d926
    content: Create MoreOptionsSection with collapsed Notes field
    status: pending
  - id: 68ec9a1c-c831-4926-b11f-2ef6e93048d7
    content: Update SaveVisitButton copy and add disabled helper text
    status: pending
  - id: 9d5412f2-7c6b-4af3-a682-bdd0d856e6c5
    content: Remove duplicate titles, add section labels, fix spacing
    status: pending
---

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