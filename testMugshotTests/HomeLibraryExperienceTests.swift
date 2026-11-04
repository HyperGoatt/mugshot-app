import Foundation
import Testing
import UIKit
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
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let guest = root.appendingPathComponent("guest")
        try FileManager.default.createDirectory(at: guest, withIntermediateDirectories: true)
        try data.write(to: guest.appendingPathComponent("library-v1.json"))
        let stored = HomeLibraryStore(baseDirectory: root).load(in: .guest)
        #expect(stored.updatedAt == shelf.updatedAt)
        #expect(stored.preferences == nil)
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
        #expect(store.load(in: .user(owner)).bags.first?.safeSnapshot == bag.safeSnapshot)
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

    @Test func coffeeDefaultsDoNotBecomeTeaOrMatchaIngredients() {
        let owner = UUID()
        let bag = CoffeeBag(ownerUserID: owner, name: "Go-to coffee")
        var shelf = HomeLibrarySnapshot.empty
        shelf.bags = [bag]; shelf.preferences = HomeLibraryPreferences(defaultBagID: bag.id)
        #expect(shelf.defaults(for: owner, method: .espresso).bag?.id == bag.id)
        #expect(shelf.defaults(for: owner, method: .westernTea).bag == nil)
        #expect(shelf.defaults(for: owner, method: .traditionalMatcha).bag == nil)
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

    @Test func failedSyncPreservesOfflineEditsAndRetryKeepsTheSameID() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root), owner = UUID()
        let bag = CoffeeBag(ownerUserID: owner, name: "Offline bag")
        _ = try store.upsert(bag, in: .user(owner))
        let remote = FakeShelf(); remote.fails = true
        let sync = HomeLibrarySynchronizer(store: store, transport: { _ in remote })
        #expect(await !sync.synchronize(scope: .user(owner), currentOwner: { owner }))
        #expect(store.load(in: .user(owner)).bags.map(\.id) == [bag.id])
        remote.fails = false
        #expect(await sync.synchronize(scope: .user(owner), currentOwner: { owner }))
        #expect(remote.writes.map(\.id) == [bag.id])
        #expect(sync.messages[owner] == nil)
    }

    @Test func changedAccountDuringFetchCannotMergeOrWrite() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root), owner = UUID()
        var current: UUID? = owner
        let remote = FakeShelf()
        remote.bags = [CoffeeBag(ownerUserID: owner, name: "Old account")]
        remote.onFetch = { current = UUID() }
        let sync = HomeLibrarySynchronizer(store: store, transport: { _ in remote })
        #expect(await !sync.synchronize(scope: .user(owner), currentOwner: { current }))
        #expect(store.load(in: .user(owner)).bags.isEmpty)
        #expect(remote.writes.isEmpty)
    }

    @Test func unchangedRemoteRowsAreNotRewrittenAndForeignRowsAreExcluded() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root), owner = UUID()
        let bag = CoffeeBag(ownerUserID: owner, name: "Same bag")
        _ = try store.upsert(bag, in: .user(owner))
        let remote = FakeShelf()
        remote.bags = [bag, CoffeeBag(ownerUserID: UUID(), name: "Other owner")]
        let sync = HomeLibrarySynchronizer(store: store, transport: { _ in remote })
        #expect(await sync.synchronize(scope: .user(owner), currentOwner: { owner }))
        #expect(store.load(in: .user(owner)).bags.map(\.id) == [bag.id])
        #expect(remote.writes.isEmpty)
    }

    @Test func anEditDuringUploadWinsOverTheOlderResponse() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root), owner = UUID()
        let original = CoffeeBag(ownerUserID: owner, name: "Original")
        _ = try store.upsert(original, in: .user(owner))
        let remote = FakeShelf()
        remote.onWrite = {
            remote.onWrite = nil
            var edited = original
            edited.name = "Newer edit"
            edited.updatedAt = original.updatedAt.addingTimeInterval(10)
            _ = try? store.upsert(edited, in: .user(owner))
        }
        let sync = HomeLibrarySynchronizer(store: store, transport: { _ in remote })
        #expect(await sync.synchronize(scope: .user(owner), currentOwner: { owner }))
        #expect(remote.writes.count == 2)
        #expect(remote.writes.last?.name == "Newer edit")
        #expect(store.load(in: .user(owner)).bags.first?.name == "Newer edit")
    }

    @Test func erasureCancelsAReadBeforeItCanRestoreTheShelf() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root), owner = UUID()
        let remote = FakeShelf()
        remote.bags = [CoffeeBag(ownerUserID: owner, name: "Removed")]
        let sync = HomeLibrarySynchronizer(store: store, transport: { _ in remote })
        remote.onFetch = { sync.invalidate(ownerID: owner); store.removeAll(ownerUserID: owner) }
        #expect(await !sync.synchronize(scope: .user(owner), currentOwner: { owner }))
        #expect(store.load(in: .user(owner)).bags.isEmpty)
        #expect(remote.writes.isEmpty)
    }

    @Test func photoSyncPreservesTheLocalPhotoAndAcknowledgesThePrivatePath() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root), owner = UUID()
        var bag = CoffeeBag(ownerUserID: owner, name: "With photo")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 8, height: 8)) }
        bag.localPhotoPath = try store.saveBagPhoto(image, bagID: bag.id, in: .user(owner))
        _ = try store.upsert(bag, in: .user(owner))
        let remote = FakeShelf(), sync = HomeLibrarySynchronizer(store: store, transport: { _ in remote })
        #expect(await sync.synchronize(scope: .user(owner), currentOwner: { owner }))
        let saved = try #require(store.load(in: .user(owner)).bags.first)
        #expect(saved.privatePhotoPath == "private/fixture.jpg")
        #expect(saved.localPhotoPath == bag.localPhotoPath)
        #expect(remote.uploads == 1)
        #expect(await sync.synchronize(scope: .user(owner), currentOwner: { owner }))
        #expect(remote.uploads == 1)
        #expect(remote.writes.count == 1)
    }

    @Test func anAccountChangeDuringPhotoUploadCannotWriteBagMetadata() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root), owner = UUID()
        var current: UUID? = owner
        var bag = CoffeeBag(ownerUserID: owner, name: "Private photo")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 8, height: 8)) }
        bag.localPhotoPath = try store.saveBagPhoto(image, bagID: bag.id, in: .user(owner))
        _ = try store.upsert(bag, in: .user(owner))
        let remote = FakeShelf(), sync = HomeLibrarySynchronizer(store: store, transport: { _ in remote })
        remote.onUpload = { current = UUID() }
        #expect(await !sync.synchronize(scope: .user(owner), currentOwner: { current }))
        #expect(remote.writes.isEmpty)
        #expect(store.load(in: .user(owner)).bags.first?.privatePhotoPath == nil)
    }

    @Test func gearSyncAcknowledgesOnceAndDoesNotRewriteUnchangedGear() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root), owner = UUID()
        let gear = EquipmentProfile(ownerUserID: owner, role: .kettle, nickname: "Kettle")
        _ = try store.upsert(gear, in: .user(owner))
        let remote = FakeShelf(), sync = HomeLibrarySynchronizer(store: store, transport: { _ in remote })
        #expect(await sync.synchronize(scope: .user(owner), currentOwner: { owner }))
        #expect(remote.gearWrites.map(\.id) == [gear.id])
        #expect(await sync.synchronize(scope: .user(owner), currentOwner: { owner }))
        #expect(remote.gearWrites.count == 1)
        #expect(store.load(in: .user(owner)).equipment.first?.nickname == "Kettle")
    }

    @Test func aGearEditDuringSyncSurvivesTheOlderAcknowledgement() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root), owner = UUID()
        let gear = EquipmentProfile(ownerUserID: owner, nickname: "Original")
        _ = try store.upsert(gear, in: .user(owner))
        let remote = FakeShelf(), sync = HomeLibrarySynchronizer(store: store, transport: { _ in remote })
        remote.onGearWrite = {
            remote.onGearWrite = nil
            var changed = gear; changed.nickname = "New name"
            _ = try? store.upsert(changed, in: .user(owner))
        }
        #expect(await sync.synchronize(scope: .user(owner), currentOwner: { owner }))
        #expect(remote.gearWrites.count == 2)
        #expect(store.load(in: .user(owner)).equipment.first?.nickname == "New name")
    }
}

