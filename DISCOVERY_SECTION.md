# Feed Tab - Discovery Section: Comprehensive Documentation

## Overview

The **Discovery** section is the third scope in the Feed tab (alongside "Friends" and "Everyone"). It serves as a personalized discovery hub that helps users find new cafes, see what their friends are sipping, and discover their next coffee spot through an interactive "Spin for a Spot" feature. Unlike the Friends and Everyone scopes which show visit posts, the Discovery section is entirely discovery-focused with no feed posts.

**Location:** Feed Tab → Discover Scope (segmented control)  
**Purpose:** Personalized cafe discovery, friend activity, and serendipitous cafe selection  
**Data Source:** Local data (no server refresh needed) + Apple Maps API for nearby cafes

---

## Discovery Section Structure

The Discovery section (`DiscoverContentView`) consists of **4 main sections** displayed in vertical order:

1. **Personalized Greeting** - Time-based greeting with user's first name
2. **Cafes Near You** - Top 5 nearby cafes with distance and ratings
3. **What Your Friends Are Sipping** - Horizontal carousel of recent friend visits
4. **Spin for a Spot** - Full-width button launching the spinner experience

---

## Section 1: Personalized Greeting

### Purpose
Creates a warm, personalized welcome that changes based on time of day and uses the user's first name.

### Implementation

**Component:** `greetingHeader` in `DiscoverContentView`

**Data Source:**
- User's display name from `dataManager.appData.currentUser?.displayNameOrUsername`
- Current date/time for greeting selection

**Greeting Logic:**
- Extracts first name from user's display name (splits by space, takes first word)
- Falls back to "Friend" if no name available
- Uses `GreetingHelper.getGreeting(userName:)` to select appropriate greeting

**GreetingHelper System:**

The `GreetingHelper` provides **72 unique greetings** organized by time of day:

- **Morning (5am - 12pm):** 18 greetings
  - Examples: "Good morning, {name} ☀️", "Rise and grind, {name} ☕", "Morning vibes, {name} ☀️"
  
- **Afternoon (12pm - 5pm):** 18 greetings
  - Examples: "Good afternoon, {name} ☕", "Afternoon pick-me-up, {name}!", "Midday fuel time, {name} ⚡"
  
- **Evening (5pm - 9pm):** 18 greetings
  - Examples: "Good evening, {name} 🌅", "Evening sips, {name}!", "Golden hour coffee, {name} 🌇"
  
- **Night (9pm - 5am):** 18 greetings
  - Examples: "Good evening, {name} 🌙", "Night owl mode, {name}! 🦉", "Late night sips, {name} ☕"

**Greeting Selection Algorithm:**
1. Get current hour from `Calendar.current.component(.hour, from: Date())`
2. Select appropriate greeting array based on time of day
3. Use seeded random number generator (seeded by day of year) to ensure consistent greeting throughout the day
4. Replace `{name}` placeholder with user's first name

**Date Display:**
- Shows formatted date: "EEEE, MMMM d" (e.g., "FRIDAY, DECEMBER 6")
- Uppercased for visual consistency
- Uses `DateFormatter` with uppercase output

**Visual Design:**
- **Title:** `DS.Typography.title1()` - Large, prominent greeting
- **Date:** `DS.Typography.caption1()` - Smaller, secondary text
- **Colors:** `textPrimary` for greeting, `textSecondary` for date
- **Spacing:** `DS.Spacing.xs` between greeting and date
- **Padding:** `DS.Spacing.pagePadding` horizontal padding

---

## Section 2: Cafes Near You

### Purpose
Shows the top 5 cafes closest to the user's current location, helping them discover nearby spots they might want to visit.

### Implementation

**Component:** `nearbyCafesSection` in `DiscoverContentView`

**Data Source:**
- User's current location via `LocationManager`
- Apple Maps API for cafe search
- Local visit data for ratings and photos

**Location Management:**
- Uses `@StateObject private var locationManager = LocationManager()`
- Requests location permission on view appear
- Triggers cafe search when location becomes available
- Monitors location changes via `.onChange(of: locationManager.location)`

**Search Algorithm:**

**Method:** `dataManager.searchNearbyCafes(near:location, radiusMiles:3.0, limit:5)`

**Hybrid Search Strategy:**
The search uses a **dual-request approach** to maximize cafe discovery:

1. **POI Category Search:**
   - Uses `MKLocalPointsOfInterestRequest` with center and radius
   - Filters for `.cafe` and `.bakery` categories
   - Searches within `radiusMeters` (default: 3.0 miles = 4,828 meters)

2. **Keyword Search:**
   - Uses `MKLocalSearch.Request` with natural language query "coffee"
   - Searches within a region (radius * 2 for broader coverage)
   - Focuses on point of interest results

