# 🏗️ Discover Tab Architecture

## Component Hierarchy

```
DiscoverContentView
│
├── Greeting Header
│   ├── GreetingHelper.getGreeting(userName)
│   │   └── Returns time-based greeting from 50 options
│   └── GreetingHelper.getTimeEmoji()
│       └── Returns ☀️ ☕ 🌅 or 🌙
│
├── Spin for a Spot Button
│   └── Launches SpinForASpotView
│
├── What Your Friends Are Sipping
│   ├── DataManager.getRecentFriendVisits(limit: 5)
│   │   ├── Filters visits from friends (last 7 days)
│   │   └── Sorts by most recent
│   │
│   └── Horizontal ScrollView
│       └── ForEach FriendVisitCard
│           ├── Friend avatar (with fallback)
│           ├── Friend name
│           ├── Time ago
│           ├── Drink subtype
│           ├── Cafe name
│           └── Photo thumbnail
│
└── Cafes Near You
    ├── getNearbyCafes(limit: 5)
    │   ├── Get user location
    │   ├── Calculate distances
    │   ├── DataManager.calculateAverageRating(for: cafeId)
    │   ├── DataManager.getMostOrderedDrinkSubtype(for: cafeId)
    │   └── DataManager.getPhotoURLsForCafe(cafeId, limit: 4)
    │
    └── Horizontal ScrollView
        └── ForEach NearbyCafeCard
            ├── Photo Collage (1-4 images)
            │   ├── Priority: Friends' photos
            │   ├── Fallback: Everyone's photos
            │   └── Empty: Placeholder
            ├── Cafe name
            ├── Distance + Rating
            └── Most ordered drink badge
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│                  DiscoverContentView                │
│                                                     │
│  ┌───────────────────────────────────────────┐    │
│  │         Greeting Header                    │    │
│  │  GreetingHelper.getGreeting(userName)     │    │
│  └───────────────────────────────────────────┘    │
│                                                     │
│  ┌───────────────────────────────────────────┐    │
│  │      Spin for a Spot Button               │    │
│  │  → SpinForASpotView                       │    │
│  └───────────────────────────────────────────┘    │
│                                                     │
│  ┌───────────────────────────────────────────┐    │
│  │   What Your Friends Are Sipping           │    │
│  │  ┌─────────────────────────────────────┐  │    │
│  │  │ DataManager.getRecentFriendVisits() │  │    │
│  │  │   ↓                                  │  │    │
│  │  │ [Visit, Visit, Visit, ...]          │  │    │
│  │  │   ↓                                  │  │    │
│  │  │ FriendVisitCard × N                 │  │    │
│  │  └─────────────────────────────────────┘  │    │
│  └───────────────────────────────────────────┘    │
│                                                     │
│  ┌───────────────────────────────────────────┐    │
│  │        Cafes Near You                     │    │
│  │  ┌─────────────────────────────────────┐  │    │
│  │  │ 1. Get user location                │  │    │
│  │  │ 2. Calculate distances to cafes     │  │    │
│  │  │ 3. For each cafe:                   │  │    │
│  │  │    ├─ Get average rating            │  │    │
│  │  │    ├─ Get most ordered drink        │  │    │
│  │  │    └─ Get photo URLs                │  │    │
│  │  │ 4. Sort by distance                 │  │    │
│  │  │ 5. Take top 5                       │  │    │
│  │  │   ↓                                  │  │    │
│  │  │ NearbyCafeCard × 5                  │  │    │
│  │  └─────────────────────────────────────┘  │    │
│  └───────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

---

## DataManager Helper Methods

### Friend Visits
```swift
func getRecentFriendVisits(limit: Int = 5) -> [Visit]
├── Get current user ID
├── Get friend IDs from appData.friendsSupabaseUserIds
├── Filter visits:
│   ├── From friends
│   ├── Not from current user
│   └── Within last 7 days
└── Sort by most recent & limit
```

### Most Ordered Drink
```swift
func getMostOrderedDrinkSubtype(for cafeId: UUID) -> String?
├── Get all visits for cafe
├── Extract drink subtypes
├── Count occurrences
└── Return most popular
```

### Photo URLs
```swift
func getPhotoURLsForCafe(_ cafeId: UUID, limit: Int = 4) -> [String]
├── Get friend IDs
├── Get all visits for cafe
├── Separate friend visits from other visits
├── Priority queue:
│   ├── 1. Add friend photos (most recent first)
│   └── 2. Fill remaining with other photos
└── Return up to 4 URLs
```

### Average Rating
```swift
func calculateAverageRating(for cafeId: UUID) -> (average: Double, count: Int)
├── Get all visits for cafe
├── Filter visits with ratings (overallScore > 0)
├── Calculate average
└── Return (average, count)
```

---

## Photo Collage Layouts

### 1 Photo
```
┌─────────────────┐
│                 │
│      Photo      │
│                 │
└─────────────────┘
```

### 2 Photos
```
┌────────┬────────┐
│ Photo  │ Photo  │
│   1    │   2    │
└────────┴────────┘
```

### 3 Photos
```
┌────────┬────────┐
│        │ Photo  │
│ Photo  │   2    │
│   1    ├────────┤
│        │ Photo  │
│        │   3    │
└────────┴────────┘
```

### 4 Photos
```
┌────────┬────────┐
│ Photo  │ Photo  │
│   1    │   2    │
├────────┼────────┤
│ Photo  │ Photo  │
│   3    │   4    │
└────────┴────────┘
```

---

## State Management

### Empty States

**Friend Activity**
```swift
if recentFriendVisits.isEmpty {
    // Show: "Your Sip Squad is quiet — 
    //        Be the first to log a sip today!"
}
```

**Nearby Cafes**
```swift
if nearbyCafes.isEmpty {
    // Show: "No cafes nearby — 
    //        Try enabling location services"
}
```

**No Ratings**
```swift
if averageRating == nil {
    // Show: "No ratings yet"
}
```

**No Most Ordered Drink**
```swift
if mostOrderedDrink == nil {
    // Show: "Be the first to log a sip!"
}
```

**No Photos**
```swift
if photoURLs.isEmpty {
    // Show: "Add the first photo taken here!"
}
```

---

## Performance Considerations

### Efficient Queries
- ✅ Filter visits once, reuse results
- ✅ Limit carousels to 5 items
- ✅ Calculate only for visible cafes

### Lazy Loading
- ✅ Use `AsyncImage` for photos
- ✅ Horizontal scroll loads on demand
- ✅ No prefetching (on-demand only)

### Caching Opportunities
- 💡 Cache calculated ratings per cafe
- 💡 Cache most ordered drinks per cafe
- 💡 Cache photo URLs per cafe
- 💡 Invalidate on new visits

---

## Dependencies

### External
```swift
import SwiftUI         // UI framework
import CoreLocation    // Location services
```

### Internal
```swift
DataManager            // Business logic & data
LocationManager        // User location
GreetingHelper         // Dynamic greetings
FriendVisitCard        // Friend activity UI
NearbyCafeCard         // Nearby cafe UI
SpinForASpotView       // Spinner experience
DS (Design System)     // Colors, typography, spacing
```

---

## Design System Tokens Used

### Colors
```swift
DS.Colors.textPrimary          // Main text
DS.Colors.textSecondary        // Supporting text
DS.Colors.textTertiary         // Subtle text
DS.Colors.primaryAccent        // Mint buttons
DS.Colors.cardBackground       // White cards
DS.Colors.screenBackground     // Light gray bg
DS.Colors.primaryAccentSoftFill // Mint fills
DS.Colors.secondaryAccent      // Blue avatars
DS.Colors.yellowAccent         // Star ratings
```

### Typography
```swift
DS.Typography.title1()         // Greeting (28pt)
DS.Typography.sectionTitle     // Section headers (17pt)
DS.Typography.headline()       // Card titles (17pt)
DS.Typography.subheadline()    // Subtitles (15pt)
DS.Typography.caption1()       // Meta labels (13pt)
DS.Typography.caption2()       // Tiny labels (11pt)
```

### Spacing
```swift
DS.Spacing.pagePadding         // 16pt horizontal
DS.Spacing.sectionVerticalGap  // 24pt between sections
DS.Spacing.md                  // 12pt card spacing
DS.Spacing.sm                  // 8pt small gaps
DS.Spacing.xs                  // 4pt tiny gaps
```

### Radius & Shadow
```swift
DS.Radius.xl                   // 20pt for cards
DS.Radius.lg                   // 16pt for buttons
DS.Radius.md                   // 12pt for thumbnails
.dsCardShadow()                // Soft elevation
```

---

## Navigation Flow

```
Discover Tab
│
├── Tap Greeting → (No action)
│
├── Tap "Spin for a Spot" → SpinForASpotView (fullscreen)
│   └── Select cafe → Cafe Detail
│
├── Tap Friend Visit Card → Visit Detail
│   ├── View full visit
│   ├── Like/comment
│   └── Navigate to cafe
│
└── Tap Nearby Cafe Card → Cafe Detail
    ├── View all visits
    ├── See ratings
    ├── View photos
    └── Log new visit
