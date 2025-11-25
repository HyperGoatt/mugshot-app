//
//  RemoteSocialModels.swift
//  testMugshot
//
//  Created as part of Phase B Supabase integration.
//

import Foundation
import CoreLocation

// MARK: - Cafes

struct RemoteCafe: Codable {
    let id: UUID
    var name: String
    var address: String?
    var city: String?
    var country: String?
    var latitude: Double?
    var longitude: Double?
    var applePlaceId: String?
    var websiteURL: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case city
        case country
        case latitude
        case longitude
        case applePlaceId = "apple_place_id"
        case websiteURL = "website_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension RemoteCafe {
    func toLocalCafe(existing: Cafe? = nil) -> Cafe {
        var location: CLLocationCoordinate2D?
        if let lat = latitude, let lon = longitude {
            location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            #if DEBUG
            print("🗺️ [RemoteCafe] Converted coordinates for '\(name)': (\(lat), \(lon))")
            #endif
        } else {
            #if DEBUG
            print("⚠️ [RemoteCafe] No coordinates for '\(name)' - lat: \(latitude?.description ?? "nil"), lon: \(longitude?.description ?? "nil")")
            #endif
        }
        
        return Cafe(
            id: existing?.id ?? id,
            supabaseId: id,
            name: name,
            location: location, // Use remote location if available
            address: address ?? existing?.address ?? "",
            city: city ?? existing?.city,
            country: country ?? existing?.country,
            isFavorite: existing?.isFavorite ?? false,
            wantToTry: existing?.wantToTry ?? false,
            averageRating: existing?.averageRating ?? 0,
            visitCount: existing?.visitCount ?? 0, // Will be calculated separately
            mapItemURL: existing?.mapItemURL,
            websiteURL: websiteURL ?? existing?.websiteURL,
            applePlaceId: applePlaceId ?? existing?.applePlaceId,
            placeCategory: existing?.placeCategory
        )
    }
}

// MARK: - Visits

struct RemoteVisit: Codable {
    let id: UUID
    let userId: String
    let cafeId: UUID
    var drinkType: String?
    var drinkTypeCustom: String?
    var caption: String
    var notes: String?
    var visibility: String
    var ratings: [String: Double]
    var overallScore: Double
    var posterPhotoURL: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    var cafe: RemoteCafe?
    var photos: [RemoteVisitPhoto]?
    var likes: [RemoteLike]?
    var comments: [RemoteComment]?
    var author: RemoteVisitAuthor?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case cafeId = "cafe_id"
        case drinkType = "drink_type"
        case drinkTypeCustom = "drink_type_custom"
        case caption
        case notes
        case visibility
        case ratings
        case overallScore = "overall_score"
        case posterPhotoURL = "poster_photo_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case cafe
        case photos = "visit_photos"
        case likes
        case comments
        case author
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        
        // Handle userId: Supabase returns UUID as string, decode as UUID then convert to String
        if let userIdUUID = try? container.decode(UUID.self, forKey: .userId) {
            userId = userIdUUID.uuidString
        } else if let userIdString = try? container.decode(String.self, forKey: .userId) {
            userId = userIdString
        } else {
            throw DecodingError.keyNotFound(CodingKeys.userId, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "user_id is required"))
        }
        
        cafeId = try container.decode(UUID.self, forKey: .cafeId)
        drinkType = try container.decodeIfPresent(String.self, forKey: .drinkType)
        drinkTypeCustom = try container.decodeIfPresent(String.self, forKey: .drinkTypeCustom)
        caption = try container.decode(String.self, forKey: .caption)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        visibility = try container.decode(String.self, forKey: .visibility)
        
        // Decode ratings JSONB: Supabase returns it as JSONB, decode as dictionary
        // Handle case where it might be empty object {} or null
        if container.contains(.ratings) {
            if (try? container.decodeNil(forKey: .ratings)) == true {
                ratings = [:]
            } else if let ratingsDict = try? container.decode([String: Double].self, forKey: .ratings) {
                ratings = ratingsDict
            } else {
                // If decoding fails, fall back to empty dict
                print("⚠️ Failed to decode ratings as [String: Double], falling back to empty dict")
                ratings = [:]
            }
        } else {
            ratings = [:]
        }
        
        overallScore = try container.decode(Double.self, forKey: .overallScore)
        posterPhotoURL = try container.decodeIfPresent(String.self, forKey: .posterPhotoURL)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        
        cafe = try container.decodeIfPresent(RemoteCafe.self, forKey: .cafe)
        photos = try container.decodeIfPresent([RemoteVisitPhoto].self, forKey: .photos)
        likes = try container.decodeIfPresent([RemoteLike].self, forKey: .likes)
        comments = try container.decodeIfPresent([RemoteComment].self, forKey: .comments)
        author = try container.decodeIfPresent(RemoteVisitAuthor.self, forKey: .author)
    }
}

