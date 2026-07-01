//
//  SupabaseUserProfile.swift
//  testMugshot
//

import Foundation

struct SupabaseUserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var username: String
    var bio: String?
    var location: String?
    var favoriteDrink: String?
    var instagramHandle: String?
    var avatarURL: String?
    var bannerURL: String?
    var websiteURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case bio
        case location
        case favoriteDrink = "favorite_drink"
        case instagramHandle = "instagram_handle"
        case avatarURL = "avatar_url"
        case bannerURL = "banner_url"
        case websiteURL = "website_url"
    }
    
    var localUser: User {
        User(
            id: id,
            username: username,
            displayName: displayName,
            location: location ?? "",
            avatarImageName: avatarURL,
            bio: bio ?? ""
        )
    }
}

struct SupabaseUserProfileUpsert: Encodable {
    let id: UUID
    let displayName: String
    let username: String
    let bio: String?
    let location: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case bio
        case location
    }
}