**Result Processing:**
1. **Combine Results:** Merges POI and keyword search results
2. **Deduplicate:** Removes duplicates by name + coordinate (unique key: `"\(name)|\(coordinate)"`)
3. **Convert to Cafes:**
   - Checks if cafe exists in local database by Apple Place ID or name
   - If exists: Uses existing cafe (may update missing metadata)
   - If new: Creates `Cafe` from `MKMapItem` with:
     - Name, location, address, city, country
     - `mapItemURL`, `websiteURL`, `applePlaceId`, `placeCategory`
4. **Sort by Distance:** Calculates distance from user location, sorts ascending
5. **Limit:** Takes top 5 cafes

**Data Enrichment:**

For each cafe, the section calculates:

- **Distance:** Calculated from user location to cafe location (in meters, converted to miles)
- **Average Rating:** `dataManager.calculateAverageRating(for: cafe.id)`
  - Filters visits for this cafe with `overallScore > 0`
  - Calculates average: `sum(overallScore) / count`
  - Returns `(average: Double, count: Int)`
- **Total Ratings:** Count of visits with ratings
- **Photo URL:** `dataManager.getPhotoURLsForCafe(cafe.id, limit: 1).first`
  - Prioritizes friend photos, then other users' photos
  - Returns poster photo URLs from recent visits
- **Has Visits:** Boolean indicating if any visits exist for this cafe

**Display Component:** `NearbyCafeCard`

**Card Layout:**
- **Left:** 60×60pt thumbnail (photo or placeholder)
- **Center:** Cafe name (headline), distance + rating row
- **Right:** Chevron indicator

**Card Content:**
- **Cafe Name:** `DS.Typography.headline()`, single line, `textPrimary`
- **Distance:** Formatted as "X.X mi" or "X ft" if < 0.1 miles
- **Rating:** Star icon + score (e.g., "4.5") if rating > 0
- **Thumbnail:** Async image loading with placeholder (mint background + cup icon)

**Empty States:**

**Loading State:**
- Progress indicator + "Finding cafes nearby..." text
- Shown while `isLoadingCafes == true`

**No Location State:**
- Location slash icon
- "Location unavailable" message
- "Check location permissions" subtitle

**No Cafes Found State:**
- Magnifying glass icon
- "No cafes found nearby" message
- "Try again later" subtitle

**Visual Design:**
- **Card:** `DSBaseCard` with `DS.Radius.lg` corner radius
- **Spacing:** `DS.Spacing.sm` between cards
- **Padding:** `DS.Spacing.pagePadding` horizontal
- **Section Header:** "Cafes near you" in `DS.Typography.sectionTitle`

---

## Section 3: What Your Friends Are Sipping

### Purpose
Shows a horizontal carousel of recent visits from the user's friends, providing social context and inspiration for cafe choices.

### Implementation

**Component:** `friendsSippingSection` in `DiscoverContentView`

**Data Source:**
- `dataManager.getRecentFriendVisits(limit: 5)`

**Friend Visit Retrieval Algorithm:**

**Method:** `DataManager.getRecentFriendVisits(limit: Int = 5) -> [Visit]`

**Filtering Logic:**
1. **Get Friend IDs:** `appData.friendsSupabaseUserIds` (array of Supabase user IDs)
2. **Time Window:** Only visits from last 7 days
   - `sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())`
3. **Filter Criteria:**
   - Visit must have `supabaseUserId` (author is a Supabase user)
   - Author ID must be in friend IDs list
   - Visit author must NOT be current user (`visit.userId != currentUserId`)
   - Visit `createdAt >= sevenDaysAgo`
4. **Sort:** Most recent first (`createdAt` descending)
5. **Limit:** Return up to `limit` visits (default: 5)

**Display Component:** `FriendVisitCard`

**Card Layout:**
- **Top:** Photo thumbnail (120pt height, full width)
- **Middle:** Friend avatar (32pt) + name + time ago
- **Bottom:** Drink subtype/type + cafe name with location icon

**Card Content:**
- **Photo:** `visit.posterPhotoURL` loaded via `AsyncImage`
  - Placeholder: Mint background with cup icon if no photo
- **Friend Avatar:** `visit.authorAvatarURL` or initials placeholder
  - 32×32pt circle with border
  - Initials shown if no avatar
- **Friend Name:** `visit.authorDisplayNameOrUsername`
  - `DS.Typography.caption1(.semibold)`, single line
- **Time Ago:** Relative time (e.g., "2h ago", "1d ago")
  - Uses `RelativeDateTimeFormatter` with abbreviated units
- **Drink Info:**
  - Prefers `drinkSubtype` if available (e.g., "Iced Lavender Latte")
  - Falls back to `drinkType.rawValue` (e.g., "Coffee")
  - `DS.Typography.subheadline(.semibold)`
- **Cafe Name:** Passed as parameter, shown with location icon
  - `DS.Typography.caption2()`, single line

**Card Dimensions:**
- Fixed width: 200pt
- Auto height based on content
- Padding: `DS.Spacing.md` all around

**Empty State:**

**Component:** `emptyFriendsPlaceholder`

