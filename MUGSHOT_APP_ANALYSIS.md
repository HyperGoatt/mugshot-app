# Mugshot: Comprehensive App Analysis

## Overview

**Mugshot** is a social journaling app designed for coffee enthusiasts to document, rate, and share their cafe visits and beverage experiences. The app combines personal coffee journaling with social networking features, creating a community around cafe culture and beverage appreciation. It's built for iOS with a distinctive mint-green aesthetic that feels calm, approachable, and content-first.

---

## Core Purpose

Mugshot serves as both a personal coffee journal and a social platform. Users can:

1. **Document their coffee journey** - Track every cafe visit, drink ordered, and rating given
2. **Discover new cafes** - Find recommendations from friends and the community
3. **Build a social network** - Connect with other coffee lovers, see where friends are sipping, and share experiences
4. **Analyze their habits** - View statistics about their coffee consumption, favorite drinks, and most-visited cafes

The app positions itself as a thoughtful alternative to generic social media, focusing specifically on the ritual and culture of cafe visits rather than broad lifestyle content.

---

## Brand Identity & Visual Design

### Color Palette
- **Primary Accent**: Mint green (`#B7E2B5`) - Used for buttons, highlights, and brand elements
- **Mint Light**: `#D6F0D6` - Used for page headers and soft backgrounds
- **Mint Soft Fill**: `#ECF8EC` - Subtle backgrounds and disabled states
- **Blue Accent**: `#2563EB` - Secondary emphasis for badges and scores
- **Neutral Background**: `#F5F5F7` - Screen backgrounds
- **White Cards**: `#FFFFFF` - Content cards that sit on the neutral background

### Design Philosophy
The design system emphasizes:
- **Soft, friendly, approachable** - Rounded cards, generous white space, subtle elevation
- **Calm, low-noise palette** - Mostly white/light gray with mint and blue used sparingly
- **Content-first** - Photos, ratings, and visit logs are the hero; UI chrome stays quiet
- **iOS-native feel** - System typography, familiar navigation patterns, iOS Human Interface Guidelines spacing
- **Consistent card grammar** - Nearly all content sits inside rounded cards with clear titles

### Typography
Uses iOS system fonts (SF Pro Text) with a clear hierarchy:
- Screen titles: 28pt bold
- Section titles: 17pt semibold
- Body text: 17pt regular
- Captions: 13pt or 11pt for metadata

---

## Main Features & Functionality

### 1. Map Tab
The primary discovery interface showing cafes on an interactive map.

**Features:**
- **Interactive Map View** - Shows cafes as pins with color-coding based on rating or visit status
- **Search Functionality** - Search for cafes by name or location
- **Sip Squad Mode** - Toggle to view combined coffee footprint of user + friends (shows cafes visited by anyone in your friend network)
- **Cafe Pins** - Color-coded markers:
  - Green: High-rated cafes (4.0+)
  - Yellow: Medium-rated (3.0-3.9)
  - Red: Lower-rated (<3.0)
  - Mint: In Sip Squad mode, shows friend-visited cafes
- **Cafe Detail Cards** - Tap a pin to see cafe name, address, average rating, visit count, and quick actions
- **Quick Log Visit** - Tap a cafe to immediately start logging a visit
- **Location Services** - Uses CoreLocation to center map on user's location
- **Apple Maps Integration** - Pulls cafe data from Apple Maps for comprehensive place information

**User Flow:**
1. Open Map tab → See cafes in current area
2. Search or pan map to explore
3. Tap cafe pin → View details
4. Tap "Log Visit" → Opens Add tab with cafe pre-selected

---

### 2. Feed Tab
A social feed showing visits from friends and the broader community.

**Three Feed Scopes:**

**a) Friends Feed**
- Shows visits from users you've added as friends
- Chronological timeline of friend activity
- See what cafes friends are visiting and what they're ordering

**b) Everyone Feed**
- Public feed showing all visits marked as "Everyone" visibility
- Discover new cafes and drinks from the broader community
- See trending cafes and popular drinks

**c) Discover Tab**
- **Social Radar** - Shows cafes where friends have visited recently
- **Guides** - Curated content (appears to be a feature in development)
- **Spin Feature** - A fun discovery mechanism (likely a wheel/randomizer for cafe suggestions)

