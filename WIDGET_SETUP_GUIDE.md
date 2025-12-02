# Mugshot iOS Widgets - Setup Guide

This guide walks you through completing the widget extension setup in Xcode.

## Overview

We've created 6 widgets for Mugshot:

### Alpha Widgets (Must Ship)
1. **Today's Mugshot** - Shows user's latest visit today or prompts to log one
2. **Friends' Latest Sips** - Rotating view of friends' recent coffee visits
3. **Streak Widget** - Displays coffee logging streak with 7-day activity bar

### Beta Widgets (Scaffolded)
4. **Favorites Quick Access** - Quick access to favorite cafes
5. **Cafe of the Day** - Daily curated cafe suggestion
6. **Nearby Cafe** - Shows nearest cafes from user's known locations

## Files Created

### Widget Extension (`MugshotWidgets/`)
```
MugshotWidgets/
├── Assets.xcassets/
│   ├── Contents.json
│   ├── AccentColor.colorset/
│   └── WidgetBackground.colorset/
├── Info.plist
├── MugshotWidgets.entitlements
├── MugshotWidgetsBundle.swift
├── Shared/
│   ├── WidgetDataModels.swift
│   └── WidgetDesignSystem.swift
└── Widgets/
    ├── TodaysMugshotWidget.swift
    ├── FriendsLatestSipsWidget.swift
    ├── StreakWidget.swift
    ├── FavoritesQuickAccessWidget.swift
    ├── CafeOfTheDayWidget.swift
    └── NearbyCafeWidget.swift
```

### Main App Updates (`testMugshot/`)
```
testMugshot/
├── Services/
│   ├── WidgetSyncService.swift     # Syncs data to widgets
│   └── WidgetDeepLinkHandler.swift # Handles widget tap actions
├── testMugshot.entitlements        # App Group entitlement
└── Info.plist                      # Added URL scheme
```

## Xcode Setup Steps

### Step 1: Add Widget Extension Target

1. Open `testMugshot.xcodeproj` in Xcode
2. Go to **File → New → Target**
3. Select **Widget Extension**
4. Configure:
   - Product Name: `MugshotWidgets`
   - Team: Your team
   - Bundle Identifier: `com.mugshot.app.widgets`
   - Include Configuration Intent: **No** (we use static configuration)
5. Click **Finish**
6. When prompted to activate the scheme, click **Activate**

### Step 2: Delete Auto-Generated Files

Xcode creates some template files. Delete them:
- Delete `MugshotWidgets.swift` (we have `MugshotWidgetsBundle.swift`)
- Delete any auto-generated widget views

### Step 3: Add Existing Files to Target

1. In Project Navigator, right-click the `MugshotWidgets` folder
2. Select **Add Files to "testMugshot"**
3. Navigate to `/MugshotWidgets/` in your project folder
4. Select all files and folders:
   - `MugshotWidgetsBundle.swift`
   - `Info.plist`
   - `MugshotWidgets.entitlements`
   - `Assets.xcassets` folder
   - `Shared` folder
   - `Widgets` folder
5. Ensure "MugshotWidgets" target is checked
6. Click **Add**

### Step 4: Configure App Groups

