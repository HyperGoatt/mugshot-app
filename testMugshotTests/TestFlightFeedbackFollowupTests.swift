import Foundation
import Testing
@testable import testMugshot

struct TestFlightFeedbackFollowupTests {
    @Test func instagramHandleNormalizationAcceptsSupportedFormsAndClearing() throws {
        #expect(try InstagramProfileHandle.normalize(" MugShot.Joe ") == "mugshot.joe")
        #expect(try InstagramProfileHandle.normalize("@MugShot_Joe") == "mugshot_joe")
        #expect(
            try InstagramProfileHandle.normalize("https://www.instagram.com/MugShot.Joe/")
                == "mugshot.joe"
        )
        #expect(try InstagramProfileHandle.normalize("  ") == nil)
        #expect(
            InstagramProfileHandle.profileURL(for: "@MugShot_Joe")?.absoluteString
                == "https://www.instagram.com/mugshot_joe/"
        )
    }

    @Test func instagramHandleNormalizationRejectsBrokenDestinations() {
        let rejected = [
            "https://example.com/mugshot",
            "http://instagram.com/mugshot",
            "https://instagram.com/p/abc",
            "https://instagram.com/mugshot/followers",
            "https://instagram.com/mugshot?ref=test",
            ".mugshot",
            "mugshot..joe",
            "mugshot/joe",
            "mügshot"
        ]
        for value in rejected {
            #expect(throws: InstagramProfileHandleError.self) {
                try InstagramProfileHandle.normalize(value)
            }
        }
    }

    @Test func prophetCoffeeUsesMugshotAverageInsteadOfCafePulse() throws {
        let cafePulse = RemoteCafeExperienceSummary(
            schemaVersion: 1,
            cafeID: UUID(),
            scope: "personal",
            physicalSessionCount: 1,
            ratedSessionCount: 1,
            contributorCount: 1,
            averageCafeRating: 4.2,
            latestNextMove: nil,
            relationshipStageValue: "first_impression",
            communityThresholdMet: true
        )
        let oneMugshot = try #require(MapPinScoreResolver.resolve(
            sips: [MapSipScoreSeed(overallScore: 3.1, cafeSessionID: UUID(), mugshotScore: 3.7)],
            cafeSummary: cafePulse,
            audience: .personal
        ))
        let twoMugshots = try #require(MapPinScoreResolver.resolve(
            sips: [
                MapSipScoreSeed(overallScore: 3.1, cafeSessionID: UUID(), mugshotScore: 3.7),
                MapSipScoreSeed(overallScore: 4.1, cafeSessionID: UUID(), mugshotScore: 4.1)
            ],
            cafeSummary: cafePulse,
            audience: .personal
        ))

        #expect(oneMugshot.value == 3.7)
        #expect(oneMugshot.source == .mugshot)
        #expect(twoMugshots.value == 3.9)
    }

    @Test func personalMugshotAverageUsesLegacyOnlyWhenV3IsAbsent() throws {
        let score = try #require(MapPinScoreResolver.personalMugshotAverage([
            MapSipScoreSeed(overallScore: 4.4, cafeSessionID: nil),
            MapSipScoreSeed(overallScore: 1.2, cafeSessionID: nil, mugshotScore: 3.6),
            MapSipScoreSeed(overallScore: 5, cafeSessionID: nil, mugshotScore: 0),
            MapSipScoreSeed(overallScore: 0, cafeSessionID: nil)
        ]))

        #expect(abs(score.value - 4.0) < 0.0001)
        #expect(score.sipCount == 2)
    }

    @Test func feedPhotosAreCoverFirstAndDeduplicated() {
        let row = SupabaseVisitRow(
            id: UUID(),
            userId: UUID(),
            cafeId: nil,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Latte",
            caption: "Ordered photos",
            notes: nil,
            visibility: "everyone",
            ratings: [:],
            overallScore: 4,
            posterPhotoURL: " https://images.example/cover.jpg ",
            contextType: "Home",
            locationName: "Home",
            cityState: nil,
            brewMethod: nil,
            createdAt: "2026-09-14T12:00:00Z"
        )
        let summary = RemoteVisitSummary(
            visit: row,
            cafe: nil,
            photoURLs: [
                "https://images.example/second.jpg",
                "https://images.example/cover.jpg",
                "https://images.example/second.jpg"
            ]
        )

        let updated = summary.updatingSocialState(RemoteVisitSocialState(
            likeCount: 1, commentCount: 0, currentUserHasLiked: true
        ))
        #expect(updated.photoURLs == summary.photoURLs)
        #expect(updated.socialState.likeCount == 1)
        #expect(summary.photoURLs == [
            "https://images.example/cover.jpg",
            "https://images.example/second.jpg"
        ])
    }

    @Test func feedCarouselLoadsOnlyTheVisiblePhotoAndNeighbors() {
        #expect(MugshotFeedMediaLoadingPolicy.loadedIndices(count: 1, selectedIndex: 0) == [0])
        #expect(MugshotFeedMediaLoadingPolicy.loadedIndices(count: 8, selectedIndex: 0) == [0, 1])
        #expect(MugshotFeedMediaLoadingPolicy.loadedIndices(count: 8, selectedIndex: 4) == [3, 4, 5])
        #expect(MugshotFeedMediaLoadingPolicy.loadedIndices(count: 8, selectedIndex: 7) == [6, 7])
    }

    @Test func legacyReflectionPreferencesRequireAnExplicitV2SaveBeforeDelivery() throws {
        let accountID = UUID()
        let json = """
        {
          "user_id": "\(accountID.uuidString)",
          "monthly_recaps": false,
          "yearly_recaps": false,
          "on_this_sip_reminders": true,
          "reflection_reminders": true
        }
        """
        let preferences = try JSONDecoder().decode(
            UserReflectionPreferences.self,
            from: Data(json.utf8)
        )

        #expect(preferences.timezoneName == "UTC")
        #expect(!preferences.deliveryActivated)
        #expect(preferences.clientCapabilityVersion == 0)
    }

    @Test func reflectionPushRouteContainsOnlyAccountOccurrenceAndSupportedDestination() throws {
        let accountID = UUID()
        let occurrenceID = UUID()
        let visitID = UUID()
        let envelope = try #require(ReflectionPushRouteEnvelope.resolve(userInfo: [
            "mugshot_reflection": [
                "recipient_id": accountID.uuidString,
                "occurrence_id": occurrenceID.uuidString,
                "reminder_kind": "on_this_day",
                "deep_link": "mugshot://reflection/memory/\(visitID.uuidString)"
            ]
        ]))

        #expect(envelope.accountID == accountID)
        #expect(envelope.occurrenceID == occurrenceID)
        #expect(envelope.destination == .memory(visitID))
        #expect(
            ReflectionPushRouteEnvelope.resolve(userInfo: [
                "mugshot_reflection": [
                    "recipient_id": accountID.uuidString,
                    "occurrence_id": occurrenceID.uuidString,
                    "deep_link": "https://example.com/private-note"
                ]
            ]) == nil
        )
    }

    @MainActor
    @Test func reflectionRouterPersistsAndRejectsAnotherAccount() throws {
        let suiteName = "ReflectionReminderRouterTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let accountID = UUID()
        let envelope = ReflectionPushRouteEnvelope(
            accountID: accountID,
            occurrenceID: UUID(),
            destination: .journal
        )
        let first = ReflectionReminderRouter(defaults: defaults)
        first.enqueue(envelope)
        let restored = ReflectionReminderRouter(defaults: defaults)

        #expect(restored.pendingRoute?.accountID == accountID)
        restored.activate(accountID: UUID())
        #expect(restored.pendingRoute == nil)
    }
}

@MainActor
struct PerformanceLifecycleRegressionTests {
    @Test func carouselSelectionSurvivesRowRecreationAndResetsForRemovedPhoto() {
        let store = FeedMediaSelectionStore()
        let visit = UUID()
        let photos = ["first", "second", "third"]
        #expect(store.selection(for: visit, available: photos) == "first")
        store.select("second", for: visit)
        #expect(store.selection(for: visit, available: photos) == "second")
        #expect(store.selection(for: UUID(), available: photos) == "first")
        #expect(store.selection(for: visit, available: ["first", "third"]) == "first")
        #expect(store.selection(for: visit, available: []) == nil)
    }

}