**Feed Features:**
- **Visit Cards** - Each post shows:
  - Cafe name and location
  - Drink type and specific drink name (e.g., "Iced vanilla latte")
  - Photo(s) from the visit
  - Overall rating with stars
  - Caption/description
  - Author profile (avatar, username)
  - Like count
  - Comment count
  - Timestamp
- **Interactions:**
  - Like visits (heart button)
  - Comment on visits
  - Tap cafe name to view cafe details
  - Tap author to view their profile
  - Pull-to-refresh to load new content
- **Notifications Badge** - Shows unread notification count in header

---

### 3. Add Tab (Log a Visit)
The core journaling feature where users document their cafe experiences.

**Visit Logging Process:**

1. **Cafe Selection**
   - Search for cafe or select from map
   - Can be pre-selected if coming from Map tab

2. **Drink Selection**
   - Choose drink type: Coffee, Matcha, Hojicha, Tea, Chai, Hot Chocolate, or Other
   - Optional: Specify exact drink (e.g., "Iced vanilla latte")
   - Optional: Custom drink type if "Other" selected

3. **Photos**
   - Add up to 10 photos from photo library
   - Select a "poster photo" (main image shown in feed)
   - Photos are cached and uploaded to cloud storage

4. **Ratings**
   - Customizable rating categories (defaults include things like Taste, Atmosphere, Service, etc.)
   - Star ratings (1-5) for each category
   - Automatic overall score calculation (weighted average)
   - Users can customize their rating template

5. **Caption**
   - Required text field (200 character limit)
   - Public description of the visit

6. **Notes** (Optional)
   - Private notes field (200 character limit)
   - Only visible to the user

7. **Visibility Settings**
   - **Private** - Only visible to you
   - **Friends** - Visible to your friend network
   - **Everyone** - Public, appears in Everyone feed

8. **Post**
   - Validates required fields (cafe, drink type, caption)
   - Saves visit to personal journal
   - If public/friends visibility, appears in relevant feeds
   - Opens visit detail view after posting

**Alternative Flow:**
- Onboarding-style post flow (feature flag) - A more guided, step-by-step experience

---

### 4. Saved Tab
Personal library of cafes organized into collections.

**Three Collections:**

**a) Favorites**
- Cafes the user has marked as favorites
- Shows visit count, last visit date, favorite drink at that cafe
- Quick access to log another visit

**b) Wishlist**
- Cafes marked as "Want to Try"
- Cafes user wants to visit in the future
- Helps plan future coffee adventures

**c) My Cafes (Library)**
- All cafes the user has visited
- Complete history of visited locations
- Shows statistics per cafe (visit count, average rating, favorite drink)

**Features:**
- **Sort Options:**
  - Best Rated
  - Most Visited
  - Recently Visited
  - Alphabetical
- **Cafe Cards** - Show:
  - Cafe name and location
  - Visit count
  - Average rating
  - Last visit date
  - Favorite drink at that cafe
  - Cafe photo (if available)
- **Swipe Actions** - Remove from favorites/wishlist with undo option
- **Quick Actions** - Log visit, view cafe details
- **Empty States** - Friendly illustrations when collections are empty

---

### 5. Profile Tab
Personal profile showing user's coffee journey and statistics.

**Profile Sections:**

**a) Profile Header**
- Banner image (customizable)
- Profile avatar (circular, with border)
- Display name
- Username (@handle)
- Bio text
- Location
- Favorite drink (self-declared)
- Instagram handle (optional)
- Website URL (optional)

**b) Action Buttons**
- Edit Profile
- Share Profile

**c) Social Row**
- Friends count (tappable to view friends list)
- Mutual friends count (when viewing other profiles)
- Instagram link (if provided)
- Website link (if provided)

**d) Coffee Stats Ribbon**
- **Total Visits** - Count of all logged visits
- **Cafes Visited** - Number of unique cafes
- **Average Rating** - Overall average score across all visits
- **Favorite Drink** - Most frequently ordered drink type
- **Top Cafe** - Most-visited or highest-rated cafe (tappable)

