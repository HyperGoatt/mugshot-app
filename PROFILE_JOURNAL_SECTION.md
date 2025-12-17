# Profile Tab - Journal Section: Comprehensive Documentation

## Overview

The **Journal** section is the third tab in the Profile view (alongside Posts and Cafes). It serves as a private, personal analytics dashboard for the user's coffee journey. Unlike the Posts and Cafes tabs which show public content, the Journal is entirely private and only visible to the user themselves. It provides insights, statistics, streaks, badges, and a comprehensive notes system for tracking personal coffee experiences.

**Location:** Profile Tab → Journal Tab  
**Privacy:** 100% private - only visible to the user  
**Purpose:** Personal coffee journaling, analytics, and habit tracking

---

## Section Structure

The Journal section is composed of **8 main cards** displayed in a vertical scroll layout:

1. **Today's Mugshot Card** - Shows today's visit or prompts to log one
2. **My Taste Section** - Tag cloud of drink subtypes (conditional - only shows if user has drink subtypes)
3. **Streaks & Consistency Card** - Current streak, longest streak, and 7-day mini calendar
4. **Coffee Stats Card** - Total visits, cafes, average rating, and recent activity
5. **Top Cafes Card** - Top 3 cafes by visit count with average ratings
6. **Badges Card** - Achievement badges with progress tracking
7. **Notes Card** - Full notes section with filtering and editing
8. **Privacy Footer** - Reminder that journal is private

All cards use the design system's `DSBaseCard` component with consistent spacing (`DS.Spacing.cardVerticalGap`).

---

## Data Source & Filtering

### User Visits Filtering

The Journal section operates on a filtered set of visits:

```swift
private var userVisits: [Visit] {
    guard let currentUserId = dataManager.appData.currentUser?.id else { return [] }
    return dataManager.appData.visits
        .filter { $0.userId == currentUserId }
        .sorted { $0.createdAt > $1.createdAt }  // Most recent first
}
```

**Filtering Logic:**
- Filters all visits to only those belonging to the current user
- Uses `userId` matching (handles both local UUID and Supabase user ID)
- Sorts by `createdAt` in descending order (newest first)

**Data Source:**
- All visits stored in `DataManager.appData.visits`
- Filtered in real-time (no server query needed - uses cached local data)
- Updates automatically when new visits are added

---

## Card 1: Today's Mugshot Card

### Purpose
Shows the user's visit from today (if any) or prompts them to log their first visit of the day.

### Design
- **Card Type:** `DSBaseCard` with standard padding
- **Header:** "Today's Mugshot" using `DSSectionHeader`
- **Layout:** Horizontal stack with icon, text, and optional CTA button

### Content Logic

**If user has a visit today:**
- Shows coffee emoji (☕️) in a circular mint background
- Displays: "Today at [Cafe Name]"
- Shows drink type and rating (e.g., "Coffee · Iced vanilla latte · ⭐ 4.5")
- No action button (visit already logged)

**If no visit today:**
- Shows large coffee emoji (☕️)
- Text: "No mugshot yet today"
- Primary button: "Log a visit" (mint background, switches to Add tab)

### Calculation

```swift
JournalStatsHelper.todaysVisit(from: userVisits)
```

**Algorithm:**
1. Uses `Calendar.current.isDateInToday()` to check if visit's `createdAt` is today
2. Returns the first visit found (if multiple visits today, shows most recent due to sorting)
3. Returns `nil` if no visit exists for today

**Helper Function:**
```swift
static func todaysVisit(from visits: [Visit]) -> Visit? {
    let calendar = Calendar.current
    return visits.first { calendar.isDateInToday($0.createdAt) }
}
```

### Cafe Lookup
Uses `cafeLookup: (UUID) -> Cafe?` closure to fetch cafe details:
- Calls `dataManager.getCafe(id: visit.cafeId)`
- Displays cafe name if found
- Gracefully handles missing cafe data

---

## Card 2: My Taste Section

### Purpose
Visualizes the user's drink preferences through a tag cloud of specific drinks they've ordered.

### Design
- **Card Type:** `DSBaseCard` with collapsible header
- **Layout:** Flow layout (wrapping tag cloud) with expand/collapse toggle
- **Visual Style:** Mint-colored pills with drink names and order counts

