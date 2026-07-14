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

struct SupabaseUserProfileUpdate: Encodable {
    let displayName: String
    let username: String
    let bio: String?
    let location: String?
    let favoriteDrink: String?
    let instagramHandle: String?
    let websiteURL: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case username
        case bio
        case location
        case favoriteDrink = "favorite_drink"
        case instagramHandle = "instagram_handle"
        case websiteURL = "website_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(username, forKey: .username)
        try container.encodeOptionalOrNull(bio, forKey: .bio)
        try container.encodeOptionalOrNull(location, forKey: .location)
        try container.encodeOptionalOrNull(favoriteDrink, forKey: .favoriteDrink)
        try container.encodeOptionalOrNull(instagramHandle, forKey: .instagramHandle)
        try container.encodeOptionalOrNull(websiteURL, forKey: .websiteURL)
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeOptionalOrNull(_ value: String?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}
