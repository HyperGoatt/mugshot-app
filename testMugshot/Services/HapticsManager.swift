//
//  HapticsManager.swift
//  testMugshot
//
//  Centralized haptics manager for providing tactile feedback across the app.
//  Uses Apple's system haptics (UIImpactFeedbackGenerator, UINotificationFeedbackGenerator, UISelectionFeedbackGenerator).
//

import UIKit

// MARK: - Haptics Design System
//
// This section defines when to use which haptic type for consistency across Mugshot.
//
// PRIMARY SUCCESS MOMENTS
// - Visit successfully saved
// - Profile update successfully saved
// - Friend request accepted
// - Email verified / Profile setup complete
// → Use: success()
//
// PRIMARY ERROR/FAILURE MOMENTS
// - Visit save fails
// - Auth error / signup error
// - Network errors when critical
// → Use: error()
//
// MEDIUM-CONFIRMATION INTERACTIONS
// - Tapping "Save Visit" button
// - Tapping "Log this café" button
// - Confirming logout or destructive action (delete post, remove friend)
// → Use: mediumTap() on tap, then success()/error() based on result
//
// LIGHT, FREQUENT INTERACTIONS
// - Toggling like heart on a post
// - Toggling favorite / want-to-try on a café
// - Changing rating sliders / tapping stars
// - Adding/removing photos
// → Use: lightTap()
//
// SELECTION CHANGES
// - Switching between segments (Everyone / Friends feed, Saved tabs, etc.)
// - Changing drink type
// - Switching visibility (Private / Friends / Everyone)
// → Use: selectionChanged()
//
// NAVIGATION TRANSITIONS
// - Tapping a post from feed → open PostPreview
// - Tapping a map pin → open visit detail or café bottom sheet
// - Tapping a notification to drill in
// → Use: lightTap() on the initial tap (not on every view appear)
//
// REFRESH / LONG ACTIONS
// - Pull-to-refresh feed completes
// - Map refresh of cafes completes
// → Use: success() if new items arrive, or lightTap() if just UI update

class HapticsManager: ObservableObject {
    static let shared = HapticsManager()
    
    /// Global toggle for haptics. Set to false to disable all haptics (e.g., for Settings toggle in future).
    /// Defaults to true.
    var isEnabled: Bool = true
    
    private init() {}
    
    // MARK: - Notification Haptics (Success, Error, Warning)
    
    /// Plays a success notification haptic.
    /// Use for: Visit successfully saved, profile update saved, friend request accepted, email verified.
    func playSuccess() {
        guard isEnabled else { return }
        #if os(iOS)
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
        #endif
    }
    
    /// Plays an error notification haptic.
    /// Use for: Visit save fails, auth errors, network errors when critical.
    func playError() {
        guard isEnabled else { return }
        #if os(iOS)
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
        #endif
    }
    
    /// Plays a warning notification haptic.
    /// Use for: Non-critical warnings (rarely used in Mugshot).
    func playWarning() {
        guard isEnabled else { return }
        #if os(iOS)
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        }
        #endif
    }
    
    // MARK: - Impact Haptics (Light, Medium, Heavy)
    
    /// Plays a light impact haptic.
    /// Use for: Toggling likes, favorites, want-to-try, rating stars, adding/removing photos, navigation taps.
    func lightTap() {
        guard isEnabled else { return }
        #if os(iOS)
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
        #endif
    }
    
    /// Plays a medium impact haptic.
    /// Use for: Tapping primary action buttons (Save Visit, Log Visit), confirming destructive actions.
    func mediumTap() {
        guard isEnabled else { return }
        #if os(iOS)
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
        #endif
    }
    
    /// Plays a heavy impact haptic.
    /// Use for: Rare, high-emphasis actions (currently unused in Mugshot, but available if needed).
    func heavyTap() {
        guard isEnabled else { return }
        #if os(iOS)
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
        }
        #endif
    }
    
    /// Plays an impact haptic with a custom style.
    /// Use for: Legacy code compatibility. Prefer lightTap(), mediumTap(), or heavyTap() for new code.
    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        #if os(iOS)
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
        #endif
    }
    
    // MARK: - Selection Haptics
    
    /// Plays a selection change haptic.
    /// Use for: Switching between segments (Everyone/Friends feed, Saved tabs), changing drink type, switching visibility.
    func selectionChanged() {
        guard isEnabled else { return }
        #if os(iOS)
        DispatchQueue.main.async {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
        #endif
    }
}

