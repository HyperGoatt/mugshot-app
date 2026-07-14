//
//  SupabaseCafe.swift
//  testMugshot
//

import Foundation
import CoreLocation

struct SupabaseCafeSummary: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let address: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
    let applePlaceId: String?
    let websiteURL: String?
    let identityKey: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case city
        case latitude
        case longitude
        case applePlaceId = "apple_place_id"
        case websiteURL = "website_url"
        case identityKey = "identity_key"
    }

    init(
        id: UUID,
        name: String,
        address: String?,
        city: String?,
        latitude: Double?,
        longitude: Double?,
        applePlaceId: String?,
        websiteURL: String?,
        identityKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.applePlaceId = applePlaceId
        self.websiteURL = websiteURL
        self.identityKey = identityKey
    }

    var displayLocation: String {
        [address, city]
            .compactMap { $0?.remoteTrimmedNonEmpty }
            .joined(separator: " · ")
    }

    func localCafe(
        isFavorite: Bool = false,
        wantToTry: Bool = false,
        averageRating: Double = 0,
        visitCount: Int = 0
    ) -> Cafe {
        Cafe(
            id: id,
            name: name,
            location: {
                guard let latitude, let longitude else {
                    return nil
                }

                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }(),
            address: address?.remoteTrimmedNonEmpty ?? city?.remoteTrimmedNonEmpty ?? "",
            isFavorite: isFavorite,
            wantToTry: wantToTry,
            averageRating: averageRating,
            visitCount: visitCount,
            mapItemURL: applePlaceId,
            websiteURL: websiteURL,
            remoteCafeId: id
        )
    }
}

struct SupabaseCafeStateRow: Identifiable, Decodable, Equatable {
    let id: UUID
    let userId: UUID
    let cafeId: UUID
    let isFavorite: Bool
    let wantToTry: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case cafeId = "cafe_id"
        case isFavorite = "is_favorite"
        case wantToTry = "want_to_try"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RemoteCafeStateSummary: Identifiable, Equatable {
    let state: SupabaseCafeStateRow
    let cafe: SupabaseCafeSummary

    var id: UUID { state.id }

    var localCafe: Cafe {
        cafe.localCafe(
            isFavorite: state.isFavorite,
            wantToTry: state.wantToTry
        )
    }
}
