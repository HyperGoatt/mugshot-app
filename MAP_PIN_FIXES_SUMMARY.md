# Map Pin Fixes - Implementation Summary

## Problem
Map pins were not appearing because:
1. Cafe `visitCount` was always 0 (not being updated after visit creation/fetch)
2. Cafe locations were not being preserved during Supabase sync
3. Search results were creating transient cafes unnecessarily
4. Visit count calculations were using wrong user scope

## Changes Made

### 1. DataManager.swift - Cafe Stats Tracking

#### `updateCafeStatsForVisit(_ visit: Visit)`
**Purpose**: Recalculate visitCount and averageRating for a cafe immediately after visit operations

**Key Changes**:
- Now counts ALL visits across all users (matches Supabase reality)
- Better cafe matching: tries `supabaseCafeId` first, then falls back to `cafeId`
- Comprehensive logging showing before/after visitCount, location status, coordinates
- Lists all available cafes when match fails (for debugging)

**When Called**:
- After creating a new visit (`createVisit`)
- After refreshing profile visits (`refreshProfileVisits`)
- After refreshing feed (`refreshFeed`)

#### `upsertCafe(from remote: RemoteCafe)`
**Purpose**: Merge remote cafe data with existing local cafe, preserving critical state

**Key Changes**:
- **PRESERVES** local state: `isFavorite`, `wantToTry`, `visitCount`
- **PRESERVES** location if remote doesn't have it
- Ensures `supabaseId` is always set from remote
- Detailed logging for every upsert operation

**Critical**: visitCount is preserved and calculated separately via `updateCafeStatsForVisit`

#### `mapRemoteVisit(_ remote: RemoteVisit)`
**Purpose**: Convert a Supabase visit into local Visit object

**Key Changes**:
- Added logging to trace cafe resolution
- Shows when embedded cafe data is present vs. reusing existing
- Calls `upsertCafe` for embedded cafe data

#### `createVisit(...)`
**Purpose**: Create a visit and ensure map updates immediately

**Key Changes**:
- Calls `updateCafeStatsForVisit` **BEFORE** merging visits
- Ensures visitCount is correct before UI refresh
- Added comprehensive logging at start showing cafe name, ID, and location status

#### `refreshFeed(scope: FeedScope)`
**Purpose**: Fetch visits from Supabase and update local state

**Key Changes**:
- After merging visits, **recalculates cafe stats for ALL unique cafes**
- Ensures map shows pins for all fetched visits
- Added detailed logging

#### `refreshProfileVisits()`
**Purpose**: Fetch user's own visits from Supabase

**Key Changes**:
- After merging visits, **recalculates cafe stats for ALL unique cafes**
- Ensures profile's visited cafes show on map
- Added detailed logging

#### `findOrCreateCafe(from mapItem: MKMapItem)`
**Purpose**: Resolve a map search result to a cafe object

**CRITICAL CHANGE**:
- **NO LONGER automatically adds cafes to AppData.cafes**
- Returns a **transient** cafe object
- Cafe is only added to AppData when:
  1. Visit is posted (via `upsertCafe` in `createVisit`)
  2. User favorites/wantToTry
  3. Visits are fetched from Supabase (via `upsertCafe` in `mapRemoteVisit`)

**Prevents**: "Neeld Ave" and other search results from polluting the cafe list

---

### 2. RemoteSocialModels.swift - Coordinate Mapping

#### `RemoteCafe.toLocalCafe(existing: Cafe?)`
**Purpose**: Convert Supabase cafe to local Cafe object

**Key Changes**:
- Added logging to show when coordinates are present/missing
- Explicitly logs converted lat/lon for debugging
- Preserves existing `visitCount` (set to 0 for new cafes, calculated separately)

---

### 3. MapTabView.swift - Enhanced Debugging

#### `cafesWithLocations` (computed property)
**Purpose**: Filter cafes eligible for map display

**Filter Criteria** (ALL must be true):
- Has `location` (latitude, longitude not nil)
- Coordinates are valid (lat ≤ 90, lon ≤ 180)
- At least ONE of:
  - `visitCount > 0`
  - `isFavorite == true`
  - `wantToTry == true`

**Key Changes**:
- Added extensive logging for each cafe:
  - ✅ Qualifies (with reason)
  - ❌ No location
  - ❌ Invalid coordinates
  - ⚠️ Has location but doesn't qualify
- Shows total cafes vs. filtered cafes
- Warns if no cafes passed filter

#### `MapViewRepresentable.makeUIView`
**Key Changes**:
- Added initial annotation loading on map creation
- Logs how many cafes are being added initially

#### `MapViewRepresentable.updateUIView`
**Key Changes**:
- Logs every update cycle
- Shows existing vs. new annotations
- Logs each pin being added with coordinates

#### `CafeAnnotation` init
**Key Changes**:
- Logs when annotation is created
- Warns if location is nil

---

## Expected Behavior After Fixes

### When User Posts a Visit:
1. **Cafe Resolution**:
   - `findOrCreateCafe` returns a transient cafe (not added to AppData yet)
   - User fills out visit form with this cafe

