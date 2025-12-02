# Sip-Inclusive Copy Audit Summary

This document summarizes all text changes made to shift Mugshot from coffee-exclusive to sip-inclusive language, celebrating all drink experiences.

## Overview

All user-facing strings, labels, placeholders, empty states, onboarding text, headers, button text, and messaging have been updated to be sip-inclusive while maintaining Mugshot's warm, friendly, clean, cozy, delightful brand personality.

## Changes by Category

### A. Onboarding Flow

**Files Updated:**
- `testMugshot/Views/Onboarding/Pages/ConcentricWelcomePage.swift`
- `testMugshot/Views/Onboarding/Pages/ConcentricJournalFeedPage.swift`
- `testMugshot/Views/Onboarding/Pages/ConcentricReadyPage.swift`
- `testMugshot/Views/Onboarding/Pages/OnboardingPage1_Welcome.swift`

**Changes:**
- "Your personal cafe journal and coffee feed" → "Your personal cafe journal and sip feed"
- "Capture your coffee story" → "Capture your sip story"
- "Start logging visits, explore your map, and share your coffee journey" → "Start logging visits, explore your map, and share your sipping journey"

### B. Authentication Flow

**Files Updated:**
- `testMugshot/Views/Auth/SignInView.swift`
- `testMugshot/Views/Auth/SignUpView.swift`
- `testMugshot/Views/Auth/AuthLandingView.swift`

**Changes:**
- "Sign in to continue your coffee journey" → "Sign in to continue your sipping journey"
- "Create an account to save visits, sync your profile, and keep your coffee journey in one place" → "Create an account to save visits, sync your profile, and keep your sipping journey in one place"
- "Your coffee journey starts here" → "Your sipping journey starts here"

### C. Add / Log Visit Flow

**Files Updated:**
- `testMugshot/Views/Add/AddTabView.swift`

**Changes:**
- "Define what matters most in your coffee journey" → "Define what matters most in your sipping journey"

### D. Profile & Journal

**Files Updated:**
- `testMugshot/Views/Profile/ProfileJournalView.swift`
- `testMugshot/Views/Profile/ProfileTabView.swift`
- `testMugshot/Views/Profile/Components/ProfilePostsGrid.swift`

**Changes:**
- "Coffee Stats" → "Sip Stats"
- "Collect badges as you log your coffee journey" → "Collect badges as you log your sipping journey"
- "Your coffee journey photos will appear here" → "Your sipping journey photos will appear here"
- "Check out my Mugshot coffee profile: @\(username)" → "Check out my Mugshot profile: @\(username)"

### E. Widgets

**Files Updated:**
- `MugshotWidgets/Widgets/StreakWidget.swift`
- `MugshotWidgets/Widgets/TodaysMugshotWidget.swift`

**Changes:**
- Widget comment: "coffee logging streak" → "sip logging streak"
- "Coffee Streak" → "Sip Streak"
- "Track your daily coffee logging streak" → "Track your daily sip logging streak"
- "See your latest coffee visit or log a new one" → "See your latest sip visit or log a new one"
- "Tap to log your first coffee of the day" → "Tap to log your first sip of the day"

### F. Badges

**Files Updated:**
- `testMugshot/Models/Badge.swift`

**Changes:**
- "Coffee Chronicler" → "Sip Chronicler" (user-facing badge name)
- Note: Badge ID `coffee_chronicler` remains unchanged (internal identifier)

### G. Map & Search

**Files Updated:**
- `testMugshot/Views/Map/MapTabView.swift`

**Changes:**
- Default search query: "Coffee" → "Café" (more inclusive, still returns good search results)

### H. Mock/JSON Files

**Files Updated:**
- `mugshot_profile_current_structure.json`
- `mugshot_profile_mock_structure.json`

**Changes:**
- "Coffee Journey" → "Sipping Journey" (for consistency in design specs)

## Terminology Mapping

The following terminology transformations were applied throughout:

- "coffee journey" → "sipping journey"
- "coffee feed" → "sip feed"
- "coffee story" → "sip story"
- "coffee stats" → "sip stats"
- "coffee visit" → "sip visit"
- "coffee profile" → "profile" (removed coffee qualifier)
- "coffee logging" → "sip logging"
- "coffee streak" → "sip streak"
- "first coffee of the day" → "first sip of the day"
- "Coffee Chronicler" → "Sip Chronicler"

## What Was NOT Changed

Per requirements, the following were intentionally left unchanged:

- Model names (Cafe, Visit, etc.)
- Enum cases (DrinkType.coffee remains)
- Internal identifiers (badge IDs, etc.)
- Database schemas
- Navigation structure
- Functionality

## Validation

- ✅ No linter errors introduced
- ✅ All changes maintain brand voice (warm, friendly, clean, cozy, delightful)
- ✅ Text length changes are minimal and should not cause layout regressions
- ✅ All user-facing strings updated to be sip-inclusive

## Files Modified

**Swift Files (15):**
1. `testMugshot/Views/Onboarding/Pages/ConcentricWelcomePage.swift`
2. `testMugshot/Views/Onboarding/Pages/ConcentricJournalFeedPage.swift`
3. `testMugshot/Views/Onboarding/Pages/ConcentricReadyPage.swift`
4. `testMugshot/Views/Onboarding/Pages/OnboardingPage1_Welcome.swift`
5. `testMugshot/Views/Auth/SignInView.swift`
6. `testMugshot/Views/Auth/SignUpView.swift`
7. `testMugshot/Views/Auth/AuthLandingView.swift`
8. `testMugshot/Views/Add/AddTabView.swift`
9. `testMugshot/Views/Profile/ProfileJournalView.swift`
10. `testMugshot/Views/Profile/ProfileTabView.swift`
11. `testMugshot/Views/Profile/Components/ProfilePostsGrid.swift`
12. `MugshotWidgets/Widgets/StreakWidget.swift`
13. `MugshotWidgets/Widgets/TodaysMugshotWidget.swift`
14. `testMugshot/Models/Badge.swift`
15. `testMugshot/Views/Map/MapTabView.swift`

**JSON Files (2):**
1. `mugshot_profile_current_structure.json`
2. `mugshot_profile_mock_structure.json`

**Total: 17 files modified**

## Next Steps

1. Test the app to ensure all text displays correctly
2. Verify layout integrity (especially for longer text like "sipping journey")
3. Review widget configurations in iOS Settings
4. Consider updating any external documentation or marketing materials

