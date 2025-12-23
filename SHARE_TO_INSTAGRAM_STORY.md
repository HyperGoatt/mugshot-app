# Share to Instagram Story: Product Requirements Document

## Overview

**Share to Instagram Story** is a branded content creation feature that transforms user visits into polished, Instagram-ready postcards. The feature allows users to generate beautiful, shareable images from their cafe visits, complete with visit details, ratings, photos, and Mugshot branding, optimized for Instagram Stories' 9:16 aspect ratio.

The feature serves as both a user engagement tool (encouraging users to share their Mugshot experiences) and a growth mechanism (exposing Mugshot to new audiences through organic social sharing). It transforms personal journaling moments into shareable social content while maintaining Mugshot's distinctive mint-green brand identity.

---

## Core Value Proposition

Share to Instagram Story provides three primary benefits:

1. **Content Creation Made Easy**: Users can instantly create polished, branded postcards from their visits without any design skills or external tools
2. **Brand Amplification**: Every shared postcard includes Mugshot branding and a "Download Now" call-to-action, driving organic app discovery
3. **Social Expression**: Users can showcase their coffee journey on Instagram Stories in a visually appealing, consistent format that reflects their personal Mugshot experience

The feature bridges the gap between private journaling and public sharing, allowing users to selectively share their favorite cafe moments while maintaining the privacy of their complete journal.

---

## User Experience Flow

### Entry Point