@MainActor
private final class FakeShelf: HomeLibrarySyncTransport {
    var bags: [CoffeeBag] = []
    var writes: [CoffeeBag] = []
    var fails = false
    var onFetch: (() -> Void)?
    var onWrite: (() -> Void)?
    var onUpload: (() -> Void)?
    var uploads = 0
    var equipment: [EquipmentProfile] = []
    var gearWrites: [EquipmentProfile] = []
    var onGearWrite: (() -> Void)?
    func fetch(userID: UUID) async throws -> RemoteHomeLibrary {
        if fails { throw CoffeeAssistanceError.unavailable }
        onFetch?()
        return RemoteHomeLibrary(bags: bags, equipment: equipment)
    }
    func upsert(_ bag: CoffeeBag, userID: UUID) async throws -> CoffeeBag {
        writes.append(bag); onWrite?()
        bags.removeAll { $0.id == bag.id }; bags.append(bag)
        return bag
    }
    func upsert(_ gear: EquipmentProfile, userID: UUID) async throws -> EquipmentProfile {
        gearWrites.append(gear); onGearWrite?()
        equipment.removeAll { $0.id == gear.id }; equipment.append(gear)
        return gear
    }
    func uploadBagPhoto(_ image: UIImage, bagID: UUID, userID: UUID) async throws -> String { uploads += 1; onUpload?(); return "private/fixture.jpg" }
}
