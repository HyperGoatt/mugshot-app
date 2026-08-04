import Foundation
import Testing
import UIKit
@testable import testMugshot

struct PendingVisitOutboxTests {
    @Test func unreadableOutboxIsReportedWithoutChangingStoredBytes() throws {
        let resources = try makeResources()
        defer { resources.cleanup() }
        let userID = UUID()
        let storedBytes = Data("not-json-recovery-data".utf8)
        let storageKey = PendingVisitSubmissionStore.outboxStorageKey(for: userID)
        resources.defaults.set(storedBytes, forKey: storageKey)
        let store = PendingVisitSubmissionStore(
            defaults: resources.defaults,
            baseDirectory: resources.directory
        )

        #expect(throws: PendingVisitSubmissionStoreError.self) {
            try store.loadAll(userId: userID)
        }
        #expect(resources.defaults.data(forKey: storageKey) == storedBytes)
    }

    @Test func multiplePendingVisitsAreFIFOAndRemovalIsExact() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let userID = UUID()
        let tagged = SipCompanion(
            userID: UUID(),
            displayName: "Tagged friend",
            username: "tagged",
            avatarURL: nil
        )
        let firstPrepared = try prepare(
            store: fixture.store,
            userID: userID,
            caption: "First",
            image: image(.brown),
            taggedCompanions: [tagged]
        )
        let secondPrepared = try prepare(
            store: fixture.store,
            userID: userID,
            caption: "Second",
            image: image(.blue)
        )
        let first = try replacingCreatedAt(
            in: firstPrepared,
            with: Date(timeIntervalSinceReferenceDate: 200)
        )
        let second = try replacingCreatedAt(
            in: secondPrepared,
            with: Date(timeIntervalSinceReferenceDate: 100)
        )
        try fixture.store.save(first)
        try fixture.store.save(second)

        #expect(try fixture.store.loadAll(userId: userID).map(\.id) == [second.id, first.id])
        #expect(fixture.store.load(userId: userID)?.id == second.id)
        #expect(fixture.store.load(visitId: first.id, userId: userID)?.taggedCompanions == [tagged])

        fixture.store.remove(second)

        #expect(try fixture.store.loadAll(userId: userID).map(\.id) == [first.id])
        #expect(fixture.store.load(visitId: second.id, userId: userID) == nil)
        #expect(try fixture.store.loadImages(for: first).count == 1)
    }

    @Test func recordsAndMediaRemainAccountScopedEvenForTheSameVisitID() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let firstUserID = UUID()
        let secondUserID = UUID()
        let sharedVisitID = UUID()

        let first = try prepare(
            store: fixture.store,
            visitID: sharedVisitID,
            userID: firstUserID,
            caption: "First account",
            image: image(.red)
        )
        let second = try prepare(
            store: fixture.store,
            visitID: sharedVisitID,
            userID: secondUserID,
            caption: "Second account",
            image: image(.green)
        )

        #expect(try fixture.store.loadAll(userId: firstUserID) == [first])
        #expect(try fixture.store.loadAll(userId: secondUserID) == [second])
        #expect(fixture.store.load(visitId: sharedVisitID, userId: UUID()) == nil)
        #expect(try fixture.store.loadImages(for: first).count == 1)
        #expect(try fixture.store.loadImages(for: second).count == 1)

        fixture.store.remove(first)

        #expect(try fixture.store.loadAll(userId: firstUserID).isEmpty)
        #expect(try fixture.store.loadAll(userId: secondUserID) == [second])
        #expect(try fixture.store.loadImages(for: second).count == 1)
    }

    @Test func legacyRecordAndMediaMigrateWithoutDeletingTheFinalizedReceipt() throws {
        let source = try makeStore()
        defer { source.cleanup() }
        let userID = UUID()
        var legacy = try prepare(
            store: source.store,
            userID: userID,
            caption: "Already published",
            image: image(.purple)
        )
        legacy.phase = .photosUploaded
        legacy.remoteFinalizedAt = Date(timeIntervalSince1970: 1_234)

        let target = try makeResources()
        defer { target.cleanup() }
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy))
                as? [String: Any]
        )
        legacyObject["sharedMemoryInvitees"] = [[
            "userID": UUID().uuidString,
            "displayName": "Retired invitee",
            "username": "retired",
            "avatarURL": NSNull()
        ]]
        legacyObject["sharedMemoryInvitationsCompletedAt"] = Date().timeIntervalSinceReferenceDate
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        target.defaults.set(
            legacyData,
            forKey: PendingVisitSubmissionStore.legacyStorageKey(for: userID)
        )
        let legacyDirectory = target.directory.appendingPathComponent(
            legacy.id.uuidString.lowercased(),
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: legacyDirectory,
            withIntermediateDirectories: true
        )
        try #require(image(.purple).jpegData(compressionQuality: 0.8)).write(
            to: legacyDirectory.appendingPathComponent("photo-0.jpg"),
            options: .atomic
        )

        let migratedStore = PendingVisitSubmissionStore(
            defaults: target.defaults,
            baseDirectory: target.directory
        )
        let migrated = try #require(migratedStore.load(userId: userID))

        #expect(migrated.id == legacy.id)
        #expect(migrated.remoteFinalizedAt == legacy.remoteFinalizedAt)
        #expect(migrated.isRemoteFinalized)
        #expect(try migratedStore.loadImages(for: migrated).count == 1)
        #expect(
            target.defaults.data(
                forKey: PendingVisitSubmissionStore.legacyStorageKey(for: userID)
            ) == legacyData
        )
        #expect(FileManager.default.fileExists(atPath: legacyDirectory.path))
        #expect(
            target.defaults.bool(
                forKey: PendingVisitSubmissionStore.migrationMarkerKey(for: userID)
            )
        )
    }

    @Test func staleMutationsAndOtherRemovalCannotDestroyAFinalizedReceipt() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let userID = UUID()
        let stale = try prepare(
            store: fixture.store,
            userID: userID,
            caption: "Published",
            image: nil
        )
        var finalized = stale
        finalized.phase = .photosUploaded
        finalized.remoteFinalizedAt = Date(timeIntervalSince1970: 4_321)
        try fixture.store.save(finalized)
        let other = try prepare(
            store: fixture.store,
            userID: userID,
            caption: "Still pending",
            image: nil
        )

        try fixture.store.save(stale)
        #expect(
            fixture.store.load(visitId: stale.id, userId: userID)?.remoteFinalizedAt
                == finalized.remoteFinalizedAt
        )
        fixture.store.remove(stale)
        fixture.store.remove(other)

        #expect(try fixture.store.loadAll(userId: userID) == [finalized])
        #expect(fixture.store.load(userId: userID)?.remoteFinalizedAt == finalized.remoteFinalizedAt)
    }

    @Test func publicationSetupPlanRetriesTagsUntilTheirReceiptIsDurable() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let person = SipCompanion(
            userID: UUID(),
            displayName: "Amanda",
            username: "amanda",
            avatarURL: nil
        )
        var finalized = try prepare(
            store: fixture.store,
            userID: UUID(),
            caption: "Tag retry",
            image: nil,
            taggedCompanions: [person]
        )
        finalized.remoteFinalizedAt = Date(timeIntervalSince1970: 4_321)

        let pendingPlan = try #require(SipPostPublicationSetupPlan.make(from: finalized))
        #expect(pendingPlan.visitID == finalized.id)
        #expect(pendingPlan.taggedUserIDs == [person.userID])
        #expect(!finalized.isPostPublicationSetupComplete)

        finalized.visitTagsCompletedAt = Date(timeIntervalSince1970: 4_322)
        let completedPlan = try #require(SipPostPublicationSetupPlan.make(from: finalized))
        #expect(completedPlan.taggedUserIDs == nil)
        #expect(finalized.isPostPublicationSetupComplete)
    }

    private func prepare(
        store: PendingVisitSubmissionStore,
        visitID: UUID = UUID(),
        userID: UUID,
        caption: String,
        image selectedImage: UIImage?,
        taggedCompanions: [SipCompanion]? = nil
    ) throws -> PendingVisitSubmissionRecord {
        try store.prepare(
            visitId: visitID,
            userId: userID,
            cafe: nil,
            entryContext: .home,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Coffee",
            caption: caption,
            notes: nil,
            visibility: .private,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            taggedCompanions: taggedCompanions,
            images: selectedImage.map { [$0] } ?? [],
            posterPhotoIndex: 0
        )
    }

    private func replacingCreatedAt(
        in record: PendingVisitSubmissionRecord,
        with date: Date
    ) throws -> PendingVisitSubmissionRecord {
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(record))
                as? [String: Any]
        )
        object["createdAt"] = date.timeIntervalSinceReferenceDate
        return try JSONDecoder().decode(
            PendingVisitSubmissionRecord.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private func makeStore() throws -> (
        store: PendingVisitSubmissionStore,
        cleanup: () -> Void
    ) {
        let resources = try makeResources()
        return (
            PendingVisitSubmissionStore(
                defaults: resources.defaults,
                baseDirectory: resources.directory
            ),
            resources.cleanup
        )
    }

    private func makeResources() throws -> (
        defaults: UserDefaults,
        directory: URL,
        cleanup: () -> Void
    ) {
        let suiteName = "PendingVisitOutboxTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PendingVisitOutbox.\(UUID().uuidString)",
            isDirectory: true
        )
        return (
            defaults,
            directory,
            {
                defaults.removePersistentDomain(forName: suiteName)
                try? FileManager.default.removeItem(at: directory)
            }
        )
    }

    private func image(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
    }
}