### Content Logic

**Conditional Display:**
- Only shows if `dataManager.getDrinkSubtypesBreakdown()` returns non-empty array
- Hidden if user hasn't logged any visits with drink subtypes

**When Expanded:**
- Shows up to 20 drink subtypes as pills
- Displays "+ X more" if there are more than 20 drinks
- Each pill shows drink name and count badge (if count > 1)

**When Collapsed:**
- Shows only header with drink count
- Header shows: "My Taste" + "X drinks" + chevron icon

### Calculation

**Data Source:**
```swift
dataManager.getDrinkSubtypesBreakdown() -> [(name: String, count: Int)]
```

**Algorithm (`getDrinkSubtypesBreakdown`):**
1. Gets all visits for current user via `visitsForCurrentUser()`
2. Extracts `drinkSubtype` field from each visit (e.g., "Iced vanilla latte")
3. Filters out empty/nil subtypes (only includes non-empty, trimmed strings)
4. Groups by subtype name and counts occurrences
5. Sorts by count (descending) - most ordered drinks first
6. Returns array of tuples: `(name: String, count: Int)`

**Example Output:**
```swift
[
    ("Iced Honey Cinnamon Latte", 5),
    ("Cortado", 3),
    ("Iced Vanilla Latte", 4),
    ("Hot Matcha", 2),
    ("Cappuccino", 3)
]
```

**Key Points:**
- Only counts visits where `drinkSubtype` is non-empty
- Case-sensitive grouping (exact string matching)
- No normalization (e.g., "Iced Latte" and "iced latte" are separate)
- Sorted by frequency (most common first)

### Visual Design

**Drink Subtype Pills:**
- **Background:** `DS.Colors.mintSoftFill` (light mint green)
- **Border:** Subtle mint border (`primaryAccent.opacity(0.2)`)
- **Text:** Drink name in `DS.Typography.caption1()`
- **Count Badge:** Only shown if count > 1
  - Badge background: `primaryAccent.opacity(0.15)`
  - Badge text: Count number in bold, mint color
  - Badge shape: Pill (fully rounded corners)

**Flow Layout:**
- Custom `FlowLayout` component that wraps pills to new lines
- Spacing: `DS.Spacing.sm` (8pt) between pills
- Responsive: Automatically adjusts to screen width

---

## Card 3: Streaks & Consistency Card

### Purpose
Tracks consecutive days of logging visits and shows a 7-day mini calendar visualization.

### Design
- **Card Type:** `DSBaseCard`
- **Header:** "Streaks & Consistency"
- **Layout:** 
  - Top row: Two streak stats (Current / Longest)
  - Bottom row: 7-day mini calendar with weekday indicators

### Content

**Streak Statistics:**
1. **Current Streak** - Consecutive days ending today (or yesterday if no visit today)
2. **Longest Streak** - Maximum consecutive days ever achieved

**7-Day Mini Calendar:**
- Shows last 7 days (including today)
- Each day shows:
  - Day letter (S, M, T, W, T, F, S)
  - Circle indicator (filled = visit, empty = no visit)
  - Today's circle has a mint border highlight

### Calculations

#### Current Streak

**Function:** `JournalStatsHelper.calculateCurrentStreak(visits: [Visit]) -> Int`

**Algorithm:**
1. **Early Exit:** Returns 0 if visits array is empty
2. **Date Normalization:** Converts all visit dates to start of day (midnight) using `Calendar.current.startOfDay()`
3. **Create Visit Date Set:** Builds a `Set<Date>` of unique visit dates (one per day)
4. **Determine Starting Point:**
   - If today has a visit → start counting from today
   - Else if yesterday has a visit → start counting from yesterday
   - Else → return 0 (no active streak)
5. **Count Backwards:** 
   - Starting from the determined date, count consecutive days backwards
   - For each day, check if it exists in the visit dates set
   - Increment streak counter for each consecutive day found
   - Stop when a day is missing
6. **Return:** Total consecutive days counted

**Example:**
- Visits on: Dec 1, Dec 2, Dec 3, Dec 5, Dec 6 (today is Dec 6)
- Visit dates set: {Dec 1, Dec 2, Dec 3, Dec 5, Dec 6}
- Starting point: Dec 6 (today has visit)
- Count backwards: Dec 6 ✓, Dec 5 ✓, Dec 4 ✗ (stop)
- **Current Streak: 2 days**

