#if DEBUG
import Foundation
import CoreLocation
import UIKit

/// Deterministic, local-only launch states used to audit the production Saved
/// and Map surfaces. These scenarios never authenticate or invoke a remote
/// service; the launch argument is ignored in Release builds.
enum SavedAuditScenario: String {
    case populated
    case empty
    case loadingEmpty = "loading-empty"
    case loadingCached = "loading-cached"
    case offlineCached = "offline-cached"
    case fatalError = "fatal-error"
    case detailLoading = "detail-loading"
    case detailError = "detail-error"
    case saveFailure = "save-failure"

    static func resolve(arguments: [String]) -> SavedAuditScenario? {
        let prefix = "--saved-audit-scenario="
        guard let value = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return SavedAuditScenario(rawValue: String(value.dropFirst(prefix.count)))
    }

    var usesPopulatedFixture: Bool {
        switch self {
        case .empty, .loadingEmpty, .fatalError:
            return false
        case .populated, .loadingCached, .offlineCached, .detailLoading, .detailError, .saveFailure:
            return true
        }
    }

    var showsForcedSavedStatus: Bool {
        switch self {
        case .loadingEmpty, .loadingCached, .offlineCached, .fatalError:
            return true
        case .populated, .empty, .detailLoading, .detailError, .saveFailure:
            return false
        }
    }

    var isForcedLoading: Bool {
        self == .loadingEmpty || self == .loadingCached
    }

    var forcedSavedErrorMessage: String? {
        switch self {
        case .offlineCached:
            return "You appear to be offline. Showing the cafes already on this device."
        case .fatalError:
            return "Mugshot couldn’t load your saved cafes."
        default:
            return nil
        }
    }
}

enum SavedAuditFixtures {
    static let userID = UUID(uuidString: "00000000-0000-4000-8010-000000000001")!
    static let primaryCafeID = UUID(uuidString: "00000000-0000-4000-8010-000000000101")!
    static let photoKey = "saved-audit-quiet-cafe-corner"
    static let secondaryPhotoKey = "saved-audit-creamy-latte"
    static let brokenPhotoKey = "saved-audit-intentionally-missing-photo"

    static func appData(for scenario: SavedAuditScenario, signedOut: Bool) -> AppData {
        let populated = scenario.usesPopulatedFixture
        let fixtureCafes = populated ? cafes : []
        return AppData(
            currentUser: signedOut ? nil : User(
                id: userID,
                username: "saved_audit",
                displayName: "Saved Audit",
                location: "San Francisco, CA"
            ),
            cafes: fixtureCafes,
            personalLibraryCafeIDs: Set(fixtureCafes.map(\.id)),
            visits: populated ? visits : [],
            ratingTemplate: RatingTemplate()
        )
    }

    static func seedLocalPhotos() {
        if let image = UIImage(named: "V3QuietCafeCorner") {
            try? PhotoCache.shared.storeDurably(image, forKey: photoKey)
        }
        if let image = UIImage(named: "V3CreamyLatte") {
            try? PhotoCache.shared.storeDurably(image, forKey: secondaryPhotoKey)
        }
    }

