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

struct Visit: Identifiable {
    let id: UUID
    var cafeId: UUID
    var userId: UUID
    var createdAt: Date // Renamed from date for clarity
    var drinkType: DrinkType
    var customDrinkType: String? // For "Other" option
    var caption: String
    var notes: String? // Private notes (optional)
    var photos: [String] // Store image names/paths
    var posterPhotoIndex: Int // Index of the photo to use as poster
    var ratings: [String: Double] // Category name -> rating value
    var overallScore: Double // Weighted average
    var visibility: VisitVisibility
    var likeCount: Int // Renamed from likes
    var likedByUserIds: [UUID] // Track which users liked this visit
    var comments: [Comment]
    var mentions: [Mention] // Mentions in caption
    
    init(
        id: UUID = UUID(),
        cafeId: UUID,
        userId: UUID,
        createdAt: Date = Date(),
        drinkType: DrinkType,
        customDrinkType: String? = nil,
        caption: String = "",
        notes: String? = nil,
        photos: [String] = [],
        posterPhotoIndex: Int = 0,
        ratings: [String: Double] = [:],
        overallScore: Double = 0.0,
        visibility: VisitVisibility = .everyone,
        likeCount: Int = 0,
        likedByUserIds: [UUID] = [],
        comments: [Comment] = [],
        mentions: [Mention] = []
    ) {
        self.id = id
        self.cafeId = cafeId
        self.userId = userId
        self.createdAt = createdAt
        self.drinkType = drinkType
        self.customDrinkType = customDrinkType
        self.caption = caption
        self.notes = notes
        self.photos = photos
        self.posterPhotoIndex = posterPhotoIndex
        self.ratings = ratings
        self.overallScore = overallScore
        self.visibility = visibility
        self.likeCount = likeCount
        self.likedByUserIds = likedByUserIds
        self.comments = comments
        self.mentions = mentions
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
        case id, cafeId, userId, drinkType, customDrinkType, caption, notes, photos
        case posterPhotoIndex, ratings, overallScore, visibility, comments, mentions
        case createdAt, date // Support both for backward compatibility
        case likeCount, likes // Support both for backward compatibility
        case likedByUserIds
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
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
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cafeId, forKey: .cafeId)
        try container.encode(userId, forKey: .userId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(drinkType, forKey: .drinkType)
        try container.encodeIfPresent(customDrinkType, forKey: .customDrinkType)
        try container.encode(caption, forKey: .caption)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(photos, forKey: .photos)
        try container.encode(posterPhotoIndex, forKey: .posterPhotoIndex)
        try container.encode(ratings, forKey: .ratings)
        try container.encode(overallScore, forKey: .overallScore)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(likedByUserIds, forKey: .likedByUserIds)
        try container.encode(comments, forKey: .comments)
        try container.encode(mentions, forKey: .mentions)
    }
}

struct Comment: Identifiable, Codable {
    let id: UUID
    var visitId: UUID
    var userId: UUID
    var text: String
    var createdAt: Date
    var mentions: [Mention]
    
    enum CodingKeys: String, CodingKey {
        case id, visitId, userId, text, mentions
        case createdAt, date // Support both for backward compatibility
    }
    
    init(
        id: UUID = UUID(),
        visitId: UUID,
        userId: UUID,
        text: String,
        createdAt: Date = Date(),
        mentions: [Mention] = []
    ) {
        self.id = id
        self.visitId = visitId
        self.userId = userId
        self.text = text
        self.createdAt = createdAt
        self.mentions = mentions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        visitId = try container.decodeIfPresent(UUID.self, forKey: .visitId) ?? UUID() // Default for old data
        userId = try container.decode(UUID.self, forKey: .userId)
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
        try container.encode(visitId, forKey: .visitId)
        try container.encode(userId, forKey: .userId)
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