**Edge Cases:**
- No visits today or yesterday → streak is 0
- Multiple visits on same day → counts as 1 day
- Gaps in dates → streak resets at gap

#### Longest Streak

**Function:** `JournalStatsHelper.calculateLongestStreak(visits: [Visit]) -> Int`

**Algorithm:**
1. **Early Exit:** Returns 0 if visits array is empty
2. **Date Normalization:** Converts all visit dates to start of day
3. **Create Sorted Date Array:** Gets unique visit dates and sorts ascending (oldest first)
4. **Iterate Through Dates:**
   - Start with `longestStreak = 1` and `currentStreak = 1`
   - For each date, check if it's exactly 1 day after the previous date
   - If consecutive: increment `currentStreak` and update `longestStreak` if needed
   - If not consecutive: reset `currentStreak = 1`
5. **Return:** Maximum streak found

**Example:**
- Visit dates: Dec 1, Dec 2, Dec 3, Dec 5, Dec 6, Dec 7, Dec 10, Dec 11
- Sorted: [Dec 1, Dec 2, Dec 3, Dec 5, Dec 6, Dec 7, Dec 10, Dec 11]
- Streaks:
  - Dec 1-3: 3 days
  - Dec 5-7: 3 days
  - Dec 10-11: 2 days
- **Longest Streak: 3 days**

**Performance:**
- O(n log n) due to sorting (n = unique visit dates)
- Efficient for typical use cases (hundreds of visits)

#### Weekday Visit Map

**Function:** `JournalStatsHelper.weekdayVisitMap(visits: [Visit]) -> [(dayLetter: String, date: Date, hasVisit: Bool)]`

**Purpose:** Creates a 7-day mini calendar showing visit activity for the last 7 days.

**Algorithm:**
1. **Get Today's Start:** `Calendar.current.startOfDay(for: Date())`
2. **Create Visit Date Set:** Normalize all visit dates to start of day and create a Set
3. **Build 7-Day Array:** For each of the last 7 days (6 days ago through today):
   - Calculate date: `today - daysAgo`
   - Get weekday number (1=Sunday, 7=Saturday)
   - Convert to letter: S, M, T, W, T, F, S
   - Check if date exists in visit dates set
   - Append tuple: `(dayLetter, date, hasVisit)`
4. **Return:** Array of 7 tuples in chronological order (oldest to newest)

**Day Letter Mapping:**
- Sunday (1) → "S"
- Monday (2) → "M"
- Tuesday (3) → "T"
- Wednesday (4) → "W"
- Thursday (5) → "T"
- Friday (6) → "F"
- Saturday (7) → "S"

**Visual Representation:**
```
S  M  T  W  T  F  S
●  ○  ●  ●  ○  ●  ●
```
- ● = Has visit (mint filled circle)
- ○ = No visit (gray empty circle)
- Today's circle has mint border

---

## Card 4: Coffee Stats Card

### Purpose
Displays key statistics about the user's coffee journey: total visits, unique cafes, average rating, and recent activity.

### Design
- **Card Type:** `DSBaseCard`
- **Header:** "Sip Stats"
- **Layout:**
  - Top row: Three stat items (Total visits, Cafes, Avg rating)
  - Divider
  - Bottom row: Recent activity stats (This week, Last 30 days)

### Content

**Main Stats (Top Row):**
1. **Total Visits** - Count of all user's visits
2. **Cafes** - Count of unique cafes visited
3. **Avg Rating** - Average overall score across all visits (formatted to 1 decimal)

**Recent Activity (Bottom Row):**
1. **This Week** - Visits in last 7 days
2. **Last 30 Days** - Visits in last 30 days

### Calculations

#### Main Stats

**Function:** `dataManager.getUserStats() -> (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?)`

**Algorithm:**
1. **Get User Visits:** Calls `visitsForCurrentUser()` to filter visits
2. **Total Visits:** `visits.count` (simple count)
3. **Total Cafes:** 
   - Extract all `cafeId` values from visits
   - Create a `Set<UUID>` to get unique cafes
   - Count: `Set(visits.map { $0.cafeId }).count`
