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
    var cafes: [Cafe]
    var visits: [Visit]
    var ratingTemplate: RatingTemplate
    var hasCompletedOnboarding: Bool
    
    // New auth and onboarding state
    var onboardingSeen: Bool = false
    var hasSeenMarketingOnboarding: Bool = false
    var isUserAuthenticated: Bool = false
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
    
    // Notifications
    var notifications: [MugshotNotification] = []
    
    init(
        currentUser: User? = nil,
        cafes: [Cafe] = [],
        visits: [Visit] = [],
        ratingTemplate: RatingTemplate = RatingTemplate(),
        hasCompletedOnboarding: Bool = false,
        onboardingSeen: Bool = false,
        hasSeenMarketingOnboarding: Bool = false,
        isUserAuthenticated: Bool = false,
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
        notifications: [MugshotNotification] = []
    ) {
        self.currentUser = currentUser
        self.cafes = cafes
        self.visits = visits
        self.ratingTemplate = ratingTemplate
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.onboardingSeen = onboardingSeen
        self.hasSeenMarketingOnboarding = hasSeenMarketingOnboarding
        self.isUserAuthenticated = isUserAuthenticated
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
        self.notifications = notifications
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