```

---

## Testing Strategy

### Unit Tests (Future)
- [ ] GreetingHelper returns correct time-based greetings
- [ ] DataManager filters friend visits correctly
- [ ] Most ordered drink calculation is accurate
- [ ] Photo priority ordering is correct

### UI Tests (Future)
- [ ] Greeting displays and updates
- [ ] Spin button launches spinner
- [ ] Friend cards navigate to visit detail
- [ ] Cafe cards navigate to cafe detail
- [ ] Empty states display correctly

### Manual Testing
- [x] Different times of day (greetings)
- [x] Users with/without friends
- [x] Users with/without location
- [x] Cafes with/without data
- [x] Photo collage layouts (1-4 images)

---

## Future Enhancements

### Pull-to-Refresh
```swift
.refreshable {
    await refreshDiscoverData()
}
```

### "See All" Buttons
```swift
Button("See all") {
    // Navigate to full friend activity
}
```

### Distance Filter
```swift
DistanceSlider(range: $radiusInKm)
// Filter cafes by distance
```

### Trending Section
```swift
// Show most visited cafes this week
TrendingCafesCarousel()
```

---

## Summary

**Architecture**: Clean separation of UI components and data logic  
**Performance**: Efficient queries with lazy loading  
**Design**: Fully compliant with Mugshot design system  
**Extensibility**: Easy to add new sections and features  
**Maintainability**: Clear data flow and component hierarchy  

The Discover tab is now a **personalized discovery engine** that scales with your user base! 🚀



