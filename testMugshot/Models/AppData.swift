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
    var ratingTemplate: RatingTemplate
    var hasCompletedOnboarding: Bool
    
    // New auth and onboarding state
    var onboardingSeen: Bool = false
    var hasSeenMarketingOnboarding: Bool = false
    var isUserAuthenticated: Bool = false
    var hasEmailVerified: Bool = false
    var hasCompletedProfileSetup: Bool = false
    
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
    
    // Feature flags
    var useOnboardingStylePostFlow: Bool = false  // Toggle between classic and onboarding-style post flow
    
    init(
        currentUser: User? = nil,
        supabaseUserId: String? = nil,
        cafes: [Cafe] = [],
        visits: [Visit] = [],
        ratingTemplate: RatingTemplate = RatingTemplate(),
        hasCompletedOnboarding: Bool = false,
        onboardingSeen: Bool = false,
        hasSeenMarketingOnboarding: Bool = false,
        isUserAuthenticated: Bool = false,
        hasEmailVerified: Bool = false,
        hasCompletedProfileSetup: Bool = false,
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
        useOnboardingStylePostFlow: Bool = false
    ) {
        self.currentUser = currentUser
        self.supabaseUserId = supabaseUserId
        self.cafes = cafes
        self.visits = visits
        self.ratingTemplate = ratingTemplate
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.onboardingSeen = onboardingSeen
        self.hasSeenMarketingOnboarding = hasSeenMarketingOnboarding
        self.isUserAuthenticated = isUserAuthenticated
        self.hasEmailVerified = hasEmailVerified
        self.hasCompletedProfileSetup = hasCompletedProfileSetup
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

