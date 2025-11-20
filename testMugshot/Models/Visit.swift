//
//  Visit.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

enum DrinkType: String, Codable, CaseIterable {
    case coffee = "Coffee"
    case matcha = "Matcha"
    case hojicha = "Hojicha"
    case tea = "Tea"
    case chai = "Chai"
    case hotChocolate = "Hot Chocolate"
    case other = "Other"
}

enum VisitVisibility: String, Codable {
    case `private` = "Private"
    case friends = "Friends"
    case everyone = "Everyone"
}

extension VisitVisibility {
    init(remoteValue: String) {
        switch remoteValue.lowercased() {
        case "friends":
            self = .friends
        case "everyone":
            self = .everyone
        default:
            self = .private
        }
    }
    
    var supabaseValue: String {
        rawValue.lowercased()
    }
}

struct Visit: Identifiable {
    let id: UUID
    var supabaseId: UUID?
    var supabaseCafeId: UUID?
    var supabaseUserId: String?
    var cafeId: UUID
    var userId: UUID
    var createdAt: Date // Renamed from date for clarity
    var drinkType: DrinkType
    var customDrinkType: String? // For "Other" option
    var caption: String
    var notes: String? // Private notes (optional)
    var photos: [String] // Store image names/paths
    var posterPhotoIndex: Int // Index of the photo to use as poster
    var posterPhotoURL: String?
    var remotePhotoURLByKey: [String: String]
    var ratings: [String: Double] // Category name -> rating value
    var overallScore: Double // Weighted average
    var visibility: VisitVisibility
    var likeCount: Int // Renamed from likes
    var likedByUserIds: [UUID] // Track which users liked this visit
    var comments: [Comment]
    var mentions: [Mention] // Mentions in caption
    var authorDisplayName: String?
    var authorUsername: String?
    var authorAvatarURL: String?
    
    init(
        id: UUID = UUID(),
        supabaseId: UUID? = nil,
        supabaseCafeId: UUID? = nil,
        supabaseUserId: String? = nil,
        cafeId: UUID,
        userId: UUID,
        createdAt: Date = Date(),
        drinkType: DrinkType,
        customDrinkType: String? = nil,
        caption: String = "",
        notes: String? = nil,
        photos: [String] = [],
        posterPhotoIndex: Int = 0,
        posterPhotoURL: String? = nil,
        remotePhotoURLByKey: [String: String] = [:],
        ratings: [String: Double] = [:],
        overallScore: Double = 0.0,
        visibility: VisitVisibility = .everyone,
        likeCount: Int = 0,
        likedByUserIds: [UUID] = [],
        comments: [Comment] = [],
        mentions: [Mention] = [],
        authorDisplayName: String? = nil,
        authorUsername: String? = nil,
        authorAvatarURL: String? = nil
    ) {
        self.id = id
        self.supabaseId = supabaseId
        self.supabaseCafeId = supabaseCafeId
        self.supabaseUserId = supabaseUserId
        self.cafeId = cafeId
        self.userId = userId
        self.createdAt = createdAt
        self.drinkType = drinkType
        self.customDrinkType = customDrinkType
        self.caption = caption
        self.notes = notes
        self.photos = photos
        self.posterPhotoIndex = posterPhotoIndex
        self.posterPhotoURL = posterPhotoURL
        self.remotePhotoURLByKey = remotePhotoURLByKey
        self.ratings = ratings
        self.overallScore = overallScore
        self.visibility = visibility
        self.likeCount = likeCount
        self.likedByUserIds = likedByUserIds
        self.comments = comments
        self.mentions = mentions
        self.authorDisplayName = authorDisplayName
        self.authorUsername = authorUsername
        self.authorAvatarURL = authorAvatarURL
    }
    
    // Computed property for backward compatibility
    var date: Date {
        get { createdAt }
        set { createdAt = newValue }
    }
    
    // Computed property for comment count
    var commentCount: Int {
        comments.count
    }
    
    // Check if current user liked this visit
    func isLikedBy(userId: UUID) -> Bool {
        likedByUserIds.contains(userId)
    }
    
    // Get the poster image path
    var posterImagePath: String? {
        guard !photos.isEmpty else { return nil }
        if posterPhotoIndex >= 0 && posterPhotoIndex < photos.count {
            return photos[posterPhotoIndex]
        }
        return photos.first
    }
    
    func remoteURL(for photoKey: String) -> String? {
        remotePhotoURLByKey[photoKey]
    }
    
    var authorDisplayNameOrUsername: String {
        authorDisplayName ?? authorUsername ?? "Mugshot Member"
    }
    
    var authorUsernameHandle: String {
        if let username = authorUsername {
            return "@\(username)"
        }
        return "@mugshot"
    }
    
    var authorInitials: String {
        String(authorDisplayNameOrUsername.prefix(1)).uppercased()
    }
}

extension Visit: Hashable {
    static func == (lhs: Visit, rhs: Visit) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Make Visit Codable with custom implementation
extension Visit: Codable {
    enum CodingKeys: String, CodingKey {
        case id, supabaseId, supabaseCafeId, supabaseUserId, cafeId, userId, drinkType, customDrinkType, caption, notes, photos
        case posterPhotoIndex, posterPhotoURL, remotePhotoURLByKey, ratings, overallScore, visibility, comments, mentions
        case createdAt, date // Support both for backward compatibility
        case likeCount, likes // Support both for backward compatibility
        case likedByUserIds
        case authorDisplayName, authorUsername, authorAvatarURL
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        supabaseId = try container.decodeIfPresent(UUID.self, forKey: .supabaseId)
        supabaseCafeId = try container.decodeIfPresent(UUID.self, forKey: .supabaseCafeId)
        supabaseUserId = try container.decodeIfPresent(String.self, forKey: .supabaseUserId)
        cafeId = try container.decode(UUID.self, forKey: .cafeId)
        userId = try container.decode(UUID.self, forKey: .userId)
        
