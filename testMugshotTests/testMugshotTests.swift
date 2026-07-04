//
//  testMugshotTests.swift
//  testMugshotTests
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import CoreLocation
import Testing
@testable import testMugshot

struct testMugshotTests {

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

        let insert = try SupabaseVisitInsert.make(
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

}
