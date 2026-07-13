//
//  testMugshotTests.swift
//  testMugshotTests
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import CoreLocation
import MapKit
import UIKit
import Testing
@testable import testMugshot

struct testMugshotTests {

    @Test func cafeIdentityIsStableAcrossAddressFormattingAndSeparatesNeighbors() {
        let location = CLLocationCoordinate2D(latitude: 32.791641, longitude: -79.941289)
        let first = Cafe(name: "Babas on Cannon", location: location, address: "11 Cannon St")
        let reformatted = Cafe(name: "  BABAS   ON CANNON ", location: location, address: "Cannon St, 11")
        let neighbor = Cafe(name: "Another Cafe", location: location, address: "11 Cannon St")

        #expect(CafeIdentity.key(for: first) == CafeIdentity.key(for: reformatted))
        #expect(CafeIdentity.key(for: first) != CafeIdentity.key(for: neighbor))
    }

    @Test func localCafeReconciliationMergesStateAndReassignsVisits() {
        let remoteId = UUID()
        let first = Cafe(
            name: "Needle & Bean",
            location: CLLocationCoordinate2D(latitude: 40.37590, longitude: -80.03693),
            address: "320 Castle Shannon Blvd",
            isFavorite: true
        )
        let duplicate = Cafe(
            name: "Needle & Bean",
            location: CLLocationCoordinate2D(latitude: 40.37590, longitude: -80.03693),
            address: "Castle Shannon Blvd, 320",
            wantToTry: true,
            remoteCafeId: remoteId
        )
        let visit = Visit(
            cafeId: first.id,
            userId: UUID(),
            drinkType: .coffee,
            overallScore: 4.5
        )

        let result = CafeIdentityReconciler.reconcile(
            AppData(cafes: [first, duplicate], visits: [visit])
        )

        #expect(result.mergedCafeCount == 1)
        #expect(result.appData.cafes.count == 1)
        #expect(result.appData.cafes[0].isFavorite)
        #expect(result.appData.cafes[0].wantToTry)
        #expect(result.appData.cafes[0].remoteCafeId == remoteId)
        #expect(result.appData.visits[0].cafeId == result.appData.cafes[0].id)
        #expect(result.appData.cafes[0].averageRating == 4.5)
    }

    @Test func pendingVisitSubmissionPersistsPhotosAndAccountScope() throws {
        let suite = "PendingVisitSubmissionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PendingVisitSubmissionStore(defaults: defaults, baseDirectory: directory)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let userId = UUID()
        let record = try store.prepare(
            userId: userId,
            cafe: Cafe(name: "Durable Cafe"),
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Latte",
            caption: "Durable draft",
            notes: nil,
            visibility: .friends,
            ratings: ["Taste": 4],
            ratingTemplate: RatingTemplate(),
            images: [image],
            posterPhotoIndex: 0
        )

        let restoredStore = PendingVisitSubmissionStore(defaults: defaults, baseDirectory: directory)
        let restored = try #require(restoredStore.load(userId: userId))
        #expect(restored.id == record.id)
        #expect(restoredStore.load(userId: UUID()) == nil)
        #expect(try restoredStore.loadImages(for: restored).count == 1)
        #expect(restored.objectPaths.count == 1)

        restoredStore.remove(restored)
        #expect(restoredStore.load(userId: userId) == nil)
    }

    @Test func visitPhotoObjectPathAndCleanupQueueAreDeterministic() throws {
        let path = "abc/visit/photo one.jpg"
        let url = "https://example.supabase.co/storage/v1/object/public/visit-photos/abc/visit/photo%20one.jpg"
        #expect(VisitPhotoObjectPath.path(fromPublicURL: url) == path)

        let suite = "VisitMediaCleanupTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = VisitMediaCleanupStore(defaults: defaults)
        let userId = UUID()
        store.enqueue([path, path, "second.jpg"], userId: userId)
        #expect(store.pendingPaths(userId: userId) == [path, "second.jpg"])
        store.remove([path], userId: userId)
        #expect(store.pendingPaths(userId: userId) == ["second.jpg"])
        #expect(store.pendingPaths(userId: UUID()).isEmpty)
    }

    @MainActor
    @Test func mapSearchCorrectsCommonPlaceTyposWithoutChangingGoodQueries() {
        #expect(MapSearchService.correctedSearchQuery("cofee shop") == "coffee shop")
        #expect(MapSearchService.correctedSearchQuery("expresso bar") == "espresso bar")
        #expect(MapSearchService.correctedSearchQuery("Huriyali Gardens") == "Huriyali Gardens")
    }