#### For Main App Target (testMugshot):
1. Select the project in Project Navigator
2. Select **testMugshot** target
3. Go to **Signing & Capabilities**
4. **Remove Push Notifications** capability if present (personal teams don't support it)
5. Click **+ Capability** → **App Groups**
6. Add: `group.co.mugshot.app.shared`

#### For Widget Target (MugshotWidgets):
1. Select **MugshotWidgets** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** → **App Groups**
4. Add: `group.co.mugshot.app.shared`

> **Note:** If you're using a Personal Development Team (free), Push Notifications won't work. You'll need a paid Apple Developer account ($99/year) for push notifications.

### Step 5: Configure Entitlements

#### Main App:
- Ensure `testMugshot.entitlements` is set in Build Settings:
  - Build Settings → Code Signing Entitlements → `testMugshot/testMugshot.entitlements`

#### Widget Extension:
- Ensure `MugshotWidgets.entitlements` is set:
  - Build Settings → Code Signing Entitlements → `MugshotWidgets/MugshotWidgets.entitlements`

### Step 6: Configure Build Settings

#### Widget Target Build Settings:
1. Select MugshotWidgets target
2. Build Settings:
   - Deployment Target: iOS 17.0 (or match main app)
   - Info.plist File: `MugshotWidgets/Info.plist`

### Step 7: Add Main App Files to Widget Target (If Needed)

The widget extension needs access to:
- `JournalStatsHelper.swift` - For streak calculations

Add to widget target membership:
1. Select `JournalStatsHelper.swift` in Project Navigator
2. In File Inspector, check **MugshotWidgets** under Target Membership

**Or** create a shared framework for common code (recommended for larger projects).

### Step 8: Test the Integration

1. Build and run the main app on a device/simulator
2. Add widgets to Home Screen:
   - Long-press → Edit Home Screen → + button
   - Search for "Mugshot"
   - Add each widget

## Deep Link URL Scheme

Widgets use the `mugshot://` URL scheme for navigation:

| Deep Link | Action |
|-----------|--------|
| `mugshot://visit/{id}` | Open visit detail |
| `mugshot://log-visit` | Open Log a Visit |
| `mugshot://feed` | Open Feed tab |
| `mugshot://friends` | Open Friends Hub |
| `mugshot://journal` | Open Journal |
| `mugshot://cafe/{id}` | Open cafe detail |
| `mugshot://saved` | Open Saved tab |
| `mugshot://map` | Open Map tab |
| `mugshot://map/cafe/{id}` | Open Map centered on cafe |

## Widget Refresh Strategy

| Widget | Refresh Policy |
|--------|----------------|
| Today's Mugshot | Next hour or midnight |
| Friends' Latest Sips | Every 30 mins (rotating) |
| Streak Widget | Midnight |
| Favorites | Every 2 hours |
| Cafe of the Day | Midnight |
| Nearby Cafe | Every 30 mins |

## Data Flow

```
Main App                    Widget Extension
    │                              │
    ├── User logs visit ──────────►│
    │   DataManager.addVisit()     │
    │   ↓                          │
    │   WidgetSyncService          │
    │   .syncWidgetData()          │
    │   ↓                          │
    │   Write to App Group    ────►│ Read from App Group
    │   container                  │ WidgetDataStore.load()
    │   ↓                          │
    │   WidgetCenter               │
    │   .reloadAllTimelines()      │
    │                              │
    │◄────── User taps widget ─────┤
    │   onOpenURL handler          │
    │   ↓                          │
    │   WidgetDeepLinkHandler      │
    │   .handleDeepLink()          │
    │   ↓                          │
    │   TabCoordinator             │
    │   .navigateToX()             │
```

## Testing Checklist

- [ ] Build main app successfully
- [ ] Build widget extension successfully
- [ ] Widgets appear in widget gallery
- [ ] Today's Mugshot shows visit or empty state
- [ ] Friends' Latest Sips rotates through friends
- [ ] Streak Widget shows correct streak count
- [ ] Tap actions navigate to correct screens
- [ ] Widget data updates after logging a visit
- [ ] Widget data updates after favoriting a cafe
- [ ] Light mode displays correctly
- [ ] Dark mode displays correctly
- [ ] Multiple widgets can be added simultaneously

## Troubleshooting

### Widgets Not Appearing
- Check bundle identifier is correct
- Verify entitlements are set
- Clean build folder (Cmd+Shift+K) and rebuild

### Data Not Syncing
- Verify App Group identifiers match exactly
- Check file permissions in App Group container
- Add logging to `WidgetSyncService.saveWidgetData()`

### Deep Links Not Working
- Verify URL scheme in Info.plist
- Check `onOpenURL` handler in testMugshotApp.swift
- Add logging to `WidgetDeepLinkHandler`

### Widget Shows Placeholder Data
- Ensure `WidgetDataStore.load()` finds the data file
- Check App Group container path is correct
- Verify JSON encoding/decoding matches between app and widget

## Brand Guidelines Compliance

All widgets follow the Mugshot Design System:
- **Colors**: Mint accent (#B7E2B5), neutral backgrounds
- **Typography**: System fonts with appropriate weights
- **Spacing**: Consistent with DS tokens
- **Corner Radius**: Rounded, friendly appearance
- **Empty States**: Friendly copy with clear CTAs