2. **Visit Creation**:
   - `createVisit` calls `cafeService.findOrCreateCafe` → creates/fetches from Supabase
   - `upsertCafe(from remoteCafe)` adds cafe to AppData with coordinates
   - If remote lacks coordinates, local coordinates are preserved
   - `updateCafeStatsForVisit` is called **before** merging visit
   - visitCount is calculated and set (e.g., 1 for first visit)
   - Visit is merged into AppData

3. **Map Update**:
   - `cafesWithLocations` re-evaluates
   - Cafe now has `visitCount > 0` and valid `location`
   - Cafe passes filter
   - Map shows pin immediately

### When User Fetches Feed/Profile:
1. **Remote Visits Fetched**:
   - Each `RemoteVisit` includes embedded `RemoteCafe` with coordinates
   - `mapRemoteVisit` calls `upsertCafe` for each cafe
   - Cafes are added/updated in AppData with coordinates

2. **Stats Recalculation**:
   - `refreshFeed`/`refreshProfileVisits` calls `updateCafeStatsForVisit` for each unique cafe
   - visitCount is recalculated based on ALL visits for that cafe
   - Ensures counts are accurate

3. **Map Update**:
   - `cafesWithLocations` sees updated cafes with visitCount > 0
   - Map shows pins for all visited cafes

### Search Results (e.g., "Neeld Ave"):
- `findOrCreateCafe` returns transient cafe
- **NOT added to AppData.cafes**
- If user doesn't post a visit, cafe is discarded
- Map will never show it

---

## Console Logs to Expect

### On Visit Creation:
```
📝 [CreateVisit] ===== STARTING VISIT CREATION =====
📝 [CreateVisit] Cafe: 'Needle & Bean' (id: ..., supabaseId: ...)
📝 [CreateVisit] Cafe has location: ✅ (34.0522, -118.2437)
🏪 [CafeUpsert] Upserting cafe from Supabase - id: ..., name: 'Needle & Bean'
🏪 [CafeUpsert] Remote has location: lat=34.0522, lon=-118.2437
🏪 [CafeUpsert] ✅ Updated existing cafe: ...
📊 [CafeStats] Updating stats for visit - cafeId: ..., supabaseCafeId: ...
📊 [CafeStats] ✅ Updated 'Needle & Bean':
   - visitCount: 0 → 1
   - hasLocation: true
   - location: 34.0522, -118.2437
```

### On Map Load:
```
🗺️ [Map] Filtering cafes - total: 5
  ✅ 'Needle & Bean' - HAS LOCATION at (34.0522, -118.2437), visitCount: 1
  ❌ 'Some Cafe' - NO LOCATION (visitCount: 0, favorite: false, wantToTry: false)
  ⚠️ 'Another Cafe' - HAS LOCATION but doesn't qualify (visitCount: 0, favorite: false, wantToTry: false)
🗺️ [Map] Filtered result: 1 cafes will show pins (from 5 total)
🗺️ [MapView] makeUIView called - initial cafes count: 1
🗺️ [MapView] Adding 1 initial annotations
✅ [CafeAnnotation] Created annotation for 'Needle & Bean' at (34.0522, -118.2437)
```

---

## Testing Checklist

- [ ] Post a visit to "Needle & Bean"
- [ ] Check console for `visitCount: 0 → 1`
- [ ] Navigate to Map tab
- [ ] Verify pin appears at correct coordinates
- [ ] Search for "Neeld Ave" (or another non-cafe location)
- [ ] Select it in visit form but DON'T post
- [ ] Verify it's NOT in AppData.cafes
- [ ] Verify it doesn't appear on map
- [ ] Close and reopen app
- [ ] Refresh feed (pull to refresh)
- [ ] Check console for stats recalculation
- [ ] Verify all visited cafes show on map
- [ ] Verify visitCount matches number of visits per cafe

---

## Files Modified

1. `testMugshot/Services/DataManager.swift`
   - `updateCafeStatsForVisit`
   - `upsertCafe`
   - `mapRemoteVisit`
   - `createVisit`
   - `refreshFeed`
   - `refreshProfileVisits`
   - `findOrCreateCafe`

2. `testMugshot/Models/Remote/RemoteSocialModels.swift`
   - `RemoteCafe.toLocalCafe`

3. `testMugshot/Views/Map/MapTabView.swift`
   - `cafesWithLocations`
   - `MapViewRepresentable.makeUIView`
   - `MapViewRepresentable.updateUIView`
   - `CafeAnnotation` init

---

## Key Design Decisions

1. **visitCount is calculated, not stored**:
   - We count visits in AppData.visits rather than trusting a stored visitCount
   - This ensures accuracy even if data gets out of sync

2. **Cafes are only added when "real"**:
   - Search results don't pollute the cafe list
   - Only posted visits, favorites, or Supabase-fetched cafes are persisted

3. **Local state is preserved**:
   - isFavorite, wantToTry, visitCount are never overwritten by remote data
   - Location is preserved if remote doesn't have it

4. **Stats are recalculated proactively**:
   - After every visit creation
   - After every feed/profile refresh
   - Ensures map is always up-to-date

5. **Comprehensive logging**:
   - Every operation logs its intent and result
   - Makes debugging future issues trivial