**Content:**
- Cup icon (32pt, tertiary color)
- "Your Sip Squad is quiet" (subheadline, semibold)
- "Be the first to log a sip today!" (caption1)
- Fixed height: 160pt
- Card background with shadow

**Visual Design:**
- **Section Header:** "What your friends are sipping" in `DS.Typography.sectionTitle`
- **Carousel:** Horizontal `ScrollView` with no indicators
- **Card Spacing:** `DS.Spacing.md` between cards
- **Padding:** `DS.Spacing.pagePadding` horizontal

---

## Section 4: Spin for a Spot

### Purpose
An interactive, gamified feature that randomly selects a nearby independent cafe for the user to visit. Combines Apple Maps search, chain filtering, fortune wheel animation, and celebratory confetti.

### Implementation

**Component:** `spinButtonSection` in `DiscoverContentView` + `SpinForASpotView` (fullscreen modal)

**Button Design:**
- Full-width button with mint background
- Dice icon + "Spin for a Spot" text
- Mint accent color with shadow
- `DS.Radius.primaryButton` corner radius
- Launches fullscreen modal on tap

**Fullscreen Experience:** `SpinForASpotView`

### Spin for a Spot Flow

The Spin for a Spot experience has **4 distinct phases**:

1. **Ready** - Initial state with distance slider
2. **Searching** - Finding cafes nearby
3. **Spinning** - Fortune wheel animation
4. **Result** - Selected cafe display with confetti

---

## Phase 1: Ready State

### Purpose
Allows user to configure search radius before starting the spin.

### Components

**Distance Slider:**
- **Label:** "Search radius" with location icon
- **Current Value:** Displayed on right (e.g., "2.5 mi", "10 mi")
- **Slider:** Maps to valid radius values
- **Range Labels:** "0.25 mi" (left) to "10 mi" (right)

**Valid Radius Values:**
```swift
[0.25, 0.5, 0.75, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
```

**Slider Logic:**
- Slider position (0 to 12) maps to index in valid values array
- Value is clamped to valid range
- Display formatting:
  - Whole numbers: "5 mi" (integer)
  - Fractional: "0.25 mi" (2 decimal places)

**Default Radius:** 10.0 miles

**Visual Design:**
- **Wheel Preview:** Decorative circle (200×200pt) with mint glow
- **Mugsy Image:** "MugsySpin" asset in center (120pt max height)
- **Slider Card:** `DSBaseCard` with `DS.Radius.lg` corner radius
- **Button:** "Find Cafes" full-width mint button

---

## Phase 2: Searching State

### Purpose
Shows loading state while searching for cafes using Apple Maps.

### Components

**Loading Indicator:**
- Large progress view (1.5x scale) with mint tint
- "Finding cafés nearby..." headline text
- "Excluding chains, keeping it local" caption

**Search Process:**

**Method:** `searchForIndependentCafes(near: coordinate)`

**Hybrid Search Strategy:**

The search uses the same dual-request approach as "Cafes Near You" but with more aggressive filtering:

1. **POI Category Search:**
   - `MKLocalPointsOfInterestRequest` with `.cafe` and `.bakery` categories
   - Radius: User-selected `searchRadiusMiles` converted to meters

2. **Keyword Search:**
   - Natural language query: "coffee"
   - Region: `radiusMeters * 2` (broader coverage)
   - Result type: Point of interest only

**Result Processing:**

**Step 1: Deduplication**
- Creates unique key: `"\(name)|\(coordinate)"`
- Removes duplicate map items

**Step 2: Distance Filtering**
- **Strict Check:** Only includes cafes within `radiusMeters` of user location
- Calculates distance: `itemLocation.distance(from: userLocation)`
- Filters out any cafes beyond the selected radius

**Step 3: Category Filtering**
- **Primary:** Only `.cafe` category (covers coffee shops)
- **Secondary:** `.bakery` category allowed ONLY if name contains coffee keywords
- Coffee keywords: "coffee", "café", "cafe", "espresso", "latte", "cappuccino", "brew", "roast", "roaster", "roastery", "bean", "beans", "mocha", "americano", "macchiato", "pour over", "cold brew", "drip", "barista", "coffeehouse", "coffee house"
- Excludes pure bakeries without coffee-related terms

**Step 4: Name-Based Filtering**
- **Dessert Shop Detection:** Filters out dessert/candy/ice cream shops
- Keywords: "candy", "sweet", "dessert", "ice cream", "icecream", "gelato", "frozen yogurt", "froyo", "cupcake", "cookie", "donut", "doughnut", "pastry", "cake shop", "cake house", "chocolat", "chocolate shop", "confection", "sweets", "treats", "sugar", "fudge", "taffy", "praline", "macarons", "macaron"

**Step 5: Chain Filtering**

**CafeChainFilter System:**

Excludes known chain cafes using pattern matching on cafe names (case-insensitive):

