//
//  RemoteUserProfile.swift
//  testMugshot
//
//  Codable representations of Supabase rows plus mapping helpers.
//

import Foundation

struct RemoteUserProfile: Codable {
    let id: String
    var displayName: String
    var username: String
    var bio: String?
    var location: String?
    var favoriteDrink: String?
    var instagramHandle: String?
    var avatarURL: String?
    var bannerURL: String?
    var createdAt: Date?
    var updatedAt: Date?

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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RemoteRatingTemplate: Codable {
    let id: String
    let userId: String
    var templateJSON: [String: Double]
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case templateJSON = "template_json"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension RemoteUserProfile {
    func toLocalUser(existing: User? = nil, overridingId: UUID? = nil) -> User {
        User(
            id: overridingId ?? existing?.id ?? UUID(),
            username: username,
            displayName: displayName,
            location: location ?? "",
            avatarImageName: existing?.avatarImageName,
            profileImageID: existing?.profileImageID,
            bannerImageID: existing?.bannerImageID,
            bio: bio ?? "",
            instagramURL: instagramHandle,
            websiteURL: existing?.websiteURL,
            favoriteDrink: favoriteDrink
        )
    }
}

extension RemoteUserProfile {
    /// Payload for updating user profile (excludes id - updated by userId query param)
    /// IDENTITY SAFE: Updates existing user by userId, never creates duplicate
    struct UpdatePayload: Codable {
        var displayName: String?
        var username: String?
        var bio: String?
        var location: String?
        var favoriteDrink: String?
        var instagramHandle: String?
        var websiteURL: String?
        var avatarURL: String?
        var bannerURL: String?
        
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case username
            case bio
            case location
            case favoriteDrink = "favorite_drink"
            case instagramHandle = "instagram_handle"
            case websiteURL = "website_url"
            case avatarURL = "avatar_url"
            case bannerURL = "banner_url"
        }
    }
}

extension RemoteRatingTemplate {
    func toLocalRatingTemplate() -> RatingTemplate {
        let categories = templateJSON.map { key, weight in
            RatingCategory(name: key, weight: weight)
        }.sorted { $0.name < $1.name }
        return RatingTemplate(categories: categories)
    }

    static func fromLocal(userId: String, template: RatingTemplate) -> RemoteRatingTemplate {
        let dict = Dictionary(uniqueKeysWithValues: template.categories.map { ($0.name, $0.weight) })
        return RemoteRatingTemplate(
            id: UUID().uuidString,
            userId: userId,
            templateJSON: dict,
            createdAt: nil,
            updatedAt: nil
        )
    }
}


