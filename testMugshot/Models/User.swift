//
//  User.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var supabaseUserId: String?
    var username: String
    var displayName: String? // Optional display name
    var location: String
    var avatarImageName: String? // For now, store image name/path (deprecated, use profileImageID)
    var profileImageID: String? // PhotoCache key for profile image
    var bannerImageID: String? // PhotoCache key for banner image
    var avatarURL: String? // Remote avatar URL from Supabase storage
    var bio: String
    var instagramURL: String? // Instagram profile URL
    var websiteURL: String? // Personal website URL
    var favoriteDrink: String? // User's self-declared favorite drink
    
    init(
        id: UUID = UUID(),
        supabaseUserId: String? = nil,
        username: String,
        displayName: String? = nil,
        location: String,
        avatarImageName: String? = nil,
        profileImageID: String? = nil,
        bannerImageID: String? = nil,
        avatarURL: String? = nil,
        bio: String = "",
        instagramURL: String? = nil,
        websiteURL: String? = nil,
        favoriteDrink: String? = nil
    ) {
        self.id = id
        self.supabaseUserId = supabaseUserId
        self.username = username
        self.displayName = displayName
        self.location = location
        self.avatarImageName = avatarImageName
        self.profileImageID = profileImageID
        self.bannerImageID = bannerImageID
        self.avatarURL = avatarURL
        self.bio = bio
        self.instagramURL = instagramURL
        self.websiteURL = websiteURL
        self.favoriteDrink = favoriteDrink
    }
    
    // Computed property for display
    var displayNameOrUsername: String {
        displayName ?? username
    }
    
    // Get effective profile image ID (prefer new field, fallback to avatarImageName)
    var effectiveProfileImageID: String? {
        profileImageID ?? avatarImageName
    }
}