    @MainActor
    @Test func mapSearchRankingKeepsTextRelevanceAheadOfRawDistance() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 32.78, longitude: -79.93),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        let exactMatch = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 32.81, longitude: -79.93)
        ))
        exactMatch.name = "The Daily"
        let nearbyWeakMatch = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 32.7801, longitude: -79.9301)
        ))
        nearbyWeakMatch.name = "Daily Dose Supplements"

        let ranked = MapSearchService.ranked(
            [nearbyWeakMatch, exactMatch],
            query: "The Daily",
            region: region
        )

        #expect(ranked.first?.name == "The Daily")
    }

    @MainActor
    @Test func mapSearchRejectsUnrelatedAndImplausiblyDistantFallbacks() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 32.78, longitude: -79.93),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        let nearbyMatch = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 32.78, longitude: -79.93)
        ))
        nearbyMatch.name = "Babas on Cannon"
        let nearbyUnrelated = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 32.781, longitude: -79.931)
        ))
        nearbyUnrelated.name = "Poke Tea House"
        let distantPartial = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 44.54, longitude: 18.67)
        ))
        distantPartial.name = "Bab"

        let filtered = MapSearchService.credibleResults(
            [nearbyUnrelated, distantPartial, nearbyMatch],
            query: "Baba",
            region: region
        )

        #expect(filtered.map(\.name) == ["Babas on Cannon"])
    }

    @MainActor
    @Test func mapSearchKeepsNearbyCategoryDiscoveryResults() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 32.78, longitude: -79.93),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        let cafe = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 32.79, longitude: -79.94)
        ))
        cafe.name = "The Daily"

        let filtered = MapSearchService.credibleResults([cafe], query: "coffee", region: region)

        #expect(filtered.first?.name == "The Daily")
    }

    @Test func mapPinsMergeCompletedLogsWithActiveSavedCafes() {
        let userId = UUID()
        let loggedCafe = SupabaseCafeSummary(
            id: UUID(),
            name: "Logged Cafe",
            address: "1 Bean St",
            city: "Charleston",
            latitude: 32.78,
            longitude: -79.93,
            applePlaceId: nil,
            websiteURL: nil
        )
        let savedCafe = SupabaseCafeSummary(
            id: UUID(),
            name: "Saved Cafe",
            address: "2 Bean St",
            city: "Charleston",
            latitude: 32.79,
            longitude: -79.94,
            applePlaceId: nil,
            websiteURL: nil
        )
        let loggedVisits = [4.0, 5.0].map { score in
            RemoteVisitSummary(
                visit: SupabaseVisitRow(
                    id: UUID(),
                    userId: userId,
                    cafeId: loggedCafe.id,
                    drinkType: "Coffee",
                    drinkTypeCustom: nil,
                    drinkSubtype: "Latte",
                    caption: "",
                    notes: nil,
                    visibility: "private",
                    ratings: [:],
                    overallScore: score,
                    posterPhotoURL: nil,
                    contextType: "cafe",
                    locationName: nil,
                    cityState: nil,
                    brewMethod: nil,
                    createdAt: "2026-07-01T12:34:56Z"
                ),
                cafe: loggedCafe
            )
        }
        let savedState = RemoteCafeStateSummary(
            state: SupabaseCafeStateRow(
                id: UUID(),
                userId: userId,
                cafeId: savedCafe.id,
                isFavorite: true,
                wantToTry: false,
                createdAt: nil,
                updatedAt: nil
            ),
            cafe: savedCafe
        )
        let inactiveCafe = SupabaseCafeSummary(
            id: UUID(),
            name: "Inactive Cafe",
            address: "3 Bean St",
            city: "Charleston",
            latitude: 32.80,
            longitude: -79.95,
            applePlaceId: nil,
            websiteURL: nil
        )
        let inactiveState = RemoteCafeStateSummary(
            state: SupabaseCafeStateRow(
                id: UUID(),
                userId: userId,
                cafeId: inactiveCafe.id,
                isFavorite: false,
                wantToTry: false,
                createdAt: nil,
                updatedAt: nil
            ),
            cafe: inactiveCafe
        )

        let snapshot = RemoteMapPinSnapshot.make(
            visits: loggedVisits,
            cafeStates: [savedState, inactiveState]
        )

        #expect(snapshot.pins.count == 2)
        #expect(snapshot.pins.first(where: { $0.cafe.id == loggedCafe.id })?.visitCount == 2)
        #expect(snapshot.pins.first(where: { $0.cafe.id == loggedCafe.id })?.averageScore == 4.5)
        #expect(snapshot.pins.first(where: { $0.cafe.id == savedCafe.id })?.isFavorite == true)
        #expect(snapshot.pins.first(where: { $0.cafe.id == savedCafe.id })?.visitCount == 0)
        #expect(snapshot.pins.contains(where: { $0.cafe.id == inactiveCafe.id }) == false)
    }

    @Test func mapPinsDoNotRenderUnratedLegacyVisitsAsCafeMarkers() {
        let userId = UUID()
        let cafe = SupabaseCafeSummary(
            id: UUID(),
            name: "Unrated Legacy Cafe",
            address: "4 Bean St",
            city: "Charleston",
            latitude: 32.78,
            longitude: -79.93,
            applePlaceId: nil,
            websiteURL: nil
        )
        let visit = RemoteVisitSummary(
            visit: SupabaseVisitRow(
                id: UUID(),
                userId: userId,
                cafeId: cafe.id,
                drinkType: "Coffee",
                drinkTypeCustom: nil,
                drinkSubtype: nil,
                caption: "",
                notes: nil,
                visibility: "private",
                ratings: [:],
                overallScore: 0,
                posterPhotoURL: nil,
                contextType: "cafe",
                locationName: nil,
                cityState: nil,
                brewMethod: nil,
                createdAt: "2026-07-01T12:34:56Z"
            ),
            cafe: cafe
        )

        let snapshot = RemoteMapPinSnapshot.make(visits: [visit], cafeStates: [])

        #expect(snapshot.pins.isEmpty)
    }

    @Test func mapKitCategoriesNeverSurfaceRawDeveloperValues() {
        let cafe = Cafe(name: "Nook", placeCategory: "MKPOICategoryCafe")

        #expect(cafe.consumerPlaceCategory == "Cafe")
        #expect(MugshotCafeCategory.display("MKPOICategoryBakery") == "Bakery")
        #expect(MugshotCafeCategory.display(nil) == nil)
    }

    @Test func supabaseConfigurationLoadsClientSafeValues() throws {
        let configuration = try SupabaseConfiguration.load(
            environment: [
                "MUGSHOT_SUPABASE_URL": "https://example.supabase.co",
                "MUGSHOT_SUPABASE_PUBLISHABLE_KEY": "sb_publishable_test_key"
            ]
        )

        #expect(configuration.url.absoluteString == "https://example.supabase.co")
        #expect(configuration.publishableKey == "sb_publishable_test_key")
    }

    @Test func supabaseConfigurationRejectsSecretKeys() {
        var thrownError: SupabaseConfigurationError?
        let rejectedClientKey = "sb_" + "secret_not_for_clients"

        do {
            _ = try SupabaseConfiguration.load(
                environment: [
                    "MUGSHOT_SUPABASE_URL": "https://example.supabase.co",
                    "MUGSHOT_SUPABASE_PUBLISHABLE_KEY": rejectedClientKey
                ]
            )
        } catch let error as SupabaseConfigurationError {
            thrownError = error
        } catch {
            thrownError = nil
        }

        #expect(thrownError == .secretKeyRejected)
    }

    @Test func supabaseProfileMapsToLocalUser() {
        let id = UUID()
        let profile = SupabaseUserProfile(
            id: id,
            displayName: "Joe",
            username: "joe",
            bio: "Coffee notes",
            location: "CHS",
            favoriteDrink: "Espresso",
            instagramHandle: "rosso5",
            avatarURL: "https://example.com/avatar.jpg",
            bannerURL: nil,
            websiteURL: "https://mugshotapp.co"
        )

        let user = profile.localUser

        #expect(user.id == id)
        #expect(user.username == "joe")
        #expect(user.displayName == "Joe")
        #expect(user.location == "CHS")
        #expect(user.bio == "Coffee notes")
        #expect(user.avatarImageName == "https://example.com/avatar.jpg")
    }

    @Test func profileUpdateEncodesNullForClearedOptionalFields() throws {
        let update = SupabaseUserProfileUpdate(
            displayName: "Joe",
            username: "joe",
            bio: nil,
            location: "CHS",
            favoriteDrink: nil,
            instagramHandle: "rosso5",
            websiteURL: nil
        )

        let data = try JSONEncoder().encode(update)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["display_name"] as? String == "Joe")
        #expect(object["username"] as? String == "joe")
        #expect(object["location"] as? String == "CHS")
        #expect(object["instagram_handle"] as? String == "rosso5")
        #expect(object["bio"] is NSNull)
        #expect(object["favorite_drink"] is NSNull)
        #expect(object["website_url"] is NSNull)
    }

    @Test func supabaseVisitRowMapsDisplayValues() {
        let row = SupabaseVisitRow(
            id: UUID(),
            userId: UUID(),
            cafeId: nil,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Cortado",
            caption: "Tiny cup, huge day.",
            notes: nil,
            visibility: "everyone",
            ratings: ["Taste": 5],
            overallScore: 4.8,
            posterPhotoURL: nil,
            contextType: "Cafe",
            locationName: nil,
            cityState: nil,
            brewMethod: nil,
            createdAt: "2026-07-01T12:34:56.789Z"
        )

        #expect(row.drinkDisplayName == "Cortado")
        #expect(row.drinkCategoryDisplayName == "Coffee")
        #expect(row.backendVisibilityLabel == "Public")
        #expect(row.createdAtDate > Date(timeIntervalSince1970: 0))
    }

    @Test func remoteVisitSummaryUsesCraftLocationWhenCafeIsMissing() {
        let row = SupabaseVisitRow(
            id: UUID(),
            userId: UUID(),
            cafeId: nil,
            drinkType: "Tea",
            drinkTypeCustom: nil,
            drinkSubtype: "Jasmine",
            caption: "",
            notes: nil,
            visibility: "private",
            ratings: [:],
            overallScore: 4,
            posterPhotoURL: nil,
            contextType: "home",
            locationName: "Kitchen counter",
            cityState: "Charleston, SC",
            brewMethod: nil,
            createdAt: "2026-07-01T12:34:56Z"
        )

        let summary = RemoteVisitSummary(visit: row, cafe: nil)

        #expect(summary.locationTitle == "Kitchen counter")
        #expect(summary.locationSubtitle == "Charleston, SC")
        #expect(row.backendVisibilityLabel == "Private")
    }

    @Test func remoteVisitDetailOrdersStoredPhotosAndFallsBackToPoster() {
        let row = SupabaseVisitRow(
            id: UUID(),
            userId: UUID(),
            cafeId: nil,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Latte",
            caption: "",
            notes: "Owner note",
            visibility: "friends",
            ratings: [:],
            overallScore: 4.5,
            posterPhotoURL: "https://example.com/poster.jpg",
            contextType: "Cafe",
            locationName: nil,
            cityState: nil,
            brewMethod: nil,
            createdAt: "2026-07-01T12:34:56Z"
        )
        let summary = RemoteVisitSummary(visit: row, cafe: nil)
        let detail = RemoteVisitDetail(
            summary: summary,
            photos: [
                SupabaseVisitPhotoRow(
                    id: UUID(),
                    visitId: row.id,
                    photoURL: "https://example.com/second.jpg",
                    sortOrder: 2,
                    createdAt: "2026-07-01T12:36:56Z"
                ),
                SupabaseVisitPhotoRow(
                    id: UUID(),
                    visitId: row.id,
                    photoURL: "https://example.com/first.jpg",
                    sortOrder: 1,
                    createdAt: "2026-07-01T12:35:56Z"
                )
            ],
            comments: [],
            likeCount: 3,
            currentUserHasLiked: true
        )

        #expect(detail.photoURLs == [
            "https://example.com/poster.jpg",
            "https://example.com/first.jpg",
            "https://example.com/second.jpg"
        ])
        #expect(detail.commentCount == 0)
        #expect(detail.summary.visit.trimmedNotes == "Owner note")
    }

    @Test func visitPhotoUploadPlanBuildsLowercaseStoragePaths() throws {
        let userId = try #require(UUID(uuidString: "71500CA8-A989-4416-B716-C160325C79BA"))
        let visitId = try #require(UUID(uuidString: "4B37B6E8-62C3-4016-8163-28CDB804E792"))
        let objectId = try #require(UUID(uuidString: "A0B1C2D3-E4F5-4678-9123-ABCDEF123456"))

        let path = VisitPhotoUploadPlan.objectPath(
            userId: userId,
            visitId: visitId,
            objectId: objectId
        )

        #expect(path == "71500ca8-a989-4416-b716-c160325c79ba/4b37b6e8-62c3-4016-8163-28cdb804e792/a0b1c2d3-e4f5-4678-9123-abcdef123456.jpg")
        #expect(path == path.lowercased())
    }

    @Test func visitPhotoUploadPlanCapsObjectPathsAtRemoteLimit() {
        let userId = UUID()
        let visitId = UUID()
        let objectIds = (0..<12).map { _ in UUID() }

        let paths = VisitPhotoUploadPlan.objectPaths(
            userId: userId,
            visitId: visitId,
            objectIds: objectIds
        )

        #expect(paths.count == VisitPhotoUploadPlan.maxPhotoCount)
        #expect(paths.last == VisitPhotoUploadPlan.objectPath(
            userId: userId,
            visitId: visitId,
            objectId: objectIds[VisitPhotoUploadPlan.maxPhotoCount - 1]
        ))
    }

    @Test func visitPhotoAttachmentRowsPreserveSortOrderAndKeys() throws {
        let visitId = UUID()
        let rows = SupabaseVisitPhotoInsert.rows(
            visitId: visitId,
            photoURLs: [
                "https://example.com/first.jpg",
                "https://example.com/second.jpg"
            ]
        )

        #expect(rows == [
            SupabaseVisitPhotoInsert(
                visitId: visitId,
                photoURL: "https://example.com/first.jpg",
                sortOrder: 0
            ),
            SupabaseVisitPhotoInsert(
                visitId: visitId,
                photoURL: "https://example.com/second.jpg",
                sortOrder: 1
            )
        ])

        let data = try JSONEncoder().encode(rows[0])
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["visit_id"] as? String == visitId.uuidString)
        #expect(object["photo_url"] as? String == "https://example.com/first.jpg")
        #expect(object["sort_order"] as? Int == 0)
    }

    @Test func visitPhotoAttachmentPosterFallsBackToFirstURL() {
        let photoURLs = [
            "https://example.com/first.jpg",
            "https://example.com/second.jpg"
        ]

        #expect(SupabaseVisitPhotoInsert.posterPhotoURL(
            photoURLs: photoURLs,
            posterPhotoIndex: 1
        ) == "https://example.com/second.jpg")
        #expect(SupabaseVisitPhotoInsert.posterPhotoURL(
            photoURLs: photoURLs,
            posterPhotoIndex: 9
        ) == "https://example.com/first.jpg")
        #expect(SupabaseVisitPhotoInsert.posterPhotoURL(
            photoURLs: [],
            posterPhotoIndex: 0
        ) == nil)
    }

    @Test func cafeInsertPayloadTrimsAndMapsRemoteIdentityFields() throws {
        let cafe = Cafe(
            name: "  Payload Cafe  ",
            location: CLLocationCoordinate2D(latitude: 32.78, longitude: -79.93),
            address: "  123 Bean St  ",
            mapItemURL: "  maps://payload-cafe  ",
            websiteURL: "  https://payload.example  "
        )

        let insert = SupabaseCafeInsert.from(cafe: cafe)
        let data = try JSONEncoder().encode(insert)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["name"] as? String == "Payload Cafe")
        #expect(object["address"] as? String == "123 Bean St")
        #expect(object["latitude"] as? Double == 32.78)
        #expect(object["longitude"] as? Double == -79.93)
        #expect(object["apple_place_id"] as? String == "maps://payload-cafe")
        #expect(object["website_url"] as? String == "https://payload.example")
        #expect(object["identity_key"] as? String == "apple:maps://payload-cafe")
    }

    @Test func visitInsertPayloadMapsSupabaseContract() throws {
        let userId = try #require(UUID(uuidString: "71500ca8-a989-4416-b716-c160325c79ba"))
        let cafeId = try #require(UUID(uuidString: "4b37b6e8-62c3-4016-8163-28cdb804e792"))
        let remoteCafe = SupabaseCafeSummary(
            id: cafeId,
            name: "Payload Cafe",
            address: "123 Bean St",
            city: "Charleston, SC",
            latitude: nil,
            longitude: nil,
            applePlaceId: nil,
            websiteURL: nil
        )
        let template = RatingTemplate(categories: [
            RatingCategory(name: "Taste", weight: 2),
            RatingCategory(name: "Vibe", weight: 1)
        ])
        let visitId = UUID()

        let insert = try SupabaseVisitInsert.make(
            visitId: visitId,
            userId: userId,
            remoteCafe: remoteCafe,
            drinkType: .coffee,
            customDrinkType: "Ignored",
            drinkSubtype: "  Cortado  ",
            caption: "  Tiny cup, huge day.  ",
            notes: "  owner note  ",
            visibility: .private,
            ratings: [
                "Taste": 5,
                "Vibe": 4,
                "Unknown": 5,
                "TooHigh": 7,
                "Zero": 0
            ],
            ratingTemplate: template
        )
        let data = try JSONEncoder().encode(insert)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let ratings = try #require(object["ratings"] as? [String: Double])
        let categoryScores = try #require(object["category_scores"] as? [[String: Any]])

        #expect(object["user_id"] as? String == userId.uuidString)
        #expect(object["id"] as? String == visitId.uuidString)
        #expect(object["cafe_id"] as? String == cafeId.uuidString)
        #expect(object["drink_type"] as? String == "Coffee")
        #expect(object["drink_type_custom"] == nil)
        #expect(object["drink_subtype"] as? String == "Cortado")
        #expect(object["caption"] as? String == "Tiny cup, huge day.")
        #expect(object["notes"] as? String == "owner note")
        #expect(object["visibility"] as? String == "private")
        #expect(object["context_type"] as? String == "Cafe")
        #expect(object["location_name"] as? String == "Payload Cafe")
        #expect(object["city_state"] as? String == "Charleston, SC")
        let overallScore = try #require(object["overall_score"] as? Double)
        #expect(abs(overallScore - (((5.0 * 2.0) + 4.0) / 3.0)) < 0.0001)
        #expect(ratings == ["Taste": 5, "Vibe": 4])
        #expect(categoryScores.count == 2)
        #expect(categoryScores[0]["name"] as? String == "Taste")
        #expect(categoryScores[0]["score"] as? Double == 5)
        #expect(categoryScores[0]["weight"] as? Double == 2)
    }

    @Test func visitInsertPayloadMapsCustomDrinkAndRejectsMissingRating() throws {
        let userId = UUID()
        let remoteCafe = SupabaseCafeSummary(
            id: UUID(),
            name: "Payload Cafe",
            address: nil,
            city: nil,
            latitude: nil,
            longitude: nil,
            applePlaceId: nil,
            websiteURL: nil
        )
        let template = RatingTemplate(categories: [
            RatingCategory(name: "Taste", weight: 1)
        ])

        let insert = try SupabaseVisitInsert.make(
            userId: userId,
            remoteCafe: remoteCafe,
            drinkType: .other,
            customDrinkType: "  Tonic Fizz  ",
            drinkSubtype: nil,
            caption: "Custom drink",
            notes: "",
            visibility: .everyone,
            ratings: ["Taste": 4],
            ratingTemplate: template
        )
        let data = try JSONEncoder().encode(insert)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["drink_type"] == nil)
        #expect(object["drink_type_custom"] as? String == "Tonic Fizz")
        #expect(object["notes"] == nil)
        #expect(object["visibility"] as? String == "everyone")

        #expect(throws: VisitServiceError.missingRating) {
            _ = try SupabaseVisitInsert.make(
                userId: userId,
                remoteCafe: remoteCafe,
                drinkType: .coffee,
                customDrinkType: nil,
                drinkSubtype: nil,
                caption: "No rating",
                notes: nil,
                visibility: .friends,
                ratings: ["Taste": 0],
                ratingTemplate: template
            )
        }
    }

    @Test func cafeStateUpsertEncodesRemoteStateContract() throws {
        let userId = UUID()
        let cafeId = UUID()
        let upsert = SupabaseCafeStateUpsert(
            userId: userId,
            cafeId: cafeId,
            isFavorite: true,
            wantToTry: false
        )

        let data = try JSONEncoder().encode(upsert)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["user_id"] as? String == userId.uuidString)
        #expect(object["cafe_id"] as? String == cafeId.uuidString)
        #expect(object["is_favorite"] as? Bool == true)
        #expect(object["want_to_try"] as? Bool == false)
    }

    @Test func remoteCafeSummaryMapsToLocalCafeWithRemoteIdentity() {
        let id = UUID()
        let remoteCafe = SupabaseCafeSummary(
            id: id,
            name: "Remote Cafe",
            address: "123 Bean St",
            city: "Charleston",
            latitude: 32.78,
            longitude: -79.93,
            applePlaceId: "maps://remote-cafe",
            websiteURL: "https://example.com"
        )

        let cafe = remoteCafe.localCafe(
            isFavorite: true,
            wantToTry: true,
            averageRating: 4.7,
            visitCount: 3
        )

        #expect(cafe.id == id)
        #expect(cafe.remoteCafeId == id)
        #expect(cafe.name == "Remote Cafe")
        #expect(cafe.address == "123 Bean St")
        #expect(cafe.location?.latitude == 32.78)
        #expect(cafe.location?.longitude == -79.93)
        #expect(cafe.isFavorite)
        #expect(cafe.wantToTry)
        #expect(cafe.averageRating == 4.7)
        #expect(cafe.visitCount == 3)
        #expect(cafe.mapItemURL == "maps://remote-cafe")
        #expect(cafe.websiteURL == "https://example.com")
    }

    @Test func remoteCafeVisitStatsCalculateCountAndAverageScore() {
        let first = RemoteVisitSummary(
            visit: SupabaseVisitRow(
                id: UUID(),
                userId: UUID(),
                cafeId: UUID(),
                drinkType: "Coffee",
                drinkTypeCustom: nil,
                drinkSubtype: "Cappuccino",
                caption: "",
                notes: nil,
                visibility: "private",
                ratings: [:],
                overallScore: 4.0,
                posterPhotoURL: nil,
                contextType: "Cafe",
                locationName: nil,
                cityState: nil,
                brewMethod: nil,
                createdAt: "2026-07-01T12:34:56Z"
            ),
            cafe: nil
        )
        let second = RemoteVisitSummary(
            visit: SupabaseVisitRow(
                id: UUID(),
                userId: UUID(),
                cafeId: UUID(),
                drinkType: "Matcha",
                drinkTypeCustom: nil,
                drinkSubtype: "Iced Matcha",
                caption: "",
                notes: nil,
                visibility: "private",
                ratings: [:],
                overallScore: 5.0,
                posterPhotoURL: nil,
                contextType: "Cafe",
                locationName: nil,
                cityState: nil,
                brewMethod: nil,
                createdAt: "2026-07-01T12:35:56Z"
            ),
            cafe: nil
        )

        let stats = RemoteCafeVisitStats.calculate(from: [first, second])

        #expect(stats.visitCount == 2)
        #expect(stats.averageScore == 4.5)
        #expect(RemoteCafeVisitStats.calculate(from: []).visitCount == 0)
        #expect(RemoteCafeVisitStats.calculate(from: []).averageScore == 0)
    }

    @Test func addVisitValidationRequiresPhotoForEverySavePath() {
        #expect(!AddVisitValidation.hasRequiredPhoto(photoCount: 0))
        #expect(AddVisitValidation.hasRequiredPhoto(photoCount: 1))
        #expect(AddVisitValidation.photoRequiredMessage.contains("photo"))
    }

    @Test func addVisitRequirementSequenceMatchesTheGuidedJournalFlow() {
        #expect(AddVisitRequirement.allCases == [.photo, .cafe, .drink, .rating, .caption])
        #expect(AddVisitRequirement.photo.actionTitle == "Add a photo")
        #expect(AddVisitRequirement.caption.guidance.contains("tasting note"))
    }

    @Test func userFacingErrorsNeverExposeTransportCopy() {
        let offline = MugshotUserFacingError.message(
            for: URLError(.notConnectedToInternet),
            context: .photoUpload
        )
        #expect(offline.contains("offline"))

        let upload = MugshotUserFacingError.message(
            for: NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "raw endpoint failure"]),
            context: .photoUpload
        )
        #expect(!upload.contains("endpoint"))
        #expect(upload.contains("sip"))
    }

    @Test func presentationNormalizesCafeNamesAndUnratedScores() {
        let cafe = Cafe(name: "  BLUE   BOTTLE COFFEE ", averageRating: 0)
        #expect(cafe.consumerDisplayName == "Blue Bottle Coffee")
        #expect(cafe.consumerScoreLabel == "Unrated")

        let remoteCafe = SupabaseCafeSummary(
            id: UUID(),
            name: "the DAILY grind",
            address: nil,
            city: nil,
            latitude: nil,
            longitude: nil,
            applePlaceId: nil,
            websiteURL: nil
        )
        #expect(remoteCafe.consumerDisplayName == "the Daily Grind")
    }

    @Test func visitInsertDefaultsToCompleteAndSupportsUploadDrafts() throws {
        let cafe = SupabaseCafeSummary(
            id: UUID(), name: "Cafe", address: nil, city: nil,
            latitude: nil, longitude: nil, applePlaceId: nil, websiteURL: nil
        )
        let template = RatingTemplate(categories: [RatingCategory(name: "Taste", weight: 1)])
        let draft = try SupabaseVisitInsert.make(
            userId: UUID(), remoteCafe: cafe, drinkType: .coffee,
            customDrinkType: nil, drinkSubtype: "Latte", caption: "Morning",
            notes: nil, visibility: .private, ratings: ["Taste": 4],
            ratingTemplate: template, uploadState: .uploading
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any]
        )
        #expect(object["upload_state"] as? String == "uploading")
    }

    @Test func supabaseSocialPayloadsTrimAndEncodeState() throws {
        let userId = UUID()
        let visitId = UUID()
        let like = SupabaseVisitLikeInsert(userId: userId, visitId: visitId)
        let comment = try SupabaseVisitCommentInsert.make(
            userId: userId,
            visitId: visitId,
            text: "  Great sip  "
        )

        let likeObject = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(like)) as? [String: Any]
        )
        let commentObject = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(comment)) as? [String: Any]
        )

        #expect(likeObject["user_id"] as? String == userId.uuidString)
        #expect(likeObject["visit_id"] as? String == visitId.uuidString)
        #expect(commentObject["user_id"] as? String == userId.uuidString)
        #expect(commentObject["visit_id"] as? String == visitId.uuidString)
        #expect(commentObject["text"] as? String == "Great sip")
        #expect(commentObject["parent_comment_id"] == nil)
        #expect(throws: VisitServiceError.emptyComment) {
            _ = try SupabaseVisitCommentInsert.make(userId: userId, visitId: visitId, text: "  ")
        }
    }

    @Test func remoteVisitUpdatePayloadTrimsAndMapsVisibility() throws {
        let update = try SupabaseVisitUpdate.make(
            caption: "  Better caption  ",
            notes: "  private note  ",
            visibility: .friends
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(update)) as? [String: Any]
        )

        #expect(object["caption"] as? String == "Better caption")
        #expect(object["notes"] as? String == "private note")
        #expect(object["visibility"] as? String == "friends")
        #expect(throws: VisitServiceError.emptyCaption) {
            _ = try SupabaseVisitUpdate.make(caption: " ", notes: nil, visibility: .private)
        }
    }

    @Test func remoteProfileStatsMapVisitsToRealStatsAndTopCafes() throws {
        let cafeId = UUID()
        let otherCafeId = UUID()
        let userId = UUID()
        let cafe = SupabaseCafeSummary(
            id: cafeId,
            name: "Top Cafe",
            address: "123 Bean St",
            city: "Charleston",
            latitude: nil,
            longitude: nil,
            applePlaceId: nil,
            websiteURL: nil
        )
        let otherCafe = SupabaseCafeSummary(
            id: otherCafeId,
            name: "Other Cafe",
            address: nil,
            city: nil,
            latitude: nil,
            longitude: nil,
            applePlaceId: nil,
            websiteURL: nil
        )
        let visits = [
            RemoteVisitSummary(
                visit: SupabaseVisitRow(
                    id: UUID(),
                    userId: userId,
                    cafeId: cafeId,
                    drinkType: "Coffee",
                    drinkTypeCustom: nil,
                    drinkSubtype: "Latte",
                    caption: "A",
                    notes: nil,
                    visibility: "everyone",
                    ratings: [:],
                    overallScore: 5,
                    posterPhotoURL: "https://example.com/a.jpg",
                    contextType: "Cafe",
                    locationName: nil,
                    cityState: nil,
                    brewMethod: nil,
                    createdAt: "2026-07-02T12:00:00Z"
                ),
                cafe: cafe
            ),
            RemoteVisitSummary(
                visit: SupabaseVisitRow(
                    id: UUID(),
                    userId: userId,
                    cafeId: cafeId,
                    drinkType: "Coffee",
                    drinkTypeCustom: nil,
                    drinkSubtype: "Latte",
                    caption: "B",
                    notes: nil,
                    visibility: "everyone",
                    ratings: [:],
                    overallScore: 4,
                    posterPhotoURL: nil,
                    contextType: "Cafe",
                    locationName: nil,
                    cityState: nil,
                    brewMethod: nil,
                    createdAt: "2026-07-01T12:00:00Z"
                ),
                cafe: cafe
            ),
            RemoteVisitSummary(
                visit: SupabaseVisitRow(
                    id: UUID(),
                    userId: userId,
                    cafeId: otherCafeId,
                    drinkType: "Tea",
                    drinkTypeCustom: nil,
                    drinkSubtype: "Jasmine",
                    caption: "C",
                    notes: nil,
                    visibility: "everyone",
                    ratings: [:],
                    overallScore: 3,
                    posterPhotoURL: nil,
                    contextType: "Cafe",
                    locationName: nil,
                    cityState: nil,
                    brewMethod: nil,
                    createdAt: "2026-06-30T12:00:00Z"
                ),
                cafe: otherCafe
            )
        ]

        let stats = RemoteProfileStats.calculate(from: visits)

        #expect(stats.totalVisits == 3)
        #expect(stats.totalCafes == 2)
        #expect(abs(stats.averageScore - 4.0) < 0.0001)
        #expect(stats.favoriteDrinkLabel == "Latte")
        #expect(stats.topCafes.first?.cafe.id == cafeId)
        #expect(stats.topCafes.first?.visitCount == 2)
        #expect(stats.topCafes.first?.posterPhotoURL == "https://example.com/a.jpg")
    }

    @Test func settingsLegalAndMugsyPresenceAreCovered() {
        #expect(SettingsDestination.allCases == [.about, .privacy, .terms, .support])
        #expect(SettingsDestination.privacy.detail.contains("connected to your account"))
        #expect(!SettingsDestination.privacy.detail.contains("Supabase"))
        #expect(SettingsDestination.terms.detail.contains("respectfully"))
        #expect(SettingsDestination.support.externalURL?.scheme == "mailto")
        #expect(MugsyEmptyStateAsset.noFavorites.rawValue == "MugsyNoFavorites")
        #expect(MugsyEmptyStateAsset.noWishlist.rawValue == "MugsyNoWishlist")
        #expect(MugsyEmptyStateAsset.noCafes.rawValue == "MugsyNoCafes")
    }

    @Test func feedSearchMatchesAcrossVisibleVisitMetadata() {
        let cafeId = UUID()
        let userId = UUID()
        let summary = RemoteVisitSummary(
            visit: SupabaseVisitRow(
                id: UUID(),
                userId: userId,
                cafeId: cafeId,
                drinkType: "Coffee",
                drinkTypeCustom: nil,
                drinkSubtype: "Cafe Latte",
                caption: "Sunny patio and orange blossom",
                notes: nil,
                visibility: "everyone",
                ratings: [:],
                overallScore: 4.5,
                posterPhotoURL: nil,
                contextType: "Cafe",
                locationName: nil,
                cityState: nil,
                brewMethod: nil,
                createdAt: "2026-07-11T12:00:00Z"
            ),
            cafe: SupabaseCafeSummary(
                id: cafeId,
                name: "Ritual Coffee Roasters",
                address: "1026 Valencia St",
                city: "San Francisco, CA",
                latitude: nil,
                longitude: nil,
                applePlaceId: nil,
                websiteURL: nil
            ),
            author: SupabaseUserProfile(
                id: userId,
                displayName: "Amélie Bean",
                username: "amelie_coffee",
                bio: nil,
                location: nil,
                favoriteDrink: nil,
                instagramHandle: nil,
                avatarURL: nil,
                bannerURL: nil,
                websiteURL: nil
            )
        )

        #expect(summary.matchesFeedSearch(""))
        #expect(summary.matchesFeedSearch("  AMELIE ritual "))
        #expect(summary.matchesFeedSearch("cafe latte"))
        #expect(summary.matchesFeedSearch("orange blossom"))
        #expect(summary.matchesFeedSearch("San Francisco"))
        #expect(!summary.matchesFeedSearch("matcha"))
    }

    @Test func discoveryPayloadDecodesRankingAndCanonicalCafeIdentity() throws {
        let cafeID = UUID()
        let json = """
        [{
          "cafe_id":"\(cafeID.uuidString)","name":"Needle & Bean","address":"1 Main St","city":"Pittsburgh",
          "latitude":40.4,"longitude":-80.0,"identity_key":"apple:needle","section":"nearby",
          "ranking_score":0.82,"ranking_reason":"Great match nearby","distance_km":2.4,
          "average_rating":4.6,"visible_visit_count":12,"friend_count":3,
          "top_drinks":[{"name":"Latte","count":6}],"recent_cover":null,
          "is_saved":true,"is_visited":false
        }]
        """

        let cafes = try JSONDecoder().decode([DiscoveryCafe].self, from: Data(json.utf8))
        #expect(cafes.first?.id == cafeID)
        #expect(cafes.first?.identityKey == "apple:needle")
        #expect(cafes.first?.topDrinks.first?.name == "Latte")
        #expect(cafes.first?.localCafe.remoteCafeId == cafeID)
    }

    @Test func peopleSearchPayloadPreservesFriendshipAndCursorFields() throws {
        let userID = UUID()
        let json = """
        [{
          "id":"\(userID.uuidString)","display_name":"Alice","username":"alice",
          "bio":null,"location":"Charleston","favorite_drink":"Cortado","avatar_url":null,"banner_url":null,
          "friendship_state":"incoming","mutual_friend_count":2,"rank_bucket":0,"match_score":1.0
        }]
        """
        let people = try JSONDecoder().decode([PeopleSearchResult].self, from: Data(json.utf8))
        #expect(people.first?.friendshipState == .incoming)
        #expect(people.first?.mutualFriendCount == 2)
        #expect(people.first?.rankBucket == 0)
    }

    @Test func rankedFeedIsTheDefaultFirstScopeAndCursorKeepsScore() {
        #expect(FeedScope.allCases.first == .ranked)
        #expect(FeedScope.ranked.displayName == "Your Mix")
        #expect(FeedScope.ranked.rpcValue == "ranked")
        #expect(FeedScope.friends.rpcValue == "friends")
        #expect(FeedScope.everyone.rpcValue == "everyone")
        let summary = RemoteVisitSummary(
            visit: SupabaseVisitRow(
                id: UUID(), userId: UUID(), cafeId: nil, drinkType: "Coffee", drinkTypeCustom: nil,
                drinkSubtype: nil, caption: "Test", notes: nil, visibility: "everyone", ratings: [:],
                overallScore: 4, posterPhotoURL: nil, contextType: "Cafe", locationName: nil,
                cityState: nil, brewMethod: nil, createdAt: "2026-07-12T12:00:00Z"
            ),
            cafe: nil,
            rankingScore: 0.73
        )
        #expect(RemoteFeedCursor(summary).rankingScore == 0.73)
    }

    @Test func distanceUnitsRespectExplicitAndAutomaticPreferences() {
        let usLocale = Locale(identifier: "en_US")
        let frenchLocale = Locale(identifier: "fr_FR")

        #expect(DistanceUnitPreference.automatic.resolvedUnit(locale: usLocale) == .miles)
        #expect(DistanceUnitPreference.automatic.resolvedUnit(locale: frenchLocale) == .kilometers)
        #expect(
            MugshotDistanceFormatter.discoveryRadius(
                kilometers: 25,
                preference: .miles,
                locale: usLocale
            ) == "16 mi"
        )
        #expect(
            MugshotDistanceFormatter.distance(
                kilometers: 0.8,
                preference: .miles,
                locale: usLocale
            ) == "0.5 mi"
        )
        #expect(
            MugshotDistanceFormatter.distance(
                kilometers: 0.8,
                preference: .kilometers,
                locale: usLocale
            ) == "0.8 km"
        )
    }

    @Test func cafeCardImageSourceUsesDurableFallbackOrder() {
        #expect(
            CafeCardImageSource.preferred(
                personalJournalPath: "/journal/cover.jpg",
                placePhotoURL: "https://places.example/cafe.jpg",
                communityPhotoURL: "https://mugshot.example/community.jpg"
            ) == .personalJournal(path: "/journal/cover.jpg")
        )
        #expect(
            CafeCardImageSource.preferred(
                personalJournalPath: nil,
                placePhotoURL: "https://places.example/cafe.jpg",
                communityPhotoURL: "https://mugshot.example/community.jpg"
            ) == .place(url: "https://places.example/cafe.jpg")
        )
        #expect(
            CafeCardImageSource.preferred(
                personalJournalPath: nil,
                placePhotoURL: nil,
                communityPhotoURL: "https://mugshot.example/community.jpg"
            ) == .community(url: "https://mugshot.example/community.jpg")
        )
        #expect(
            CafeCardImageSource.preferred(
                personalJournalPath: nil,
                placePhotoURL: nil,
                communityPhotoURL: nil
            ) == .placeholder
        )
    }

    @Test func productCopyUsesAsciiCafeSpelling() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let roots = [
            repositoryRoot.appendingPathComponent("testMugshot"),
            repositoryRoot.appendingPathComponent("docs")
        ]
        let accentedE = String(UnicodeScalar(0x00E9)!)
        let forbidden = ["caf\(accentedE)", "caf\(accentedE)s"]
        let scannedExtensions = Set(["swift", "strings", "xcstrings", "md"])
        var violations: [String] = []

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard scannedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                let contents = try String(contentsOf: fileURL, encoding: .utf8).lowercased()
                if forbidden.contains(where: contents.contains) {
                    violations.append(fileURL.path)
                }
            }
        }

        #expect(violations.isEmpty)
    }

}