        // Support both createdAt and date for backward compatibility
        if let createdAt = try? container.decode(Date.self, forKey: .createdAt) {
            self.createdAt = createdAt
        } else if let date = try? container.decode(Date.self, forKey: .date) {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }
        
        drinkType = try container.decode(DrinkType.self, forKey: .drinkType)
        customDrinkType = try container.decodeIfPresent(String.self, forKey: .customDrinkType)
        caption = try container.decode(String.self, forKey: .caption)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        photos = try container.decode([String].self, forKey: .photos)
        posterPhotoIndex = try container.decode(Int.self, forKey: .posterPhotoIndex)
        posterPhotoURL = try container.decodeIfPresent(String.self, forKey: .posterPhotoURL)
        remotePhotoURLByKey = try container.decodeIfPresent([String: String].self, forKey: .remotePhotoURLByKey) ?? [:]
        ratings = try container.decode([String: Double].self, forKey: .ratings)
        overallScore = try container.decode(Double.self, forKey: .overallScore)
        visibility = try container.decode(VisitVisibility.self, forKey: .visibility)
        
        // Support both likeCount and likes for backward compatibility
        if let likeCount = try? container.decode(Int.self, forKey: .likeCount) {
            self.likeCount = likeCount
        } else if let likes = try? container.decode(Int.self, forKey: .likes) {
            self.likeCount = likes
        } else {
            self.likeCount = 0
        }
        
        likedByUserIds = try container.decodeIfPresent([UUID].self, forKey: .likedByUserIds) ?? []
        comments = try container.decodeIfPresent([Comment].self, forKey: .comments) ?? []
        mentions = try container.decodeIfPresent([Mention].self, forKey: .mentions) ?? []
        authorDisplayName = try container.decodeIfPresent(String.self, forKey: .authorDisplayName)
        authorUsername = try container.decodeIfPresent(String.self, forKey: .authorUsername)
        authorAvatarURL = try container.decodeIfPresent(String.self, forKey: .authorAvatarURL)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(supabaseId, forKey: .supabaseId)
        try container.encodeIfPresent(supabaseCafeId, forKey: .supabaseCafeId)
        try container.encodeIfPresent(supabaseUserId, forKey: .supabaseUserId)
        try container.encode(cafeId, forKey: .cafeId)
        try container.encode(userId, forKey: .userId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(drinkType, forKey: .drinkType)
        try container.encodeIfPresent(customDrinkType, forKey: .customDrinkType)
        try container.encode(caption, forKey: .caption)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(photos, forKey: .photos)
        try container.encode(posterPhotoIndex, forKey: .posterPhotoIndex)
        try container.encodeIfPresent(posterPhotoURL, forKey: .posterPhotoURL)
        try container.encode(remotePhotoURLByKey, forKey: .remotePhotoURLByKey)
        try container.encode(ratings, forKey: .ratings)
        try container.encode(overallScore, forKey: .overallScore)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(likedByUserIds, forKey: .likedByUserIds)
        try container.encode(comments, forKey: .comments)
        try container.encode(mentions, forKey: .mentions)
        try container.encodeIfPresent(authorDisplayName, forKey: .authorDisplayName)
        try container.encodeIfPresent(authorUsername, forKey: .authorUsername)
        try container.encodeIfPresent(authorAvatarURL, forKey: .authorAvatarURL)
    }
}

struct Comment: Identifiable, Codable {
    let id: UUID
    var supabaseId: UUID?
    var visitId: UUID
    var userId: UUID
    var supabaseUserId: String?
    var text: String
    var createdAt: Date
    var mentions: [Mention]
    
    enum CodingKeys: String, CodingKey {
        case id, supabaseId, visitId, userId, supabaseUserId, text, mentions
        case createdAt, date // Support both for backward compatibility
    }
    
    init(
        id: UUID = UUID(),
        supabaseId: UUID? = nil,
        visitId: UUID,
        userId: UUID,
        supabaseUserId: String? = nil,
        text: String,
        createdAt: Date = Date(),
        mentions: [Mention] = []
    ) {
        self.id = id
        self.supabaseId = supabaseId
        self.visitId = visitId
        self.userId = userId
        self.supabaseUserId = supabaseUserId
        self.text = text
        self.createdAt = createdAt
        self.mentions = mentions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        supabaseId = try container.decodeIfPresent(UUID.self, forKey: .supabaseId)
        visitId = try container.decodeIfPresent(UUID.self, forKey: .visitId) ?? UUID() // Default for old data
        userId = try container.decode(UUID.self, forKey: .userId)
        supabaseUserId = try container.decodeIfPresent(String.self, forKey: .supabaseUserId)
        text = try container.decode(String.self, forKey: .text)
        
        // Support both createdAt and date for backward compatibility
        if let createdAt = try? container.decode(Date.self, forKey: .createdAt) {
            self.createdAt = createdAt
        } else if let date = try? container.decode(Date.self, forKey: .date) {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }
        
        mentions = try container.decodeIfPresent([Mention].self, forKey: .mentions) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(supabaseId, forKey: .supabaseId)
        try container.encode(visitId, forKey: .visitId)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(supabaseUserId, forKey: .supabaseUserId)
        try container.encode(text, forKey: .text)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(mentions, forKey: .mentions)
    }
    
    // Computed property for backward compatibility
    var date: Date {
        get { createdAt }
        set { createdAt = newValue }
    }
}

struct Mention: Identifiable, Codable {
    let id: UUID
    var username: String
    
    init(id: UUID = UUID(), username: String) {
        self.id = id
        self.username = username
    }
}

