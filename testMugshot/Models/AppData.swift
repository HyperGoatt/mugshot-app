//
//  AppData.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

// Container for all app data
struct AppData: Codable {
    var currentUser: User?
    var supabaseUserId: String?
    var cafes: [Cafe]
    var visits: [Visit]
    var recentSearches: [RecentSearchEntry] = []
    var ratingTemplate: RatingTemplate
    var hasCompletedOnboarding: Bool
    
    // New auth and onboarding state
    var onboardingSeen: Bool = false
    var hasSeenMarketingOnboarding: Bool = false
    var isUserAuthenticated: Bool = false
    var hasEmailVerified: Bool = false
    var hasCompletedProfileSetup: Bool = false
    
    /// Tracks if this is a brand new account that just signed up (vs returning user who logged in)
    /// Only new signups should see the onboarding flow
    var isNewAccountSignup: Bool = false
    
    // User profile fields
    var currentUserDisplayName: String?
    var currentUserUsername: String?
    var currentUserEmail: String?
    var currentUserBio: String?
    var currentUserLocation: String?
    var currentUserFavoriteDrink: String?
    var currentUserInstagramHandle: String?
    var currentUserWebsite: String?
    var currentUserProfileImageId: String?
    var currentUserBannerImageId: String?
    var currentUserAvatarURL: String?
    var currentUserBannerURL: String?
    
    // Notifications
    var notifications: [MugshotNotification] = []
    var friendsSupabaseUserIds: Set<String> = []
    /// Timestamp of the last time the user cleared all notifications.
    /// Used to hide older notifications after a \"Clear all\" action, even if they still exist server-side.
    var notificationsClearedAt: Date? = nil
    
    // Pending friend request tracking for quick status lookups
    /// Maps target user ID -> request UUID for outgoing pending friend requests
    var outgoingRequestsByUserId: [String: String] = [:]
    /// Maps source user ID -> request UUID for incoming pending friend requests  
    var incomingRequestsByUserId: [String: String] = [:]
    
    // Feature flags
    var useOnboardingStylePostFlow: Bool = false  // Toggle between classic and onboarding-style post flow
    
    // Map mode
    /// When true, the Map tab shows the combined coffee footprint of user + friends (Sip Squad Mode)
    var isSipSquadModeEnabled: Bool = false
    /// When true, Sip Squad mode uses simplified styling (mint pins with rating, no color legend)
    /// When false, uses standard color-coded pins with legend
    var useSipSquadSimplifiedStyle: Bool = false
    
    init(
        currentUser: User? = nil,
        supabaseUserId: String? = nil,
        cafes: [Cafe] = [],
        visits: [Visit] = [],
        recentSearches: [RecentSearchEntry] = [],
        ratingTemplate: RatingTemplate = RatingTemplate(),
        hasCompletedOnboarding: Bool = false,
        onboardingSeen: Bool = false,
        hasSeenMarketingOnboarding: Bool = false,
        isUserAuthenticated: Bool = false,
        hasEmailVerified: Bool = false,
        hasCompletedProfileSetup: Bool = false,
        isNewAccountSignup: Bool = false,
        currentUserDisplayName: String? = nil,
        currentUserUsername: String? = nil,
        currentUserEmail: String? = nil,
        currentUserBio: String? = nil,
        currentUserLocation: String? = nil,
        currentUserFavoriteDrink: String? = nil,
        currentUserInstagramHandle: String? = nil,
        currentUserWebsite: String? = nil,
        currentUserProfileImageId: String? = nil,
        currentUserBannerImageId: String? = nil,
        currentUserAvatarURL: String? = nil,
        currentUserBannerURL: String? = nil,
        notifications: [MugshotNotification] = [],
        friendsSupabaseUserIds: Set<String> = [],
        useOnboardingStylePostFlow: Bool = false,
        isSipSquadModeEnabled: Bool = false,
        useSipSquadSimplifiedStyle: Bool = false
    ) {
        self.currentUser = currentUser
        self.supabaseUserId = supabaseUserId
        self.cafes = cafes
        self.visits = visits
        self.recentSearches = recentSearches
        self.ratingTemplate = ratingTemplate
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.onboardingSeen = onboardingSeen
        self.hasSeenMarketingOnboarding = hasSeenMarketingOnboarding
        self.isUserAuthenticated = isUserAuthenticated
        self.hasEmailVerified = hasEmailVerified
        self.hasCompletedProfileSetup = hasCompletedProfileSetup
        self.isNewAccountSignup = isNewAccountSignup
        self.currentUserDisplayName = currentUserDisplayName
        self.currentUserUsername = currentUserUsername
        self.currentUserEmail = currentUserEmail
        self.currentUserBio = currentUserBio
        self.currentUserLocation = currentUserLocation
        self.currentUserFavoriteDrink = currentUserFavoriteDrink
        self.currentUserInstagramHandle = currentUserInstagramHandle
        self.currentUserWebsite = currentUserWebsite
        self.currentUserProfileImageId = currentUserProfileImageId
        self.currentUserBannerImageId = currentUserBannerImageId
        self.currentUserAvatarURL = currentUserAvatarURL
        self.currentUserBannerURL = currentUserBannerURL
        self.notifications = notifications
        self.friendsSupabaseUserIds = friendsSupabaseUserIds
        self.useOnboardingStylePostFlow = useOnboardingStylePostFlow
        self.isSipSquadModeEnabled = isSipSquadModeEnabled
        self.useSipSquadSimplifiedStyle = useSipSquadSimplifiedStyle
        self.notificationsClearedAt = nil
    }
}

extension AppData {
    var hasSeenOnboarding: Bool {
        get { onboardingSeen }
        set { onboardingSeen = newValue }
    }
    
    var isAuthenticated: Bool {
        get { isUserAuthenticated }
        set { isUserAuthenticated = newValue }
    }
}