**Major Chains Excluded:**
- Starbucks
- Dunkin' / Dunkin
- Panera
- Peet's Coffee / Peets Coffee
- Coffee Bean & Tea Leaf
- McDonald's / McDonalds
- Burger King
- Wendy's / Wendys
- Tim Hortons
- Caribou Coffee
- Dutch Bros
- 7-Eleven / 7 Eleven
- Circle K
- Wawa
- Sheetz
- Krispy Kreme
- Cinnabon
- Au Bon Pain
- Corner Bakery
- La Boulange
- Noah's Bagels
- Einstein Bros
- Bruegger's
- Atlanta Bread
- Cosi
- Paradise Bakery
- McAlister's Deli
- Jason's Deli

**Filtering Logic:**
```swift
static func isChain(mapItem: MKMapItem) -> Bool {
    guard let name = mapItem.name?.lowercased() else { return false }
    return chainPatterns.contains { pattern in
        name.contains(pattern)
    }
}
```

**Step 6: Cafe Mapping**
- For each filtered result, calls `dataManager.findOrCreateCafe(from: mapItem)`
- Maps `MKMapItem` to `Cafe` model
- Checks if cafe exists locally (by location within 50 meters or name match)
- Creates new cafe if not found
- Stores `mappedCafe` reference in `SpinCafeResult`

**Step 7: Random Sampling**
- Sorts filtered results by distance (closest first)
- Randomly samples up to 20 cafes for the wheel
- Uses `shuffled().prefix(20)` to keep results fresh
- Ensures each spin can show different cafes even with same search

**Error Handling:**

**No Location:**
- Error: "Unable to get your location. Please enable location services."
- Returns to ready state

**No Results:**
- Error: "No cafés found within X mi. Try increasing the search radius."
- Returns to ready state

**No Independent Cafes:**
- Error: "No independent cafés found nearby. All results were chains. Try a larger radius."
- Returns to ready state

**Search Errors:**
- Error: "Couldn't search for cafés. Please try again."
- Returns to ready state

---

## Phase 3: Spinning State

### Purpose
Displays an animated fortune wheel that spins to select a random cafe from the search results.

### Components

**MugshotFortuneWheel:**
- 300×300pt circular wheel
- Segmented by number of cafes found
- Each segment shows cafe's shortened name
- Mint-branded color palette for segments
- Center hub with Mugsy image
- Pointer/indicator at top (triangle)

**Wheel Design:**

**Segment Colors (8-color palette, cycles):**
- `#B7E2B5` - Mugshot mint
- `#FAF8F6` - Cream white
- `#E6DED4` - Sand beige
- `#D6F0D6` - Light mint
- `#FFFFFF` - White
- `#ECF8EC` - Mint soft fill
- `#F9FAFB` - Neutral card
- `#C8D8C8` - Sage mint

**Segment Layout:**
- Each segment is a pie slice (`WheelSlice` shape)
- Segments start from top (0°) and divide 360° equally
- Segment index `i` spans: `[i * (360/total), (i+1) * (360/total)]`
- White stroke (2pt) between segments

**Cafe Name Display:**
- Shortened name for wheel (max 12 characters, truncates with "...")
- Positioned at 65% radius from center
- Rotated to align with segment angle
- Font: System 10pt semibold
- Color: `textPrimary`

**Center Hub:**
- 70×70pt circle with card background
- 60×60pt inner circle with mint stroke (3pt)
- Mugsy image (40pt max height) in center
- Shadow for depth

**Pointer:**
- Triangle shape at top of wheel
- Mint color (`primaryAccent`)
- 24×20pt size
- Positioned 135pt from center (top)
- Shadow for visibility

**Animation:**

**Selection Algorithm:**
1. **Random Selection:** Picks random index from `0..<cafeResults.count`
   - Each cafe has equal probability: `1/count`
   - 100% random, no weighting
2. **Rotation Calculation:**
   - Base rotation: 5-8 full rotations (1,800° - 2,880°)
   - Segment alignment: Calculates angle needed to align selected segment with pointer
   - Final rotation: `baseRotation + alignmentNeeded`
3. **Animation:**
   - Duration: 5.0 seconds
   - Easing: `.easeOut` (starts fast, decelerates)
   - Rotates wheel to final position

**Progressive Haptics:**

During the 5-second spin, haptics progressively intensify:

- **Fast Spin (0-2 seconds):** Light haptics every 0.1 seconds (20 haptics)
- **Medium Spin (2-3.5 seconds):** Medium haptics every 0.2 seconds (8 haptics)
- **Slow Deceleration (3.5-5 seconds):** Heavy haptics every 0.4 seconds (4 haptics)

**Total:** 32 haptic feedback events over 5 seconds, creating a tactile sense of the wheel slowing down.

**Result Display:**
- After 5.2 seconds, shows selected cafe
- Transitions to result phase with spring animation

---

## Phase 4: Result State

### Purpose
Celebrates the selected cafe with confetti animation and provides actions to view the cafe or spin again.

