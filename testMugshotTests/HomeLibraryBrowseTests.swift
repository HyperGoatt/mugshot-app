import Foundation
import Testing
@testable import testMugshot

struct HomeLibraryBrowseTests {
    @Test func recipeSortsKeepPinsFirstAndNewestUsesTheOriginalSave() {
        let pin = recipe("Zest latte", created: 1, pinned: true)
        var older = recipe("Almond latte", created: 2, used: 15)
        older.versions.append(HomeRecipeVersion(number: 2, createdAt: date(20), content: older.versions[0].content))
        let newer = recipe("Berry latte", created: 10)
        let shelf = [newer, older, pin]

        #expect(HomeLibraryBrowse.recipes(shelf, sort: .recentlyUsed).map(\.id) == [pin.id, older.id, newer.id])
        #expect(HomeLibraryBrowse.recipes(shelf, sort: .newest).map(\.id) == [pin.id, newer.id, older.id])
        #expect(HomeLibraryBrowse.recipes(shelf, sort: .name).map(\.id) == [pin.id, older.id, newer.id])
    }

    @Test func recipeSortTiesDoNotDependOnStorageOrder() {
        let firstID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let first = recipe("Tea", created: 10, id: firstID)
        let second = recipe("Tea", created: 10, id: secondID)
        for sort in HomeRecipeShelfSort.allCases {
            #expect(HomeLibraryBrowse.recipes([second, first], sort: sort).map(\.id) == [firstID, secondID])
        }
    }

    @Test func recipeFiltersComposeAndArchivesStayOffTheActiveShelf() {
        let tea = recipe("Mint tea", created: 5, method: .westernTea, template: .preparation)
        let syrup = recipe("Mint syrup", created: 3, method: .syrupSauce, template: .component)
        let archived = recipe("Mint iced tea", created: 4, method: .icedTea, template: .preparation, archived: true)
        let shelf = [tea, syrup, archived, HomeRecipeRecord(versions: [])]

        #expect(HomeLibraryBrowse.recipes(shelf, query: "  MINT ", use: .base, method: .westernTea).map(\.id) == [tea.id])
        #expect(HomeLibraryBrowse.recipes(shelf, query: "mint", use: .component).map(\.id) == [syrup.id])
        #expect(HomeLibraryBrowse.recipes(shelf, method: .traditionalMatcha).isEmpty)
        #expect(HomeLibraryBrowse.recipes(shelf, archived: true).map(\.id) == [archived.id])
        #expect(HomeLibraryBrowse.recipes(shelf).count == 2)
    }

    @Test func bagsUseRealRoastDatesAndKeepUnknownDatesLast() {
        let owner = UUID()
        let unknown = CoffeeBag(ownerUserID: owner, name: "Alder")
        let older = CoffeeBag(ownerUserID: owner, name: "Cedar", roastDate: date(1), status: .resting)
        let newer = CoffeeBag(ownerUserID: owner, name: "Birch", roastDate: date(5))
        let archive = CoffeeBag(ownerUserID: owner, name: "Dogwood", roastDate: date(10), status: .finished)
        let otherOwner = CoffeeBag(ownerUserID: UUID(), name: "Foreign", roastDate: date(20))
        let bags = [unknown, older, newer, archive, otherOwner]

        #expect(HomeLibraryBrowse.bags(bags, ownerID: owner, sort: .roastDate).map(\.id) == [newer.id, older.id, unknown.id])
        #expect(HomeLibraryBrowse.bags(bags, ownerID: owner, sort: .name).map(\.id) == [unknown.id, newer.id, older.id])
        #expect(HomeLibraryBrowse.bags(bags, ownerID: owner, status: .resting).map(\.id) == [older.id])
        #expect(HomeLibraryBrowse.bags(bags, ownerID: owner, showsArchived: true, status: .finished).map(\.id) == [archive.id])
        #expect(HomeLibraryBrowse.roastDateLabel(unknown) == "Roast date unknown")
    }

    @Test func gearFiltersIntersectRoleSetupOwnershipAndArchiveVisibility() {
        let owner = UUID()
        let kettle = EquipmentProfile(ownerUserID: owner, role: .kettle, nickname: "Kettle")
        let scale = EquipmentProfile(ownerUserID: owner, role: .scale, nickname: "Scale")
        let archived = EquipmentProfile(ownerUserID: owner, role: .kettle, nickname: "Old kettle", archivedAt: date(2))
        let other = EquipmentProfile(ownerUserID: UUID(), role: .kettle, nickname: "Foreign kettle")
        let setup = HomePlaceProfile(ownerUserID: owner, name: "Brew bench", equipmentIDs: [kettle.id, archived.id, other.id])
        let gear = [other, scale, archived, kettle]

        #expect(HomeLibraryBrowse.gear(gear, ownerID: owner, role: .kettle, setup: setup).map(\.id) == [kettle.id])
        #expect(HomeLibraryBrowse.gear(gear, ownerID: owner, showsArchived: true, role: .kettle, setup: setup).map(\.id) == [kettle.id, archived.id])
        #expect(HomeLibraryBrowse.gear(gear, ownerID: owner, role: .scale, setup: setup).isEmpty)
        #expect(HomeLibraryBrowse.gear(gear, ownerID: other.ownerUserID, setup: setup).isEmpty)
    }

    private func recipe(_ name: String, created: TimeInterval, used: TimeInterval? = nil,
                        method: HomeBrewMethod = .completeDrink, template: HomeRecipeTemplate = .drink,
                        pinned: Bool = false, archived: Bool = false, id: UUID = UUID()) -> HomeRecipeRecord {
        HomeRecipeRecord(id: id, versions: [HomeRecipeVersion(createdAt: date(created),
            content: HomeRecipeContent(name: name, template: template, method: method))],
            isPinned: pinned, isArchived: archived, lastUsedAt: used.map(date))
    }

    private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }
}
