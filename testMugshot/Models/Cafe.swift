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
    // Stable Apple Maps place identity. Do not use the website URL as identity.
    var appleMapsPlaceID: String?
    // Legacy Apple/website reference retained for backward-compatible local data.
    var mapItemURL: String?
    var websiteURL: String? // Website URL if available from Apple Maps
    var placeCategory: String? // Category like "Coffee Shop" from Apple Maps
    var remoteCafeId: UUID? // Supabase cafe id once this local cafe is resolved remotely
    var discoveryNote: String?
    var discoverySource: DiscoveryAttributionSource?
    var discoveredAt: Date?
    var discoveryAttributionConsumedAt: Date?
    
    init(
        id: UUID = UUID(),
        name: String,
        location: CLLocationCoordinate2D? = nil,
        address: String = "",
        isFavorite: Bool = false,
        wantToTry: Bool = false,
        averageRating: Double = 0.0,
        visitCount: Int = 0,
        appleMapsPlaceID: String? = nil,
        mapItemURL: String? = nil,
        websiteURL: String? = nil,
        placeCategory: String? = nil,
        remoteCafeId: UUID? = nil,
        discoveryNote: String? = nil,
        discoverySource: DiscoveryAttributionSource? = nil,
        discoveredAt: Date? = nil,
        discoveryAttributionConsumedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.address = address
        self.isFavorite = isFavorite
        self.wantToTry = wantToTry
        self.averageRating = averageRating
        self.visitCount = visitCount
        self.appleMapsPlaceID = appleMapsPlaceID
        self.mapItemURL = mapItemURL
        self.websiteURL = websiteURL
        self.placeCategory = placeCategory
        self.remoteCafeId = remoteCafeId
        self.discoveryNote = discoveryNote
        self.discoverySource = discoverySource
        self.discoveredAt = discoveredAt
        self.discoveryAttributionConsumedAt = discoveryAttributionConsumedAt
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
        case appleMapsPlaceID
        case mapItemURL
        case websiteURL
        case placeCategory
        case remoteCafeId
        case discoveryNote
        case discoverySource
        case discoveredAt
        case discoveryAttributionConsumedAt
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
        appleMapsPlaceID = try container.decodeIfPresent(String.self, forKey: .appleMapsPlaceID)
        mapItemURL = try container.decodeIfPresent(String.self, forKey: .mapItemURL)
        websiteURL = try container.decodeIfPresent(String.self, forKey: .websiteURL)
        placeCategory = try container.decodeIfPresent(String.self, forKey: .placeCategory)
        remoteCafeId = try container.decodeIfPresent(UUID.self, forKey: .remoteCafeId)
        discoveryNote = try container.decodeIfPresent(String.self, forKey: .discoveryNote)
        discoverySource = try container.decodeIfPresent(DiscoveryAttributionSource.self, forKey: .discoverySource)
        discoveredAt = try container.decodeIfPresent(Date.self, forKey: .discoveredAt)
        discoveryAttributionConsumedAt = try container.decodeIfPresent(Date.self, forKey: .discoveryAttributionConsumedAt)
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
        try container.encodeIfPresent(appleMapsPlaceID, forKey: .appleMapsPlaceID)
        try container.encodeIfPresent(mapItemURL, forKey: .mapItemURL)
        try container.encodeIfPresent(websiteURL, forKey: .websiteURL)
        try container.encodeIfPresent(placeCategory, forKey: .placeCategory)
        try container.encodeIfPresent(remoteCafeId, forKey: .remoteCafeId)
        try container.encodeIfPresent(discoveryNote, forKey: .discoveryNote)
        try container.encodeIfPresent(discoverySource, forKey: .discoverySource)
        try container.encodeIfPresent(discoveredAt, forKey: .discoveredAt)
        try container.encodeIfPresent(discoveryAttributionConsumedAt, forKey: .discoveryAttributionConsumedAt)
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
        lhs.appleMapsPlaceID == rhs.appleMapsPlaceID &&
        lhs.mapItemURL == rhs.mapItemURL &&
        lhs.websiteURL == rhs.websiteURL &&
        lhs.placeCategory == rhs.placeCategory &&
        lhs.remoteCafeId == rhs.remoteCafeId &&
        lhs.discoveryNote == rhs.discoveryNote &&
        lhs.discoverySource == rhs.discoverySource &&
        lhs.discoveredAt == rhs.discoveredAt &&
        lhs.discoveryAttributionConsumedAt == rhs.discoveryAttributionConsumedAt
    }
}

enum CafeIdentity {
    static func key(for cafe: Cafe) -> String {
        key(
            name: cafe.name,
            address: cafe.address,
            location: cafe.location,
            applePlaceId: cafe.appleMapsPlaceID ?? cafe.mapItemURL
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

        return "text:\(normalizedName)|\(normalizedAddress(address) ?? "")"
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

    private static func normalizedAddress(_ value: String?) -> String? {
        guard let value else { return nil }
        let tokens = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .sorted()
        return tokens.isEmpty ? nil : tokens.joined(separator: " ")
    }
}
