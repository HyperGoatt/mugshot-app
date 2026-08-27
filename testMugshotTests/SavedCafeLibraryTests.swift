import Foundation
import Testing
@testable import testMugshot

struct SavedCafeLibraryTests {
    @Test func incidentalCafeDoesNotEnterPersonalLibraryUntilActivelySaved() throws {
        let suiteName = "SavedCafeLibrary.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = DataManager(defaults: defaults)
        let cafe = Cafe(name: "Incidental Map Result")

        manager.addCafe(cafe)
        #expect(manager.personalLibraryCafes.isEmpty)

        manager.setCafeState(cafeId: cafe.id, isFavorite: true, wantToTry: false)
        #expect(manager.personalLibraryCafes.map(\.id) == [cafe.id])

        manager.setCafeState(cafeId: cafe.id, isFavorite: false, wantToTry: false)
        #expect(manager.personalLibraryCafes.isEmpty)
    }

    @Test func personalLibraryMembershipPersistsAcrossRelaunch() throws {
        let suiteName = "SavedCafeLibraryPersistence.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let favorite = Cafe(name: "Persistent Favorite", isFavorite: true)
        let manager = DataManager(defaults: defaults)
        manager.addCafe(favorite)
        manager.setCafeState(cafeId: favorite.id, isFavorite: true, wantToTry: false)

        let relaunched = DataManager(defaults: defaults)
        #expect(relaunched.personalLibraryCafes.map(\.id) == [favorite.id])
    }

    @Test func completedSipClearsWantToTryButKeepsCafeInAllAndSupportsUndo() throws {
        let suiteName = "WantToTryCompletion.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = DataManager(defaults: defaults)
        let cafe = Cafe(name: "First Sip Cafe", wantToTry: true)
        manager.addCafe(cafe)
        manager.setCafeState(cafeId: cafe.id, isFavorite: false, wantToTry: true)

        let prior = manager.completeWantToTryAfterSip(at: cafe)
        #expect(prior?.wantToTry == true)
        #expect(manager.getCafe(id: cafe.id)?.wantToTry == false)
        #expect(manager.personalLibraryCafes.map(\.id) == [cafe.id])

        manager.restoreWantToTry(after: cafe)
        #expect(manager.getCafe(id: cafe.id)?.wantToTry == true)
    }

    @Test func projectionKeepsCategorySearchAndSortDeterministic() {
        let favorite = Cafe(
            name: "Harborlight Coffee Roasters",
            address: "Embarcadero",
            isFavorite: true,
            averageRating: 4.8,
            visitCount: 4
        )
        let wantToTry = Cafe(
            name: "Juniper and Stone",
            address: "Hayes Valley",
            wantToTry: true
        )
        let visited = Cafe(
            name: "Paper Moon Espresso",
            address: "Mission",
            averageRating: 4.2,
            visitCount: 2
        )
        let cafes = [wantToTry, visited, favorite]

        let favorites = SavedCafeLibraryProjector.project(
            cafes: cafes,
            visits: [],
            query: SavedCafeLibraryQuery(category: .favorites, sort: .name)
        )
        #expect(favorites.map(\.id) == [favorite.id])

        let searched = SavedCafeLibraryProjector.project(
            cafes: cafes,
            visits: [],
            query: SavedCafeLibraryQuery(
                category: .all,
                searchText: "mission",
                sort: .recentActivity
            )
        )
        #expect(searched.map(\.id) == [visited.id])

        let highestRated = SavedCafeLibraryProjector.project(
            cafes: cafes,
            visits: [],
            query: SavedCafeLibraryQuery(
                category: .all,
                sort: .highestRated
            )
        )
        #expect(highestRated.map(\.id) == [favorite.id, visited.id, wantToTry.id])

        let now = Date(timeIntervalSince1970: 1_785_859_200)
        let recent = SavedCafeLibraryProjector.project(
            cafes: cafes,
            visits: [],
            query: SavedCafeLibraryQuery(category: .all, sort: .recentActivity),
            remoteActivityDates: [
                favorite.id: now.addingTimeInterval(-3_600),
                wantToTry.id: now,
                visited.id: now.addingTimeInterval(-86_400)
            ]
        )
        #expect(recent.map(\.id) == [wantToTry.id, favorite.id, visited.id])
    }