**e) Content Tabs**
Three tabs showing different views of user's content:

1. **Posts Tab**
   - Grid view of all visits (Instagram-style)
   - Shows poster photo for each visit
   - Tap to view visit details

2. **Cafes Tab**
   - List of all cafes visited
   - Shows visit count and average rating per cafe
   - Tap to view cafe details

3. **Journal Tab**
   - Chronological list of all visits
   - Full visit cards with all details
   - Filterable by timeframe (Today, Week, Month, Year)

**f) Friends Hub**
- View all friends
- Friend requests (incoming/outgoing)
- Search for users
- Mutual friends display
- Add/remove friends

**g) Notifications Center**
- All notifications in one place
- Mark as read/unread
- Clear all notifications
- Filter by notification type

---

## Social Features

### Friends System
- **Friend Requests** - Send and receive friend requests
- **Friend Network** - See visits from friends in Friends feed
- **Mutual Friends** - Discover connections through mutual friends
- **Friend Activity** - Notifications when friends post new visits
- **Sip Squad Mode** - View combined cafe map of your friend network

### Interactions
- **Likes** - Heart button on visits
- **Comments** - Text comments on visits
- **Replies** - Reply to comments
- **Mentions** - Tag users in captions/comments using @username
- **Shares** - Share profile or visit externally

### Notifications
The app sends notifications for:
- **New Visit from Friend** - Friend posted a new visit
- **Like** - Someone liked your visit
- **Comment** - Someone commented on your visit
- **Reply** - Someone replied to your comment
- **Mention** - Someone mentioned you (@username)
- **Friend Request** - Someone sent you a friend request
- **Friend Accept** - Someone accepted your friend request
- **Friend Join** - A friend joined Mugshot
- **System** - App-wide announcements

---

## Widgets (iOS Home Screen)

Mugshot offers several widgets for quick access:

### 1. Today's Mugshot Widget
- **Small & Medium sizes**
- Shows most recent visit from today
- If no visit today, shows motivational "Log Today's Sip" CTA
- Displays: Cafe name, drink type, rating, photo (medium size)
- Tappable to open visit detail or log visit flow

### 2. Cafe of the Day Widget
- **Small & Medium sizes**
- Daily featured cafe suggestion
- Prioritizes: Favorites → High-rated visited cafes → Nearby cafes
- Shows: Cafe name, location, rating, "Featured" badge
- Refreshes at midnight for new daily pick
- Tappable to view cafe details or open map

### 3. Favorites Quick Access Widget
- Quick access to favorite cafes
- Tappable to view cafe or log visit

### 4. Friends Latest Sips Widget
- Shows recent visits from friends
- Stay connected to friend activity

### 5. Nearby Cafe Widget
- Shows cafes near user's location
- Helps discover new places

### 6. Streak Widget
- Tracks consecutive days of logging visits
- Motivates daily journaling habit

---

## Data & Statistics

### Personal Analytics
Users can view:
- **Total Visits** - Lifetime count
- **Cafes Visited** - Unique cafe count
- **Average Rating** - Overall score across all visits
- **Favorite Drink Type** - Most frequently ordered
- **Top Cafe** - Most-visited or highest-rated
- **Visit Timeline** - Chronological history
- **Drink Distribution** - Breakdown by drink type
- **Rating Trends** - How ratings change over time

### Cafe Analytics
Per-cafe statistics:
- **Visit Count** - How many times visited
- **Average Rating** - User's average rating at this cafe
- **Favorite Drink** - Most ordered drink at this cafe
- **Last Visit Date** - Most recent visit
- **Visit History** - All visits to this cafe

### Platform-Wide Stats
- **Cafe Aggregate Stats** - Total visits, average rating, top drinks (across all users)
- **Popular Drinks** - Most ordered drinks at a cafe
- **Community Ratings** - Average ratings from all users

---

## User Experience Flow

### New User Journey
1. **Onboarding** - Welcome screens explaining app purpose
2. **Account Creation** - Sign up with email, username, display name
3. **Email Verification** - Verify email address
4. **Profile Setup** - Add bio, location, favorite drink, profile photo
5. **First Visit** - Guided flow to log first cafe visit
6. **Discover Features** - Learn about Map, Feed, Saved tabs