struct RemoteVisitPhoto: Codable {
    let id: UUID
    let visitId: UUID
    let photoURL: String
    let sortOrder: Int
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case visitId = "visit_id"
        case photoURL = "photo_url"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

struct RemoteLike: Codable {
    let id: UUID
    let userId: String
    let visitId: UUID
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case visitId = "visit_id"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        
        // Handle userId: Supabase returns UUID as string, decode as UUID then convert to String
        if let userIdUUID = try? container.decode(UUID.self, forKey: .userId) {
            userId = userIdUUID.uuidString
        } else if let userIdString = try? container.decode(String.self, forKey: .userId) {
            userId = userIdString
        } else {
            throw DecodingError.keyNotFound(CodingKeys.userId, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "user_id is required"))
        }
        
        visitId = try container.decode(UUID.self, forKey: .visitId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct RemoteComment: Codable {
    let id: UUID
    let userId: String
    let visitId: UUID
    let text: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case visitId = "visit_id"
        case text
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        
        // Handle userId: Supabase returns UUID as string, decode as UUID then convert to String
        if let userIdUUID = try? container.decode(UUID.self, forKey: .userId) {
            userId = userIdUUID.uuidString
        } else if let userIdString = try? container.decode(String.self, forKey: .userId) {
            userId = userIdString
        } else {
            throw DecodingError.keyNotFound(CodingKeys.userId, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "user_id is required"))
        }
        
        visitId = try container.decode(UUID.self, forKey: .visitId)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct RemoteVisitAuthor: Codable {
    let id: String
    let displayName: String?
    let username: String?
    let avatarURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle id: Supabase returns UUID as string, decode as UUID then convert to String
        if let idUUID = try? container.decode(UUID.self, forKey: .id) {
            id = idUUID.uuidString
        } else if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else {
            throw DecodingError.keyNotFound(CodingKeys.id, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "id is required"))
        }
        
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
    }
}

// MARK: - Social Graph

struct RemoteFollow: Codable {
    let followerId: String
    let followeeId: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followeeId = "followee_id"
        case createdAt = "created_at"
    }
}

// MARK: - Friends

enum FriendRequestStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
}

struct RemoteFriendRequest: Codable {
    let id: UUID
    let fromUserId: String
    let toUserId: String
    let status: FriendRequestStatus
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case status
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        
        // Handle fromUserId: Supabase returns UUID as string, decode as UUID then convert to String
        if let userIdUUID = try? container.decode(UUID.self, forKey: .fromUserId) {
            fromUserId = userIdUUID.uuidString
        } else if let userIdString = try? container.decode(String.self, forKey: .fromUserId) {
            fromUserId = userIdString
        } else {
            throw DecodingError.keyNotFound(CodingKeys.fromUserId, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "from_user_id is required"))
        }
        
        // Handle toUserId: Supabase returns UUID as string, decode as UUID then convert to String
        if let userIdUUID = try? container.decode(UUID.self, forKey: .toUserId) {
            toUserId = userIdUUID.uuidString
        } else if let userIdString = try? container.decode(String.self, forKey: .toUserId) {
            toUserId = userIdString
        } else {
            throw DecodingError.keyNotFound(CodingKeys.toUserId, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "to_user_id is required"))
        }
        
        let statusString = try container.decode(String.self, forKey: .status)
        status = FriendRequestStatus(rawValue: statusString.lowercased()) ?? .pending
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct RemoteFriend: Codable {
    let userId: String
    let friendUserId: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case friendUserId = "friend_user_id"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle userId: Supabase returns UUID as string, decode as UUID then convert to String
        if let userIdUUID = try? container.decode(UUID.self, forKey: .userId) {
            userId = userIdUUID.uuidString
        } else if let userIdString = try? container.decode(String.self, forKey: .userId) {
            userId = userIdString
        } else {
            throw DecodingError.keyNotFound(CodingKeys.userId, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "user_id is required"))
        }
        
        // Handle friendUserId: Supabase returns UUID as string, decode as UUID then convert to String
        if let userIdUUID = try? container.decode(UUID.self, forKey: .friendUserId) {
            friendUserId = userIdUUID.uuidString
        } else if let userIdString = try? container.decode(String.self, forKey: .friendUserId) {
            friendUserId = userIdString
        } else {
            throw DecodingError.keyNotFound(CodingKeys.friendUserId, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "friend_user_id is required"))
        }
        
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

// MARK: - Notifications

struct RemoteNotification: Codable {
    let id: UUID
    let userId: String
    let actorUserId: String
    let type: String
    let visitId: UUID?
    let commentId: UUID?
    let createdAt: Date?
    let readAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case actorUserId = "actor_user_id"
        case type
        case visitId = "visit_id"
        case commentId = "comment_id"
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}

