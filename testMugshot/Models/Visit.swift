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

enum VisitVisibility: String, Codable, CaseIterable, Identifiable {
    case `private` = "Private"
    case friends = "Friends"
    case everyone = "Everyone"

    var id: String { rawValue }

    var breadth: Int {
        switch self {
        case .private: return 0
        case .friends: return 1
        case .everyone: return 2
        }
    }
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
    var context: JournalEntryContext {
        didSet {
            if !context.supportsCafeSession {
                cafeSessionID = nil
                cafeSessionSipOrder = nil
                cafeSessionSipRole = nil
                sipReorderIntention = nil
            }
        }
    }
    var locationName: String?
    var brewMethod: String?
    var equipment: String?
    var brewDetails: BrewDetails
    var drinkAnalysis: DrinkAnalysis?
    var sensorySnapshot: SipSensorySnapshot?
    var photos: [String] // Store image names/paths
    var posterPhotoIndex: Int // Index of the photo to use as poster
    var ratings: [String: Double] // Category name -> rating value
    var ratingCriteria: [SipRatingCriterionSnapshot]
    var overallScore: Double // The user's independent personal enjoyment rating
    var cafeSessionID: UUID?
    var cafeSessionSipOrder: Int?
    var cafeSessionSipRole: CafeSessionSipRole?
    var sipReorderIntention: SipReorderIntention?
    var v3Reflection: V3VisitReflection?
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
        context: JournalEntryContext = .cafe,
        locationName: String? = nil,
        brewMethod: String? = nil,
        equipment: String? = nil,
        brewDetails: BrewDetails = .empty,
        drinkAnalysis: DrinkAnalysis? = nil,
        sensorySnapshot: SipSensorySnapshot? = nil,
        photos: [String] = [],
        posterPhotoIndex: Int = 0,
        ratings: [String: Double] = [:],
        ratingCriteria: [SipRatingCriterionSnapshot] = [],
        overallScore: Double = 0.0,
        cafeSessionID: UUID? = nil,
        cafeSessionSipOrder: Int? = nil,
        cafeSessionSipRole: CafeSessionSipRole? = nil,
        sipReorderIntention: SipReorderIntention? = nil,
        v3Reflection: V3VisitReflection? = nil,
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
        self.context = context
        self.locationName = locationName
        self.brewMethod = brewMethod
        self.equipment = equipment
        self.brewDetails = brewDetails
        self.drinkAnalysis = drinkAnalysis
        self.sensorySnapshot = sensorySnapshot
        self.photos = photos
        self.posterPhotoIndex = posterPhotoIndex
        self.ratings = ratings
        self.ratingCriteria = ratingCriteria
        self.overallScore = overallScore
        self.cafeSessionID = context.supportsCafeSession ? cafeSessionID : nil
        self.cafeSessionSipOrder = context.supportsCafeSession ? cafeSessionSipOrder : nil
        self.cafeSessionSipRole = context.supportsCafeSession ? cafeSessionSipRole : nil
        self.sipReorderIntention = context.supportsCafeSession ? sipReorderIntention : nil
        self.v3Reflection = v3Reflection
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

    /// The journal-facing name always prefers the immutable natural-language
    /// entry. Legacy visits fall back to their existing custom or family label.
    var journalDrinkName: String {
        if let rawText = drinkAnalysis?.rawDrinkName.remoteTrimmedNonEmpty {
            return rawText
        }
        if let customDrinkType = customDrinkType?.remoteTrimmedNonEmpty {
            return customDrinkType
        }
        return drinkType.rawValue
    }
}

// Make Visit Codable with custom implementation
extension Visit: Codable {
    enum CodingKeys: String, CodingKey {
        case id, cafeId, userId, drinkType, customDrinkType, caption, notes, photos
        case context, locationName, brewMethod, equipment, brewDetails, drinkAnalysis, sensorySnapshot
        case posterPhotoIndex, ratings, ratingCriteria, overallScore, visibility, comments, mentions
        case cafeSessionID, cafeSessionSipOrder, cafeSessionSipRole, sipReorderIntention
        case v3Reflection
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
        context = try container.decodeIfPresent(JournalEntryContext.self, forKey: .context) ?? .cafe
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        brewMethod = try container.decodeIfPresent(String.self, forKey: .brewMethod)
        equipment = try container.decodeIfPresent(String.self, forKey: .equipment)
        brewDetails = try container.decodeIfPresent(BrewDetails.self, forKey: .brewDetails) ?? .empty
        drinkAnalysis = try container.decodeIfPresent(DrinkAnalysis.self, forKey: .drinkAnalysis)
        sensorySnapshot = try container.decodeIfPresent(SipSensorySnapshot.self, forKey: .sensorySnapshot)
        photos = try container.decode([String].self, forKey: .photos)
        posterPhotoIndex = try container.decode(Int.self, forKey: .posterPhotoIndex)
        ratings = try container.decode([String: Double].self, forKey: .ratings)
        ratingCriteria = try container.decodeIfPresent([SipRatingCriterionSnapshot].self, forKey: .ratingCriteria) ?? []
        overallScore = try container.decode(Double.self, forKey: .overallScore)
        if context.supportsCafeSession {
            cafeSessionID = try container.decodeIfPresent(UUID.self, forKey: .cafeSessionID)
            cafeSessionSipOrder = try container.decodeIfPresent(Int.self, forKey: .cafeSessionSipOrder)
            cafeSessionSipRole = try container.decodeIfPresent(
                CafeSessionSipRole.self,
                forKey: .cafeSessionSipRole
            )
            sipReorderIntention = try container.decodeIfPresent(
                SipReorderIntention.self,
                forKey: .sipReorderIntention
            )
        } else {
            cafeSessionID = nil
            cafeSessionSipOrder = nil
            cafeSessionSipRole = nil
            sipReorderIntention = nil
        }
        v3Reflection = try container.decodeIfPresent(V3VisitReflection.self, forKey: .v3Reflection)
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
        try container.encode(context, forKey: .context)
        try container.encodeIfPresent(locationName, forKey: .locationName)
        try container.encodeIfPresent(brewMethod, forKey: .brewMethod)
        try container.encodeIfPresent(equipment, forKey: .equipment)
        try container.encode(brewDetails, forKey: .brewDetails)
        try container.encodeIfPresent(drinkAnalysis, forKey: .drinkAnalysis)
        try container.encodeIfPresent(sensorySnapshot, forKey: .sensorySnapshot)
        try container.encode(photos, forKey: .photos)
        try container.encode(posterPhotoIndex, forKey: .posterPhotoIndex)
        try container.encode(ratings, forKey: .ratings)
        try container.encode(ratingCriteria, forKey: .ratingCriteria)
        try container.encode(overallScore, forKey: .overallScore)
        try container.encodeIfPresent(cafeSessionID, forKey: .cafeSessionID)
        try container.encodeIfPresent(cafeSessionSipOrder, forKey: .cafeSessionSipOrder)
        try container.encodeIfPresent(cafeSessionSipRole, forKey: .cafeSessionSipRole)
        try container.encodeIfPresent(sipReorderIntention, forKey: .sipReorderIntention)
        try container.encodeIfPresent(v3Reflection, forKey: .v3Reflection)
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
