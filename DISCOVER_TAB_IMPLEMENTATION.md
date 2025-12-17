# Discover Tab Implementation Guide

## Overview
This document describes the complete redesign of the Discover tab into a personalized, high-value exploration surface.

## ✅ Implementation Complete

### 1. **Personalized Greeting** ✓
- **File**: `testMugshot/Views/Discover/Helpers/GreetingHelper.swift`
- **Features**:
  - 50 unique greetings based on time of day (morning, afternoon, evening, night)
  - Dynamic emoji based on time: ☀️ ☕ 🌅 🌙
  - Seeded random selection ensures consistent greeting throughout the day
  - Personalized with user's first name

### 2. **Spin for a Spot** ✓
- **Location**: Integrated in `DiscoverContentView.swift`
- **Features**:
  - Full-width tappable card with Mugshot mint styling
  - Launches the existing `SpinForASpotView`
  - Haptic feedback on tap

### 3. **What Your Friends Are Sipping** ✓
- **File**: `testMugshot/Views/Discover/Components/FriendVisitCard.swift`
- **Features**:
  - Horizontal carousel of 3-5 most recent friend visits
  - Each card shows:
    - Friend's avatar (with fallback initials)
    - Friend's display name
    - Time ago (e.g., "2h ago")
    - Drink subtype (e.g., "Iced Lavender Latte")
    - Cafe name with location icon
    - Thumbnail of drink photo
  - Tap to open Visit detail
  - Empty state: "Your Sip Squad is quiet — Be the first to log a sip today!"

### 4. **Cafes Near You** ✓
- **File**: `testMugshot/Views/Discover/Components/NearbyCafeCard.swift`
- **Features**:
  - Horizontal carousel of top 5 closest cafés
  - Each card displays:
    - **Distance**: Formatted in meters or kilometers
    - **Rating**: Average rating with count (e.g., "4.5 (28)")
    - **Most Ordered Drink**: Subtype from all users (e.g., "Most ordered: Iced Lavender Latte")
    - **Photo Collage**: 1-4 images in responsive grid layout
      - Priority: Friends' photos → Everyone's photos → Placeholder
      - Layouts: Single, 2-grid, 3-grid (1 large + 2 stacked), 4-grid (2×2)
  - Empty states:
    - No ratings: "No ratings yet"
    - No drink data: "Be the first to log a sip!"
    - No photos: "Add the first photo taken here!" with camera icon
  - Tap to open Cafe Detail View

### 5. **Data Layer Enhancements** ✓
- **File**: `testMugshot/Services/DataManager.swift`
- **New Methods**:
  ```swift
  func getRecentFriendVisits(limit: Int = 5) -> [Visit]
  func getMostOrderedDrinkSubtype(for cafeId: UUID) -> String?
  func getPhotoURLsForCafe(_ cafeId: UUID, limit: Int = 4) -> [String]
  func calculateAverageRating(for cafeId: UUID) -> (average: Double, count: Int)
  ```

## 📐 Design System Compliance

All components follow the Mugshot Design System (`design-system.json`):

### Colors
- Primary accent: Mugshot mint (`mintMain`)
- Card backgrounds: White (`cardBackground`)
- Screen background: Light gray (`screenBackground`)
- Text hierarchy: `textPrimary`, `textSecondary`, `textTertiary`

### Typography
- Greetings: `title1` (28pt, bold)
- Section titles: `sectionTitle` (17pt, semibold)
- Card titles: `headline` (17pt, semibold)
- Captions: `caption1` (13pt), `caption2` (11pt)

### Spacing
- Page padding: 16pt
- Section vertical gap: 24pt
- Card padding: 16pt
- Card gaps: 12pt

### Corner Radius
- Cards: `xl` (20pt)
- Buttons: `lg` (16pt)
- Small elements: `md` (12pt)

### Shadows
- Normal cards: `cardSoft` (18pt blur, 6pt offset, 0.08 opacity)

## 🎯 Layout Order

The Discover tab sections appear in this order:
1. Personalized Greeting
2. Spin for a Spot
3. What Your Friends Are Sipping
4. Cafes Near You

## 🔄 Data Flow

### Friend Activity
1. Query all visits from friends in last 7 days
2. Sort by most recent
3. Take top 5
4. Display in horizontal carousel