### Components

**Victory Animation:**
- "MugsySpinCelebrate" image (120pt max height)
- "Mugsy chose..." text (caption1, semibold, tracking: 2)
- Positioned at top of result view

**Result Card:**
- Cafe name (title1, 2-line limit)
- Distance badge (mint pill with location icon)
- Address (caption1, 2-line limit, tertiary color)
- Mini map preview (100pt height) showing cafe location

**Distance Badge:**
- Format: "Nearby" (< 0.1 mi), "X.X mi away" (< 1 mi), "X mi away" (≥ 1 mi)
- Mint background (`primaryAccentSoftFill`)
- Location icon + distance text
- Pill shape (`DS.Radius.pill`)

**Mini Map Preview:**
- `MiniMapPreview` component
- Shows cafe location with mint marker
- Standard map style, disabled interaction
- 100pt height, medium corner radius

**Confetti Explosion:**

**Component:** `MugshotConfettiCannon`

**Trigger:**
- Triggered 0.5 seconds after result appears
- Uses `confettiTrigger` binding (incremented to trigger)
- Positioned to shoot from Mugsy image center

**Confetti Properties:**
- **Count:** 60 pieces
- **Colors:** 6 Mugshot brand colors
  - `#B7E2B5` - Mugshot mint
  - `#FAF8F6` - Cream white
  - `#2563EB` - Blue accent
  - `#FACC15` - Yellow accent
  - `#ECF8EC` - Mint soft fill
  - `#8AC28E` - Mint dark
- **Size:** 10pt per piece
- **Shape Variety:** Circles, rounded rectangles, triangles (distributed evenly)
- **Spread:** 360° explosion (full circle)
- **Radius:** 350pt maximum distance
- **Duration:** 1.5-2.5 seconds per piece (randomized)
- **Animation:** Ease-out movement with rotation (360°-1080°)
- **Fade:** Opacity fades to 0 over last 30% of duration