**Access Location:**
- The feature is accessible from the **Visit Detail View** (the full-screen view when viewing a visit)
- A share button appears in the social actions row (alongside Like, Comment, Bookmark buttons)
- **Important**: The share button is only visible when viewing **your own visits** (not friends' or public visits)
- This ensures users can only share their own content and maintains privacy

**User Action:**
1. User navigates to a visit detail view (from Feed, Profile, or Saved tab)
2. User taps the share button (square.and.arrow.up icon)
3. Postcard Preview Sheet opens as a full-screen modal

### Postcard Preview Experience

**Initial State:**
- The preview sheet loads all photos from the visit
- Photos are fetched from local cache first, then from remote URLs if needed
- Author avatar is pre-loaded (required for rendering)
- A loading indicator appears while photos are being fetched

**Postcard Selection Interface:**

1. **Variant Picker (Top)**
   - Two toggle buttons: "Light" and "Dark"
   - Light variant: Lighter gradient overlay for better text readability on bright photos
   - Dark variant: Darker gradient overlay for better contrast on darker photos
   - Selected variant is highlighted in mint-green with white text
   - Unselected variant uses gray background with secondary text
   - Users can switch variants at any time; the selected postcard re-renders automatically

2. **Postcard Carousel (Center)**
   - Horizontal scrollable carousel showing all available postcard options
   - **Single Photo Postcards**: One postcard for each photo in the visit
     - Labeled as "Photo 1", "Photo 2", etc.
     - Each uses that specific photo as the background
   - **Collage Postcard** (if visit has 2+ photos):
     - Labeled as "Collage (N)" where N is the number of photos
     - Displays multiple photos in a 2-column grid layout
     - Uses an even number of photos (rounds down to nearest even: 3 photos → 2, 5 photos → 4)
   - Postcards are displayed as scaled-down previews (240×427pt when unselected, 280×498pt when selected)
   - Selected postcard has:
     - Mint-green border (4pt width)
     - Larger size and enhanced shadow
     - Bold label text
   - Unselected postcards have:
     - No border
     - Smaller size and subtle shadow
     - Regular weight label text
   - Users tap any postcard to select it
   - First postcard is auto-selected when the sheet opens

3. **Action Buttons (Bottom)**
   - Buttons appear only after a postcard is selected
   - **Primary Action: Share Button**
     - Mint-green background with white text
     - Icon: square.and.arrow.up
     - Label: "Share"
     - Opens iOS native share sheet (allows sharing to any app, AirDrop, etc.)
   - **Secondary Actions (Two buttons side-by-side):**
     - **Instagram Story Button**
       - White background with border
       - Icon: camera.fill
       - Label: "Instagram Story"
       - Directly shares to Instagram Stories (if Instagram is installed)
     - **Save Button**
       - White background with border
       - Icon: arrow.down.to.line
       - Label: "Save"
       - Saves postcard to Photos app (requires photo library permission)
   - All buttons are disabled until the postcard image is rendered
   - Buttons show reduced opacity (50%) when disabled

**Rendering Process:**
- When a postcard is selected, it renders to a high-resolution image (1080×1920 pixels)
- A rendering overlay appears with:
  - Semi-transparent black background
  - Progress indicator (mint-green)
  - Text: "Generating postcard..."
- Rendering happens asynchronously to avoid blocking the UI
- Once complete, buttons become enabled and the overlay disappears

**Empty State:**
- If no postcard is selected, a prompt appears: "Tap a postcard to select it"
- This guides users to make a selection before sharing

### Sharing Actions

**1. General Share (Share Button)**
- Opens iOS native `UIActivityViewController`
- Allows sharing to:
  - Other apps (Messages, Mail, Twitter, etc.)
  - AirDrop
  - Save to Files
  - Copy to clipboard
  - Any other app that accepts images
- User can choose destination and complete sharing within iOS

**2. Instagram Story (Direct Share)**
- Checks if Instagram is installed on the device
- If installed:
  - Encodes the postcard image as PNG data
  - Places image data in iOS pasteboard with Instagram-specific key: `com.instagram.sharedSticker.backgroundImage`
  - Sets pasteboard expiration to 5 minutes
  - Opens Instagram Stories via URL scheme: `instagram-stories://share`
  - Instagram automatically detects the pasteboard content and offers it as a story background
  - User can then add stickers, text, or other Instagram features before posting
- If not installed:
  - Shows error alert: "Instagram is not installed on your device."
  - Recovery suggestion: "Please install Instagram from the App Store to share stories."
  - User can still use the general Share button to save the image

**3. Save to Photos**
- Requests photo library permission (add-only permission)
- If authorized:
  - Saves the postcard image to the user's Photos library
  - Shows success alert: "Your postcard has been saved to Photos."
  - Provides haptic success feedback
- If denied:
  - Shows error alert: "Unable to save to Photos. Please check your privacy settings."
  - Provides haptic error feedback

---

## Postcard Design

### Layout & Structure

**Aspect Ratio:**
- Fixed 9:16 aspect ratio (1080×1920 pixels)
- Matches Instagram Stories format exactly
- Ensures perfect display on Instagram without cropping or letterboxing

**Background Layer:**
- **With Photo**: Visit photo fills entire background (full bleed)
  - Photo is cropped to fill 9:16 aspect ratio
  - Uses aspect fill to ensure no empty space
  - Gradient overlay applied from top to bottom:
    - Top 40%: Fully transparent (photo visible)
    - 40-70%: Gradually darkening (black opacity 0.0 → 0.4)
    - 70-100%: Dark overlay (black opacity 0.4 → 0.8)
  - Ensures text readability at bottom while preserving photo visibility at top
- **Without Photo**: Branded mint-green gradient background
  - Three-color gradient: Light mint (#A8D5BA) → Mugshot mint → Darker mint (#7CB889)
  - Subtle decorative circles (white, low opacity) for visual interest
  - Bottom gradient overlay for text area (similar to photo version)

**Content Overlay (Bottom Section):**
- Glassmorphism card design (frosted glass effect)
- Positioned at bottom of postcard
- Contains all visit information and branding
- Background: Ultra-thin material with 85% opacity + black overlay (35% opacity)
- Border: White stroke (15% opacity, 2pt width)
- Corner radius: 56pt (scaled for high-res canvas)
- Padding: 60pt horizontal, 48pt sides, 56pt bottom

### Content Elements

**Row 1: Rating + Drink Type**
- **Left Side**: Overall rating score
  - Gold star icon (48pt, bold)
  - Score number (84pt, bold, rounded font, white)
  - Format: "4.2" (one decimal place)
- **Right Side**: Drink type pill
  - Drink icon (varies by type: cup.and.saucer.fill for coffee, leaf.fill for matcha/tea, etc.)
  - Drink name text (36pt, semibold)
  - Mint-green background (primaryAccent color)
  - White text (textOnMint color)
  - Capsule shape with padding (32pt horizontal, 20pt vertical)
  - Shows custom drink type if available, otherwise shows base drink type

**Row 2: Cafe Name**
- Large, bold text (72pt, bold, white)
- Maximum 2 lines (line limit)
- Truncates with ellipsis if too long

**Row 3: Location & Date**
- **Location** (if available):
  - Map pin icon (32pt, medium weight)
  - City name (34pt, medium weight, white, 90% opacity)
- **Separator**: Bullet point (•) in white, 50% opacity
- **Date**:
  - Calendar icon (32pt, medium weight)
  - Formatted date (34pt, medium weight, white, 90% opacity)
  - Format: "January 15, 2024" (full month name, day, year)

**Row 4: Caption (Optional)**
- Only shown if visit has a caption
- Quoted text with quotation marks: "Caption text here..."
- Serif font (40pt, regular, italic)
- White text, 95% opacity
- Maximum 3 lines
- Truncates to 100 characters if longer (shows "..." at end)
- **Note**: Uses public caption only, never shows private notes

**Divider:**
- Horizontal line (2pt height)
- White, 25% opacity
- 10pt vertical padding above and below

**Row 5: Author + Branding**
- **Left Side: Author Section**
  - Circular avatar (100pt diameter)
    - User's profile photo if available
    - White border (3pt, 40% opacity)
    - Fallback: Mint-green circle with first letter of display name
  - Author name and username (stacked vertically)
    - Display name (36pt, semibold, white)
    - Username with @ symbol (30pt, regular, white, 75% opacity)
- **Right Side: Mugshot Branding**
  - App icon (48pt) + "Mugshot" wordmark (42pt, bold, white)
  - "Download Now" call-to-action (28pt, semibold, white, 70% opacity)
  - Fixed size (doesn't expand)

### Visual Variants

**Light Variant:**
- Lighter gradient overlay for better text readability
- Gradient stops: [clear, clear, black 0.3, black 0.75]
- Best for bright, well-lit photos
- Text remains highly readable

**Dark Variant:**
- Darker gradient overlay for stronger contrast
- Gradient stops: [clear, clear, black 0.4, black 0.85]
- Best for darker photos or when user wants more dramatic effect
- Ensures text readability on any photo

### Collage Layout

**When Multiple Photos Available:**
- If visit has 2+ photos, a collage option is automatically generated
- Uses 2-column grid layout
- Photos fill available space (65% of total height reserved for photos)
- Even number of photos used (rounds down: 3 photos → 2, 5 photos → 4)
- 4pt spacing between photos
- Photos are cropped to fill their grid cells (aspect fill)
- Same content overlay at bottom (35% of height)
- All other design elements identical to single-photo postcards

---

## Technical Implementation

### Image Rendering

**Rendering Engine:**
- Uses iOS 16+ `ImageRenderer` API
- Renders SwiftUI views directly to `UIImage`
- Fixed output size: 1080×1920 pixels (exact Instagram Stories dimensions)
- Scale: 1.0 (pixel-perfect, no scaling)

**Rendering Process:**
1. User selects a postcard variant and photo/collage
2. SwiftUI view (`MugshotPostcardView` or `CollagePostcardView`) is created with visit data
3. View is rendered to `UIImage` at 1080×1920 size
4. Image is cached in memory for immediate sharing
5. Rendering happens asynchronously to avoid UI blocking

**Performance:**
- Rendering typically takes <1 second
- Large photos may take slightly longer
- Rendering overlay provides visual feedback during process
- Images are only rendered when needed (on selection change)

### Photo Loading

**Loading Strategy:**
1. **Local Cache First**: Checks `PhotoCache` for locally stored photos
2. **Remote URL Fallback**: Downloads from Supabase Storage if not cached
3. **Poster Photo Fallback**: If no photos load, uses `posterPhotoURL` from visit
4. **Avatar Loading**: Author avatar is pre-loaded before rendering (required for ImageRenderer compatibility)

**Error Handling:**
- If photos fail to load, postcard still renders with gradient background
- Missing avatar shows fallback (mint circle with initial)
- Loading errors are logged but don't block the experience

### Instagram Integration

**URL Scheme API:**
- Uses Instagram's official Stories sharing API
- Documentation: https://developers.facebook.com/docs/instagram/sharing-to-stories
- Requires `LSApplicationQueriesSchemes` in Info.plist:
  - `instagram-stories`
  - `instagram`

**Pasteboard Format:**
- Key: `com.instagram.sharedSticker.backgroundImage`
- Format: PNG image data
- Expiration: 5 minutes (prevents stale data)
- Instagram automatically detects pasteboard content when opened

**Error Handling:**
- Checks if Instagram is installed before attempting share
- Provides clear error messages if Instagram not available
- Falls back gracefully (user can still use general share or save)

### Privacy & Permissions

**Photo Library Permission:**
- Requests "Add Only" permission (iOS 14+)
- Allows saving without full library access
- Permission requested only when user taps "Save"
- Clear error messaging if permission denied

**Data Privacy:**
- Only public visit data is included in postcards:
  - Public caption (never private notes)
  - Overall rating
  - Cafe name and location
  - Visit date
  - Author information
- Private notes are never exposed in shared content
- Users control what they share (only their own visits can be shared)

---

## User States & Edge Cases

### No Photos

**Behavior:**
- Postcard still generates with branded gradient background
- All visit information still displayed
- User can still share or save
- Collage option is not available

### Single Photo

**Behavior:**
- One single-photo postcard available
- No collage option (requires 2+ photos)
- Standard postcard experience

### Multiple Photos

**Behavior:**
- One postcard per photo (e.g., 3 photos = 3 single postcards)
- One collage postcard (uses even number of photos)
- User can choose which photo or collage to share

### Missing Data

**Cafe Name:**
- Falls back to "Unknown Cafe" if cafe data unavailable

**City:**
- Location row simply omits city if unavailable
- Date still displays

**Caption:**
- Caption row is hidden if no caption exists
- Other content remains visible

**Avatar:**
- Falls back to mint circle with user's first initial
- Never shows broken image

### Instagram Not Installed

**Behavior:**
- Instagram Story button still appears
- Tapping shows error alert with clear message
- User can still use general Share or Save buttons
- No blocking experience

### Permission Denied (Photos)

**Behavior:**
- Save button still appears
- Tapping requests permission
- If denied, shows error alert
- User can still use Share or Instagram Story

### Rendering Failures

**Behavior:**
- Rare edge case
- Buttons remain disabled if rendering fails
- User can try selecting different postcard
- Error is logged for debugging

---

## Design System Integration

### Colors

**Primary Accent (Mint-Green):**
- Used for: Drink type pill, variant picker selection, postcard borders, branding
- Ensures consistent Mugshot brand identity

**Text Colors:**
- White for all text (ensures readability on dark gradients)
- Opacity variations for hierarchy (90% for secondary info, 75% for usernames)

**Background:**
- Ultra-thin material for glassmorphism effect
- Black overlay for depth and contrast

### Typography

**Font Sizes (Scaled for 1080×1920 canvas):**
- Score: 84pt (bold, rounded)
- Cafe name: 72pt (bold)
- Caption: 40pt (regular, serif, italic)
- Author name: 36pt (semibold)
- Meta info: 34pt (medium)
- Username: 30pt (regular)
- CTA: 28pt (semibold)

**Font Weights:**
- Bold for emphasis (scores, titles)
- Semibold for important info (author, drink type)
- Regular for body text (caption, meta)
- Medium for icons and secondary info

### Spacing

**Padding:**
- Content card: 60pt horizontal, 48pt sides, 56pt bottom
- Elements: 40pt between major rows, 24pt for icon-text spacing
- Consistent with Mugshot's spacing scale (scaled for high-res)

**Corner Radius:**
- Content card: 56pt
- Drink pill: Capsule (auto)
- Avatar: Circle (50pt radius)

---

## Branding & Marketing

### Mugshot Branding Elements

**App Icon:**
- Loaded from app bundle
- 48pt size in postcard
- Fallback design if icon unavailable (mint rectangle with mug icon)

**Wordmark:**
- "Mugshot" text (42pt, bold, white)
- Positioned next to app icon

**Call-to-Action:**
- "Download Now" text (28pt, semibold, white, 70% opacity)
- Encourages Instagram viewers to download Mugshot
- Non-intrusive but discoverable

### Brand Consistency

**Visual Identity:**
- Mint-green color throughout (drink pill, borders, selection states)
- Consistent typography and spacing
- Polished, premium aesthetic
- Recognizable as Mugshot content

**Content Quality:**
- High-resolution output (1080×1920)
- Professional design
- No watermarks or obtrusive branding
- Branding is integrated, not added-on

---

## User Benefits

### For Content Creators

1. **Professional Output**: Instantly create polished, Instagram-ready content
2. **Time Savings**: No need for external design apps or manual creation
3. **Consistency**: All postcards follow the same design system
4. **Flexibility**: Choose from multiple photos, variants, and layouts

### For Social Sharers

1. **Easy Sharing**: One-tap sharing to Instagram Stories
2. **Brand Expression**: Showcase coffee journey with branded content
3. **Story Enhancement**: Postcards work perfectly as Instagram Story backgrounds
4. **Personalization**: Multiple variants and photo options

### For Mugshot Growth

1. **Organic Discovery**: Every shared postcard exposes Mugshot to new audiences
2. **Brand Recognition**: Consistent visual identity builds brand awareness
3. **App Downloads**: "Download Now" CTA drives direct installs
4. **User Advocacy**: Users become brand ambassadors through sharing

---

## Success Metrics

### Engagement Indicators

- **Share Rate**: Percentage of visits that generate postcards
- **Instagram Share Rate**: Percentage of postcards shared to Instagram Stories
- **Save Rate**: Percentage of postcards saved to Photos
- **Variant Preference**: Light vs. Dark variant usage
- **Photo Selection**: Single photo vs. Collage preference

### Growth Indicators

- **App Installs from Shares**: Track installs attributed to Instagram Story shares
- **Brand Mentions**: Instagram posts/stories mentioning Mugshot
- **Viral Coefficient**: How many new users each sharer brings in
- **Share Frequency**: Average postcards shared per user per month

### Quality Indicators

- **Rendering Success Rate**: Percentage of successful renders
- **Error Rate**: Frequency of Instagram/share errors
- **User Satisfaction**: Feedback on postcard quality and ease of use
- **Completion Rate**: Users who start postcard creation vs. those who complete sharing

---

## Future Enhancement Opportunities

### Design Variants

1. **Seasonal Themes**: Holiday or seasonal postcard designs
2. **Color Schemes**: Alternative color palettes (beyond light/dark)
3. **Layout Options**: Different content arrangements (centered, left-aligned, etc.)
4. **Animation**: Animated postcards for Instagram (video stories)

### Sharing Enhancements

1. **Multi-Platform**: Direct sharing to TikTok, Snapchat, Twitter
2. **Scheduled Sharing**: Save postcards for later sharing
3. **Batch Creation**: Generate postcards for multiple visits at once
4. **Custom Branding**: User-selectable branding elements (for power users)

### Content Features

1. **Template Library**: Pre-designed postcard templates
2. **Custom Text Overlays**: User-added text or quotes
3. **Sticker Integration**: Mugshot-branded stickers for Instagram
4. **QR Codes**: Include QR codes linking to visit or cafe in Mugshot

### Analytics

1. **Share Tracking**: See which postcards get the most engagement
2. **Performance Insights**: Show users how their shared postcards perform
3. **Best Practices**: Tips for creating shareable postcards

---

## Technical Considerations (Non-Technical Summary)

### Performance

**Rendering Speed:**
- Postcards render in <1 second typically
- Large photos may take slightly longer
- Rendering happens asynchronously to avoid blocking

**Image Quality:**
- Output is exactly 1080×1920 pixels (Instagram's recommended size)
- High resolution ensures crisp display on all devices
- PNG format preserves quality

**Memory Management:**
- Images are rendered on-demand (not pre-rendered)
- Rendered images cached in memory for immediate sharing
- Memory is released after sharing completes

### Compatibility

**iOS Requirements:**
- Requires iOS 16+ (for ImageRenderer API)
- Instagram app must be installed for direct Stories sharing
- Photo library permission required for saving

**Device Support:**
- Works on all iOS devices (iPhone, iPad)
- Optimized for iPhone screen sizes
- Postcards display correctly on all Instagram-supported devices

### Reliability

**Error Handling:**
- Graceful fallbacks for missing data
- Clear error messages for user-facing issues
- Logging for debugging technical problems

**Data Integrity:**
- Only public data included in postcards
- Private notes never exposed
- User privacy maintained

---

## Conclusion

Share to Instagram Story transforms Mugshot from a private journaling app into a social content creation platform. By making it effortless to create beautiful, branded postcards from visits, the feature encourages users to share their coffee journey while simultaneously driving organic growth for Mugshot.

The feature balances user needs (easy sharing, professional output) with business goals (brand exposure, app discovery) through thoughtful design, consistent branding, and seamless integration with Instagram's native sharing capabilities. Every shared postcard serves as both a personal expression and a subtle invitation for others to join the Mugshot community.

The polished design, high-quality output, and intuitive user experience make sharing feel natural and rewarding, turning users into brand advocates one postcard at a time.