    private static var cafes: [Cafe] {
        [
            Cafe(
                id: primaryCafeID,
                name: "Harborlight Coffee Roasters",
                location: CLLocationCoordinate2D(latitude: 37.7955, longitude: -122.3937),
                address: "12 Embarcadero Center, San Francisco, CA",
                isFavorite: true,
                averageRating: 4.8,
                visitCount: 4,
                websiteURL: "https://example.com/harborlight",
                placeCategory: "Coffee Shop"
            ),
            Cafe(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000102")!,
                name: "Juniper & Stone",
                location: CLLocationCoordinate2D(latitude: 37.7764, longitude: -122.4242),
                address: "401 Grove Street, San Francisco, CA",
                isFavorite: true,
                wantToTry: true,
                placeCategory: "Cafe"
            ),
            Cafe(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000103")!,
                name: "Paper Moon Espresso",
                location: CLLocationCoordinate2D(latitude: 37.7599, longitude: -122.4148),
                address: "88 Valencia Street, San Francisco, CA",
                isFavorite: true,
                wantToTry: false,
                averageRating: 4.2,
                visitCount: 2,
                placeCategory: "Coffee Shop"
            ),
            Cafe(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000104")!,
                name: "Little Palm Cafe",
                location: CLLocationCoordinate2D(latitude: 37.7609, longitude: -122.4350),
                address: "190 Castro Street, San Francisco, CA",
                averageRating: 3.7,
                visitCount: 1,
                placeCategory: "Cafe"
            ),
            Cafe(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000105")!,
                name: "The Archive Coffee Bar Inside the Museum of Contemporary Craft",
                location: CLLocationCoordinate2D(latitude: 37.7890, longitude: -122.4010),
                address: "150 Market Street, Mezzanine Level, San Francisco, California 94105",
                isFavorite: true,
                averageRating: 4.5,
                visitCount: 3,
                placeCategory: "Coffee Shop"
            ),
            Cafe(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000106")!,
                name: "Untitled Corner",
                address: "",
                isFavorite: true
            ),
            Cafe(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000107")!,
                name: "Cedar Room",
                address: "Location unavailable",
                wantToTry: true,
                placeCategory: "Cafe"
            ),
            Cafe(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000108")!,
                name: "Blue Hour Coffee",
                location: CLLocationCoordinate2D(latitude: 37.8060, longitude: -122.4103),
                address: "75 Grant Avenue, San Francisco, CA",
                averageRating: 4.0,
                visitCount: 1,
                placeCategory: "Coffee Shop"
            ),
            Cafe(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000109")!,
                name: "Sunward Cafe",
                location: CLLocationCoordinate2D(latitude: 37.7812, longitude: -122.3972),
                address: "9 Brannan Street, San Francisco, CA",
                isFavorite: true,
                averageRating: 3.9,
                visitCount: 1,
                placeCategory: "Cafe"
            )
        ]
    }

    private static var visits: [Visit] {
        let day: TimeInterval = 86_400
        let anchor = Date(timeIntervalSince1970: 1_785_715_200) // 2026-08-01 UTC
        return [
            Visit(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000201")!,
                cafeId: primaryCafeID,
                userId: userID,
                createdAt: anchor,
                drinkType: .coffee,
                customDrinkType: "Honey oat cortado",
                caption: "Bright, balanced, and worth the walk.",
                photos: [photoKey],
                overallScore: 4.8,
                visibility: .private
            ),
            Visit(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000202")!,
                cafeId: primaryCafeID,
                userId: userID,
                createdAt: anchor - (14 * day),
                drinkType: .matcha,
                caption: "Silky with a grassy finish.",
                overallScore: 4.6,
                visibility: .friends
            ),
            Visit(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000203")!,
                cafeId: primaryCafeID,
                userId: userID,
                createdAt: anchor - (42 * day),
                drinkType: .coffee,
                customDrinkType: "Espresso tonic",
                overallScore: 4.9,
                visibility: .everyone
            ),
            Visit(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000204")!,
                cafeId: UUID(uuidString: "00000000-0000-4000-8010-000000000103")!,
                userId: userID,
                createdAt: anchor - day,
                drinkType: .coffee,
                customDrinkType: "Flat white",
                photos: [secondaryPhotoKey],
                overallScore: 4.2,
                visibility: .friends
            ),
            Visit(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000205")!,
                cafeId: UUID(uuidString: "00000000-0000-4000-8010-000000000104")!,
                userId: userID,
                createdAt: anchor - (7 * day),
                drinkType: .chai,
                overallScore: 3.7,
                visibility: .private
            ),
            Visit(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000206")!,
                cafeId: UUID(uuidString: "00000000-0000-4000-8010-000000000105")!,
                userId: userID,
                createdAt: anchor - (21 * day),
                drinkType: .tea,
                overallScore: 4.5,
                visibility: .private
            ),
            Visit(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000207")!,
                cafeId: UUID(uuidString: "00000000-0000-4000-8010-000000000108")!,
                userId: userID,
                createdAt: anchor - (30 * day),
                drinkType: .hojicha,
                overallScore: 4.0,
                visibility: .friends
            ),
            Visit(
                id: UUID(uuidString: "00000000-0000-4000-8010-000000000208")!,
                cafeId: UUID(uuidString: "00000000-0000-4000-8010-000000000109")!,
                userId: userID,
                createdAt: anchor - (35 * day),
                drinkType: .hotChocolate,
                photos: [brokenPhotoKey],
                overallScore: 3.9,
                visibility: .private
            )
        ]
    }
}
#endif
