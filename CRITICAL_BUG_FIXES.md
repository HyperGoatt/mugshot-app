# Critical Bug Fixes - Duplicate Key Crash

## Date: November 30, 2025

## Critical Issue: Fatal Crash on Map View

### Problem
The app was crashing with a fatal error when enabling Sip Squad mode:
```
Fatal error: Duplicate values for key: '6567CFAD-44A1-41BF-9AE2-8C2912C03684'
```

**Crash Location**: `MapViewRepresentable.updateUIView` at line 543

### Root Causes

1. **Dictionary Creation with Duplicate Keys** (`MapTabView.swift:543`)
   - The optimization added `Dictionary(uniqueKeysWithValues:)` which crashes if there are duplicate cafe IDs
   - The `getSipSquadCafes()` method was returning cafes with duplicate IDs

2. **Duplicate Cafe IDs in Sip Squad Mode** (`DataManager.getSipSquadCafes()`)
   - When aggregating cafes from user + friends, the same cafe could appear multiple times
   - Different visit groups could map to the same cafe ID through different lookup strategies
   - No deduplication logic was in place

### Fixes Applied

#### 1. Safe Dictionary Initialization (`MapTabView.swift`)
**Before**:
```swift
let currentCafesById = Dictionary(uniqueKeysWithValues: cafes.map { ($0.id, $0) })
```

**After**:
```swift
// BUGFIX: Handle duplicate cafe IDs safely - keep only the first occurrence
var cafesById: [UUID: Cafe] = [:]
for cafe in cafes {
    if cafesById[cafe.id] == nil {
        cafesById[cafe.id] = cafe
    }
}
let currentCafesById = cafesById
```

**Impact**: Prevents crash if duplicate cafes are passed to the map view. Now safely handles duplicates by keeping only the first occurrence.

#### 2. Deduplication in `getSipSquadCafes()` (`DataManager.swift`)
**Changes**:
- Track cafes by their actual ID (not the visit's cafe key) to prevent duplicates
- Merge visits if the same cafe ID is encountered multiple times
- Recalculate aggregated ratings after all cafes are processed

**Impact**: Ensures `getSipSquadCafes()` never returns duplicate cafes, preventing the crash at the source.

#### 3. MainActor Isolation Warning Fix (`DataManager.swift`)
- Fixed warning: "call to main actor-isolated instance method in a synchronous nonisolated context"
- Captured photo paths before async dispatch to avoid MainActor isolation issues

### Testing Checklist

- [x] App builds without errors
- [ ] Sip Squad mode can be toggled without crashing
- [ ] Map displays correctly with Sip Squad mode enabled
- [ ] No duplicate cafe pins appear on map
- [ ] Cafe detail views open correctly from map pins

### Files Modified

1. `testMugshot/Views/Map/MapTabView.swift` - Safe dictionary initialization
2. `testMugshot/Services/DataManager.swift` - Deduplication in `getSipSquadCafes()` and MainActor fix

### Additional Notes

- The "Failed to locate resource named 'default.csv'" warning is from MapKit/another framework and is not critical
- The "Requesting visual style in an implementation that has disabled it" warnings are also from system frameworks

### Prevention

To prevent similar issues in the future:
- Always use safe dictionary initialization when dealing with potentially duplicate keys
- Add deduplication logic when aggregating data from multiple sources
- Consider using `Dictionary(grouping:by:)` or similar methods that handle duplicates gracefully

