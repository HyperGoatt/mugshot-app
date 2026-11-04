import Foundation
import Testing
@testable import testMugshot

@MainActor
struct HomeLibraryExperienceTests {
    @Test func lunaPermissionIsExplicitRememberedAndAccountScoped() throws {
        let suite = "home.luna.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = UUID(), other = UUID()
        let store = CoffeeAssistancePermissionStore(defaults: defaults)
        #expect(!store.isEnabled(ownerID: owner))
        #expect(!store.isEnabled(ownerID: nil))
        store.setEnabled(true, ownerID: owner)
        #expect(CoffeeAssistancePermissionStore(defaults: defaults).isEnabled(ownerID: owner))
        #expect(!store.isEnabled(ownerID: other))
        store.setEnabled(false, ownerID: owner)
        #expect(!store.isEnabled(ownerID: owner))
    }

    @Test func permissionErasureDoesNotChangeAnotherAccount() throws {
        let suite = "home.luna.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CoffeeAssistancePermissionStore(defaults: defaults)
        let owner = UUID(), other = UUID()
        store.setEnabled(true, ownerID: owner); store.setEnabled(true, ownerID: other)
        store.removeAll(ownerID: owner)
        #expect(!store.isEnabled(ownerID: owner))
        #expect(store.isEnabled(ownerID: other))
    }

    @Test func oldShelfDecodesWithoutPreferences() throws {
        let data = Data(#"{"bags":[],"equipment":[],"recentSetups":[],"updatedAt":"2026-11-04T00:00:00Z"}"#.utf8)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let shelf = try decoder.decode(HomeLibrarySnapshot.self, from: data)
        #expect(shelf.preferences == nil)
    }

    @Test func defaultsPersistWithoutCrossingAccountOrChangingSnapshots() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root)
        let owner = UUID(), other = UUID()
        let bag = CoffeeBag(ownerUserID: owner, name: "Morning")
        _ = try store.upsert(bag, in: .user(owner))
        let preferences = HomeLibraryPreferences(preferredMethod: .westernTea, defaultBagID: bag.id)
        _ = try store.savePreferences(preferences, in: .user(owner))
        #expect(store.load(in: .user(owner)).preferences == preferences)
        #expect(store.load(in: .user(other)).preferences == nil)
        #expect(store.load(in: .user(owner)).defaults(for: owner).bag?.id == bag.id)
        #expect(store.load(in: .user(owner)).defaults(for: other).bag == nil)
        #expect(store.load(in: .user(owner)).bags.first == bag)
    }

    @Test func archivedOrMissingDefaultsStayUnknown() {
        let owner = UUID()
        let bag = CoffeeBag(ownerUserID: owner, name: "Finished", status: .archived)
        var shelf = HomeLibrarySnapshot.empty
        shelf.bags = [bag]
        shelf.preferences = HomeLibraryPreferences(defaultBagID: bag.id, defaultEquipmentIDs: [UUID()])
        #expect(shelf.defaults(for: owner).bag == nil)
        #expect(shelf.defaults(for: owner).equipment.isEmpty)
    }

    @Test func autofillPreservesTypingWhileReadingAndIgnoresBlankFields() {
        let baseline = CoffeeBag(roaster: "", name: "", origin: "")
        var edited = baseline
        edited.name = "My own name"
        CoffeeBagAutofill.apply([
            CoffeeAssistanceField(key: "roaster", value: "Printed roaster", sourceQuote: "Printed roaster"),
            CoffeeAssistanceField(key: "name", value: "Printed name", sourceQuote: "Printed name"),
            CoffeeAssistanceField(key: "origin", value: "", sourceQuote: "")
        ], to: &edited, unchangedSince: baseline)
        #expect(edited.roaster == "Printed roaster")
        #expect(edited.name == "My own name")
        #expect(edited.origin.isEmpty)
        #expect(edited.id == baseline.id)
        #expect(edited.ownerUserID == baseline.ownerUserID)
    }

    @Test func autofillCannotChangeInventoryOrInventInvalidRoastDate() {
        let baseline = CoffeeBag(name: "Coffee", remainingWeightGrams: 100)
        var bag = baseline
        CoffeeBagAutofill.apply([
            CoffeeAssistanceField(key: "remainingWeightGrams", value: "999", sourceQuote: "999"),
            CoffeeAssistanceField(key: "roastDate", value: "Not a date", sourceQuote: "Not a date")
        ], to: &bag, unchangedSince: baseline)
        #expect(bag.remainingWeightGrams == 100)
        #expect(bag.roastDate == nil)
    }
}