### Daily Usage Flow
1. **Open App** → See Feed or Map
2. **Visit Cafe** → Open Add tab → Log visit with photos, ratings, caption
3. **Browse Feed** → See friends' visits, discover new cafes
4. **Check Map** → Find nearby cafes or explore new areas
5. **View Profile** → Check stats, review journal
6. **Save Cafes** → Add to favorites or wishlist

### Social Flow
1. **Add Friends** → Search users, send friend requests
2. **View Friends' Visits** → See in Friends feed
3. **Interact** → Like, comment, mention friends
4. **Discover** → Find new cafes through friend activity
5. **Share** → Share profile or visits externally

---

## Technical Architecture (High-Level)

### Backend
- **Supabase** - Backend-as-a-Service for:
  - Authentication (email/password)
  - Database (PostgreSQL) for users, cafes, visits, comments, notifications
  - Storage (for photos)
  - Real-time subscriptions (for notifications, feed updates)
  - Edge functions (for push notifications, friend activity)

### Data Models
- **User** - Profile, authentication, social connections
- **Cafe** - Location, name, address, aggregate stats
- **Visit** - User's cafe visit with drink, photos, ratings, caption, visibility
- **Comment** - Comments on visits
- **Notification** - Social interaction notifications
- **Rating Template** - Customizable rating categories

### Offline Support
- Local caching of photos
- Offline visit creation (syncs when online)
- Network monitoring for connectivity status

---

## Unique Differentiators

1. **Coffee-Specific Focus** - Not a generic social app, but purpose-built for cafe culture
2. **Detailed Rating System** - Multi-category ratings (not just overall score)
3. **Drink Tracking** - Specific drink types and custom drink names
4. **Privacy Controls** - Private, friends-only, or public visibility per visit
5. **Personal Journal** - Private notes separate from public captions
6. **Sip Squad Mode** - Collaborative map view of friend network's cafe footprint
7. **Widget Integration** - Deep iOS integration with home screen widgets
8. **Mint Branding** - Distinctive, calm visual identity
9. **Content-First Design** - Photos and ratings are the hero, not the UI

---

## Target Audience

**Primary Users:**
- Coffee enthusiasts who visit cafes regularly
- People who enjoy documenting experiences
- Social users who want to share recommendations
- Location-based discovery seekers
- Journaling/reflection-oriented users

**Use Cases:**
- Personal coffee journaling and habit tracking
- Discovering new cafes through friends
- Sharing recommendations with community
- Building a social network around shared interests
- Analyzing coffee consumption patterns
- Planning cafe visits (wishlist feature)

---

## App Structure Summary

**Five Main Tabs:**
1. **Map** - Discover cafes geographically
2. **Feed** - Social feed of visits (Friends/Everyone/Discover)
3. **Add** - Log a new visit
4. **Saved** - Personal cafe library (Favorites/Wishlist/My Cafes)
5. **Profile** - Personal stats, journal, settings

**Key Screens:**
- Visit Detail View - Full visit with comments
- Cafe Detail View - Cafe info, stats, user's visits to this cafe
- Profile View (other users) - View friends' profiles
- Notifications Center - All notifications
- Friends Hub - Manage friend network
- Edit Profile - Update profile information
- Onboarding Flow - New user setup

---

## Brand Voice & Personality

**Tone:**
- Warm and inviting
- Calm and thoughtful (not frantic or noisy)
- Coffee-focused but not pretentious
- Community-oriented
- Personal and journaling-focused

**Language:**
- Uses "sip" and "visit" terminology
- "Mugshot" = a photo/documentation of a cafe visit
- "Sip Squad" = friend network
- "Coffee Journey" = personal statistics/analytics
- Friendly, approachable copy throughout

---

## Conclusion

Mugshot is a thoughtfully designed social journaling app that combines personal coffee documentation with community discovery. It stands out through its specific focus on cafe culture, detailed rating systems, privacy controls, and distinctive mint-green aesthetic. The app serves both introverted journalers (private notes, personal stats) and extroverted social users (feed, friends, sharing), making it appealing to a broad range of coffee enthusiasts who want to document, discover, and share their cafe experiences.


