import CoreLocation
import CryptoKit
import Foundation
import MapKit

enum DiscoveryAttributionSource: String, Codable, CaseIterable, Sendable {
    case forYou = "for_you"
    case appleSearch = "apple_search"
    case publicList = "public_list"
    case shareImport = "share_import"
    case nearbyReminder = "nearby_reminder"
}

enum DiscoveryInteractionKind: String, Codable, Sendable {
    case recommendationOpened = "recommendation_opened"
    case directionsRequested = "directions_requested"
    case cafeSaved = "cafe_saved"
    case listSaved = "list_saved"
    case shareImported = "share_imported"
    case nearbyNudgeOpened = "nearby_nudge_opened"
    case publicListOpened = "public_list_opened"
}

enum DiscoveryAvailability: String, Codable, Sendable {
    case verifiedOpen = "verified_open"
    case verifiedClosed = "verified_closed"
    case unknown
}

enum DiscoveryEvidenceKind: String, Codable, Sendable {
    case friendVisit = "friend_visit"
    case wantToTry = "want_to_try"
    case practicalFit = "practical_fit"
    case drinkMatch = "drink_match"
    case publicMugshot = "public_mugshot"
    case publicList = "public_list"
    case nearby
}

struct DiscoveryEvidence: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let kind: DiscoveryEvidenceKind
    let reason: String
    let strength: Double
    let authorID: UUID?
    let authorName: String?
    let tags: [String]

    init(
        id: UUID = UUID(),
        kind: DiscoveryEvidenceKind,
        reason: String,
        strength: Double = 1,
        authorID: UUID? = nil,
        authorName: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.reason = reason
        self.strength = min(max(strength, 0), 1)
        self.authorID = authorID
        self.authorName = authorName
        self.tags = tags
    }
}

struct DiscoveryPlaceCandidate: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let localID: UUID
    let appleMapsPlaceID: String?
    let remoteCafeID: UUID?
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let phoneNumber: String?
    let websiteURL: String?
    let category: String?
    let availability: DiscoveryAvailability
    let isFavorite: Bool
    let isWantToTry: Bool
    let visitCount: Int
    let discoveryNote: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var cafe: Cafe {
        Cafe(
            id: localID,
            name: name,
            location: coordinate,
            address: address,
            isFavorite: isFavorite,
            wantToTry: isWantToTry,
            visitCount: visitCount,
            appleMapsPlaceID: appleMapsPlaceID,
            websiteURL: websiteURL,
            placeCategory: category,
            remoteCafeId: remoteCafeID,
            discoveryNote: discoveryNote
        )
    }

    var mapItem: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.phoneNumber = phoneNumber
        item.url = websiteURL.flatMap(URL.init(string:))
        return item
    }

    init(
        mapItem: MKMapItem,
        existingCafe: Cafe? = nil,
        availability: DiscoveryAvailability = .unknown
    ) {
        let coordinate = mapItem.placemark.coordinate
        let appleMapsPlaceID = mapItem.identifier?.rawValue.remoteTrimmedNonEmpty
        let name = mapItem.name?.remoteTrimmedNonEmpty ?? "Cafe"
        let address = Self.address(for: mapItem.placemark)
        let stableKey = appleMapsPlaceID
            ?? CafeIdentity.key(
                name: name,
                address: address,
                location: coordinate,
                applePlaceId: nil
            )
        self.id = stableKey
        self.localID = existingCafe?.id ?? Self.deterministicUUID(for: stableKey)
        self.appleMapsPlaceID = appleMapsPlaceID ?? existingCafe?.appleMapsPlaceID
        self.remoteCafeID = existingCafe?.remoteCafeId
        self.name = name
        self.address = address
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.phoneNumber = mapItem.phoneNumber?.remoteTrimmedNonEmpty
        self.websiteURL = mapItem.url?.absoluteString.remoteTrimmedNonEmpty
            ?? existingCafe?.websiteURL
        self.category = mapItem.pointOfInterestCategory?.rawValue
            ?? existingCafe?.placeCategory
        self.availability = availability
        self.isFavorite = existingCafe?.isFavorite ?? false
        self.isWantToTry = existingCafe?.wantToTry ?? false
        self.visitCount = existingCafe?.visitCount ?? 0
        self.discoveryNote = existingCafe?.discoveryNote
    }

    init(cafe: Cafe, availability: DiscoveryAvailability = .unknown) {
        let stableKey = cafe.appleMapsPlaceID ?? CafeIdentity.key(for: cafe)
        id = stableKey
        localID = cafe.id
        appleMapsPlaceID = cafe.appleMapsPlaceID
        remoteCafeID = cafe.remoteCafeId
        name = cafe.name
        address = cafe.address
        latitude = cafe.location?.latitude ?? 0
        longitude = cafe.location?.longitude ?? 0
        phoneNumber = nil
        websiteURL = cafe.websiteURL
        category = cafe.placeCategory
        self.availability = availability
        isFavorite = cafe.isFavorite
        isWantToTry = cafe.wantToTry
        visitCount = cafe.visitCount
        discoveryNote = cafe.discoveryNote
    }

    func applying(localCafe: Cafe) -> DiscoveryPlaceCandidate {
        DiscoveryPlaceCandidate(
            id: id,
            localID: localCafe.id,
            appleMapsPlaceID: appleMapsPlaceID ?? localCafe.appleMapsPlaceID,
            remoteCafeID: localCafe.remoteCafeId ?? remoteCafeID,
            name: name,
            address: address.isEmpty ? localCafe.address : address,
            latitude: latitude,
            longitude: longitude,
            phoneNumber: phoneNumber,
            websiteURL: websiteURL ?? localCafe.websiteURL,
            category: category ?? localCafe.placeCategory,
            availability: availability,
            isFavorite: localCafe.isFavorite,
            isWantToTry: localCafe.wantToTry,
            visitCount: localCafe.visitCount,
            discoveryNote: localCafe.discoveryNote
        )
    }

    func applying(
        remoteCafeID: UUID?,
        isFavorite: Bool,
        isWantToTry: Bool
    ) -> DiscoveryPlaceCandidate {
        DiscoveryPlaceCandidate(
            id: id,
            localID: localID,
            appleMapsPlaceID: appleMapsPlaceID,
            remoteCafeID: remoteCafeID ?? self.remoteCafeID,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            phoneNumber: phoneNumber,
            websiteURL: websiteURL,
            category: category,
            availability: availability,
            isFavorite: self.isFavorite || isFavorite,
            isWantToTry: self.isWantToTry || isWantToTry,
            visitCount: visitCount,
            discoveryNote: discoveryNote
        )
    }

    private init(
        id: String,
        localID: UUID,
        appleMapsPlaceID: String?,
        remoteCafeID: UUID?,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        phoneNumber: String?,
        websiteURL: String?,
        category: String?,
        availability: DiscoveryAvailability,
        isFavorite: Bool,
        isWantToTry: Bool,
        visitCount: Int,
        discoveryNote: String?
    ) {
        self.id = id
        self.localID = localID
        self.appleMapsPlaceID = appleMapsPlaceID
        self.remoteCafeID = remoteCafeID
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.phoneNumber = phoneNumber
        self.websiteURL = websiteURL
        self.category = category
        self.availability = availability
        self.isFavorite = isFavorite
        self.isWantToTry = isWantToTry
        self.visitCount = visitCount
        self.discoveryNote = discoveryNote
    }

    private static func deterministicUUID(for value: String) -> UUID {
        let hex = SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let formatted = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-4\(hex.dropFirst(13).prefix(3))-8\(hex.dropFirst(17).prefix(3))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: formatted) ?? UUID()
    }

    private static func address(for placemark: MKPlacemark) -> String {
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0?.remoteTrimmedNonEmpty }
            .joined(separator: " ")
        return [street.remoteTrimmedNonEmpty, placemark.locality, placemark.administrativeArea]
            .compactMap { $0?.remoteTrimmedNonEmpty }
            .joined(separator: ", ")
    }
}