### Nearby Cafes
1. Get user's current location
2. Filter cafes with location data
3. Calculate distance for each cafe
4. Get aggregate stats (rating, most ordered drink, photos)
5. Sort by distance
6. Take top 5
7. Display in horizontal carousel

### Photo Priority
For each cafe's photo collage:
1. **First**: Most recent photos from user's friends
2. **Second**: Most recent photos from everyone
3. **Fallback**: Placeholder with call-to-action

## 📱 User Interactions

### Haptic Feedback
- Light tap on "Spin for a Spot" button
- Consider adding subtle haptic on card scrolls (future enhancement)

### Navigation
- Tap friend visit card → Open Visit detail
- Tap nearby cafe card → Open Cafe detail
- Tap "Spin for a Spot" → Launch spinner fullscreen

### Pull-to-Refresh
- **Future Enhancement**: Add pull-to-refresh to reload recommendations

## 🚀 Next Steps

### To Complete Integration:
1. **Add files to Xcode project**:
   - Open `testMugshot.xcodeproj` in Xcode
   - Add new files to project:
     - `GreetingHelper.swift` → Views/Discover/Helpers/
     - `FriendVisitCard.swift` → Views/Discover/Components/
     - `NearbyCafeCard.swift` → Views/Discover/Components/
   - Ensure files are added to the `testMugshot` target

2. **Update Feed tab to use new DiscoverContentView**:
   - Ensure the Feed tab's Discover scope passes `onVisitTap` callback
   - Update navigation to handle visit detail from friend cards

3. **Test data scenarios**:
   - [ ] User with no friends
   - [ ] User with friends but no recent activity
   - [ ] User with active friends
   - [ ] User with location disabled
   - [ ] Cafes with no ratings
   - [ ] Cafes with no photos
   - [ ] Cafes with no drink data

4. **Performance optimizations**:
   - [ ] Add caching for cafe photos
   - [ ] Prefetch friend visit photos
   - [ ] Throttle location updates
   - [ ] Cache calculated ratings and drink stats

5. **Future enhancements**:
   - [ ] Add pull-to-refresh
   - [ ] Add "See All" buttons for sections
   - [ ] Add filters for nearby cafes (distance radius, rating minimum)
   - [ ] Add "Recently Visited" section
   - [ ] Add "Trending This Week" section

## 🎨 Visual Examples

### Greeting Variations
- Morning: "Good morning, Joe ☀️"
- Afternoon: "Afternoon pick-me-up time, Joe!"
- Evening: "Evening sips, Joe 🌅"
- Night: "Night owl mode, Joe!"

### Photo Collage Layouts
- **1 photo**: Full-width rectangle
- **2 photos**: Side-by-side split
- **3 photos**: Large left + 2 stacked right
- **4 photos**: 2×2 grid

## 📊 Data Requirements

### User Data
- Current user's first name
- Friend list (Supabase user IDs)
- Current location

### Cafe Data
- Cafe name, address, location coordinates
- All visits to each cafe (for aggregation)
- Visit photos (with author info)
- Visit drink subtypes
- Visit ratings

### Visit Data
- Author info (name, username, avatar)
- Creation timestamp
- Drink type and subtype
- Poster photo URL
- Cafe reference

## ✨ Key Features

### Personalization
- Dynamic greetings based on time
- Friend-focused activity feed
- Photo prioritization for friends' content

### Discovery
- Location-based cafe recommendations
- Social proof through friend activity
- Data-driven drink recommendations

### Engagement
- Visual-first design with photo collages
- Quick access to cafe details
- One-tap navigation to visit details

## 🔧 Technical Details

### Dependencies
- CoreLocation for user positioning
- SwiftUI for UI components
- Async/await for data fetching
- DataManager for business logic

### Performance Considerations
- Lazy loading of images with AsyncImage
- Limited carousels (5 items max) to prevent memory issues
- Efficient filtering and sorting of visits
- No expensive computations on main thread

### Error Handling
- Graceful fallbacks for missing data
- Empty states for all sections
- Placeholder images for missing photos
- Safe unwrapping of optional data

---

## Summary

This implementation transforms the Discover tab into a personalized, engaging surface that helps users:
- **Connect** with friends through their coffee journey
- **Discover** new cafes nearby based on location and community data
- **Explore** what others are ordering at local spots
- **Engage** with the Mugshot community through visual, data-rich cards

The design follows Mugshot's mint-themed, card-based aesthetic while providing high-value, actionable information to users.



