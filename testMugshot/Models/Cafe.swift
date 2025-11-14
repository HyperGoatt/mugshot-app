//
//  Cafe.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import CoreLocation

struct Cafe: Identifiable, Codable {
    let id: UUID
    var name: String
    var location: CLLocationCoordinate2D?
    var address: String
    var isFavorite: Bool
    var wantToTry: Bool
    var averageRating: Double
    var visitCount: Int
    // Apple Maps place reference
    var mapItemURL: String? // URL to open this place in Maps app
    var websiteURL: String? // Website URL if available from Apple Maps
    var placeCategory: String? // Category like "Coffee Shop" from Apple Maps
    
    init(
        id: UUID = UUID(),
        name: String,
        location: CLLocationCoordinate2D? = nil,
        address: String = "",
        isFavorite: Bool = false,
        wantToTry: Bool = false,
        averageRating: Double = 0.0,
        visitCount: Int = 0,
        mapItemURL: String? = nil,
        websiteURL: String? = nil,
        placeCategory: String? = nil
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.address = address
        self.isFavorite = isFavorite
        self.wantToTry = wantToTry
        self.averageRating = averageRating
        self.visitCount = visitCount
        self.mapItemURL = mapItemURL
        self.websiteURL = websiteURL
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

