import Foundation
import Testing
@testable import testMugshot

struct HomePlaceProfileControlTests {
    @Test func genericHomeNameIsReservedForTheUnspecifiedSetup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileControls-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root)
        let profile = HomePlaceProfile(name: "  hOmE  ")
        #expect(profile.validationMessage != nil)
        #expect(throws: (any Error).self) { try shelf.upsertHomeProfile(profile, in: .guest) }
        #expect(shelf.load(in: .guest).preferences?.homeProfiles?.isEmpty ?? true)
    }

    @Test func duplicateNamesCannotMakeTheSelectedSetupAmbiguous() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileControls-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root)
        var existing = HomePlaceProfile(name: "Kitchen counter")
        _ = try shelf.upsertHomeProfile(existing, in: .guest)
        #expect(throws: (any Error).self) {
            try shelf.upsertHomeProfile(HomePlaceProfile(name: "  KITCHEN counter  "), in: .guest)
        }
        existing.name = "Kitchen Counter"
        let saved = try shelf.upsertHomeProfile(existing, in: .guest)
        #expect(saved.preferences?.homeProfiles?.count == 1)
        #expect(saved.preferences?.homeProfiles?.first?.id == existing.id)
    }

    @Test func guestProfilesMergeWithoutReplacingAccountDefaults() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileAdoption-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        let guestGear = EquipmentProfile(nickname: "Travel kettle")
        let accountGear = EquipmentProfile(ownerUserID: owner, nickname: "Kitchen grinder")
        _ = try shelf.upsert(guestGear, in: .guest)
        _ = try shelf.upsert(accountGear, in: .user(owner))
        let guest = HomePlaceProfile(name: "Cottage", equipmentIDs: [guestGear.id])
        let account = HomePlaceProfile(ownerUserID: owner, name: "Kitchen", equipmentIDs: [accountGear.id])
        var guestPreferences = try shelf.upsertHomeProfile(guest, in: .guest).preferences ?? HomeLibraryPreferences()
        guestPreferences.preferredMethod = .pourOver; guestPreferences.defaultBagID = UUID()
        guestPreferences.defaultEquipmentIDs = [guestGear.id]; guestPreferences.defaultHomeProfileID = guest.id
        _ = try shelf.savePreferences(guestPreferences, in: .guest)
        var accountPreferences = try shelf.upsertHomeProfile(account, in: .user(owner)).preferences ?? HomeLibraryPreferences()
        accountPreferences.preferredMethod = .espresso; accountPreferences.defaultBagID = UUID()
        accountPreferences.defaultEquipmentIDs = [accountGear.id]; accountPreferences.defaultHomeProfileID = account.id
        _ = try shelf.savePreferences(accountPreferences, in: .user(owner))

        let adopted = try shelf.adoptGuestLibrary(for: owner)
        let profiles = try #require(adopted.preferences?.homeProfiles)
        #expect(Set(profiles.map(\.id)) == [guest.id, account.id])
        #expect(profiles.allSatisfy { $0.ownerUserID == owner })
        #expect(profiles.first { $0.id == guest.id }?.equipmentIDs == [guestGear.id])
        #expect(adopted.preferences?.preferredMethod == accountPreferences.preferredMethod)
        #expect(adopted.preferences?.defaultBagID == accountPreferences.defaultBagID)
        #expect(adopted.preferences?.defaultEquipmentIDs == accountPreferences.defaultEquipmentIDs)
        #expect(adopted.preferences?.defaultHomeProfileID == account.id)
        let reloaded = HomeLibraryStore(baseDirectory: root).load(in: .user(owner))
        #expect(reloaded.preferences == adopted.preferences)
        #expect(shelf.load(in: .guest).preferences == nil)
    }

    @Test(arguments: [false, true]) func missingAccountDefaultsAdoptReboundGuestProfile(_ hasPreferences: Bool) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileAdoption-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        let guest = HomePlaceProfile(name: "Window nook")
        var preferences = try shelf.upsertHomeProfile(guest, in: .guest).preferences ?? HomeLibraryPreferences()
        preferences.defaultHomeProfileID = guest.id; preferences.preferredMethod = .westernTea
        _ = try shelf.savePreferences(preferences, in: .guest)
        if hasPreferences { _ = try shelf.savePreferences(HomeLibraryPreferences(), in: .user(owner)) }

        let adopted = try shelf.adoptGuestLibrary(for: owner)
        #expect(adopted.selectedHomeProfile(for: owner)?.id == guest.id)
        #expect(adopted.preferences?.preferredMethod == .westernTea)
        #expect(adopted.preferences?.homeProfiles?.first?.ownerUserID == owner)
        #expect(shelf.load(in: .guest).preferences == nil)
    }

    @Test func foreignProfileCannotBeAdoptedAndBothShelvesRemainUntouched() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileAdoption-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        let foreign = HomePlaceProfile(ownerUserID: UUID(), name: "Someone else’s setup")
        var preferences = HomeLibraryPreferences(); preferences.homeProfiles = [foreign]
        _ = try shelf.savePreferences(preferences, in: .guest)
        _ = try shelf.upsertHomeProfile(HomePlaceProfile(ownerUserID: owner, name: "My kitchen"), in: .user(owner))
        let guestBefore = shelf.load(in: .guest); let accountBefore = shelf.load(in: .user(owner))
        #expect(throws: (any Error).self) { try shelf.adoptGuestLibrary(for: owner) }
        #expect(shelf.load(in: .guest) == guestBefore)
        #expect(shelf.load(in: .user(owner)) == accountBefore)
    }

    @Test func failedAccountWriteKeepsGuestProfileAvailableForRetry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileAdoption-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        let guest = HomePlaceProfile(name: "Coffee corner")
        _ = try shelf.upsertHomeProfile(guest, in: .guest)
        let occupiedMetadata = root.appendingPathComponent(LocalAccountScope.user(owner).storageComponent)
            .appendingPathComponent("library-v1.json")
        try FileManager.default.createDirectory(at: occupiedMetadata, withIntermediateDirectories: true)
        #expect(throws: (any Error).self) { try shelf.adoptGuestLibrary(for: owner) }
        #expect(shelf.load(in: .guest).preferences?.homeProfiles?.first?.id == guest.id)
        #expect(shelf.load(in: .guest).preferences?.homeProfiles?.first?.ownerUserID == nil)
    }

    @Test func adoptionRetainsExistingProfileIdentityOnRetry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileAdoption-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        let guest = HomePlaceProfile(name: "Earlier nickname")
        _ = try shelf.upsertHomeProfile(guest, in: .guest)
        var account = guest; account.ownerUserID = owner; account.name = "Current nickname"
        _ = try shelf.upsertHomeProfile(account, in: .user(owner))
        let adopted = try shelf.adoptGuestLibrary(for: owner)
        #expect(adopted.preferences?.homeProfiles == [account])
        #expect(shelf.load(in: .guest).preferences == nil)
    }

    @Test func adoptionPreservesBothSameNamedProfilesWithADistinctGuestNickname() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileAdoption-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        let guest = HomePlaceProfile(name: "My kitchen")
        let account = HomePlaceProfile(ownerUserID: owner, name: "MY kitchen")
        _ = try shelf.upsertHomeProfile(guest, in: .guest)
        var preferences = try shelf.upsertHomeProfile(account, in: .user(owner)).preferences ?? HomeLibraryPreferences()
        preferences.defaultHomeProfileID = account.id; preferences.preferredMethod = .espresso
        _ = try shelf.savePreferences(preferences, in: .user(owner))
        let adopted = try shelf.adoptGuestLibrary(for: owner)
        let profiles = try #require(adopted.preferences?.homeProfiles)
        #expect(Set(profiles.map(\.id)) == [guest.id, account.id])
        #expect(profiles.first { $0.id == account.id } == account)
        #expect(profiles.first { $0.id == guest.id }?.name == "My kitchen (from this device)")
        #expect(profiles.allSatisfy { $0.ownerUserID == owner })
        #expect(adopted.preferences?.defaultHomeProfileID == account.id)
        #expect(adopted.preferences?.preferredMethod == .espresso)
        #expect(shelf.load(in: .guest).preferences == nil)
        _ = try shelf.upsertHomeProfile(guest, in: .guest)
        #expect(try shelf.adoptGuestLibrary(for: owner).preferences == adopted.preferences)
    }

    @Test func adoptedNicknameSuffixSkipsCollisionsAndStaysWithinSixtyCharacters() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileAdoption-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        let name = String(repeating: "K", count: 60)
        let guest = HomePlaceProfile(name: name)
        _ = try shelf.upsertHomeProfile(guest, in: .guest)
        for suffix in ["", " (from this device)", " (from this device 2)"] {
            let existing = String(name.prefix(60 - suffix.count)) + suffix
            _ = try shelf.upsertHomeProfile(HomePlaceProfile(ownerUserID: owner, name: existing), in: .user(owner))
        }
        let adopted = try shelf.adoptGuestLibrary(for: owner)
        let profiles = try #require(adopted.preferences?.homeProfiles)
        let renamed = try #require(profiles.first { $0.id == guest.id })
        #expect(renamed.name.hasSuffix(" (from this device 3)"))
        #expect(renamed.name.count == 60 && renamed.validationMessage == nil)
        #expect(profiles.count == 4)
        #expect(Set(profiles.map { $0.name.lowercased() }).count == profiles.count)
    }

    @Test(arguments: [false, true]) func malformedDuplicateNamesWithinAScopeRemainFailClosed(_ damagedAccount: Bool) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileAdoption-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        _ = try shelf.upsertHomeProfile(HomePlaceProfile(name: "Travel setup"), in: .guest)
        _ = try shelf.upsertHomeProfile(HomePlaceProfile(ownerUserID: owner, name: "Account setup"), in: .user(owner))
        let damagedScope: LocalAccountScope = damagedAccount ? .user(owner) : .guest
        var preferences = HomeLibraryPreferences()
        preferences.homeProfiles = [HomePlaceProfile(ownerUserID: damagedScope.userID, name: "Kitchen"),
            HomePlaceProfile(ownerUserID: damagedScope.userID, name: "KITCHEN")]
        _ = try shelf.savePreferences(preferences, in: damagedScope)
        let guestBefore = shelf.load(in: .guest); let accountBefore = shelf.load(in: .user(owner))
        #expect(throws: (any Error).self) { try shelf.adoptGuestLibrary(for: owner) }
        #expect(shelf.load(in: .guest) == guestBefore && shelf.load(in: .user(owner)) == accountBefore)
    }

    @Test func unreadableAccountMetadataIsNeverOverwrittenDuringAdoption() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileAdoption-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        let guest = HomePlaceProfile(name: "Window seat")
        _ = try shelf.upsertHomeProfile(guest, in: .guest)
        _ = try shelf.upsertHomeProfile(HomePlaceProfile(ownerUserID: owner, name: "Kitchen"), in: .user(owner))
        let metadata = root.appendingPathComponent(LocalAccountScope.user(owner).storageComponent)
            .appendingPathComponent("library-v1.json")
        let damaged = Data("unreadable account metadata".utf8); try damaged.write(to: metadata)
        #expect(throws: (any Error).self) { try shelf.adoptGuestLibrary(for: owner) }
        #expect(try Data(contentsOf: metadata) == damaged)
        #expect(shelf.load(in: .guest).preferences?.homeProfiles?.first?.id == guest.id)
    }

    @Test func unreadableGuestMetadataDoesNotReportACompletedAdoption() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeProfileAdoption-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        _ = try shelf.upsertHomeProfile(HomePlaceProfile(name: "Window seat"), in: .guest)
        _ = try shelf.upsertHomeProfile(HomePlaceProfile(ownerUserID: owner, name: "Kitchen"), in: .user(owner))
        let accountBefore = shelf.load(in: .user(owner))
        let metadata = root.appendingPathComponent(LocalAccountScope.guest.storageComponent)
            .appendingPathComponent("library-v1.json")
        let damaged = Data("unreadable guest metadata".utf8); try damaged.write(to: metadata)
        #expect(throws: (any Error).self) { try shelf.adoptGuestLibrary(for: owner) }
        #expect(try Data(contentsOf: metadata) == damaged)
        #expect(shelf.load(in: .user(owner)) == accountBefore)
    }
}
