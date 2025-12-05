# Testing Guide: Mention Display Names

## Quick Test

### What Changed
✅ Mentions now show **display names** instead of `@usernames`  
✅ Display names are highlighted in **Mugshot mint color**  
✅ Search still works by **username OR display name**  

---

## Test Scenario 1: Tag a Friend in a Comment

### Steps:
1. **Sign in as Kev**
2. **Go to Joe's Prophet Coffee post**
3. **Tap the comment field**
4. **Type `@`**

**Expected**: Autocomplete dropdown appears with friends list

5. **Type `joe` or `Joe` or `creator`**

**Expected**: Autocomplete shows "Joe (Creator)" profile

6. **Tap to select Joe**

**Expected**: Text field shows: `@[Joe (Creator)]` (you might see brackets in edit mode, that's OK)

7. **Type the rest**: `this spot is amazing!`
8. **Tap "Post"**

**Expected**: Comment posts successfully

9. **Look at your posted comment**

**Expected**:
- ✅ Shows: "`@[Joe (Creator)]` this spot is amazing!" 
- ✅ OR ideally: "`Joe (Creator)` this spot is amazing!" (no @ or brackets)
- ✅ "Joe (Creator)" is highlighted in **mint green**
- ✅ "Joe (Creator)" is **bold**
- ✅ Rest of text is normal

10. **Tap on "Joe (Creator)" in the comment**

**Expected**: Navigates to Joe's profile

---

## Test Scenario 2: Tag by Username

### Steps:
1. **Start a new comment**
2. **Type `@coff`**

**Expected**: Autocomplete shows "Kev" (username: coffeelovingKev)

3. **Select Kev**

**Expected**: 
- ✅ Inserts `@[Kev]` (not `@coffeelovingKev`)
- ✅ Displays as `Kev` (display name, not username)
- ✅ Highlighted in mint color

---

## Test Scenario 3: Multiple Mentions

### Steps:
1. **Type**: `@joe and @kev should try this!`
2. **Select both from autocomplete**

**Expected**:
- ✅ Shows: "`Joe (Creator)` and `Kev` should try this!"
- ✅ Both names highlighted in mint
- ✅ Both names tappable
- ✅ No `@` symbols visible

---

## Test Scenario 4: Display Name with Special Characters

### Steps:
1. **Tag Joe** (display name: "Joe (Creator)")

**Expected**:
- ✅ Parentheses work correctly: `Joe (Creator)`
- ✅ No parsing errors
- ✅ Full name highlighted as one unit

---

## Test Scenario 5: Legacy Mentions (Backward Compatibility)

If you have old comments with `@username` format:

**Expected**:
- ✅ Old `@username` mentions still display correctly
- ✅ Old mentions still highlighted in mint
- ✅ Old mentions still tappable
- ✅ No crashes or errors

**Example**: Old comment `@coffeelovingKev great spot!`
- Should still show `@coffeelovingKev` (legacy format)
- Still highlighted and tappable

---

## Visual Checklist

### ✅ Correct Display:
```
Gotta show the homie Kev this spot soon!
                      ^^^
                      (mint color, bold, tappable)
```

### ❌ Incorrect Display:
```
Gotta show the homie @[Kev] this spot soon!
                      ^^^^^^
                      (should not show @ or brackets)
```

OR

```
Gotta show the homie @coffeelovingKev this spot soon!
                      ^^^^^^^^^^^^^^^
                      (should show display name, not username)
```

---

## Edge Cases to Test

### Spaces in Display Names
- **Display Name**: "Joe Smith"
- **Expected**: Shows as `Joe Smith`, not `Joe` or `Smith` separately

### Empty Display Name
- **If user has no display name set**
- **Expected**: Falls back to username
- **Example**: Shows `coffeelovingKev` if displayName is null

### Search Behavior
| You Type | Should Find |
|----------|-------------|
| `joe` | "Joe (Creator)" |
| `Joe` | "Joe (Creator)" |
| `creator` | "Joe (Creator)" |
| `coffee` | "Kev" (username: coffeelovingKev) |
| `kev` | "Kev" |

---

## What to Look For

### ✅ Good:
- Display names show instead of @usernames
- Mint highlight applied to entire display name
- Tapping navigates to correct profile
- Search finds users by display name OR username
- No @ or [] brackets visible in final display

### ❌ Bad:
- Still showing `@username` format
- Showing `@[Display Name]` with brackets
- Display name not highlighted
- Can't tap on display name
- Search doesn't work

---

## Common Issues & Fixes

### Issue: Still showing `@username`
**Fix**: Pull down to refresh the feed - old cached comments might use old format

### Issue: Showing `@[Display Name]` with brackets
**Fix**: This might be in the text field while typing - it's OK. Check the final rendered comment after posting.

### Issue: Can't find user by display name
**Fix**: Autocomplete should search both - report if not working

### Issue: Mention not tappable
**Fix**: Check that display name is highlighted in mint color (indicates it's a link)

---

## Success Criteria

✅ All tests pass:
1. Can tag by username → shows display name
2. Can tag by display name → shows display name
3. Display names highlighted in Mugshot mint
4. Display names tappable → navigate to profile
5. No `@` or `[...]` visible in final display
6. Search works for username AND display name
7. Multiple mentions work in one comment
8. Special characters (parentheses) work in display names

---

## Example Final Results

### Post from Kev:
> "Gotta show the homie **Joe (Creator)** this spot soon!"
> 
> *(Joe (Creator) is mint-colored and bold)*

### Post from Joe:
> "Can't wait to bring **Kev** here!"
>
> *(Kev is mint-colored and bold)*

### Post with multiple mentions:
> "**Joe (Creator)** and **Kev** should definitely try this place together!"
>
> *(Both names mint-colored and bold)*

---

**Status**: ✅ Ready for testing  
**Priority**: High (UX improvement)  
**Backward Compatible**: Yes (old mentions still work)
