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

    @Test func guestIntroductionOnlyAppearsForAnUnintroducedGuest() {
        #expect(MugshotGuestIntroductionPolicy.shouldPresent(
            hasSeen: false,
            hasAuthenticatedNavigation: false,
            isUITesting: false
        ))
        #expect(!MugshotGuestIntroductionPolicy.shouldPresent(
            hasSeen: true,
            hasAuthenticatedNavigation: false,
            isUITesting: false
        ))
        #expect(!MugshotGuestIntroductionPolicy.shouldPresent(
            hasSeen: false,
            hasAuthenticatedNavigation: true,
            isUITesting: false
        ))
        #expect(!MugshotGuestIntroductionPolicy.shouldPresent(
            hasSeen: false,
            hasAuthenticatedNavigation: false,
            isUITesting: true
        ))
    }

    @Test func authCallbackRoutingSeparatesRecoveryFromOrdinaryDeepLinks() throws {
        let confirmation = try #require(URL(string: "mugshot://auth/callback?code=confirmation-code"))
        let recovery = try #require(URL(string: "mugshot://auth/recovery?code=recovery-code"))
        let sipShortcut = try #require(URL(string: "mugshot://sip/camera"))
        let untrustedScheme = try #require(URL(string: "https://auth/recovery?code=recovery-code"))

        #expect(MugshotAuthCallbackRoute.resolve(confirmation) == .confirmation)
        #expect(MugshotAuthCallbackRoute.resolve(recovery) == .passwordRecovery)
        #expect(MugshotAuthCallbackRoute.resolve(sipShortcut) == nil)
        #expect(MugshotAuthCallbackRoute.resolve(untrustedScheme) == nil)
    }

    @Test func authInputPolicyNormalizesEmailAndPreservesLegacySignIn() {
        #expect(MugshotAuthInput.normalizedEmail("  Member@Example.COM \n") == "member@example.com")
        #expect(MugshotPasswordPolicy.acceptsExistingPassword("123456"))
        #expect(!MugshotPasswordPolicy.acceptsExistingPassword("12345"))
        #expect(MugshotPasswordPolicy.acceptsNewPassword("12345678"))
        #expect(!MugshotPasswordPolicy.acceptsNewPassword("1234567"))
        #expect(AuthService.callbackURL.absoluteString == "mugshot://auth/callback")
        #expect(AuthService.passwordRecoveryURL.absoluteString == "mugshot://auth/recovery")
    }

    @Test func authCallbackQueueDefersColdLinksAndConsumesEachLinkOnce() throws {
        let coldURL = try #require(URL(
            string: "mugshot://auth/recovery?code=one-time-recovery-code"
        ))
        let warmURL = try #require(URL(
            string: "mugshot://auth/callback?code=one-time-confirmation-code"
        ))
        var queue = MugshotAuthCallbackQueue()

        let acceptedColdURL = queue.enqueue(coldURL)
        #expect(acceptedColdURL)
        #expect(queue.pendingCount == 1)
        #expect(queue.nextIfReady(false) == nil)
        #expect(queue.nextIfReady(true) == coldURL)
        #expect(queue.isProcessing)
        #expect(queue.nextIfReady(true) == nil)

        queue.retryCurrentCallback()
        #expect(!queue.isProcessing)
        #expect(queue.pendingCount == 1)
        #expect(queue.nextIfReady(true) == coldURL)

        queue.completeCurrentCallback()
        #expect(!queue.isProcessing)
        let acceptedDuplicateURL = queue.enqueue(coldURL)
        #expect(acceptedDuplicateURL)
        #expect(queue.pendingCount == 0)

        let acceptedWarmURL = queue.enqueue(warmURL)
        #expect(acceptedWarmURL)
        #expect(queue.nextIfReady(true) == warmURL)
        queue.completeCurrentCallback()
        #expect(queue.nextIfReady(true) == nil)
    }

    @Test func ritualSnapshotCelebratesSupportedMilestonesWithoutPunishingRest() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-14T12:00:00Z"))
        let sevenDays = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: now)
        }

        let milestone = MugshotRitualSnapshot.make(dates: sevenDays, now: now, calendar: calendar)
        #expect(milestone.consecutiveDays == 7)
        #expect(milestone.totalDays == 7)
        #expect(milestone.tone == .milestone(7))

        let olderDate = try #require(calendar.date(byAdding: .day, value: -12, to: now))
        let returning = MugshotRitualSnapshot.make(dates: [olderDate], now: now, calendar: calendar)
        #expect(returning.consecutiveDays == 0)
        #expect(returning.tone == .returning)
    }

    @Test func ritualSnapshotKeepsYesterdayWarmWithoutInventingToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-14T12:00:00Z"))
        let dates = (1...3).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: now)
        }

        let snapshot = MugshotRitualSnapshot.make(dates: dates, now: now, calendar: calendar)
        #expect(snapshot.consecutiveDays == 3)
        #expect(snapshot.tone == .yesterday)
    }

    @Test func motionProgressAndDrinkAppearanceStayDeterministic() {
        #expect(MugshotMotion.normalized(-0.4) == 0)
        #expect(MugshotMotion.normalized(1.4) == 1)
        #expect(MugshotDrinkAppearance.infer(from: "Iced strawberry matcha") == .matcha)
        #expect(MugshotDrinkAppearance.infer(from: "Masala chai") == .chai)
        #expect(MugshotDrinkAppearance.infer(from: "Earl Grey tea") == .tea)
        #expect(MugshotDrinkAppearance.infer(from: "Flat white") == .coffee)
    }

    @Test func guestSavedCafesStayIsolatedFromAuthenticatedLocalDataUntilMerge() throws {
        let suite = "DataManagerGuestScopeTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = DataManager(defaults: defaults)
        manager.prepareGuestSession()

        let guestCafe = Cafe(name: "Guest Saved Cafe", isFavorite: true)
        manager.addCafe(guestCafe)
        #expect(manager.guestSavedCafes().map(\.name) == ["Guest Saved Cafe"])

        let userId = UUID()
        manager.applyAuthenticatedProfile(SupabaseUserProfile(
            id: userId,
            displayName: "Journal Owner",
            username: "journal_owner",
            bio: nil,
            location: nil,
            favoriteDrink: nil,
            instagramHandle: nil,
            avatarURL: nil,
            bannerURL: nil,
            websiteURL: nil
        ))

        #expect(manager.appData.cafes.isEmpty)
        #expect(manager.guestSavedCafes().map(\.name) == ["Guest Saved Cafe"])

        manager.addCafe(Cafe(name: "Account Cafe", wantToTry: true))
        manager.prepareGuestSession()
        #expect(manager.appData.cafes.map(\.name) == ["Guest Saved Cafe"])

        manager.applyAuthenticatedProfile(SupabaseUserProfile(
            id: userId,
            displayName: "Journal Owner",
            username: "journal_owner",
            bio: nil,
            location: nil,
            favoriteDrink: nil,
            instagramHandle: nil,
            avatarURL: nil,
            bannerURL: nil,
            websiteURL: nil
        ))
        #expect(manager.appData.cafes.map(\.name) == ["Account Cafe"])
    }

    @Test func clearingMergedGuestSavesDoesNotEraseAuthenticatedLocalData() throws {
        let suite = "DataManagerGuestMergeTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = DataManager(defaults: defaults)
        manager.prepareGuestSession()
        manager.addCafe(Cafe(name: "Guest Favorite", isFavorite: true))

        let userId = UUID()
        manager.applyAuthenticatedProfile(SupabaseUserProfile(
            id: userId,
            displayName: "Journal Owner",
            username: "journal_owner",
            bio: nil,
            location: nil,
            favoriteDrink: nil,
            instagramHandle: nil,
            avatarURL: nil,
            bannerURL: nil,
            websiteURL: nil
        ))
        manager.addCafe(Cafe(name: "Account Favorite", isFavorite: true))
        manager.clearMergedGuestSavedCafes()

        #expect(manager.guestSavedCafes().isEmpty)
        #expect(manager.appData.cafes.map(\.name) == ["Account Favorite"])
    }

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
        let sensorySnapshot = SipSensorySnapshot(
            bundleID: "mugshot.sensory.en-US",
            bundleContentVersion: "2026.07.16.1",
            identity: SensoryDrinkIdentity(
                rawName: "Latte",
                family: .milkCoffee,
                preparation: .latte,
                confidence: 1,
                provenance: .user,
                userConfirmed: true
            ),
            depth: .guided,
            ownWords: "Silky and cocoa-like",
            responses: [],
            personalEnjoyment: PersonalEnjoymentRating(value: 4.5)
        )
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
            overallScore: 4.5,
            ratingTemplate: RatingTemplate(),
            sensorySnapshot: sensorySnapshot,
            images: [image],
            posterPhotoIndex: 0
        )

        let restoredStore = PendingVisitSubmissionStore(defaults: defaults, baseDirectory: directory)
        let restored = try #require(restoredStore.load(userId: userId))
        #expect(restored.id == record.id)
        #expect(restoredStore.load(userId: UUID()) == nil)
        #expect(try restoredStore.loadImages(for: restored).count == 1)
        #expect(restored.objectPaths.count == 1)
        #expect(restored.sensorySnapshot == sensorySnapshot)
        #expect(restored.resolvedOverallScore == 4.5)

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

    @Test func privateVisitPhotoReferencesRoundTripWithoutExpiringURLs() throws {
        let path = "71500ca8-a989-4416-b716-c160325c79ba/4b37b6e8-62c3-4016-8163-28cdb804e792/photo one.jpg"
        let reference = try #require(VisitPhotoStorageReference(
            bucketName: VisitPhotoStorageReference.privateBucketName,
            objectPath: path
        ))

        #expect(
            reference.storedValue ==
                "mugshot-storage://visit-photos-private/71500ca8-a989-4416-b716-c160325c79ba/4b37b6e8-62c3-4016-8163-28cdb804e792/photo%20one.jpg"
        )
        #expect(VisitPhotoStorageReference(storedValue: reference.storedValue) == reference)
        #expect(
            VisitPhotoStorageLocation(storedValue: reference.storedValue) ==
                VisitPhotoStorageLocation(
                    bucketName: VisitPhotoStorageReference.privateBucketName,
                    objectPath: path
                )
        )
        #expect(
            VisitPhotoStorageReference(
                bucketName: VisitPhotoStorageReference.legacyPublicBucketName,
                objectPath: path
            ) == nil
        )
        #expect(
            VisitPhotoStorageReference(
                storedValue: "mugshot-storage://visit-photos-private/../escape.jpg"
            ) == nil
        )
    }

    @Test func visitMediaCleanupQueuePreservesPrivateAndLegacyBuckets() throws {
        let suite = "VisitMediaCleanupBucketTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = VisitMediaCleanupStore(defaults: defaults)
        let userId = UUID()
        let legacy = VisitPhotoStorageLocation(
            bucketName: VisitPhotoStorageReference.legacyPublicBucketName,
            objectPath: "owner/visit/legacy.jpg"
        )
        let privatePhoto = VisitPhotoStorageLocation(
            bucketName: VisitPhotoStorageReference.privateBucketName,
            objectPath: "owner/visit/private.jpg"
        )

        store.enqueue([legacy, privatePhoto, privatePhoto], userId: userId)

        #expect(Set(store.pendingLocations(userId: userId)) == Set([legacy, privatePhoto]))
        store.remove([privatePhoto], userId: userId)
        #expect(store.pendingLocations(userId: userId) == [legacy])
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

    @MainActor
    @Test func mapSearchAllowsNamedCafeAndCityOutsideVisibleRegion() {
        let charlestonRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 32.78, longitude: -79.93),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        let newYorkCafe = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 40.75, longitude: -73.99),
            addressDictionary: [
                "Street": "8th Avenue",
                "City": "New York"
            ]
        ))
        newYorkCafe.name = "Blank Street Coffee"

        let filtered = MapSearchService.credibleResults(
            [newYorkCafe],
            query: "Blank Street New York 8th Ave",
            region: charlestonRegion
        )

        #expect(filtered.first?.name == "Blank Street Coffee")
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
        #expect(snapshot.pins.first(where: { $0.cafe.id == loggedCafe.id })?.score?.source == .sip)
        #expect(snapshot.pins.first(where: { $0.cafe.id == savedCafe.id })?.isFavorite == true)
        #expect(snapshot.pins.first(where: { $0.cafe.id == savedCafe.id })?.visitCount == 0)
        #expect(snapshot.pins.first(where: { $0.cafe.id == savedCafe.id })?.score == nil)
        #expect(snapshot.pins.contains(where: { $0.cafe.id == inactiveCafe.id }) == false)
    }

    @Test func mapPinsPreferCafeEvidenceAndBalanceSipFallbackByPhysicalSession() {
        let sharedSession = UUID()
        let sipFallback = MapPinScoreResolver.resolve(
            sips: [
                MapSipScoreSeed(overallScore: 5, cafeSessionID: sharedSession),
                MapSipScoreSeed(overallScore: 1, cafeSessionID: sharedSession),
                MapSipScoreSeed(overallScore: 5, cafeSessionID: nil)
            ],
            cafeSummary: nil,
            audience: .personal
        )

        #expect(sipFallback?.source == .sip)
        #expect(sipFallback?.value == 4)
        #expect(sipFallback?.sipCount == 3)
        #expect(sipFallback?.physicalSessionCount == 2)
        #expect(sipFallback?.evidenceDescription == "3 sips across 2 visits")

        let cafeID = UUID()
        let cafeSummary = RemoteCafeExperienceSummary(
            schemaVersion: 1,
            cafeID: cafeID,
            scope: "personal",
            physicalSessionCount: 1,
            ratedSessionCount: 1,
            contributorCount: 1,
            averageCafeRating: 2.5,
            latestNextMove: "come_back_try_another",
            relationshipStageValue: "first_impression",
            communityThresholdMet: true
        )
        let cafeFirst = MapPinScoreResolver.resolve(
            sips: [
                MapSipScoreSeed(overallScore: 5, cafeSessionID: nil)
            ],
            cafeSummary: cafeSummary,
            audience: .personal
        )

        #expect(cafeFirst?.source == .cafe)
        #expect(cafeFirst?.value == 2.5)
        #expect(cafeFirst?.relationshipStage == .firstImpression)
        #expect(cafeFirst?.pinUseTitle == "Pin uses your Cafe average")
        #expect(cafeFirst?.evidenceDescription == "First impression · 1 rated Cafe Session")
    }

    @Test func mapPinScopesUseTheApprovedJournalFirstOrder() {
        #expect(
            MapDiscoveryScope.available(isAuthenticated: true) ==
                [.visited, .friends, .favorites, .wantToTry, .discovery, .all]
        )
        #expect(
            MapDiscoveryScope.available(isAuthenticated: false) ==
                [.visited, .favorites, .wantToTry, .discovery, .all]
        )
    }

    @Test func mapDiscoveryOnlyIncludesNetNewCafes() {
        #expect(
            MapDiscoveryEligibility.isNetNew(
                isVisited: false,
                isSaved: false,
                isInPersonalJournal: false
            )
        )
        #expect(
            !MapDiscoveryEligibility.isNetNew(
                isVisited: true,
                isSaved: false,
                isInPersonalJournal: false
            )
        )
        #expect(
            !MapDiscoveryEligibility.isNetNew(
                isVisited: false,
                isSaved: true,
                isInPersonalJournal: false
            )
        )
        #expect(
            !MapDiscoveryEligibility.isNetNew(
                isVisited: false,
                isSaved: false,
                isInPersonalJournal: true
            )
        )
    }

    @Test func mapPinRatingBandsUseClassicTrafficLightThresholds() {
        #expect(MapPinRatingBand(score: 5) == .high)
        #expect(MapPinRatingBand(score: 4) == .high)
        #expect(MapPinRatingBand(score: 3.9) == .middle)
        #expect(MapPinRatingBand(score: 3) == .middle)
        #expect(MapPinRatingBand(score: 2.9) == .low)
        #expect(MapPinRatingBand(score: 0) == .unrated)
        #expect(MapPinRatingBand(score: nil) == .unrated)
    }

    @Test func mapPinPresentationKeepsScorePrimaryAndUsesStateBadgesOnlyInAll() {
        let cafe = Cafe(
            name: "Mugshot Test Cafe",
            isFavorite: true,
            wantToTry: true,
            visitCount: 2
        )
        let score = MapPinScore(
            value: 4.25,
            source: .cafe,
            audience: .personal,
            ratedCafeSessionCount: 2,
            physicalSessionCount: 2,
            sipCount: 0,
            contributorCount: 1,
            relationshipStage: .emergingView
        )

        let all = MapPinPresentation.resolve(
            scope: .all,
            cafe: cafe,
            pinScore: score,
            friendCount: 3
        )
        #expect(all.primaryKind == .journal)
        #expect(all.scoreText == "4.2")
        #expect(all.ratingBand == .high)
        #expect(all.showsFavoriteBadge)
        #expect(all.showsWantToTryBadge)
        #expect(all.showsFriendsBadge)

        let favorite = MapPinPresentation.resolve(
            scope: .favorites,
            cafe: cafe,
            pinScore: score,
            friendCount: 3
        )
        #expect(favorite.primaryKind == .favorite)
        #expect(!favorite.hasStateBadges)

        let friends = MapPinPresentation.resolve(
            scope: .friends,
            cafe: cafe,
            pinScore: nil,
            friendCount: 3
        )
        #expect(friends.primaryKind == .friends)
        #expect(friends.scoreText == nil)
        #expect(friends.ratingBand == .unrated)
        #expect(friends.friendCount == 3)
    }

    @Test func friendMapSipSummaryPreservesItsSourceAndEvidence() throws {
        let cafeID = UUID()
        let json = """
        {
          "cafe_id":"\(cafeID.uuidString)",
          "average_sip_rating":3.875,
          "sip_count":3,
          "physical_session_count":2,
          "contributor_count":1
        }
        """
        let summary = try JSONDecoder().decode(
            RemoteFriendMapSipSummary.self,
            from: Data(json.utf8)
        )

        #expect(summary.mapPinScore?.source == .sip)
        #expect(summary.mapPinScore?.audience == .friends)
        #expect(summary.mapPinScore?.value == 3.875)
        #expect(summary.mapPinScore?.pinUseTitle == "Pin uses friends’ Sip fallback")
        #expect(
            summary.mapPinScore?.evidenceDescription ==
                "3 sips across 2 visits · 1 friend"
        )
    }

    @Test func mapPinsKeepUnratedCompletedVisitsWithoutInventingScore() {
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

        #expect(snapshot.pins.count == 1)
        #expect(snapshot.pins.first?.visitCount == 1)
        #expect(snapshot.pins.first?.score == nil)
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

    @Test func remoteVisitSummaryUsesContextLocationAndHidesStaleCafeAddress() {
        let staleCafe = SupabaseCafeSummary(
            id: UUID(),
            name: "Stale Cafe",
            address: "123 Private Way",
            city: "Charleston, SC",
            latitude: nil,
            longitude: nil,
            applePlaceId: nil,
            websiteURL: nil
        )
        let row = SupabaseVisitRow(
            id: UUID(),
            userId: UUID(),
            cafeId: staleCafe.id,
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

        let summary = RemoteVisitSummary(visit: row, cafe: staleCafe)

        #expect(summary.locationTitle == "Kitchen counter")
        #expect(summary.locationSubtitle == nil)
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
                    photoURL: "https://example.com/poster.jpg",
                    sortOrder: 2,
                    createdAt: "2026-07-01T12:36:56Z"
                ),
                SupabaseVisitPhotoRow(
                    id: UUID(),
                    visitId: row.id,
                    photoURL: "https://example.com/second.jpg",
                    sortOrder: 3,
                    createdAt: "2026-07-01T12:37:56Z"
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
            overallScore: 3.5,
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
        #expect(object["notes"] == nil)
        #expect(object["visibility"] as? String == "private")
        #expect(object["context_type"] as? String == "Cafe")
        #expect(object["location_name"] as? String == "Payload Cafe")
        #expect(object["city_state"] as? String == "Charleston, SC")
        let overallScore = try #require(object["overall_score"] as? Double)
        #expect(overallScore == 3.5)
        #expect(ratings == ["Taste": 5, "Vibe": 4])
        #expect(categoryScores.count == 2)
        #expect(categoryScores[0]["name"] as? String == "Taste")
        #expect(categoryScores[0]["score"] as? Double == 5)
        #expect(categoryScores[0]["weight"] as? Double == 2)
    }

    @Test func nonCafeVisitInsertDropsStaleCafeAssociation() throws {
        let remoteCafe = SupabaseCafeSummary(
            id: UUID(),
            name: "Should Not Persist",
            address: "123 Cafe Way",
            city: "Charleston, SC",
            latitude: nil,
            longitude: nil,
            applePlaceId: nil,
            websiteURL: nil
        )
        let insert = try SupabaseVisitInsert.make(
            userId: UUID(),
            remoteCafe: remoteCafe,
            entryContext: .elsewhere,
            locationName: "Window seat on the Coast Starlight",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Train coffee",
            caption: "A moving memory",
            notes: nil,
            visibility: .friends,
            ratings: ["Taste": 3],
            ratingTemplate: RatingTemplate(categories: [
                RatingCategory(name: "Taste", weight: 1)
            ])
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(insert)) as? [String: Any]
        )

        #expect(object["cafe_id"] == nil)
        #expect(object["context_type"] as? String == "Elsewhere")
        #expect(object["location_name"] as? String == "Window seat on the Coast Starlight")
        #expect(object["city_state"] == nil)
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

    @Test func legacyAddVisitRequiresCaptionButKeepsPhotoOptional() {
        #expect(AddVisitRequirement.requiredCases == [.cafe, .drink, .rating, .caption])
        #expect(AddVisitRequirement.optionalCases == [.photo])
    }

    @Test func addVisitRequirementSequenceMatchesTheGuidedJournalFlow() {
        #expect(AddVisitRequirement.allCases == [.photo, .cafe, .drink, .rating, .caption])
        #expect(AddVisitRequirement.photo.actionTitle == "Add a photo")
        #expect(AddVisitRequirement.caption.guidance.contains("tasting note"))
    }

    @Test func guidedComposerIsTheDefaultAndQuickSaveIsPrivate() {
        #expect(SipComposerExperience.defaultExperience == .guided)
        #expect(SipPublicationPolicy.requirement(
            visibility: .private,
            photoCount: 0,
            socialCaption: "",
            confirmedTextOnlyEveryone: false
        ) == .ready)
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

        let missingCafeSessionsCapability = MugshotUserFacingError.message(
            for: NSError(
                domain: "PostgREST",
                code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Could not find the function public.get_cafe_sessions_capability_v1"
                ]
            ),
            context: .loading
        )
        #expect(!missingCafeSessionsCapability.contains("session ended"))
        #expect(missingCafeSessionsCapability.contains("load"))

        let expiredJWT = MugshotUserFacingError.message(
            for: NSError(
                domain: "Auth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "JWT expired"]
            ),
            context: .loading
        )
        #expect(expiredJWT.contains("session ended"))
    }

    @Test func visitQueriesFallBackOnlyForMissingCafeSessionColumns() {
        let missingColumn = NSError(
            domain: "PostgREST",
            code: 400,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Could not find the 'cafe_session_id' column of 'visits' in the schema cache"
            ]
        )
        #expect(VisitSchemaCompatibility.isMissingCafeSessionColumn(missingColumn))

        let expiredSession = NSError(
            domain: "Auth",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "JWT expired"]
        )
        #expect(!VisitSchemaCompatibility.isMissingCafeSessionColumn(expiredSession))

        let unrelatedMissingColumn = NSError(
            domain: "PostgREST",
            code: 400,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Could not find the 'poster_photo_url' column of 'visits' in the schema cache"
            ]
        )
        #expect(!VisitSchemaCompatibility.isMissingCafeSessionColumn(unrelatedMissingColumn))
    }

    @Test func v3ProjectionRequestsBatchEveryVisitWithoutDuplicates() {
        let identifiers = (0..<205).map { _ in UUID() }
        let batches = VisitService.v3ProjectionBatches(
            visitIDs: identifiers + [identifiers[20], identifiers[140]]
        )

        #expect(batches.map(\.count) == [100, 100, 5])
        #expect(batches.flatMap { $0 } == identifiers)
    }

    @Test func remoteSaveErrorsNameTheFailedStageAndKeepRetryCopyAccurate() {
        let rawFailure = NSError(
            domain: "test",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "relation missing"]
        )
        let snapshot = MugshotUserFacingError.message(
            for: rawFailure,
            context: SipRemoteSaveOperation.savingTastingLens.errorContext
        )
        let photo = MugshotUserFacingError.message(
            for: rawFailure,
            context: SipRemoteSaveOperation.uploadingPhotos.errorContext
        )

        #expect(snapshot.contains("Tasting Lens"))
        #expect(snapshot.contains("tasting answers"))
        #expect(!snapshot.localizedCaseInsensitiveContains("photo"))
        #expect(photo.localizedCaseInsensitiveContains("photo"))
        #expect(SipRemoteSaveOperation.savingTastingLens.recoveryMessage.contains("Tasting Lens"))
        #expect(SipRemoteSaveOperation.uploadingPhotos.recoveryMessage.contains("photos"))
        #expect(SipRemoteSaveOperation.finalizing.errorContext == .sipSave)
    }

    @Test func presentationNormalizesCafeNamesAndUnratedScores() {
        let cafe = Cafe(name: "  BLUE   BOTTLE COFFEE ", averageRating: 0)
        #expect(cafe.consumerDisplayName == "Blue Bottle Coffee")
        #expect(cafe.consumerScoreLabel == "Cafe not rated")

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

    @Test func remoteVisitUpdateExcludesPrivateNotesAndMapsVisibility() throws {
        let update = try SupabaseVisitUpdate.make(
            caption: "  Better caption  ",
            visibility: .friends
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(update)) as? [String: Any]
        )

        #expect(object["caption"] as? String == "Better caption")
        #expect(object["notes"] == nil)
        #expect(object["visibility"] as? String == "friends")
        #expect(throws: SipCaptionValidationError.required) {
            _ = try SupabaseVisitUpdate.make(caption: " ", visibility: .private)
        }
    }

    @Test func privateNotePayloadUsesOwnerOnlyContract() throws {
        let visitID = UUID()
        let userID = UUID()
        let payload = SupabaseVisitPrivateNoteUpsert(
            visitId: visitID,
            userId: userID,
            note: "Dial the grind finer"
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any]
        )

        #expect(object["visit_id"] as? String == visitID.uuidString)
        #expect(object["user_id"] as? String == userID.uuidString)
        #expect(object["note"] as? String == "Dial the grind finer")
        #expect(object["caption"] == nil)
    }

    @Test func quickSipRequiresOnlyContextDrinkAndOverallRating() {
        var draft = SipDraft(
            context: .cafe,
            cafe: Cafe(name: "Quick Sip Cafe"),
            drinkName: "Cortado",
            overallScore: 4.5,
            socialCaption: "",
            privateNotes: "",
            visibility: .private
        )

        #expect(draft.hasRequiredCore)
        #expect(draft.localPhotoNames.isEmpty)
        #expect(draft.socialCaption.isEmpty)

        draft.overallScore = 0
        #expect(!draft.hasRequiredCore)
    }

    @Test func naturalLanguageDrinkAnalysisDefaultsToHotAndKeepsOrderEvidenceSeparate() {
        let analysis = DrinkAnalysisParser.analyze("Strawberry matcha with oat milk")
        let matchaLatte = DrinkAnalysisParser.analyze("Iced strawberry matcha latte with oat milk")
        let hojichaLatte = DrinkAnalysisParser.analyze("Hojicha latte with macadamia milk")
        let chaiLatte = DrinkAnalysisParser.analyze("Dirty chai latte with whole milk")
        let hotLatteWithColdFoam = DrinkAnalysisParser.analyze("Vanilla latte with cold foam")

        #expect(analysis.rawDrinkName == "Strawberry matcha with oat milk")
        #expect(analysis.family == .matcha)
        #expect(analysis.preparation == .matcha)
        #expect(analysis.temperature == .hot)
        #expect(analysis.milk == "oat milk")
        #expect(analysis.flavors.contains("strawberry"))
        #expect(analysis.orderPreferenceSignals.contains("chooses_fruit_flavors"))
        #expect(analysis.orderPreferenceSignals.contains("chooses_sweet_flavors"))
        #expect(!analysis.orderPreferenceSignals.contains("tastes_sweet"))
        #expect(matchaLatte.family == .matcha)
        #expect(matchaLatte.preparation == .latte)
        #expect(hojichaLatte.family == .hojicha)
        #expect(hojichaLatte.preparation == .latte)
        #expect(hojichaLatte.milk == "macadamia milk")
        #expect(chaiLatte.family == .chai)
        #expect(chaiLatte.preparation == .latte)
        #expect(hotLatteWithColdFoam.temperature == .hot)
    }

    @Test func naturalLanguageDrinkAnalysisRecognizesIcedEspressoAndDefaultsToTwoShots() {
        let analysis = DrinkAnalysisParser.analyze("Iced cinnamon and orange cortado")

        #expect(analysis.family == .espresso)
        #expect(analysis.preparation == .cortado)
        #expect(analysis.temperature == .iced)
        #expect(analysis.espressoShotCount == 2)
        #expect(analysis.flavors == ["orange", "cinnamon"])
        #expect(analysis.estimatedCaffeineMilligrams == 126)
    }

    @Test func semanticSipTagsDescribeTheRitualInsteadOfRepeatingDrinkTokens() {
        let cinnamonBun = SemanticSipTagEngine.suggestions(
            drinkName: "Cinnamon bun latte",
            analysis: DrinkAnalysisParser.analyze("Cinnamon bun latte"),
            context: .cafe
        )
        let washedChemex = SemanticSipTagEngine.suggestions(
            drinkName: "Washed Ethiopian Chemex",
            analysis: DrinkAnalysisParser.analyze("Washed Ethiopian Chemex"),
            context: .home
        )
        let strawberryMatcha = SemanticSipTagEngine.suggestions(
            drinkName: "Strawberry matcha with oat milk",
            analysis: DrinkAnalysisParser.analyze("Strawberry matcha with oat milk"),
            context: .cafe
        )

        #expect(cinnamonBun.contains("Bakery-inspired"))
        #expect(cinnamonBun.contains("Spice-led order"))
        #expect(cinnamonBun.contains("Dessert-style"))
        #expect(!cinnamonBun.contains("Cinnamon"))
        #expect(!cinnamonBun.contains("Latte"))
        #expect(washedChemex.contains("Washed process"))
        #expect(washedChemex.contains("Manual brew"))
        #expect(washedChemex.contains("Single-origin"))
        #expect(strawberryMatcha.contains("Berry-inspired"))
        #expect(strawberryMatcha.contains("Plant-milk pick"))
        #expect(strawberryMatcha.contains("Matcha creation"))
    }

    @Test func caffeineEstimatesUsePreparationAveragesWithoutUserEnteredMilligrams() {
        let largeLatte = DrinkAnalysisParser.analyze(
            "Vanilla latte",
            servingVolumeMilliliters: 473
        )
        let largeChemex = DrinkAnalysisParser.analyze(
            "Washed Ethiopian Chemex",
            servingVolumeMilliliters: 600
        )
        let decafSingle = DrinkAnalysisParser.analyze("Decaf vanilla latte, single shot")
        let unknown = DrinkAnalysisParser.analyze("House seasonal special")

        #expect(largeLatte.estimatedCaffeineMilligrams == 126)
        #expect(largeChemex.estimatedCaffeineMilligrams == 240)
        #expect(decafSingle.estimatedCaffeineMilligrams == 6)
        #expect(unknown.coverage == .excluded)
        #expect(unknown.estimatedCaffeineMilligrams == nil)
    }

    @Test func tastingLensKeepsPersonalStarsIndependentFromLegacyCriteria() {
        var draft = SipDraft(
            captureMode: .addDetails,
            context: .cafe,
            cafe: Cafe(name: "Lens Cafe"),
            drinkName: "Cortado",
            overallScore: 1,
            visibility: .friends,
            ratingCriteria: [
                SipRatingCriterionSnapshot(name: "Aroma", score: 4, weight: 1, sortOrder: 0),
                SipRatingCriterionSnapshot(name: "Mouthfeel", score: 5, weight: 2, sortOrder: 1),
                SipRatingCriterionSnapshot(
                    name: "Value",
                    score: 1,
                    weight: 1,
                    sortOrder: 2,
                    relevanceOverride: false
                )
            ]
        )

        #expect(draft.resolvedOverallScore == 1)
        #expect(draft.ratingsDictionary["Value"] == nil)
        #expect(!draft.hasRequiredCore, "A new guided lens save requires a typed sensory snapshot.")

        draft.sensorySnapshot = SipSensorySnapshot(
            bundleID: "mugshot.sensory.en-US",
            bundleContentVersion: "2026.07.16.1",
            identity: SensoryDrinkIdentity(
                rawName: "Cortado",
                family: .milkCoffee,
                preparation: .cortado,
                confidence: 1,
                provenance: .user,
                userConfirmed: true
            ),
            depth: .guided,
            ownWords: "Dense and roasty",
            responses: [],
            personalEnjoyment: PersonalEnjoymentRating(value: 1)
        )
        #expect(draft.hasRequiredCore)
        #expect(draft.ratingsDictionary.isEmpty, "Typed observations must not be flattened into legacy star criteria.")

        draft.ratingCriteria[0].score = 0
        draft.ratingCriteria[1].score = 0
        #expect(draft.resolvedOverallScore == 1)

        draft.overallScore = 0
        #expect(!draft.hasRequiredCore)
    }

    @Test func halfStepRatingMapsTheTrailingHalfOfTheFifthStarToFive() {
        #expect(HalfStepStarRating.ratingValue(starIndex: 5, tapX: 10, starWidth: 40) == 4.5)
        #expect(HalfStepStarRating.ratingValue(starIndex: 5, tapX: 30, starWidth: 40) == 5)
        #expect(HalfStepStarRating.ratingValue(starIndex: 1, tapX: 10, starWidth: 40) == 1)
        #expect(HalfStepStarRating.ratingValue(starIndex: 1, tapX: 30, starWidth: 40) == 1)
        #expect(TastingLensEnjoymentRating.ratingValue(starIndex: 1, tapX: 10, starWidth: 40) == 1)
    }

    @Test func servingVolumeIsSeparateFromExtractionYieldAndSurvivesDraftEncoding() throws {
        var draft = SipDraft(
            context: .home,
            locationName: "Kitchen bar",
            drinkName: "Double espresso",
            overallScore: 4,
            brewDetails: BrewDetails(
                doseGrams: 18,
                yieldGrams: 36,
                servingVolumeMilliliters: 120,
                espressoShotCount: 2
            ),
            composerExperience: .guided,
            guidedStep: .audience,
            memoryDetailsExpanded: true
        )
        draft.refreshDrinkAnalysis()

        let restored = try JSONDecoder().decode(SipDraft.self, from: JSONEncoder().encode(draft))
        #expect(restored.brewDetails.yieldGrams == 36)
        #expect(restored.brewDetails.servingVolumeMilliliters == 120)
        #expect(restored.brewDetails.espressoShotCount == 2)
        #expect(restored.guidedStep == .audience)
        #expect(restored.composerExperience == .guided)
        #expect(restored.drinkAnalysis?.estimatedCaffeineMilligrams == 126)
    }

    @Test func drinkAnalysisRetriesAreDurableIdempotentAndAccountScoped() {
        let suiteName = "DrinkAnalysisRetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DrinkAnalysisRetryStore(defaults: defaults)
        let owner = UUID()
        let otherUser = UUID()
        let visit = UUID()

        store.enqueue(visitId: visit, userId: owner)
        store.enqueue(visitId: visit, userId: owner)

        #expect(store.pendingVisitIDs(userId: owner) == [visit])
        #expect(store.pendingVisitIDs(userId: otherUser).isEmpty)

        store.remove(visitId: visit, userId: owner)
        #expect(store.pendingVisitIDs(userId: owner).isEmpty)
    }

    @Test func contextualVisibilityDefaultsAreRememberedOnlyForCafe() throws {
        let suiteName = "CafeVisibilityPreferenceStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = CafeVisibilityPreferenceStore(defaults: defaults)

        #expect(preferences.defaultCafeVisibility == .friends)
        preferences.rememberCafeVisibility(.everyone)
        #expect(preferences.defaultCafeVisibility == .everyone)

        var home = SipDraft(context: .home, visibility: .everyone)
        home.applyContextDefaults(using: preferences)
        #expect(home.visibility == .private)

        var recipe = SipDraft(context: .recipe, visibility: .friends)
        recipe.applyContextDefaults(using: preferences)
        #expect(recipe.visibility == .private)
    }

    @Test func composerWorkflowScaffoldingDoesNotCreateAnUntitledDraft() {
        let untouchedDraft = SipDraft(
            composerExperience: .guided,
            guidedStep: .context,
            v3Step: .setup
        )

        #expect(!untouchedDraft.hasDraftWorthyUserContent)

        let preselectedCafeDraft = SipDraft(
            launchContext: SipComposerLaunchContext(source: .cafeDetail),
            cafe: Cafe(name: "Mugshot Test Cafe"),
            composerExperience: .guided,
            guidedStep: .context,
            v3Step: .setup
        )

        #expect(preselectedCafeDraft.hasDraftWorthyUserContent)
    }

    @Test func everyonePublicationRequiresMediaOrIntentionalTextOnlyConfirmation() {
        #expect(
            SipPublicationPolicy.requirement(
                visibility: .private,
                photoCount: 0,
                socialCaption: "",
                confirmedTextOnlyEveryone: false
            ) == .ready
        )
        #expect(
            SipPublicationPolicy.requirement(
                visibility: .friends,
                photoCount: 0,
                socialCaption: "",
                confirmedTextOnlyEveryone: false
            ) == .ready
        )
        #expect(
            SipPublicationPolicy.requirement(
                visibility: .everyone,
                photoCount: 0,
                socialCaption: "",
                confirmedTextOnlyEveryone: false
            ) == .needsTextOrPhoto
        )
        #expect(
            SipPublicationPolicy.requirement(
                visibility: .everyone,
                photoCount: 0,
                socialCaption: "Bright and floral",
                confirmedTextOnlyEveryone: false
            ) == .needsTextOnlyConfirmation
        )
        #expect(
            SipPublicationPolicy.requirement(
                visibility: .everyone,
                photoCount: 0,
                socialCaption: "Bright and floral",
                confirmedTextOnlyEveryone: true
            ) == .ready
        )
        #expect(
            SipPublicationPolicy.requirement(
                visibility: .everyone,
                photoCount: 1,
                socialCaption: "",
                confirmedTextOnlyEveryone: false
            ) == .ready
        )
    }

    @Test func brewAgainCreatesIndependentHomeAttemptFromRecipeVersion() {
        let recipeID = UUID()
        let originalDate = Date(timeIntervalSince1970: 100)
        let repeatDate = Date(timeIntervalSince1970: 200)
        let recipe = SipDraft(
            createdAt: originalDate,
            context: .recipe,
            drinkName: "Washed Ethiopia V60",
            overallScore: 4.5,
            visibility: .private,
            ratingCriteria: [
                SipRatingCriterionSnapshot(name: "Clarity", score: 5, weight: 1.5, sortOrder: 0)
            ],
            brewMethod: "V60",
            equipment: "Kettle and scale",
            brewDetails: BrewDetails(
                beans: "Ethiopia Hambela",
                doseGrams: 15,
                yieldGrams: 250,
                recipeName: "Bright V60",
                recipeVersion: "v3",
                recipeIdentityID: recipeID,
                steps: [BrewRecipeStep(instruction: "Bloom for 45 seconds")]
            )
        )

        let attempt = SipDraft.brewAgain(from: recipe, ownerUserID: UUID(), now: repeatDate)

        #expect(attempt.id != recipe.id)
        #expect(attempt.createdAt == repeatDate)
        #expect(attempt.context == .home)
        #expect(attempt.visibility == .private)
        #expect(attempt.overallScore == 0)
        #expect(attempt.ratingCriteria.first?.score == 0)
        #expect(attempt.brewDetails.sourceRecipeIdentityID == recipeID)
        #expect(attempt.brewDetails.sourceRecipeVersion == "v3")
        #expect(attempt.brewDetails.recipeName == nil)
        #expect(attempt.brewDetails.steps?.first?.instruction == "Bloom for 45 seconds")
    }

    @Test func sipDraftStoreRestoresFieldsAndMediaAcrossRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SipDraftStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SipDraftStore(baseDirectory: directory)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        let draft = SipDraft(
            context: .home,
            locationName: "Kitchen bar",
            drinkName: "Espresso",
            overallScore: 4,
            privateNotes: "Try a finer grind",
            visibility: .private
        )

        let stored = try store.save(draft, images: [image])
        let restored = try #require(store.load())

        #expect(stored.localPhotoNames.count == 1)
        #expect(restored.draft.id == draft.id)
        #expect(restored.draft.privateNotes == "Try a finer grind")
        #expect(restored.images.count == 1)
    }

    @Test func sipDraftStoreParksEarlierDraftsForNewEntryPoints() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SipDraftStoreMultiTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SipDraftStore(baseDirectory: directory)
        let recipe = SipDraft(context: .recipe, drinkName: "Recipe draft", overallScore: 4, visibility: .private)
        let cafe = SipDraft(
            launchContext: SipComposerLaunchContext(source: .cafeDetail),
            cafe: Cafe(name: "Preselected Cafe"),
            drinkName: "Cafe draft",
            overallScore: 4.5,
            visibility: .friends
        )

        _ = try store.save(recipe, images: [])
        _ = try store.save(cafe, images: [])

        #expect(store.allDrafts().count == 2)
        #expect(store.load()?.draft.id == cafe.id)

        store.remove(cafe)
        #expect(store.load()?.draft.id == recipe.id)
    }

    @Test func remoteRepeatSipKeepsReusableContextAndResetsMemoryFields() {
        let userID = UUID()
        let cafeID = UUID()
        let visitID = UUID()
        let row = SupabaseVisitRow(
            id: visitID,
            userId: userID,
            cafeId: cafeID,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Iced orange cortado",
            caption: "A social memory",
            notes: nil,
            visibility: "Everyone",
            ratings: ["Aroma": 4.5, "Mouthfeel": 4],
            categoryScores: [
                SupabaseVisitCategoryScore(name: "Aroma", score: 4.5, weight: 1),
                SupabaseVisitCategoryScore(name: "Mouthfeel", score: 4, weight: 2)
            ],
            overallScore: 4.2,
            posterPhotoURL: "https://example.com/sip.jpg",
            contextType: "Cafe",
            locationName: nil,
            cityState: "Charleston, SC",
            brewMethod: nil,
            createdAt: "2026-07-01T12:00:00Z",
            brewDetails: BrewDetails(tags: ["sunny"], companions: ["Amanda"])
        )
        let cafe = SupabaseCafeSummary(
            id: cafeID,
            name: "Harbinger Cafe",
            address: "1107 King St",
            city: "Charleston",
            latitude: 32.8,
            longitude: -79.9,
            applePlaceId: nil,
            websiteURL: nil
        )
        let summary = RemoteVisitSummary(visit: row, cafe: cafe)
        let repeated = SipDraft.repeatSip(
            from: summary,
            ownerUserID: userID,
            now: Date(timeIntervalSince1970: 500)
        )

        #expect(repeated.id != visitID)
        #expect(repeated.launchContext.sourceVisitID == visitID)
        #expect(repeated.cafe?.remoteCafeId == cafeID)
        #expect(repeated.drinkName == "Iced orange cortado")
        #expect(repeated.tags == ["sunny"])
        #expect(repeated.companions.isEmpty)
        #expect(repeated.socialCaption.isEmpty)
        #expect(repeated.privateNotes.isEmpty)
        #expect(repeated.localPhotoNames.isEmpty)
        #expect(repeated.ratingCriteria.allSatisfy { $0.score == 0 })
    }

    @Test func remoteRecipeBrewAgainReferencesExactRecipeAndCreatesPrivateAttempt() {
        let recipeIdentityID = UUID()
        let recipeVersionID = UUID()
        let row = SupabaseVisitRow(
            id: UUID(),
            userId: UUID(),
            cafeId: nil,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Washed Ethiopian V60",
            caption: "",
            notes: nil,
            visibility: "Private",
            ratings: ["Clarity": 5],
            overallScore: 5,
            posterPhotoURL: nil,
            contextType: "Recipe",
            locationName: "Home",
            cityState: nil,
            brewMethod: "V60",
            createdAt: "2026-07-01T12:00:00Z",
            equipment: "Kettle and scale",
            brewDetails: BrewDetails(
                beans: "Ethiopia Hambela",
                recipeName: "Bright V60",
                recipeVersion: "v3",
                recipeIdentityID: recipeIdentityID,
                steps: [BrewRecipeStep(instruction: "Bloom for 45 seconds")]
            ),
            recipeVersionID: recipeVersionID
        )
        let summary = RemoteVisitSummary(visit: row, cafe: nil)
        let projection = RemoteVisitRecipeProjection(
            recipeIdentityID: recipeIdentityID,
            recipeVersionID: recipeVersionID,
            recipeName: "Bright V60",
            versionNumber: 3,
            versionLabel: "v3",
            visibilityValue: "private",
            sourceKindValue: "original",
            sourceRecipeVersionID: nil,
            brewMethod: "V60",
            equipment: "Kettle and scale",
            brewDetails: BrewDetails(
                beans: "Ethiopia Hambela",
                steps: [BrewRecipeStep(instruction: "Bloom for 45 seconds")]
            ),
            canSaveAndAdapt: false
        )
        let detail = RemoteVisitDetail(
            summary: summary,
            photos: [],
            comments: [],
            likeCount: 0,
            currentUserHasLiked: false,
            recipeProjection: projection
        )
        let attempt = SipDraft.brewAgain(from: detail, ownerUserID: UUID())

        #expect(attempt.context == .home)
        #expect(attempt.visibility == .private)
        #expect(attempt.launchContext.source == .brewAgain)
        #expect(attempt.launchContext.sourceRecipeIdentityID == recipeIdentityID)
        #expect(attempt.brewDetails.sourceRecipeIdentityID == recipeIdentityID)
        #expect(attempt.brewDetails.sourceRecipeVersion == "v3")
        #expect(attempt.brewDetails.recipeName == nil)
        #expect(attempt.brewDetails.steps?.first?.instruction == "Bloom for 45 seconds")
        #expect(attempt.overallScore == 0)
    }

    @Test func journalProjectionSearchIncludesOwnerNoteAndTags() {
        let row = SupabaseVisitRow(
            id: UUID(), userId: UUID(), cafeId: nil,
            drinkType: "Coffee", drinkTypeCustom: nil, drinkSubtype: "Flat white",
            caption: "Quiet morning", notes: nil, visibility: "Private",
            ratings: ["Overall": 4], overallScore: 4, posterPhotoURL: nil,
            contextType: "Home", locationName: "Kitchen", cityState: nil,
            brewMethod: "Espresso", createdAt: "2026-07-01T12:00:00Z",
            brewDetails: BrewDetails(tags: ["dial-in"])
        )
        let entry = JournalEntryProjection(
            summary: RemoteVisitSummary(visit: row, cafe: nil),
            privateNote: "Use the finer grind next time",
            isBookmarked: false
        )

        #expect(entry.matches("finer grind"))
        #expect(entry.matches("dial-in"))
        #expect(entry.matches("flat white"))
        #expect(!entry.matches("Harbinger"))
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

        let cafeSummary = RemoteCafeExperienceSummary(
            schemaVersion: 1,
            cafeID: cafeId,
            scope: "personal",
            physicalSessionCount: 3,
            ratedSessionCount: 3,
            contributorCount: 1,
            averageCafeRating: 2,
            latestNextMove: "come_back_try_another",
            relationshipStageValue: "trend",
            communityThresholdMet: true
        )
        let otherCafeSummary = RemoteCafeExperienceSummary(
            schemaVersion: 1,
            cafeID: otherCafeId,
            scope: "personal",
            physicalSessionCount: 1,
            ratedSessionCount: 1,
            contributorCount: 1,
            averageCafeRating: 5,
            latestNextMove: "come_back_for_this",
            relationshipStageValue: "first_impression",
            communityThresholdMet: true
        )

        let cafeExperienceRanking = RemoteProfileCafeRanking.calculate(
            from: visits,
            cafeExperienceSummaries: [cafeSummary, otherCafeSummary]
        )
        #expect(cafeExperienceRanking.basis == .cafeExperience)
        #expect(cafeExperienceRanking.entries.map(\.cafe.id) == [otherCafeId, cafeId])
        #expect(cafeExperienceRanking.entries.first?.score == 5)
        #expect(cafeExperienceRanking.entries.first?.ratedCafeSessionCount == 1)

        let partiallyRated = RemoteProfileCafeRanking.calculate(
            from: visits,
            cafeExperienceSummaries: [otherCafeSummary]
        )
        #expect(partiallyRated.basis == .cafeExperience)
        #expect(partiallyRated.entries.map(\.cafe.id) == [otherCafeId])

        let sipAverageFallback = RemoteProfileCafeRanking.calculate(
            from: visits,
            cafeExperienceSummaries: []
        )
        #expect(sipAverageFallback.basis == .sipAverageLegacy)
        #expect(sipAverageFallback.entries.first?.cafe.id == cafeId)
        #expect(sipAverageFallback.entries.first?.score == 4.5)
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
        #expect(cafes.first?.friends.isEmpty == true)
    }

    @Test func friendCafeDiscoveryDecodesFriendOnlyContext() throws {
        let cafeID = UUID()
        let friendID = UUID()
        let json = """
        [{
          "cafe_id":"\(cafeID)","name":"Friend Bean","address":"2 Main St","city":"Pittsburgh",
          "latitude":40.4,"longitude":-80.0,"identity_key":"apple:friend-bean","section":"loved_by_friends",
          "ranking_score":0.91,"ranking_reason":"Shared by 1 friend","distance_km":1.2,
          "average_rating":4.7,"visible_visit_count":2,"friend_count":1,
          "top_drinks":[],"recent_cover":null,"is_saved":false,"is_visited":false,
          "friend_profiles":[{
            "user_id":"\(friendID)","display_name":"Alice","username":"alice","avatar_url":"https://example.com/alice.jpg",
            "average_rating":4.7,"sip_count":2
          }]
        }]
        """

        let cafe = try #require(JSONDecoder().decode([DiscoveryCafe].self, from: Data(json.utf8)).first)
        let friend = try #require(cafe.friends.first)
        #expect(cafe.averageRating == 4.7)
        #expect(cafe.friendCount == 1)
        #expect(friend.id == friendID)
        #expect(friend.sipCount == 2)
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

    @Test func structuredHomeRecipeEncodesWithoutCafeAndKeepsBrewVariables() throws {
        let template = RatingTemplate(categories: [RatingCategory(name: "Taste", weight: 1)])
        let details = BrewDetails(
            doseGrams: 18,
            yieldGrams: 36,
            brewTimeSeconds: 27,
            beanOrigin: "Peru",
            roastLevel: "Medium-light",
            grindSetting: "4.2",
            waterTemperatureCelsius: 94,
            recipeName: "Peru Mocha",
            recipeVersion: "v3",
            additions: "Mocha sauce"
        )
        let insert = try SupabaseVisitInsert.make(
            userId: UUID(),
            remoteCafe: nil,
            entryContext: .recipe,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Mocha",
            brewMethod: "Espresso",
            equipment: "Lelit Bianca",
            brewDetails: details,
            caption: "Sweeter and cleaner",
            notes: "Use less sauce next time",
            visibility: .private,
            ratings: ["Taste": 4.5],
            ratingTemplate: template
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(insert)) as? [String: Any]
        )
        let encodedDetails = try #require(object["brew_details"] as? [String: Any])

        #expect(object["cafe_id"] == nil)
        #expect(object["context_type"] as? String == "Recipe")
        #expect(object["location_name"] as? String == "Home")
        #expect(object["brew_method"] as? String == "Espresso")
        #expect(object["equipment"] as? String == "Lelit Bianca")
        #expect(encodedDetails["doseGrams"] as? Double == 18)
        #expect(encodedDetails["yieldGrams"] as? Double == 36)
        #expect(encodedDetails["brewTimeSeconds"] as? Int == 27)
        #expect(details.extractionSummary == "18g in · 36g out · 27 sec")
        #expect(details.recipeDisplayName == "Peru Mocha · v3")
    }

    @Test func localVisitPrefersImmutableNaturalLanguageDrinkName() {
        let rawName = "Iced cinnamon and orange cortado"
        let visit = Visit(
            cafeId: UUID(),
            userId: UUID(),
            drinkType: .coffee,
            drinkAnalysis: DrinkAnalysisParser.analyze(rawName)
        )

        #expect(visit.journalDrinkName == rawName)
    }

    @Test func tasteIdentityUsesCafeAndHomeJournalEvidence() {
        let userID = UUID()
        let cafe = SupabaseCafeSummary(
            id: UUID(), name: "Neighborhood Coffee", address: nil, city: nil,
            latitude: nil, longitude: nil, applePlaceId: nil, websiteURL: nil
        )
        let cafeVisit = RemoteVisitSummary(
            visit: SupabaseVisitRow(
                id: UUID(), userId: userID, cafeId: cafe.id, drinkType: "Coffee",
                drinkTypeCustom: nil, drinkSubtype: "Cortado", caption: "Good", notes: nil,
                visibility: "everyone", ratings: ["Taste": 4], overallScore: 4,
                posterPhotoURL: nil, contextType: "Cafe", locationName: cafe.name,
                cityState: nil, brewMethod: nil, createdAt: "2026-07-12T12:00:00Z"
            ),
            cafe: cafe
        )
        let homeVisit = RemoteVisitSummary(
            visit: SupabaseVisitRow(
                id: UUID(), userId: userID, cafeId: nil, drinkType: "Coffee",
                drinkTypeCustom: nil, drinkSubtype: "Mocha", caption: "Dialed in", notes: nil,
                visibility: "private", ratings: ["Taste": 4.5], overallScore: 4.5,
                posterPhotoURL: nil, contextType: "home", locationName: "Home",
                cityState: nil, brewMethod: "Espresso", createdAt: "2026-07-13T12:00:00Z",
                equipment: "Lelit Bianca",
                brewDetails: BrewDetails(doseGrams: 18, yieldGrams: 36, brewTimeSeconds: 27)
            ),
            cafe: nil
        )

        let identity = TasteIdentitySummary.calculate(from: [cafeVisit, homeVisit])

        #expect(identity.title == "The Neighborhood Experimenter")
        #expect(identity.patterns.contains { $0.text.contains("Espresso") })
        #expect(identity.patterns.contains { $0.text.contains("1:2.0") })
        #expect(homeVisit.visit.journalContext == .home)
    }

    @Test func resolvedCafeSummaryDecodesCanonicalStatsAndState() throws {
        let cafeID = UUID()
        let json = """
        [{
          "cafe_id":"\(cafeID.uuidString)","name":"Babas on Cannon","address":"11 Cannon St",
          "city":"Charleston","latitude":32.79164,"longitude":-79.94129,
          "identity_key":"geo:babas on cannon|32.79164|-79.94129","apple_place_id":null,
          "website_url":"https://example.com","average_rating":3.0,"visible_visit_count":1,
          "recent_cover":"https://example.com/cover.jpg","is_favorite":true,
          "want_to_try":false,"is_visited":true
        }]
        """
        let summary = try #require(JSONDecoder().decode([ResolvedCafeSummary].self, from: Data(json.utf8)).first)

        #expect(summary.cafeID == cafeID)
        #expect(summary.averageRating == 3)
        #expect(summary.visibleVisitCount == 1)
        #expect(summary.isFavorite)
        #expect(summary.isVisited)
        #expect(summary.remoteCafe.id == cafeID)
    }

    @Test func explainableTasteIdentityRequiresThreeEntriesAndSeparatesEvidenceFamilies() {
        let userID = UUID()
        let visitIDs = [UUID(), UUID(), UUID()]
        let emerging = RemoteTasteSignal(
            id: UUID(), userID: userID, signalType: .orderPreference,
            attribute: "chooses_fruit_flavors", supportCount: 2, confidence: 0.25,
            averageScore: nil, evidenceVisitIDs: Array(visitIDs.prefix(2)),
            calculationVersion: "taste-signals-1", ownerState: .active,
            ownerLabel: nil, updatedAt: "2026-07-14T00:00:00Z"
        )
        let sensory = RemoteTasteSignal(
            id: UUID(), userID: userID, signalType: .sensoryEvaluation,
            attribute: "mouthfeel", supportCount: 3, confidence: 0.375,
            averageScore: 4.5, evidenceVisitIDs: visitIDs,
            calculationVersion: "taste-signals-1", ownerState: .active,
            ownerLabel: nil, updatedAt: "2026-07-14T00:00:00Z"
        )

        let summary = TasteIdentitySummary.calculate(from: [emerging, sensory])

        #expect(!emerging.isDurableClaim)
        #expect(sensory.isDurableClaim)
        #expect(summary.title.hasPrefix("The "))
        #expect(summary.descriptors.count == 3)
        #expect(summary.descriptors[1] == "Texture-Led")
        #expect(summary.patterns.count == 1)
        #expect(summary.patterns[0].text.contains("Mouthfeel"))
        #expect(!summary.patterns[0].text.contains("Fruit"))
    }

    @Test func mugshotPassportUsesThreeDescriptorsAndAStableLargeTitleSystem() {
        let userID = UUID()
        let visitIDs = [UUID(), UUID(), UUID()]
        let fruit = RemoteTasteSignal(
            id: UUID(), userID: userID, signalType: .orderPreference,
            attribute: "chooses_fruit_flavors", supportCount: 3, confidence: 0.8,
            averageScore: nil, evidenceVisitIDs: visitIDs,
            calculationVersion: "taste-signals-1", ownerState: .active,
            ownerLabel: nil, updatedAt: "2026-07-14T00:00:00Z"
        )
        let ambiance = RemoteTasteSignal(
            id: UUID(), userID: userID, signalType: .sensoryEvaluation,
            attribute: "ambiance", supportCount: 4, confidence: 0.9,
            averageScore: 4.25, evidenceVisitIDs: visitIDs,
            calculationVersion: "taste-signals-1", ownerState: .active,
            ownerLabel: nil, updatedAt: "2026-07-14T00:00:00Z"
        )

        let first = TasteIdentitySummary.calculate(from: [fruit, ambiance], visits: [])
        let second = TasteIdentitySummary.calculate(from: [ambiance, fruit], visits: [])

        #expect(TasteIdentitySummary.possiblePassportTitles >= 500)
        #expect(first.descriptors == ["Fruit-Forward", "Ambiance-Led", "Memory Keeper"])
        #expect(first.title == second.title)
        #expect(first.title.hasPrefix("The "))
        #expect(!first.isForming)
    }

    @Test func tasteSignalCorrectionChangesTheClaimWithoutChangingEvidence() {
        let visits = [UUID(), UUID(), UUID()]
        let signal = RemoteTasteSignal(
            id: UUID(), userID: UUID(), signalType: .orderPreference,
            attribute: "chooses_sweetened_drinks", supportCount: 3, confidence: 0.375,
            averageScore: nil, evidenceVisitIDs: visits,
            calculationVersion: "taste-signals-1", ownerState: .corrected,
            ownerLabel: "Dessert-like orders", updatedAt: "2026-07-14T00:00:00Z"
        )

        #expect(signal.displayAttribute == "Dessert-like orders")
        #expect(signal.claimText.contains("Dessert-like orders"))
        #expect(signal.evidenceVisitIDs == visits)
        #expect(signal.signalType == .orderPreference)
    }

    @Test func rankedFeedDecodesStructuredRecommendationReason() throws {
        let visitID = UUID()
        let json = """
        [{"visit_id":"\(visitID.uuidString)","feed_score":0.82,"created_at":"2026-07-14T00:00:00Z","ranking_reason":"Matches patterns in your Taste Identity","reason_type":"taste_match"}]
        """

        let reference = try #require(JSONDecoder().decode([RankedFeedReference].self, from: Data(json.utf8)).first)

        #expect(reference.visitID == visitID)
        #expect(reference.rankingReason == "Matches patterns in your Taste Identity")
        #expect(reference.reasonType == "taste_match")
    }

    @Test func drinkInterpretationCorrectionCannotContainCaffeineOrPrivateJournalText() throws {
        let correction = DrinkAnalysisCorrection(
            canonicalFamily: nil,
            preparation: "cortado",
            temperature: "iced",
            espressoShotCount: 2,
            servingVolumeMilliliters: 355
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(correction)) as? [String: Any]
        )

        #expect(object["preparation"] as? String == "cortado")
        #expect(object["temperature"] as? String == "iced")
        #expect(object["espresso_shot_count"] as? Int == 2)
        #expect(object["serving_volume_ml"] as? Double == 355)
        #expect(object["estimated_caffeine_mg"] == nil)
        #expect(object["private_notes"] == nil)
        #expect(object["caption"] == nil)
    }

    @Test func friendCompatibilityCommunicatesEvidenceWithoutCompetitiveRanking() throws {
        let json = """
        [{"evidence_level":"some_overlap","shared_signal_count":2,"shared_attributes":["mouthfeel","iced drinks"],"explanation":"A few journal patterns overlap."}]
        """
        let compatibility = try #require(
            JSONDecoder().decode([FriendCompatibility].self, from: Data(json.utf8)).first
        )

        #expect(compatibility.title == "Some taste overlap")
        #expect(compatibility.sharedSignalCount == 2)
        #expect(compatibility.sharedAttributes == ["mouthfeel", "iced drinks"])
        #expect(!compatibility.explanation.lowercased().contains("rank"))
        #expect(!compatibility.explanation.contains("%"))
    }

    @Test func sharedRecipeDecodesOnlyBrewInstructions() throws {
        let recommendationID = UUID()
        let identityID = UUID()
        let versionID = UUID()
        let senderID = UUID()
        let json = """
        [{
          "recommendation_id":"\(recommendationID)",
          "recipe_identity_id":"\(identityID)",
          "recipe_version_id":"\(versionID)",
          "recipe_name":"Morning V60",
          "version_number":2,
          "version_label":"Sweeter finish",
          "brew_details":{"doseGrams":18,"yieldGrams":300,"brewTimeSeconds":180},
          "sender_id":"\(senderID)",
          "note":"Try a finer grind",
          "shared_at":"2026-07-14T00:00:00Z"
        }]
        """
        let recipe = try #require(
            JSONDecoder().decode([SharedRecipeRecord].self, from: Data(json.utf8)).first
        )

        #expect(recipe.recipeName == "Morning V60")
        #expect(recipe.brewDetails.doseGrams == 18)
        #expect(recipe.brewDetails.yieldGrams == 300)
        #expect(recipe.brewDetails.extractionSummary == "18g in · 300g out · 180 sec")
    }

    @Test func sipReactionsRemainSmallAndCoffeeFocused() {
        #expect(SipReaction.allCases.count == 4)
        #expect(Set(SipReaction.allCases.map(\.rawValue)) == ["want_to_try", "great_find", "dialed_in", "cozy"])
    }

    @Test func mapDiscoveryScopesKeepSourcesExplicitAndAuthenticationAware() {
        #expect(MapDiscoveryScope.all.sections(isAuthenticated: false) == [.nearby, .trending])
        #expect(MapDiscoveryScope.friends.sections(isAuthenticated: false).isEmpty)
        #expect(MapDiscoveryScope.friends.sections(isAuthenticated: true) == [.lovedByFriends])
        #expect(MapDiscoveryScope.favorites.sections(isAuthenticated: true).isEmpty)
        #expect(MapDiscoveryScope.wantToTry.sections(isAuthenticated: true).isEmpty)
        #expect(MapDiscoveryScope.visited.sections(isAuthenticated: true).isEmpty)
        #expect(MapDiscoveryScope.all.sections(isAuthenticated: true) == [.nearby, .lovedByFriends, .trending])
        #expect(MapDiscoveryScope.all.explanation.lowercased().contains("together"))
        #expect(
            MapDiscoveryScope.available(isAuthenticated: false) ==
                [.visited, .favorites, .wantToTry, .discovery, .all]
        )
    }

    @Test func mapDiscoveryRadiusUsesAZeroToFiftyMileControl() {
        #expect(MapDiscoveryRadius.miles == 0...50)
        #expect(MapDiscoveryRadius.kilometers(forMiles: 0) == 1.609_344)
        #expect(abs(MapDiscoveryRadius.kilometers(forMiles: 50) - 80.467_2) < 0.000_1)
    }

    @Test func sipShareCardPayloadContainsOnlyExplicitlyShareableMemoryFields() {
        let payload = SipShareCardPayload(
            authorName: "Journal Owner",
            drinkName: "Cortado",
            cafeName: "Mugshot Test Cafe",
            rating: 4.5,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            publicCaption: "A bright finish",
            remotePhotoURL: "https://example.com/sip.jpg",
            localPhotoPath: nil
        )
        let fieldNames = Set(Mirror(reflecting: payload).children.compactMap(\.label))

        #expect(fieldNames == [
            "visitID", "visibility", "isOwner", "isRemote",
            "authorName", "drinkName", "cafeName", "rating", "date",
            "publicCaption", "remotePhotoURL", "localPhotoPath"
        ])
        #expect(!fieldNames.contains("privateNote"))
        #expect(!fieldNames.contains("notes"))
        #expect(payload.shareText == "Journal Owner remembered Cortado at Mugshot Test Cafe on Mugshot.")
    }

    @Test func journalReflectionUsesOnlyCoveredCaffeineEstimates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let referenceDate = try #require(ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z"))
        let entries = [
            Self.reflectionEntry(
                drink: "Double cortado", context: "Cafe", score: 4.5,
                createdAt: "2026-07-03T12:00:00Z", estimatedCaffeine: 126,
                caffeineCoverage: DrinkAnalysisCoverage.estimated.rawValue
            ),
            Self.reflectionEntry(
                drink: "Washed Ethiopian Chemex", context: "Home", score: 4,
                createdAt: "2026-07-08T12:00:00Z", estimatedCaffeine: 172,
                caffeineCoverage: DrinkAnalysisCoverage.estimated.rawValue
            ),
            Self.reflectionEntry(
                drink: "Seasonal special", context: "Cafe", score: 3.5,
                createdAt: "2026-07-10T12:00:00Z", estimatedCaffeine: nil,
                caffeineCoverage: DrinkAnalysisCoverage.excluded.rawValue
            ),
            Self.reflectionEntry(
                drink: "June latte", context: "Cafe", score: 3,
                createdAt: "2026-06-10T12:00:00Z", estimatedCaffeine: 126,
                caffeineCoverage: DrinkAnalysisCoverage.estimated.rawValue
            )
        ]

        let summary = JournalReflectionEngine.summary(
            for: .month, entries: entries, referenceDate: referenceDate, calendar: calendar
        )

        #expect(summary.entryCount == 3)
        #expect(summary.homeExperimentCount == 1)
        #expect(summary.caffeine?.roundedTotal == 298)
        #expect(summary.caffeine?.coveredEntries == 2)
        #expect(summary.caffeine?.totalEntries == 3)
        #expect(summary.caffeine?.coverageText == "Based on 2 of 3 sips")
        #expect(summary.ratingChange == 1)
    }

    @Test func journalReflectionDoesNotInventZeroCaffeineWhenCoverageIsUnknown() {
        let entry = Self.reflectionEntry(
            drink: "House special", context: "Cafe", score: 4,
            createdAt: "2026-07-10T12:00:00Z", estimatedCaffeine: nil,
            caffeineCoverage: DrinkAnalysisCoverage.excluded.rawValue
        )

        let summary = JournalReflectionEngine.summary(
            for: .month,
            entries: [entry],
            referenceDate: ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z") ?? Date()
        )

        #expect(summary.entryCount == 1)
        #expect(summary.caffeine == nil)
    }

    @Test func journalReflectionCarriesPrivatePeopleCountsWithoutChangingSipTotals() {
        let person = JournalPeopleCount(
            accountID: UUID(),
            displayName: "Amanda",
            username: "amanda",
            avatarURL: nil,
            sipCount: 16,
            latestSharedSipAt: "2026-07-10T12:00:00Z"
        )
        let entry = Self.reflectionEntry(
            drink: "Cortado",
            context: "Cafe",
            score: 4,
            createdAt: "2026-07-10T12:00:00Z",
            estimatedCaffeine: nil,
            caffeineCoverage: DrinkAnalysisCoverage.excluded.rawValue
        )

        let summary = JournalReflectionEngine.summary(
            for: .month,
            entries: [entry],
            people: [person],
            referenceDate: ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z") ?? Date()
        )

        #expect(summary.entryCount == 1)
        #expect(summary.people == [person])
        #expect(summary.people.first?.personLabel == "Amanda")
        #expect(summary.people.first?.sipCount == 16)
    }

    @Test func journalMilestonesRewardMemoryAndLearningInsteadOfConsumptionPressure() {
        let entries = [
            Self.reflectionEntry(
                drink: "V60", context: "Home", score: 4,
                createdAt: "2026-07-10T12:00:00Z", estimatedCaffeine: nil,
                caffeineCoverage: DrinkAnalysisCoverage.excluded.rawValue,
                caption: "Dialed in a calmer finish"
            ),
            Self.reflectionEntry(
                drink: "Morning V60", context: "Recipe", score: 4.5,
                createdAt: "2026-07-11T12:00:00Z", estimatedCaffeine: nil,
                caffeineCoverage: DrinkAnalysisCoverage.excluded.rawValue
            )
        ]

        let milestones = JournalReflectionEngine.milestones(entries: entries)
        let combinedCopy = milestones.flatMap { [$0.title, $0.detail] }.joined(separator: " ").lowercased()

        #expect(milestones.contains(where: { $0.id == "first-home" }))
        #expect(milestones.contains(where: { $0.id == "first-recipe" }))
        #expect(!combinedCopy.contains("streak"))
        #expect(!combinedCopy.contains("most drinks"))
        #expect(!combinedCopy.contains("caffeine goal"))
    }

    @MainActor
    @Test func systemEntryRoutesPersistUntilExplicitlyConsumed() throws {
        let suite = "SipSystemRouterTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = SipSystemRouter(defaults: defaults)

        router.enqueue(.cameraSip)
        let pending = try #require(router.pendingRoute)
        #expect(pending.destination == .cameraSip)

        let restored = SipSystemRouter(defaults: defaults)
        #expect(restored.pendingRoute == pending)
        restored.consume(pending)
        #expect(restored.pendingRoute == nil)
    }

    @MainActor
    @Test func widgetAndShortcutDeepLinksUseOneKnownRouteContract() throws {
        let routes: [(String, SipSystemRoute.Destination)] = [
            ("mugshot://cafe-sip", .cafeSip),
            ("mugshot://home-sip", .homeSip),
            ("mugshot://repeat-sip", .repeatRecentSip),
            ("mugshot://brew-recipe", .brewSavedRecipe),
            ("mugshot://camera", .cameraSip),
            ("mugshot://journal", .journal)
        ]
        for (rawURL, destination) in routes {
            let url = try #require(URL(string: rawURL))
            #expect(SipSystemRouter.destination(for: url) == destination)
        }
        #expect(SipSystemRouter.destination(for: try #require(URL(string: "https://mugshotapp.co"))) == nil)
        #expect(SipSystemRouter.destination(for: try #require(URL(string: "mugshot://unknown"))) == nil)
    }

    private static func reflectionEntry(
        drink: String,
        context: String,
        score: Double,
        createdAt: String,
        estimatedCaffeine: Double?,
        caffeineCoverage: String,
        caption: String = ""
    ) -> JournalEntryProjection {
        let visitID = UUID()
        let row = SupabaseVisitRow(
            id: visitID, userId: UUID(), cafeId: nil,
            drinkType: "Coffee", drinkTypeCustom: nil, drinkSubtype: drink,
            caption: caption, notes: nil, visibility: "Private",
            ratings: ["Overall": score], overallScore: score, posterPhotoURL: nil,
            contextType: context, locationName: context == "Cafe" ? "Test Cafe" : "Home",
            cityState: context == "Cafe" ? "Charleston" : nil,
            brewMethod: context == "Home" || context == "Recipe" ? drink : nil,
            createdAt: createdAt
        )
        let analysis = JournalDrinkAnalysis(
            visitID: visitID,
            processingStatus: "complete",
            preparation: drink,
            caffeineModifier: nil,
            estimatedCaffeineMilligrams: estimatedCaffeine,
            caffeineCalculationBasis: estimatedCaffeine == nil ? nil : "Traditional preparation average",
            caffeineCoverage: caffeineCoverage,
            caffeineReferenceVersion: "traditional-averages-1",
            parserVersion: "local-1",
            confidence: estimatedCaffeine == nil ? 0.2 : 0.9
        )
        return JournalEntryProjection(
            summary: RemoteVisitSummary(visit: row, cafe: nil),
            privateNote: nil,
            isBookmarked: false,
            drinkAnalysis: analysis
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