    @Test func photoSelectionSkipsNewerVisitsWithoutPhotos() {
        let cafeID = UUID()
        let userID = UUID()
        let olderPhoto = Visit(
            cafeId: cafeID,
            userId: userID,
            createdAt: Date(timeIntervalSince1970: 100),
            drinkType: .coffee,
            photos: ["older-photo.jpg"]
        )
        let newerWithoutPhoto = Visit(
            cafeId: cafeID,
            userId: userID,
            createdAt: Date(timeIntervalSince1970: 200),
            drinkType: .coffee
        )

        #expect(
            CafePhotoSelection.mostRecentLocalPosterPath(
                in: [newerWithoutPhoto, olderPhoto]
            ) == "older-photo.jpg"
        )
    }

    @Test func photoSelectionRecognizesPrivateStorageReferencesAsRemoteMedia() {
        let privateReference = "mugshot-storage://visit-photos-private/user/visit/photo.jpg"

        #expect(CafePhotoSelection.isRemotePhotoReference(privateReference))
        #expect(CafePhotoSelection.isRemotePhotoReference("https://example.com/photo.jpg"))
        #expect(!CafePhotoSelection.isRemotePhotoReference("local-photo.jpg"))
    }

    @Test func personalSnapshotKeepsUnratedVisitsAndMostRecentAvailablePhoto() {
        let cafe = SupabaseCafeSummary(
            id: UUID(),
            name: "Photo Cafe",
            address: "1 Test Street",
            city: "Charleston",
            latitude: 32.78,
            longitude: -79.93,
            applePlaceId: nil,
            websiteURL: nil
        )
        let newestDate = Date(timeIntervalSince1970: 300)
        let snapshot = RemoteMapPinSnapshot.make(
            mapVisits: [
                RemoteMapVisitSeed(
                    cafe: cafe,
                    overallScore: 0,
                    cafeSessionID: nil,
                    createdAt: newestDate,
                    posterPhotoURL: nil
                ),
                RemoteMapVisitSeed(
                    cafe: cafe,
                    overallScore: 4.5,
                    cafeSessionID: nil,
                    createdAt: Date(timeIntervalSince1970: 200),
                    posterPhotoURL: "https://example.com/authorized.jpg"
                )
            ],
            cafeStates: []
        )

        #expect(snapshot.pins.count == 1)
        #expect(snapshot.pins.first?.visitCount == 2)
        #expect(snapshot.pins.first?.lastActivityAt == newestDate)
        #expect(snapshot.pins.first?.coverPhotoURL == "https://example.com/authorized.jpg")
    }

    @Test func personalSnapshotStitchesEquivalentCafeIDsAndCombinesTheirSips() {
        let newestDate = Date(timeIntervalSince1970: 300)
        let summaries = [
            SupabaseCafeSummary(
                id: UUID(),
                name: "Nook Tiny Cafe & Market",
                address: "267 Rutledge Ave, Charleston, SC",
                city: "Charleston",
                latitude: 32.79258,
                longitude: -79.94854,
                applePlaceId: nil,
                appleMapsPlaceID: "i32caaad56a85b4a1",
                websiteURL: "https://nooktinycafe.com",
                identityKey: "apple-mapkit:i32caaad56a85b4a1"
            ),
            SupabaseCafeSummary(
                id: UUID(),
                name: "Nook Tiny Cafe & Market",
                address: "267 Rutledge Avenue, Charleston, SC 29403",
                city: "267 Rutledge Ave",
                latitude: 32.79260,
                longitude: -79.94861,
                applePlaceId: "google-place-id",
                websiteURL: nil
            ),
            SupabaseCafeSummary(
                id: UUID(),
                name: "Nook Tiny Cafe & Market",
                address: "Rutledge Ave, 267, Charleston, SC",
                city: "Charleston",
                latitude: 32.79258,
                longitude: -79.94854,
                applePlaceId: "https://nooktinycafe.com",
                websiteURL: "https://nooktinycafe.com"
            )
        ]
        let snapshot = RemoteMapPinSnapshot.make(
            mapVisits: summaries.enumerated().map { index, cafe in
                RemoteMapVisitSeed(
                    cafe: cafe,
                    overallScore: Double(index + 3),
                    cafeSessionID: nil,
                    createdAt: index == 1
                        ? newestDate
                        : Date(timeIntervalSince1970: Double(index + 1) * 50),
                    posterPhotoURL: index == 1 ? "https://example.com/nook.jpg" : nil
                )
            },
            cafeStates: []
        )

        #expect(snapshot.pins.count == 1)
        #expect(snapshot.pins.first?.visitCount == 3)
        #expect(snapshot.pins.first?.coverPhotoURL == "https://example.com/nook.jpg")
        #expect(snapshot.pins.first?.cafe.appleMapsPlaceID == "i32caaad56a85b4a1")
    }
}