**Confetti Animation:**
- Each piece calculates direction angle based on index
- Moves outward from source point with random variation
- Rotates while moving (random direction, 1-3 full rotations)
- Fades out near end of animation
- Non-interactive overlay (doesn't block taps)

**Action Buttons:**

**Primary Action: "View Café"**
- Full-width mint button
- Cup icon + "View Café" text
- Opens `UnifiedCafeView` in fullscreen
- Dismisses spin modal
- Calls `onCafeSelected` callback

**Secondary Actions (2-button row):**

1. **"Open in Maps"**
   - Opens selected cafe in Apple Maps
   - Uses `MKMapItem.openInMaps()` with driving directions
   - Mint outline button style

2. **"Spin Again"**
   - Resets spin state and immediately starts new search
   - Gray background button
   - Allows quick re-spin without closing modal

**Error State:**
- Shows error message in red (`negativeChange` color)
- "Try Again" button to reset and retry

---

## Spin for a Spot: Technical Details

### Data Structures

**SpinCafeResult:**
```swift
struct SpinCafeResult {
    let mapItem: MKMapItem
    let distanceMeters: Double
    var mappedCafe: Cafe?
    
    var name: String
    var shortName: String  // For wheel display (max 12 chars)
    var address: String?
    var coordinate: CLLocationCoordinate2D?
    var formattedDistance: String
    func openInMaps()
}
```

**NearbyCafeData:**
```swift
struct NearbyCafeData {
    let cafe: Cafe
    let distance: Double?  // in meters
    let averageRating: Double?
    let totalRatings: Int
    let photoURL: String?
    let hasVisits: Bool
}
```

### Search Performance

**Request Count:**
- Each spin makes **2 Apple Maps requests** (POI + keyword)
- Well under Apple's rate limits
- Requests are parallel (using `DispatchGroup`)

**Result Limits:**
- Initial search: No limit (returns all Apple Maps results)
- After filtering: All independent cafes within radius
- Wheel sampling: Randomly selects up to 20 cafes for display
- Final result: 1 randomly selected cafe

**Filtering Efficiency:**
- Deduplication: O(n) with Set-based lookup
- Distance filtering: O(n) with single pass
- Chain filtering: O(n*m) where m = chain patterns (constant, ~30 patterns)
- Overall: O(n) complexity for typical result sets

### Location Services

**LocationManager Integration:**
- Uses `LocationManager` observable object
- Requests permission on view appear
- Monitors location changes
- Handles location unavailable states gracefully

**Location Accuracy:**
- Uses device's current location
- No minimum accuracy requirement
- Falls back gracefully if location unavailable

### Cafe Mapping

**findOrCreateCafe Logic:**
1. Check if cafe exists by location (within 50 meters threshold)
2. If found: Return existing cafe, update missing metadata
3. If not found: Create new cafe from `MKMapItem`
4. Store `applePlaceId` for future deduplication
5. Preserve location, address, and metadata

**Cafe Creation:**
- Extracts name, location, address, city, country
- Stores `mapItemURL` and `websiteURL` if available
- Records `placeCategory` (POI category)
- Stores `applePlaceId` for Apple Maps integration

---

## Discovery Section: Data Flow

### Initialization

1. **View Appears:**
   - Requests location permission
   - Displays greeting (computed from current time)
   - Shows friend visits (from local data)
   - Loads nearby cafes when location available

2. **Location Available:**
   - Triggers `loadNearbyCafes()`
   - Sets `isLoadingCafes = true`
   - Calls `dataManager.searchNearbyCafes(near: location, radiusMiles: 3.0, limit: 5)`
   - Processes results and updates `nearbyCafes` state

3. **Friend Visits:**
   - Computed on-demand: `dataManager.getRecentFriendVisits(limit: 5)`
   - No async loading needed (local data)
   - Updates when friend visits change

### Data Refresh

**No Server Refresh:**
- Discovery section uses **local data only**
- No `refreshFeed()` call for discover scope
- Friend visits come from `appData.visits` (already synced)
- Nearby cafes use Apple Maps (always fresh)

**When Data Updates:**
- Friend visits: Updates when `appData.visits` changes
- Nearby cafes: Re-searches when location changes
- Greeting: Changes based on time of day (computed)

---

## Discovery Section: Visual Design

### Layout

**Container:**
- `ScrollView` with vertical `VStack`
- Spacing: `DS.Spacing.sectionVerticalGap` between sections
- Top padding: `DS.Spacing.md`
- Background: `DS.Colors.screenBackground`

**Section Headers:**
- Typography: `DS.Typography.sectionTitle`
- Color: `textPrimary` (or `modernTextPrimary` in dark mode)
- Padding: `DS.Spacing.pagePadding` horizontal

**Cards:**
- Use `DSBaseCard` or custom card styling
- Corner radius: `DS.Radius.lg` or `DS.Radius.xl`
- Shadow: `dsCardShadow()` (soft shadow)
- Padding: `DS.Spacing.md` or `DS.Spacing.cardPadding`

### Theme Support

**Dark Mode:**
- Uses `ThemeManager` for color adaptation
- `textPrimary` → `modernTextPrimary` in dark mode
- `textSecondary` → `modernTextSecondary` in dark mode
- `cardBackground` → `modernSurface` in dark mode
- `primaryAccent` → `modernAccent` in dark mode

**Color Tokens:**
- All colors use design system tokens
- No hard-coded colors
- Respects theme changes dynamically

---

## Spin for a Spot: User Experience

### Interaction Flow

1. **User opens Discover tab**
   - Sees greeting, nearby cafes, friend activity
   - Notices "Spin for a Spot" button

2. **User taps "Spin for a Spot"**
   - Fullscreen modal appears
   - Ready state with distance slider
   - Can adjust radius (0.25-10 mi)

3. **User taps "Find Cafes"**
   - Button triggers haptic feedback
   - Transitions to searching state
   - Shows loading indicator

4. **Search completes**
   - If cafes found: Transitions to spinning state
   - If error: Shows error message, returns to ready

5. **Wheel spins**
   - 5-second animation with progressive haptics
   - Visual feedback of wheel slowing down
   - Builds anticipation

6. **Result appears**
   - Confetti explosion from Mugsy image
   - Success haptic feedback
   - Cafe card with map preview

7. **User actions**
   - "View Café": Opens cafe detail, dismisses modal
   - "Open in Maps": Launches Apple Maps with directions
   - "Spin Again": Resets and searches again

### Accessibility

**Haptic Feedback:**
- Light tap on button press
- Medium tap on search start
- Progressive haptics during spin
- Success haptic on result

**Visual Feedback:**
- Loading states clearly indicated
- Error messages in readable format
- Confetti doesn't block content
- All buttons have sufficient tap targets (≥44×44pt)

**Screen Reader:**
- All text is accessible
- Buttons have descriptive labels
- Images have appropriate accessibility labels

---

## Spin for a Spot: Algorithm Details

### Random Selection

**Selection Method:**
- Uses `Int.random(in: 0..<cafeResults.count)`
- Each cafe has **equal probability**: `1/count`
- No weighting by distance, rating, or popularity
- True random selection

**Example:**
- 10 cafes found → Each has 10% chance
- 20 cafes found → Each has 5% chance
- Ensures fairness and variety

### Wheel Rotation Math

**Segment Angle:**
```swift
let sliceAngle = 360.0 / Double(cafeResults.count)
```

**Winner Segment Start:**
```swift
let segmentStartAngle = Double(winnerIndex) * sliceAngle
```

**Alignment Needed:**
- Pointer is at top (0°)
- Winner segment starts at `segmentStartAngle`
- To align: rotate by `360 - segmentStartAngle` (mod 360)

**Final Rotation:**
```swift
let baseRotation = Double.random(in: 5...8) * 360  // 5-8 full spins
let alignmentNeeded = (360 - segmentStartAngle).truncatingRemainder(dividingBy: 360)
targetRotation = baseRotation + alignmentNeeded
```

**Result:**
- Wheel spins 5-8 full rotations
- Lands with winner segment aligned with pointer
- Creates satisfying visual result

---

## Discovery Section: Integration Points

### Feed Tab Integration

**Scope Selection:**
- `FeedScope.discover` is one of three scopes
- Selected via `DSDesignSegmentedControl`
- No feed refresh when switching to discover (uses local data)

**Navigation:**
- Cafe taps open `UnifiedCafeView` in fullscreen sheet
- Visit taps (from friend cards) open `VisitDetailView`
- All navigation handled by `FeedTabView`

### DataManager Methods

**Used by Discovery Section:**
- `getRecentFriendVisits(limit:)` - Friend activity
- `searchNearbyCafes(near:radiusMiles:limit:)` - Nearby cafes
- `findOrCreateCafe(from:)` - Cafe mapping (Spin)
- `calculateAverageRating(for:)` - Cafe ratings
- `getPhotoURLsForCafe(_:limit:)` - Cafe photos
- `getCafe(id:)` - Cafe lookup

### Location Services

**LocationManager:**
- Observable object managing location permissions
- Provides `location: CLLocation?` property
- Handles permission requests
- Monitors location updates

**Permission Flow:**
1. View appears → Request permission
2. User grants → Location becomes available
3. Location changes → Triggers nearby cafe search

---

## Discovery Section: Empty States

### No Friends

**Condition:** `getRecentFriendVisits()` returns empty array

**Display:**
- "Your Sip Squad is quiet" message
- Cup icon
- "Be the first to log a sip today!" subtitle
- Card with mint background

### No Nearby Cafes

**Condition:** `searchNearbyCafes()` returns empty array

**Display:**
- Location slash icon (if no location)
- Magnifying glass icon (if location but no cafes)
- Appropriate message based on state
- Card with mint background

### No Location Permission

**Condition:** `locationManager.location == nil`

**Display:**
- Location slash icon
- "Location unavailable" message
- "Check location permissions" subtitle
- Card with mint background

---

## Spin for a Spot: Error Handling

### Search Errors

**Network Errors:**
- Apple Maps API failures
- Timeout errors
- Error message: "Couldn't search for cafés. Please try again."
- Returns to ready state

**No Results:**
- No cafes found within radius
- Error message: "No cafés found within X mi. Try increasing the search radius."
- Suggests increasing radius

**All Chains:**
- All results filtered as chains
- Error message: "No independent cafés found nearby. All results were chains. Try a larger radius."
- Suggests larger radius

**Location Errors:**
- No location available
- Error message: "Unable to get your location. Please enable location services."
- Returns to ready state

### Recovery Actions

**Try Again Button:**
- Resets all state
- Returns to ready phase
- Allows user to retry

**Reset and Search:**
- "Spin Again" button
- Resets state
- Immediately starts new search
- No need to close modal

---

## Discovery Section: Performance Considerations

### Search Optimization

**Parallel Requests:**
- POI and keyword searches run concurrently
- Uses `DispatchGroup` for coordination
- Reduces total search time

**Result Limiting:**
- Nearby cafes: Limited to 5 results
- Spin wheel: Samples up to 20 cafes
- Prevents overwhelming UI

**Caching:**
- Cafe results can be reused if location unchanged
- Friend visits computed on-demand (fast, local data)
- Photos loaded asynchronously

### Memory Management

**Image Loading:**
- Async image loading for thumbnails
- Placeholders shown during load
- No memory leaks from retained images

**State Management:**
- Minimal state variables
- Resets state on modal dismiss
- Cleans up animations on phase change

---

## Discovery Section: Design System Integration

### Typography

**Section Headers:**
- `DS.Typography.sectionTitle` - "Cafes near you", "What your friends are sipping"

**Card Titles:**
- `DS.Typography.headline()` - Cafe names, friend names
- `DS.Typography.title1()` - Greeting, result cafe name

**Body Text:**
- `DS.Typography.bodyText` - Descriptions, addresses
- `DS.Typography.caption1()` - Metadata, time ago
- `DS.Typography.caption2()` - Secondary metadata

**Buttons:**
- `DS.Typography.buttonLabel` - Button text

### Colors

**Primary:**
- `DS.Colors.primaryAccent` - Mint green for buttons, accents
- `DS.Colors.textPrimary` - Main text
- `DS.Colors.textSecondary` - Secondary text
- `DS.Colors.textTertiary` - Tertiary text

**Backgrounds:**
- `DS.Colors.screenBackground` - Main background
- `DS.Colors.cardBackground` - Card backgrounds
- `DS.Colors.primaryAccentSoftFill` - Mint soft fills

**Accents:**
- `DS.Colors.yellowAccent` - Star ratings
- `DS.Colors.negativeChange` - Error messages

### Spacing

**Page Level:**
- `DS.Spacing.pagePadding` - Horizontal padding (16pt)

**Section Level:**
- `DS.Spacing.sectionVerticalGap` - Between major sections (24pt)

**Card Level:**
- `DS.Spacing.cardPadding` - Card internal padding (16pt)
- `DS.Spacing.md` - Card spacing (12pt)
- `DS.Spacing.sm` - Tight spacing (8pt)

### Corner Radius

**Cards:**
- `DS.Radius.lg` - Standard cards (12pt)
- `DS.Radius.xl` - Large cards (16pt)

**Buttons:**
- `DS.Radius.primaryButton` - Primary buttons (10pt)
- `DS.Radius.pill` - Pills/badges (20pt)

### Shadows

**Cards:**
- `dsCardShadow()` - Soft shadow for elevation
- Color: Black with 10% opacity
- Radius: 8pt, offset: (0, 4)

**Buttons:**
- Mint buttons have colored shadow: `accentColor.opacity(0.3)`
- Radius: 8pt, offset: (0, 4)

---

## Spin for a Spot: Advanced Features

### Chain Detection

**Pattern Matching:**
- Case-insensitive substring matching
- Handles variations (e.g., "McDonald's" vs "McDonalds")
- Covers major coffee chains and fast-food chains with coffee

**Extensibility:**
- Easy to add new chain patterns
- Centralized in `CafeChainFilter` struct
- No database lookup needed (fast)

### Coffee Keyword Detection

**Purpose:**
- Allows bakeries that serve coffee
- Filters out pure bakeries without coffee

**Keywords:**
- Comprehensive list of coffee-related terms
- Covers drink types, equipment, and coffee culture terms
- Case-insensitive matching

### Dessert Shop Filtering

**Purpose:**
- Excludes candy shops, ice cream parlors, etc.
- Keeps focus on cafes/coffee shops

**Keywords:**
- Extensive list of dessert/candy terms
- Covers international terms (gelato, macarons)
- Prevents false positives

---

## Discovery Section: User Interactions

### Tap Targets

**Cafe Cards:**
- Full card is tappable
- Opens `UnifiedCafeView` in fullscreen
- Minimum 44×44pt hit area

**Friend Visit Cards:**
- Full card is tappable
- Opens `VisitDetailView` for that visit
- 200pt width ensures comfortable tap

**Spin Button:**
- Full-width button
- Large tap target
- Clear visual feedback

### Navigation

**Cafe Detail:**
- Fullscreen sheet presentation
- Dismissible via swipe or close button
- Preserves navigation stack

**Visit Detail:**
- Navigation destination (pushes on stack)
- Can navigate back
- Maintains feed context

---

## Discovery Section: Data Privacy

### Location Privacy

**Permission:**
- Explicit location permission request
- Only used for nearby cafe search
- Not stored or transmitted to server

**Local Only:**
- Location stays on device
- Apple Maps API called directly from device
- No location data sent to Mugshot servers

### Friend Data

**Privacy:**
- Only shows visits from confirmed friends
- Respects visit visibility settings
- No private visits shown

**Filtering:**
- Excludes current user's own visits
- Only shows last 7 days
- Limited to 5 most recent

---

## Spin for a Spot: Brand Integration

### Mugsy Character

**Assets:**
- "MugsySpin" - Ready state center image
- "MugsySpinCelebrate" - Result state celebration image

**Usage:**
- Adds personality to the feature
- Creates memorable experience
- Reinforces Mugshot brand

### Color Palette

**Wheel Segments:**
- 8 Mugshot brand colors
- Cycles through palette
- Creates cohesive visual

**Confetti:**
- 6 Mugshot brand colors
- Mint-focused palette
- Celebratory but on-brand

---

## Discovery Section: Future Enhancements

### Potential Additions

**Guides Section:**
- Curated cafe guides by neighborhood
- Themed collections (e.g., "Best Matcha Spots")
- User-generated guides

**Trending Cafes:**
- Cafes with recent activity
- Popular this week
- Friend favorites

**Personalized Recommendations:**
- Based on visit history
- Similar to cafes user likes
- Drink type preferences

**Social Features:**
- See which friends visited nearby cafes
- Friend recommendations
- Group cafe discovery

---

## Conclusion

The Discovery section in the Feed tab provides a comprehensive, personalized cafe discovery experience. It combines:

- **Personalization:** Time-based greetings, friend activity
- **Location Intelligence:** Nearby cafe search with ratings
- **Social Context:** Friend visit carousel
- **Gamification:** Spin for a Spot with fortune wheel and confetti
- **Quality Filtering:** Chain exclusion, independent cafe focus
- **Seamless Integration:** Works with existing cafe and visit data

The Spin for a Spot feature is particularly innovative, combining Apple Maps search, intelligent filtering, engaging animation, and celebratory feedback to create a delightful way for users to discover their next coffee spot.

All components follow the Mugshot design system, ensuring visual consistency and iOS-native feel throughout the experience.