4. **Average Score:**
   - Sum all `overallScore` values: `visits.reduce(0.0) { $0 + $1.overallScore }`
   - Divide by visit count: `totalScore / Double(visits.count)`
   - Returns 0.0 if no visits
5. **Favorite Drink Type:**
   - Group visits by `drinkType` (Coffee, Matcha, Tea, etc.)
   - Count occurrences per type: `Dictionary(grouping: visits, by: { $0.drinkType }).mapValues { $0.count }`
   - Find type with maximum count: `.max(by: { $0.value < $1.value })?.key`
   - Returns `nil` if no visits

**Example:**
- 10 visits total
- 4 unique cafes
- Scores: [4.5, 3.0, 4.0, 3.5, 4.2, 3.8, 4.1, 3.9, 4.3, 3.7]
- Average: 38.0 / 10 = 3.8
- Drink types: Coffee (7), Matcha (2), Tea (1)
- Favorite: Coffee

#### Recent Activity

**This Week (Last 7 Days):**

**Function:** `JournalStatsHelper.visitsInLast7Days(visits: [Visit]) -> Int`

**Algorithm:**
1. Get start of today: `Calendar.current.startOfDay(for: Date())`
2. Calculate 6 days ago: `calendar.date(byAdding: .day, value: -6, to: startOfToday)`
3. Filter visits where `createdAt >= weekAgo`
4. Return count

**Note:** Uses 6 days ago (not 7) because it includes today, making it 7 days total.

**Last 30 Days:**

**Function:** `JournalStatsHelper.visitsInLast30Days(visits: [Visit]) -> Int`

**Algorithm:**
1. Get start of today: `Calendar.current.startOfDay(for: Date())`
2. Calculate 29 days ago: `calendar.date(byAdding: .day, value: -29, to: startOfToday)`
3. Filter visits where `createdAt >= monthAgo`
4. Return count

**Note:** Uses 29 days ago (not 30) because it includes today, making it 30 days total.

### Visual Design

**Stat Items:**
- **Value:** Large number using `DS.Typography.numericStat` (24pt semibold)
- **Label:** Small text using `DS.Typography.caption1()` (13pt regular)
- **Layout:** Centered vertical stack
- **Spacing:** Equal width distribution in HStack

**Recent Activity Stats:**
- **Value:** Number in `DS.Typography.headline()` (17pt semibold) in mint color
- **Label:** "X visits · This week" format
- **Color:** Mint accent for value, secondary gray for label

---

## Card 5: Top Cafes Card

### Purpose
Shows the user's top 3 most-visited cafes with visit counts and average ratings.

### Design
- **Card Type:** `DSBaseCard` (only shown if user has visited cafes)
- **Header:** "Top Cafes"
- **Layout:** Vertical list of cafe rows with dividers
- **Interaction:** Tappable rows open cafe detail view

### Content

**Each Cafe Row Shows:**
- **Rank Badge:** Numbered circle (1, 2, 3)
  - #1 badge: Mint background with white text
  - #2-3 badges: Light gray background with gray text
- **Cafe Name:** Headline typography
- **Cafe City:** If available
- **Visit Count:** "X visits" or "X visit" (singular/plural)
- **Average Rating:** Star icon + score (1 decimal)
- **Chevron:** Right arrow indicating tappable

### Calculation

**Function:** `JournalStatsHelper.topCafes(from: visits, cafeLookup: (UUID) -> Cafe?, limit: Int = 3) -> [(cafe: Cafe, visitCount: Int, avgRating: Double)]`

**Algorithm:**
1. **Group Visits by Cafe:**
   - Create dictionary: `Dictionary(grouping: visits, by: { $0.cafeId })`
   - Keys: Cafe IDs, Values: Arrays of visits to that cafe

2. **Calculate Stats Per Cafe:**
   - For each cafe group:
     - **Visit Count:** `cafeVisits.count`
     - **Average Rating:** Sum all `overallScore` values and divide by count
     - Lookup cafe object using `cafeLookup(cafeId)`
     - Skip if cafe not found

3. **Sort:**
   - Primary: By visit count (descending) - most visited first
   - Secondary: By average rating (descending) - if visit counts are equal
   - Result: Cafes with most visits appear first, ties broken by rating

