//
//  Cafe.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import CoreLocation

struct Cafe: Identifiable, Codable, Equatable {
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
    var remoteCafeId: UUID? // Supabase cafe id once this local cafe is resolved remotely
    
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
        placeCategory: String? = nil,
        remoteCafeId: UUID? = nil
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
        self.remoteCafeId = remoteCafeId
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case location
        case address
        case isFavorite
        case wantToTry
        case averageRating
        case visitCount
        case mapItemURL
        case websiteURL
        case placeCategory
        case remoteCafeId
    }

    private struct StoredCoordinate: Codable {
        let latitude: CLLocationDegrees
        let longitude: CLLocationDegrees
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let coordinate = try container.decodeIfPresent(StoredCoordinate.self, forKey: .location) {
            location = CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        } else {
            location = nil
        }
        address = try container.decode(String.self, forKey: .address)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        wantToTry = try container.decode(Bool.self, forKey: .wantToTry)
        averageRating = try container.decode(Double.self, forKey: .averageRating)
        visitCount = try container.decode(Int.self, forKey: .visitCount)
        mapItemURL = try container.decodeIfPresent(String.self, forKey: .mapItemURL)
        websiteURL = try container.decodeIfPresent(String.self, forKey: .websiteURL)
        placeCategory = try container.decodeIfPresent(String.self, forKey: .placeCategory)
        remoteCafeId = try container.decodeIfPresent(UUID.self, forKey: .remoteCafeId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(
            location.map { StoredCoordinate(latitude: $0.latitude, longitude: $0.longitude) },
            forKey: .location
        )
        try container.encode(address, forKey: .address)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(wantToTry, forKey: .wantToTry)
        try container.encode(averageRating, forKey: .averageRating)
        try container.encode(visitCount, forKey: .visitCount)
        try container.encodeIfPresent(mapItemURL, forKey: .mapItemURL)
        try container.encodeIfPresent(websiteURL, forKey: .websiteURL)
        try container.encodeIfPresent(placeCategory, forKey: .placeCategory)
        try container.encodeIfPresent(remoteCafeId, forKey: .remoteCafeId)
    }

    static func == (lhs: Cafe, rhs: Cafe) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.location?.latitude == rhs.location?.latitude &&
        lhs.location?.longitude == rhs.location?.longitude &&
        lhs.address == rhs.address &&
        lhs.isFavorite == rhs.isFavorite &&
        lhs.wantToTry == rhs.wantToTry &&
        lhs.averageRating == rhs.averageRating &&
        lhs.visitCount == rhs.visitCount &&
        lhs.mapItemURL == rhs.mapItemURL &&
        lhs.websiteURL == rhs.websiteURL &&
        lhs.placeCategory == rhs.placeCategory &&
        lhs.remoteCafeId == rhs.remoteCafeId
    }
}

enum CafeIdentity {
    static func key(for cafe: Cafe) -> String {
        key(
            name: cafe.name,
            address: cafe.address,
            location: cafe.location,
            applePlaceId: cafe.mapItemURL
        )
    }

    static func key(
        name: String,
        address: String?,
        location: CLLocationCoordinate2D?,
        applePlaceId: String?
    ) -> String {
        if let applePlaceId = normalized(applePlaceId), !applePlaceId.isEmpty {
            return "apple:\(applePlaceId)"
        }

        let normalizedName = normalized(name) ?? "cafe"
        if let location {
            return String(
                format: "geo:%@|%.5f|%.5f",
                locale: Locale(identifier: "en_US_POSIX"),
                normalizedName,
                location.latitude,
                location.longitude
            )
        }

        return "text:\(normalizedName)|\(normalized(address) ?? "")"
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
        return collapsed.isEmpty ? nil : collapsed
    }
}