enum ForYouSection: String, Codable, CaseIterable, Identifiable, Sendable {
    case wantToTryNearby = "want_to_try_nearby"
    case friendsWereHere = "friends_were_here"
    case goodForWork = "good_for_work"
    case quietCafes = "quiet_cafes"
    case strongDrinkMatches = "strong_drink_matches"
    case followedLists = "followed_lists"
    case openNearYou = "open_near_you"
    case nearbyNow = "nearby_now"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wantToTryNearby: "Want to Try nearby"
        case .friendsWereHere: "Friends were here"
        case .goodForWork: "Good for work"
        case .quietCafes: "Quiet cafes"
        case .strongDrinkMatches: "Strong drink matches"
        case .followedLists: "From lists you follow"
        case .openNearYou: "Open near you"
        case .nearbyNow: "Nearby now"
        }
    }
}

struct ForYouRecommendation: Identifiable, Equatable, Sendable {
    let candidate: DiscoveryPlaceCandidate
    let score: Double
    let distanceMeters: CLLocationDistance?
    let reason: String
    let evidence: [DiscoveryEvidence]
    let section: ForYouSection
    let rankingVersion: String

    var id: String { candidate.id }
    var cafe: Cafe { candidate.cafe }
}

struct ForYouRankingConfiguration: Equatable, Sendable {
    static let v1 = ForYouRankingConfiguration(
        version: "for_you_v1",
        distanceWeight: 0.60,
        availabilityWeight: 0.20,
        compatibilityWeight: 0.20,
        friendCompatibilityWeight: 0.35,
        savedCompatibilityWeight: 0.25,
        practicalCompatibilityWeight: 0.20,
        drinkCompatibilityWeight: 0.10,
        publicCompatibilityWeight: 0.10,
        maximumDistanceMeters: 32_000
    )

    let version: String
    let distanceWeight: Double
    let availabilityWeight: Double
    let compatibilityWeight: Double
    let friendCompatibilityWeight: Double
    let savedCompatibilityWeight: Double
    let practicalCompatibilityWeight: Double
    let drinkCompatibilityWeight: Double
    let publicCompatibilityWeight: Double
    let maximumDistanceMeters: CLLocationDistance
}