4. **Limit:**
   - Take first `limit` items (default: 3)
   - Return as array of tuples

**Example:**
- Cafe A: 5 visits, avg 4.2
- Cafe B: 3 visits, avg 4.8
- Cafe C: 3 visits, avg 3.5
- Cafe D: 2 visits, avg 4.0

**Result:**
1. Cafe A (5 visits, 4.2)
2. Cafe B (3 visits, 4.8) - higher rating than Cafe C
3. Cafe C (3 visits, 3.5)

### Visual Design

**Rank Badge:**
- **Size:** 28×28pt circle
- **#1:** `DS.Colors.primaryAccent` background, `DS.Colors.textOnMint` text
- **#2-3:** `DS.Colors.cardBackgroundAlt` background, `DS.Colors.textSecondary` text
- **Typography:** `DS.Typography.caption1(.semibold)`

**Cafe Row:**
- **Spacing:** `DS.Spacing.md` (12pt) between elements
- **Alignment:** Leading (left-aligned)
- **Divider:** Between rows (not before first row)
- **Tap Target:** Full row is tappable

**Interaction:**
- Tapping a cafe opens `UnifiedCafeView` in full-screen sheet
- Shows cafe details, user's visits to that cafe, and aggregate stats

---

## Card 6: Badges Card

### Purpose
Gamification element showing achievement badges unlocked through coffee journaling activities.

### Design
- **Card Type:** `DSBaseCard`
- **Header:** "Badges" with subtitle "Collect badges as you log your sipping journey."
- **Layout:** 
  - Horizontal scrolling badge chips
  - Summary line showing "X/Y badges unlocked"

### Content

**Badge Display:**
- **Unlocked Badges:** Full color (mint icon, primary text)
- **Locked Badges:** Muted (gray icon, tertiary text, 70% opacity)
- **Horizontal Scroll:** Swipeable row of badge chips
- **Tap Interaction:** Opens badge detail sheet

**Badge Chip Shows:**
- **Icon:** System SF Symbol in circular background
- **Name:** Badge name (caption2, single line, 72pt width)
- **Progress Text:** Shows progress or "Unlocked!" status

### Calculation

**Function:** `BadgeEngine.computeBadges(visits: [Visit]) -> [BadgeState]`

**Badge System:**
- Badges are defined in `BadgeEngine` with categories (Exploration, Consistency, Journal)
- Each badge has:
  - **Definition:** Name, icon, description, category, unlock criteria
  - **State:** Current progress, target value, unlocked status
  - **Progress Text:** "X / Y" or "Unlocked!" based on status

**Badge Categories:**
1. **Exploration:** Cafes visited, unique drinks tried
2. **Consistency:** Streaks (uses `JournalStatsHelper.calculateCurrentStreak` and `calculateLongestStreak`)
3. **Journal:** Notes written, visits logged

**Badge States:**
- **Unlocked:** `isUnlocked = true`, shows full color
- **Locked:** `isUnlocked = false`, shows muted style
- **Progress:** Calculated as `currentValue / targetValue` (0.0 to 1.0)

**Summary:**
- Counts unlocked badges: `badgeStates.filter { $0.isUnlocked }.count`
- Shows: "X/Y badges unlocked" with trophy icon

### Visual Design

**Badge Chip:**
- **Size:** 56×56pt icon circle
- **Unlocked Background:** `DS.Colors.primaryAccentSoftFill` (mint)
- **Locked Background:** `DS.Colors.cardBackgroundAlt` (light gray)
- **Icon:** 24pt SF Symbol
- **Name:** Centered below icon, 72pt width, single line with ellipsis
- **Progress:** Small text below name

**Badge Detail Sheet:**
- Full-screen modal showing:
  - Large icon (120×120pt)
  - Badge name (title1)
  - Category pill
  - Description
  - Progress bar (if not unlocked)
  - Unlock status or hint

---

## Card 7: Notes Card

### Purpose
Comprehensive notes management system for private visit notes. Allows viewing, filtering, and editing notes.

### Design
- **Card Type:** `DSBaseCard`
- **Header:** "Notes"
- **Layout:**
  - Summary line
  - Filter controls (segmented control + cafe picker)
  - Grouped notes list (by month)

### Content Structure

**Summary:**
- Shows: "You've logged X note(s) so far."
- Highlights count in mint color

