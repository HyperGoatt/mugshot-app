//
//  Cafe.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import CoreLocation

// MARK: - Cafe Aggregate Stats (App-Wide)

/// Aggregated statistics for a cafe from ALL visits across the platform
/// Used to show app-wide data like total visits, average rating, and popular drinks
struct CafeAggregateStats: Codable {
    let totalVisits: Int
    let averageRating: Double
    let topDrinks: [DrinkStat]
    
    /// Individual drink statistic
    struct DrinkStat: Codable, Identifiable, Hashable {
        var id: String { name }
        let name: String        // "Oat Latte", "Matcha", "Brown Sugar Cinnamon Latte", etc.
        let count: Int
        let percentage: Double
        
        enum CodingKeys: String, CodingKey {
            case name = "drink_name"
            case count = "order_count"
            case percentage
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case totalVisits = "total_visits"
        case averageRating = "average_rating"
        case topDrinks = "top_drinks"
    }
    
    /// Empty stats for when no data is available
    static var empty: CafeAggregateStats {
        CafeAggregateStats(totalVisits: 0, averageRating: 0, topDrinks: [])
    }
}

// MARK: - Cafe Model

struct Cafe: Identifiable, Codable {
    let id: UUID
    var supabaseId: UUID?
    var name: String
    var location: CLLocationCoordinate2D?
    var address: String
    var city: String?
    var country: String?
    var isFavorite: Bool
    var wantToTry: Bool
    var averageRating: Double
    var visitCount: Int
    // Apple Maps place reference
    var mapItemURL: String? // URL to open this place in Maps app
    var websiteURL: String? // Website URL if available from Apple Maps
    var applePlaceId: String?
    var placeCategory: String? // Category like "Coffee Shop" from Apple Maps
    
    init(
        id: UUID = UUID(),
        supabaseId: UUID? = nil,
        name: String,
        location: CLLocationCoordinate2D? = nil,
        address: String = "",
        city: String? = nil,
        country: String? = nil,
        isFavorite: Bool = false,
        wantToTry: Bool = false,
        averageRating: Double = 0.0,
        visitCount: Int = 0,
        mapItemURL: String? = nil,
        websiteURL: String? = nil,
        applePlaceId: String? = nil,
        placeCategory: String? = nil
    ) {
        self.id = id
        self.supabaseId = supabaseId
        self.name = name
        self.location = location
        self.address = address
        self.city = city
        self.country = country
        self.isFavorite = isFavorite
        self.wantToTry = wantToTry
        self.averageRating = averageRating
        self.visitCount = visitCount
        self.mapItemURL = mapItemURL
        self.websiteURL = websiteURL
        self.applePlaceId = applePlaceId
        self.placeCategory = placeCategory
    }
}

// Custom Codable for CLLocationCoordinate2D
extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
}