enum ForYouLearningPolicy {
    static let minimumMugshots = 5

    static func isStillLearning(mugshotCount: Int) -> Bool {
        mugshotCount < minimumMugshots
    }
}

enum ForYouRankingService {
    static func rank(
        candidates: [DiscoveryPlaceCandidate],
        evidenceByCandidateID: [String: [DiscoveryEvidence]],
        userLocation: CLLocation?,
        configuration: ForYouRankingConfiguration = .v1,
        limit: Int = 20
    ) -> [ForYouRecommendation] {
        candidates.map { candidate in
            let evidence = evidenceByCandidateID[candidate.id] ?? []
            let distance = userLocation.map {
                $0.distance(from: CLLocation(latitude: candidate.latitude, longitude: candidate.longitude))
            }
            let distanceScore = distance.map {
                max(0, 1 - min($0, configuration.maximumDistanceMeters) / configuration.maximumDistanceMeters)
            } ?? 0.5
            let compatibility = compatibilityScore(
                candidate: candidate,
                evidence: evidence,
                configuration: configuration
            )

            let score: Double
            switch candidate.availability {
            case .verifiedOpen:
                score = distanceScore * configuration.distanceWeight
                    + configuration.availabilityWeight
                    + compatibility * configuration.compatibilityWeight
            case .verifiedClosed:
                score = distanceScore * configuration.distanceWeight
                    + compatibility * configuration.compatibilityWeight
            case .unknown:
                let knownWeight = configuration.distanceWeight + configuration.compatibilityWeight
                score = knownWeight > 0
                    ? (distanceScore * configuration.distanceWeight
                        + compatibility * configuration.compatibilityWeight) / knownWeight
                    : 0
            }

            return ForYouRecommendation(
                candidate: candidate,
                score: min(max(score, 0), 1),
                distanceMeters: distance,
                reason: recommendationReason(candidate: candidate, evidence: evidence),
                evidence: evidence,
                section: section(candidate: candidate, evidence: evidence),
                rankingVersion: configuration.version
            )
        }
        .sorted {
            if abs($0.score - $1.score) > 0.000_1 { return $0.score > $1.score }
            if ($0.distanceMeters ?? .greatestFiniteMagnitude) != ($1.distanceMeters ?? .greatestFiniteMagnitude) {
                return ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude)
            }
            return $0.candidate.name.localizedCaseInsensitiveCompare($1.candidate.name) == .orderedAscending
        }
        .prefix(max(limit, 0))
        .map { $0 }
    }

    private static func compatibilityScore(
        candidate: DiscoveryPlaceCandidate,
        evidence: [DiscoveryEvidence],
        configuration: ForYouRankingConfiguration
    ) -> Double {
        func strongest(_ kinds: Set<DiscoveryEvidenceKind>) -> Double {
            evidence.filter { kinds.contains($0.kind) }.map(\.strength).max() ?? 0
        }

        let friend = strongest([.friendVisit])
        let saved = max(candidate.isWantToTry ? 1 : 0, strongest([.wantToTry]))
        let practical = strongest([.practicalFit])
        let drink = strongest([.drinkMatch])
        let publicSignal = strongest([.publicMugshot, .publicList])
        return friend * configuration.friendCompatibilityWeight
            + saved * configuration.savedCompatibilityWeight
            + practical * configuration.practicalCompatibilityWeight
            + drink * configuration.drinkCompatibilityWeight
            + publicSignal * configuration.publicCompatibilityWeight
    }

    private static func recommendationReason(
        candidate: DiscoveryPlaceCandidate,
        evidence: [DiscoveryEvidence]
    ) -> String {
        let priority: [DiscoveryEvidenceKind] = [
            .friendVisit, .wantToTry, .practicalFit, .drinkMatch, .publicList, .publicMugshot
        ]
        for kind in priority {
            if let match = evidence
                .filter({ $0.kind == kind })
                .max(by: { $0.strength < $1.strength }) {
                return match.reason
            }
        }
        if candidate.isWantToTry { return "Saved in your Want to Try" }
        return "Close to you"
    }

    private static func section(
        candidate: DiscoveryPlaceCandidate,
        evidence: [DiscoveryEvidence]
    ) -> ForYouSection {
        if candidate.isWantToTry || evidence.contains(where: { $0.kind == .wantToTry }) {
            return .wantToTryNearby
        }
        if evidence.contains(where: { $0.kind == .friendVisit }) { return .friendsWereHere }
        if evidence.contains(where: {
            $0.kind == .practicalFit && $0.tags.contains("work_study")
        }) { return .goodForWork }
        if evidence.contains(where: {
            $0.kind == .practicalFit && $0.tags.contains("quiet")
        }) { return .quietCafes }
        if evidence.contains(where: { $0.kind == .drinkMatch }) { return .strongDrinkMatches }
        if evidence.contains(where: { $0.kind == .publicList }) { return .followedLists }
        return candidate.availability == .verifiedOpen ? .openNearYou : .nearbyNow
    }
}