**Filter Modes:**
1. **All Notes** - Shows all visits with notes, grouped by month
2. **By Cafe** - Filters to specific cafe, shows cafe picker menu

**Notes List:**
- **Grouping:** By month/year (e.g., "NOVEMBER 2025")
- **Order:** Most recent first (within month, newest first)
- **Each Note Row Shows:**
  - Date (e.g., "Nov 24")
  - Cafe name and city
  - Drink type and rating
  - Note preview (1-3 lines)
  - "Tap to edit" hint

### Calculations

#### All Visits With Notes

**Function:** `JournalStatsHelper.allVisitsWithNotes(from: visits) -> [Visit]`

**Algorithm:**
1. Filter visits where `notes != nil && !notes.isEmpty`
2. Sort by `createdAt` descending (newest first)
3. Return filtered and sorted array

**Notes Count:**
```swift
JournalStatsHelper.notesCount(from: userVisits) -> Int
```
- Simply returns `allVisitsWithNotes(from: visits).count`

#### Cafes With Notes

**Function:** `JournalStatsHelper.cafesWithNotes(from: visits, cafeLookup: (UUID) -> Cafe?) -> [Cafe]`

**Algorithm:**
1. Get all visits with notes using `allVisitsWithNotes()`
2. Extract unique cafe IDs: `Set(visitsWithNotes.map { $0.cafeId })`
3. Lookup each cafe using `cafeLookup` closure
4. Filter out nil results
5. Sort alphabetically by cafe name (case-insensitive)
6. Return sorted array

#### Filter Notes By Cafe

**Function:** `JournalStatsHelper.filterNotesByCafe(_ visits: [Visit], cafeId: UUID) -> [Visit]`

**Algorithm:**
1. Filter visits where `cafeId == cafeId`
2. Sort by `createdAt` descending
3. Return filtered array

#### Group Visits By Month

**Function:** `JournalStatsHelper.groupVisitsByMonth(_ visits: [Visit]) -> [(key: String, displayString: String, visits: [Visit])]`

**Algorithm:**
1. **Create Formatters:**
   - Key formatter: "yyyy-MM" (e.g., "2025-11") for sorting
   - Display formatter: "MMMM yyyy" (e.g., "November 2025") for UI

2. **Group by Month:**
   - Create dictionary keyed by "yyyy-MM" string
   - Group visits by their month/year key
   - Each group contains all visits from that month

3. **Convert to Array:**
   - Map dictionary to array of tuples
   - Each tuple: `(key: "2025-11", displayString: "November 2025", visits: [Visit])`
   - Sort visits within each group by `createdAt` descending

4. **Sort Groups:**
   - Sort by key descending (newest months first)
   - Return sorted array

**Example:**
- Visits on: Nov 1, Nov 15, Dec 3, Dec 20, Jan 5
- Grouped:
  - "2025-11" → "November 2025" → [Nov 15, Nov 1]
  - "2025-12" → "December 2025" → [Dec 20, Dec 3]
  - "2026-01" → "January 2026" → [Jan 5]
- Sorted: January, December, November (newest first)

### Visual Design

**Filter Controls:**
- **Segmented Control:** Two options in pill-style container
  - Selected: White background, primary text
  - Unselected: Transparent, secondary text
- **Cafe Picker:** Menu button showing selected cafe name
  - Only visible when "By cafe" mode is selected
  - Shows checkmark next to selected cafe

**Note Rows:**
- **Date:** "MMM d" format (e.g., "Nov 24")
- **Cafe Info:** Name and city with bullet separators
- **Drink/Rating:** Small text with star icon
- **Note Preview:** Body text, 1-3 lines, ellipsis if longer
- **Edit Hint:** "Tap to edit" with pencil icon (tertiary text)

**Month Headers:**
- Uppercase caption text
- Tertiary color
- Spacing above each month group

### Note Editing

**Edit Flow:**
1. User taps a note row
2. Opens `NoteDetailEditView` in sheet
3. Shows:
   - Visit info header (cafe name, date, drink, rating)
   - Text editor for notes (200+ character limit)
   - Character count
   - Save/Cancel buttons

**Save Logic:**
- Calls `dataManager.updateVisitNotes(visitId: UUID, notes: String?)`
- Updates visit's `notes` field in Supabase
- Syncs back to local data
- Shows success haptic feedback

