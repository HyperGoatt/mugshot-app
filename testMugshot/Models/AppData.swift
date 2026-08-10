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
    /// Local cafe identifiers that belong to the person's Saved library.
    ///
    /// This projection deliberately excludes incidental Map searches. It is
    /// refreshed from the same personal snapshot that powers Map, and is also
    /// maintained immediately for local visits and save-state changes so the
    /// Saved experience remains truthful while offline.
    var personalLibraryCafeIDs: Set<UUID>
    var visits: [Visit]
    var cafeSessions: [CafeSession]
    var ratingTemplate: RatingTemplate
    
    init(
        currentUser: User? = nil,
        cafes: [Cafe] = [],
        personalLibraryCafeIDs: Set<UUID> = [],
        visits: [Visit] = [],
        cafeSessions: [CafeSession] = [],
        ratingTemplate: RatingTemplate = RatingTemplate()
    ) {
        self.currentUser = currentUser
        self.cafes = cafes
        self.personalLibraryCafeIDs = personalLibraryCafeIDs
        self.visits = visits
        self.cafeSessions = cafeSessions
        self.ratingTemplate = ratingTemplate
    }

    private enum CodingKeys: String, CodingKey {
        case currentUser
        case cafes
        case personalLibraryCafeIDs
        case visits
        case cafeSessions
        case ratingTemplate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentUser = try container.decodeIfPresent(User.self, forKey: .currentUser)
        cafes = try container.decodeIfPresent([Cafe].self, forKey: .cafes) ?? []
        visits = try container.decodeIfPresent([Visit].self, forKey: .visits) ?? []
        personalLibraryCafeIDs = try container.decodeIfPresent(
            Set<UUID>.self,
            forKey: .personalLibraryCafeIDs
        ) ?? Set(cafes.filter { $0.isFavorite || $0.wantToTry }.map(\.id))
            .union(visits.filter { $0.context == .cafe }.map(\.cafeId))
        cafeSessions = try container.decodeIfPresent([CafeSession].self, forKey: .cafeSessions) ?? []
        ratingTemplate = try container.decodeIfPresent(
            RatingTemplate.self,
            forKey: .ratingTemplate
        ) ?? RatingTemplate()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(currentUser, forKey: .currentUser)
        try container.encode(cafes, forKey: .cafes)
        try container.encode(personalLibraryCafeIDs, forKey: .personalLibraryCafeIDs)
        try container.encode(visits, forKey: .visits)
        try container.encode(cafeSessions, forKey: .cafeSessions)
        try container.encode(ratingTemplate, forKey: .ratingTemplate)
    }
}
