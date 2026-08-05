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

    @Test func projectionKeepsCategorySearchFiltersAndSortDeterministic() {
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

        let visitedOnly = SavedCafeLibraryProjector.project(
            cafes: cafes,
            visits: [],
            query: SavedCafeLibraryQuery(
                category: .all,
                sort: .highestRated,
                requiresVisit: true
            )
        )
        #expect(visitedOnly.map(\.id) == [favorite.id, visited.id])
    }
}
