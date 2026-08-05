import Foundation
import Testing
import UIKit
@testable import testMugshot

struct AccountScopedLocalStateTests {
    @Test func laterAuthenticationAttemptInvalidatesEveryEarlierCompletion() {
        var epoch = AuthenticationOperationEpoch()
        let firstAttempt = epoch.begin()
        let secondAttempt = epoch.begin()

        #expect(!epoch.isCurrent(firstAttempt))
        #expect(epoch.isCurrent(secondAttempt))
    }

    @Test func accountMutationRequiresBothPresentedAndTransportIdentity() {
        let expectedAccountID = UUID()
        let replacementAccountID = UUID()

        #expect(MugshotAccountOperationScope.matches(
            expectedAccountID: expectedAccountID,
            presentedAccountID: expectedAccountID,
            authenticatedSessionID: expectedAccountID
        ))
        #expect(!MugshotAccountOperationScope.matches(
            expectedAccountID: expectedAccountID,
            presentedAccountID: replacementAccountID,
            authenticatedSessionID: expectedAccountID
        ))
        #expect(!MugshotAccountOperationScope.matches(
            expectedAccountID: expectedAccountID,
            presentedAccountID: expectedAccountID,
            authenticatedSessionID: replacementAccountID
        ))
    }

    @Test func authenticationProvidersExposeOnlyValidFreshVerificationMethods() {
        let googleUser = AuthenticatedUser(
            id: UUID(),
            email: "google@mugshot.test",
            providers: [.google]
        )
        #expect(!googleUser.canVerifyWithPassword)
        #expect(!googleUser.canVerifyWithApple)
        #expect(googleUser.canVerifyWithGoogle)

        let emailUser = AuthenticatedUser(
            id: UUID(),
            email: "email@mugshot.test",
            providers: [.email]
        )
        #expect(emailUser.canVerifyWithPassword)
        #expect(!emailUser.canVerifyWithApple)
        #expect(!emailUser.canVerifyWithGoogle)

        let appleUser = AuthenticatedUser(
            id: UUID(),
            email: "relay@privaterelay.appleid.com",
            providers: [.apple]
        )
        #expect(!appleUser.canVerifyWithPassword)
        #expect(appleUser.canVerifyWithApple)
        #expect(!appleUser.canVerifyWithGoogle)

        let legacyUser = AuthenticatedUser(
            id: UUID(),
            email: "legacy@mugshot.test"
        )
        #expect(legacyUser.canVerifyWithPassword)
        #expect(legacyUser.canVerifyWithApple)
        #expect(!legacyUser.canVerifyWithGoogle)

        let deletionContext = AccountDeletionVerificationContext(user: googleUser)
        #expect(!deletionContext.canVerifyWithPassword)
        #expect(!deletionContext.canVerifyWithApple)
        #expect(deletionContext.canVerifyWithGoogle)
        #expect(deletionContext.verificationMethodCount == 1)
    }

    @Test func legacyJournalWithAnotherExplicitOwnerIsNeverRelabeled() throws {
        let suiteName = "LegacyJournalOwner.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstUserID = UUID()
        let secondUserID = UUID()
        let firstCafe = Cafe(name: "First Owner Cafe", isFavorite: true)
        let legacy = AppData(
            currentUser: User(
                id: firstUserID,
                username: "first_owner",
                displayName: "First Owner",
                location: ""
            ),
            cafes: [firstCafe],
            visits: [],
            ratingTemplate: RatingTemplate(),
            hasCompletedOnboarding: true
        )
        defaults.set(try JSONEncoder().encode(legacy), forKey: "MugshotAppData")
        let manager = DataManager(defaults: defaults)

        manager.applyAuthenticatedProfile(profile(id: secondUserID, username: "second_owner"))

        #expect(manager.appData.currentUser?.id == secondUserID)
        #expect(manager.appData.cafes.isEmpty)

        manager.applyAuthenticatedProfile(profile(id: firstUserID, username: "first_owner"))
        #expect(manager.appData.currentUser?.id == firstUserID)
        #expect(manager.appData.cafes.map(\.name) == [firstCafe.name])
    }

    @Test func ownerlessLegacyJournalIsHeldInsteadOfClaimedByFirstLogin() throws {
        let suiteName = "OwnerlessLegacyJournal.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacy = AppData(cafes: [Cafe(name: "Unproven Legacy Cafe")])
        let encodedLegacy = try JSONEncoder().encode(legacy)
        defaults.set(encodedLegacy, forKey: "MugshotAppData")
        let manager = DataManager(defaults: defaults)
        let newUserID = UUID()

        manager.applyAuthenticatedProfile(profile(id: newUserID, username: "new_owner"))

        #expect(manager.appData.currentUser?.id == newUserID)
        #expect(manager.appData.cafes.isEmpty)
        #expect(defaults.data(forKey: "MugshotAppData") == encodedLegacy)
    }

    @Test func personalMapSnapshotNeverCrossesAccountOrGuestScopes() throws {
        let suiteName = "PersonalMapSnapshotScope.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstUserID = UUID()
        let secondUserID = UUID()
        let manager = DataManager(defaults: defaults)
        let snapshot = RemoteMapPinSnapshot(pins: [], cafeStates: [])

        manager.applyAuthenticatedProfile(profile(id: firstUserID, username: "first"))
        manager.applyPersonalMapSnapshot(snapshot, for: firstUserID)
        #expect(manager.personalMapSnapshot(for: firstUserID) == snapshot)

        manager.applyAuthenticatedProfile(profile(id: secondUserID, username: "second"))
        #expect(manager.personalMapSnapshot(for: firstUserID) == nil)
        #expect(manager.personalMapSnapshot(for: secondUserID) == nil)

        manager.prepareGuestSession()
        #expect(manager.personalMapSnapshot(for: secondUserID) == nil)
    }

    @Test func deletedOwnerLegacyJournalCannotReappearAfterRelaunch() throws {
        let suiteName = "DeletedLegacyJournalOwner.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let ownerID = UUID()
        let ownerDataKey = "MugshotUserAppData.v1.\(ownerID.uuidString.lowercased())"
        let legacy = AppData(
            currentUser: User(
                id: ownerID,
                username: "departing_owner",
                displayName: "Departing Owner",
                location: ""
            ),
            cafes: [Cafe(name: "Departing Owner Cafe", isFavorite: true)],
            visits: [],
            ratingTemplate: RatingTemplate(),
            hasCompletedOnboarding: true
        )
        defaults.set(try JSONEncoder().encode(legacy), forKey: "MugshotAppData")

        let authenticatedManager = DataManager(defaults: defaults)
        authenticatedManager.applyAuthenticatedProfile(
            profile(id: ownerID, username: "departing_owner")
        )
        #expect(defaults.data(forKey: "MugshotAppData") == nil)
        #expect(defaults.data(forKey: ownerDataKey) != nil)

        authenticatedManager.clearLocalReleaseState(for: ownerID)

        let relaunchedManager = DataManager(defaults: defaults)
        relaunchedManager.prepareGuestSession()

        #expect(relaunchedManager.appData.currentUser == nil)
        #expect(relaunchedManager.appData.cafes.isEmpty)
        #expect(relaunchedManager.appData.visits.isEmpty)
        #expect(defaults.data(forKey: "MugshotAppData") == nil)
        #expect(defaults.data(forKey: ownerDataKey) == nil)
    }

    @Test func sipDraftsAndMediaStayInsideTheirOwnerScope() throws {
        let directory = temporaryDirectory(named: "ScopedSipDrafts")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SipDraftStore(baseDirectory: directory)
        let firstUserID = UUID()
        let secondUserID = UUID()
        let firstDraft = SipDraft(
            ownerUserID: firstUserID,
            context: .home,
            drinkName: "First account sip",
            visibility: .private
        )
        let secondDraft = SipDraft(
            ownerUserID: secondUserID,
            context: .home,
            drinkName: "Second account sip",
            visibility: .private
        )

        _ = try store.save(firstDraft, images: [testImage(.systemOrange)], in: .user(firstUserID))
        _ = try store.save(secondDraft, images: [testImage(.systemBlue)], in: .user(secondUserID))

        #expect(store.load(id: firstDraft.id, in: .user(firstUserID))?.images.count == 1)
        #expect(store.load(id: firstDraft.id, in: .user(secondUserID)) == nil)
        #expect(store.load(id: firstDraft.id, in: .guest) == nil)
        #expect(store.allDrafts(in: .user(firstUserID)).map(\.id) == [firstDraft.id])
        #expect(store.allDrafts(in: .user(secondUserID)).map(\.id) == [secondDraft.id])
        #expect(store.allDrafts(in: .guest).isEmpty)
        #expect(throws: SipDraftStoreError.self) {
            try store.save(firstDraft, images: [], in: .user(secondUserID))
        }
    }

    @Test func draftReadReportPreservesAndSurfacesUnreadableMetadata() throws {
        let directory = temporaryDirectory(named: "UnreadableSipDraft")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SipDraftStore(baseDirectory: directory)
        let ownerID = UUID()
        let readableDraft = SipDraft(
            ownerUserID: ownerID,
            context: .home,
            drinkName: "Readable draft",
            visibility: .private
        )
        _ = try store.save(readableDraft, images: [], in: .user(ownerID))

        let unreadableID = UUID()
        let unreadableDirectory = directory
            .appendingPathComponent("v2/users", isDirectory: true)
            .appendingPathComponent(ownerID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(unreadableID.uuidString.lowercased(), isDirectory: true)
        try FileManager.default.createDirectory(
            at: unreadableDirectory,
            withIntermediateDirectories: true
        )
        let storedBytes = Data("not-a-draft".utf8)
        let metadataURL = unreadableDirectory.appendingPathComponent("draft.json")
        try storedBytes.write(to: metadataURL, options: .atomic)

        let report = store.readReport(in: .user(ownerID))

        #expect(report.drafts.map(\.id) == [readableDraft.id])
        #expect(report.issues.contains(.unreadableDraftMetadata(unreadableID)))
        #expect(report.unreadableDraftCount == 1)
        #expect(try Data(contentsOf: metadataURL) == storedBytes)
    }

    @Test func draftReadReportSurfacesMigrationFailureWithoutReplacingSource() throws {
        let baseURL = temporaryDirectory(named: "BlockedSipDraftMigration")
        defer { try? FileManager.default.removeItem(at: baseURL) }
        let sourceBytes = Data("legacy-source-must-remain".utf8)
        try sourceBytes.write(to: baseURL, options: .atomic)
        let store = SipDraftStore(baseDirectory: baseURL)

        let report = store.readReport(in: .user(UUID()))

        #expect(report.drafts.isEmpty)
        #expect(report.issues.contains(.legacyMigrationUnavailable))
        #expect(try Data(contentsOf: baseURL) == sourceBytes)
    }

    @Test func transientSessionResolutionPrefersCachedIdentityAndKeepsItsScope() throws {
        let cached = AuthenticatedUser(id: UUID(), email: "cached@mugshot.test")
        let established = AuthenticatedUser(id: UUID(), email: "old@mugshot.test")

        #expect(TransientSessionAccountResolver.accountToPreserve(
            cachedUser: cached,
            establishedUser: established
        ) == cached)
        #expect(TransientSessionAccountResolver.accountToPreserve(
            cachedUser: nil,
            establishedUser: established
        ) == established)

        let suiteName = "TransientSessionScope.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = DataManager(defaults: defaults)
        manager.applyAuthenticatedProfile(
            profile(id: cached.id, username: "cached_owner")
        )
        manager.addCafe(Cafe(name: "Cached Owner Cafe"))
        manager.prepareGuestSession()
        manager.addCafe(Cafe(name: "Guest Cafe"))

        manager.preserveAuthenticatedAccountScope(userID: cached.id)

        #expect(manager.appData.currentUser?.id == cached.id)
        #expect(manager.appData.cafes.map(\.name) == ["Cached Owner Cafe"])
    }

    @Test func legacyDraftMigrationCopiesProvenOwnersAndQuarantinesAmbiguousDrafts() throws {
        let directory = temporaryDirectory(named: "SipDraftMigration")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ownerUserID = UUID()
        let provenDraft = SipDraft(
            ownerUserID: ownerUserID,
            context: .home,
            drinkName: "Proven legacy draft",
            visibility: .private,
            localPhotoNames: ["legacy-photo.jpg"]
        )
        let ambiguousDraft = SipDraft(
            context: .home,
            drinkName: "Ambiguous legacy draft",
            visibility: .private
        )
        try writeLegacyBundle(provenDraft, image: testImage(.systemGreen), at: directory)
        try writeLegacyBundle(ambiguousDraft, image: nil, at: directory)
        try Data(provenDraft.id.uuidString.lowercased().utf8).write(
            to: directory.appendingPathComponent("active-draft-id"),
            options: .atomic
        )

        let store = SipDraftStore(baseDirectory: directory)
        let migrated = try #require(store.load(in: .user(ownerUserID)))

        #expect(migrated.draft.id == provenDraft.id)
        #expect(migrated.images.count == 1)
        #expect(store.load(in: .guest) == nil)
        #expect(FileManager.default.fileExists(
            atPath: directory
                .appendingPathComponent(provenDraft.id.uuidString.lowercased(), isDirectory: true)
                .path
        ))
        let quarantine = directory
            .appendingPathComponent("v2", isDirectory: true)
            .appendingPathComponent("quarantine", isDirectory: true)
        let quarantinedNames = try FileManager.default.contentsOfDirectory(atPath: quarantine.path)
        #expect(quarantinedNames.contains { $0.hasPrefix(ambiguousDraft.id.uuidString.lowercased()) })
        #expect(FileManager.default.fileExists(
            atPath: directory
                .appendingPathComponent("v2", isDirectory: true)
                .appendingPathComponent("legacy-migration-complete")
                .path
        ))
    }

    @Test func cafeVisibilityDefaultsDoNotCrossAccountsOrGuest() throws {
        let suiteName = "AccountScopedVisibility.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CafeVisibilityPreferenceStore(defaults: defaults)
        let firstScope = LocalAccountScope.user(UUID())
        let secondScope = LocalAccountScope.user(UUID())

        store.rememberCafeVisibility(.everyone, in: firstScope)
        store.rememberCafeVisibility(.private, in: .guest)

        #expect(store.defaultCafeVisibility(in: firstScope) == .everyone)
        #expect(store.defaultCafeVisibility(in: secondScope) == .friends)
        #expect(store.defaultCafeVisibility(in: .guest) == .private)
        #expect(defaults.string(forKey: CafeVisibilityPreferenceStore.valueKey) == nil)
    }

    @MainActor
    @Test func mapRecentsReloadForTheActivatedAccountScope() throws {
        let suiteName = "AccountScopedMapRecents.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstScope = LocalAccountScope.user(UUID())
        let secondScope = LocalAccountScope.user(UUID())
        let firstRecent = MapSearchRecent(
            title: "First Cafe",
            subtitle: "First city",
            query: "First Cafe, First city"
        )
        let secondRecent = MapSearchRecent(
            title: "Second Cafe",
            subtitle: "Second city",
            query: "Second Cafe, Second city"
        )
        defaults.set(
            try JSONEncoder().encode([firstRecent]),
            forKey: MapSearchService.recentsKey(for: firstScope)
        )
        defaults.set(
            try JSONEncoder().encode([secondRecent]),
            forKey: MapSearchService.recentsKey(for: secondScope)
        )

        let service = MapSearchService(defaults: defaults, scope: firstScope)
        #expect(service.recents == [firstRecent])

        service.activate(scope: secondScope)
        #expect(service.recents == [secondRecent])

        service.activate(scope: .guest)
        #expect(service.recents.isEmpty)
    }

    @Test func photoCacheClearsMemoryAndMigratesOnlyKnownLegacyKeys() throws {
        let directory = temporaryDirectory(named: "ScopedPhotoCache")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let knownKey = "known-legacy-photo"
        let unknownKey = "unknown-legacy-photo"
        try #require(testImage(.systemPurple).jpegData(compressionQuality: 0.8)).write(
            to: directory.appendingPathComponent("\(knownKey).jpg"),
            options: .atomic
        )
        try #require(testImage(.systemRed).jpegData(compressionQuality: 0.8)).write(
            to: directory.appendingPathComponent("\(unknownKey).jpg"),
            options: .atomic
        )
        let firstScope = LocalAccountScope.user(UUID())
        let secondScope = LocalAccountScope.user(UUID())
        let cache = PhotoCache(photosDirectory: directory, initialScope: .guest)

        try cache.activate(scope: firstScope, migratingKnownKeys: [knownKey])
        #expect(cache.retrieve(forKey: knownKey) != nil)
        #expect(cache.retrieve(forKey: unknownKey) == nil)

        try cache.activate(scope: secondScope)
        #expect(cache.retrieve(forKey: knownKey) == nil)

        try cache.activate(scope: firstScope)
        #expect(cache.retrieve(forKey: knownKey) != nil)
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("\(knownKey).jpg").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("\(unknownKey).jpg").path
        ))
    }

    private func temporaryDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).\(UUID().uuidString)", isDirectory: true)
    }

    private func testImage(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
    }

    private func profile(id: UUID, username: String) -> SupabaseUserProfile {
        SupabaseUserProfile(
            id: id,
            displayName: username,
            username: username,
            bio: nil,
            location: nil,
            favoriteDrink: nil,
            instagramHandle: nil,
            avatarURL: nil,
            bannerURL: nil,
            websiteURL: nil
        )
    }

    private func writeLegacyBundle(
        _ draft: SipDraft,
        image: UIImage?,
        at baseDirectory: URL
    ) throws {
        let bundle = baseDirectory
            .appendingPathComponent(draft.id.uuidString.lowercased(), isDirectory: true)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(draft).write(
            to: bundle.appendingPathComponent("draft.json"),
            options: .atomic
        )
        if let image,
           let name = draft.localPhotoNames.first,
           let data = image.jpegData(compressionQuality: 0.8) {
            try data.write(to: bundle.appendingPathComponent(name), options: .atomic)
        }
    }
}