**Validation:**
- Empty string is allowed (clears notes)
- No character limit enforced in editor (app-level limit is 200 chars)

---

## Card 8: Privacy Footer

### Purpose
Reminds users that the Journal section is private.

### Design
- **Layout:** Horizontal stack with icon and text
- **Icon:** Lock icon (12pt)
- **Text:** "Journal and notes are private – only visible to you."
- **Typography:** `DS.Typography.caption1()`
- **Color:** Tertiary text color

### Placement
- Appears at the bottom of the Journal section
- Padding: Top `DS.Spacing.md`, Bottom `DS.Spacing.lg`

---

## Data Flow & Performance

### Data Loading

**Initial Load:**
- Journal section uses cached visits from `DataManager.appData.visits`
- No network requests on initial render
- All calculations happen client-side

**Real-Time Updates:**
- When user logs a new visit, it's added to `appData.visits`
- Journal automatically recalculates all stats
- UI updates via SwiftUI's reactive `@ObservedObject` binding

### Performance Optimizations

**Streak Calculations:**
- Uses `Set<Date>` for O(1) date lookups
- Early exits for empty arrays
- Date normalization happens once per calculation

**Top Cafes:**
- Groups visits in single pass: O(n) where n = visit count
- Sorting is O(k log k) where k = unique cafe count (typically small)

**Notes Grouping:**
- Dictionary grouping: O(n) where n = visits with notes
- Sorting: O(m log m) where m = number of months (typically < 12)

**Badge Computation:**
- Calculated once per render
- Uses cached streak values from `JournalStatsHelper`

### Memory Considerations

- All calculations work on filtered `userVisits` array (not all visits)
- No large data structures persisted
- Date sets are created on-demand and discarded after calculation

---

## Design System Integration

### Components Used

**Cards:**
- `DSBaseCard` - All section cards use this
- Standard padding: `DS.Spacing.cardPadding` (16pt)
- Corner radius: `DS.Radius.xl` (20pt)
- Shadow: `DS.Shadow.cardSoft`

**Typography:**
- Section headers: `DS.Typography.sectionTitle` (17pt semibold)
- Stat numbers: `DS.Typography.numericStat` (24pt semibold)
- Body text: `DS.Typography.bodyText` (17pt regular)
- Captions: `DS.Typography.caption1()` (13pt) or `caption2()` (11pt)

**Colors:**
- Primary accent: Mint green (`DS.Colors.primaryAccent`)
- Text hierarchy: Primary, Secondary, Tertiary
- Backgrounds: Card background, screen background, mint soft fill

**Spacing:**
- Card gaps: `DS.Spacing.cardVerticalGap` (12pt)
- Internal spacing: `DS.Spacing.md` (12pt) for sections
- Page padding: `DS.Spacing.pagePadding` (16pt) horizontally

**Interactive Elements:**
- Buttons: Mint background with `DS.Radius.primaryButton` (16pt)
- Badge chips: Pill shape with mint soft fill
- Dividers: `DS.Colors.dividerSubtle`

---

## User Interactions

### Navigation

**From Journal:**
- **Log Visit Button** → Switches to Add tab (`tabCoordinator.selectedTab = 2`)
- **Cafe Row Tap** → Opens `UnifiedCafeView` in full-screen sheet
- **Badge Chip Tap** → Opens `BadgeDetailSheet` modal
- **Note Row Tap** → Opens `NoteDetailEditView` sheet

**To Journal:**
- Profile tab → Journal tab (segmented control)
- Widget deep link: `mugshot://journal` (opens Profile tab with Journal selected)

### Editing

**Notes Editing:**
1. Tap note row
2. Sheet opens with text editor
3. Edit notes text
4. Tap "Save" → Updates Supabase, syncs locally
5. Sheet dismisses, UI updates

**Validation:**
- Notes can be empty (clears note)
- No character limit enforced (app allows up to 200 chars)
- Save button disabled while saving

---

## Empty States

### Today's Mugshot
- Shows coffee emoji and "No mugshot yet today"
- Primary CTA: "Log a visit"

### My Taste
- Hidden if no drink subtypes exist

### Streaks
- Shows "0 days" for both streaks if no visits

### Coffee Stats
- Shows "0" for all stats if no visits
- Average rating shows "-" if no visits

### Top Cafes
- Card hidden if no cafes visited

### Badges
- Shows empty state with coffee emoji
- Text: "Start logging visits to unlock your first badge."
- Primary CTA: "Log a visit"

### Notes
- Shows empty state with book icon
- Text: "No notes yet" + "Use the Notes field when logging a visit to capture your thoughts."
- Primary CTA: "Log a visit"

---

## Statistics Summary

### All Calculations Reference

| Statistic | Function | Complexity | Data Source |
|-----------|----------|------------|-------------|
| Total Visits | `getUserStats().totalVisits` | O(1) | `visits.count` |
| Unique Cafes | `getUserStats().totalCafes` | O(n) | `Set(visits.map { $0.cafeId })` |
| Average Rating | `getUserStats().averageScore` | O(n) | Sum of `overallScore` / count |
| Favorite Drink | `getUserStats().favoriteDrinkType` | O(n) | Group by `drinkType`, max count |
| Current Streak | `calculateCurrentStreak()` | O(n) | Date set lookup, backwards count |
| Longest Streak | `calculateLongestStreak()` | O(n log n) | Sort dates, find max consecutive |
| Visits This Week | `visitsInLast7Days()` | O(n) | Filter by date >= 6 days ago |
| Visits Last 30 Days | `visitsInLast30Days()` | O(n) | Filter by date >= 29 days ago |
| Top Cafes | `topCafes()` | O(n + k log k) | Group by cafe, sort by count/rating |
| Drink Subtypes | `getDrinkSubtypesBreakdown()` | O(n log n) | Group by subtype, sort by count |
| Notes Count | `notesCount()` | O(n) | Filter visits with notes |
| Weekday Map | `weekdayVisitMap()` | O(n) | Check last 7 days for visits |

**n** = number of user visits  
**k** = number of unique cafes/drinks/months

---

## Key Design Principles

1. **Privacy First:** All data is private, clearly communicated via footer
2. **Content-First:** Statistics and insights are the hero, UI stays minimal
3. **Progressive Disclosure:** Collapsible sections (My Taste), filtered views (Notes)
4. **Visual Hierarchy:** Large numbers for key stats, smaller text for context
5. **Consistent Spacing:** Uses design system tokens throughout
6. **Empty States:** Friendly, actionable empty states with CTAs
7. **Real-Time Updates:** All stats recalculate automatically when visits change
8. **Performance:** Efficient algorithms, early exits, Set-based lookups

---

## Technical Implementation Notes

### SwiftUI View Structure

```swift
ProfileJournalView
├── VStack (spacing: cardVerticalGap)
    ├── TodaysMugshotCard
    ├── MyTasteSection (conditional)
    ├── StreaksCard
    ├── CoffeeStatsCard
    ├── TopCafesCard
    ├── BadgesCard
    ├── NotesCard
    └── JournalPrivacyFooter
```

### State Management

- **Data Source:** `@ObservedObject var dataManager: DataManager`
- **Tab Navigation:** `@EnvironmentObject var tabCoordinator: TabCoordinator`
- **Local State:** Minimal (only for sheet presentations and filter selections)
- **Reactive:** All computed properties recalculate when `dataManager.appData.visits` changes

### Helper Functions Location

- **JournalStatsHelper:** `/testMugshot/Utilities/JournalStatsHelper.swift`
- **DataManager Stats:** `/testMugshot/Services/DataManager.swift` (getUserStats, getFavoriteCafe, getDrinkSubtypesBreakdown)
- **BadgeEngine:** `/testMugshot/Utilities/BadgeEngine.swift`

---

## Conclusion

The Profile Journal section is a comprehensive, private analytics dashboard that transforms raw visit data into meaningful insights about a user's coffee journey. It combines statistical analysis (streaks, averages, counts) with visualizations (tag clouds, mini calendars, progress bars) and practical tools (notes management, badge tracking) to create an engaging, personal journaling experience.

All calculations are performed client-side on filtered user visits, ensuring privacy and real-time updates. The design follows Mugshot's mint-green aesthetic with consistent spacing, typography, and interaction patterns, creating a calm, thoughtful experience that encourages continued journaling.

