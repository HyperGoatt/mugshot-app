import Foundation
import Testing
import UIKit
@testable import testMugshot

struct PendingVisitRecoveryTests {
    @Test func pendingSubmissionOnlyResumesItsOriginatingDraftAndSession() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }

        let userID = UUID()
        let draftID = UUID()
        let sessionID = UUID()
        let cafe = Cafe(name: "Identity Cafe")
        let session = CafeSessionDraft(
            id: sessionID,
            ownerUserID: userID,
            cafeID: cafe.id,
            primarySipDraftID: draftID
        )
        let draft = SipDraft(
            id: draftID,
            ownerUserID: userID,
            context: .cafe,
            cafe: cafe,
            drinkName: "Cortado",
            overallScore: 4,
            cafeSessionDraft: session,
            cafeSessionSipOrder: 0,
            cafeSessionSipRole: .primary
        )
        let link = PendingCafeSessionLink(
            sessionID: sessionID,
            startedAt: session.startedAt,
            sipOrder: 0,
            sipRole: .primary,
            visitContext: CafeVisitContext(),
            returnIntention: nil,
            reorderIntention: nil,
            repeatComparison: nil,
            experienceSnapshot: nil,
            shareProjection: CafeExperienceShareProjection()
        )
        let pending = try fixture.store.prepare(
            visitId: draftID,
            userId: userID,
            cafe: cafe,
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Cortado",
            caption: "",
            notes: nil,
            visibility: .friends,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            cafeSession: link,
            images: [],
            posterPhotoIndex: 0
        )

        #expect(pending.canResume(with: draft, authenticatedUserID: userID))

        var wrongSessionOrder = draft
        wrongSessionOrder.cafeSessionSipOrder = 1
        #expect(!pending.canResume(with: wrongSessionOrder, authenticatedUserID: userID))

        var wrongCafe = draft
        wrongCafe.cafe = Cafe(name: "Another Cafe")
        #expect(!pending.canResume(with: wrongCafe, authenticatedUserID: userID))

        #expect(!pending.canResume(with: draft, authenticatedUserID: UUID()))

        let anotherDraft = SipDraft(
            ownerUserID: userID,
            context: .cafe,
            cafe: cafe,
            drinkName: "Cortado",
            overallScore: 4
        )
        #expect(!pending.canResume(with: anotherDraft, authenticatedUserID: userID))
    }

    @Test func replacingPendingPhotosKeepsVisitIdentityAndFreezesTheNewPlan() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }

        let userID = UUID()
        let visitID = UUID()
        let original = try fixture.store.prepare(
            visitId: visitID,
            userId: userID,
            cafe: Cafe(name: "Photo Cafe"),
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Latte",
            caption: "Same frozen sip",
            notes: nil,
            visibility: .friends,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            images: [image(.brown), image(.red)],
            posterPhotoIndex: 1
        )
        var created = original
        created.phase = .visitCreated
        try fixture.store.save(created)

        let replacement = try fixture.store.replaceImages(
            for: created,
            images: [image(.blue)],
            posterPhotoIndex: 0
        )

        #expect(replacement.record.id == visitID)
        #expect(replacement.record.userId == userID)
        #expect(replacement.record.caption == created.caption)
        #expect(replacement.record.phase == .visitCreated)
        #expect(replacement.record.posterPhotoIndex == 0)
        #expect(replacement.record.localPhotoNames.count == 1)
        #expect(replacement.record.objectPaths.count == 1)
        #expect(replacement.record.objectPaths != created.objectPaths)
        #expect(replacement.obsoleteObjectPaths == created.objectPaths)
        #expect(try fixture.store.loadImages(for: replacement.record).count == 1)
        #expect(fixture.store.load(userId: userID) == replacement.record)

        var uploaded = replacement.record
        uploaded.phase = .photosUploaded
        #expect(throws: PendingVisitSubmissionStoreError.self) {
            try fixture.store.replaceImages(
                for: uploaded,
                images: [],
                posterPhotoIndex: 0
            )
        }
    }

    @Test func taggedCompanionIdentitiesRoundTripAndOlderRecordsRemainDecodable() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }

        let userID = UUID()
        let companions = [
            SipCompanion(
                userID: UUID(),
                displayName: "Amanda",
                username: "amanda",
                avatarURL: "https://example.com/amanda.jpg"
            ),
            SipCompanion(
                userID: UUID(),
                displayName: "Jake",
                username: "jake",
                avatarURL: nil
            )
        ]
        let pending = try fixture.store.prepare(
            userId: userID,
            cafe: nil,
            entryContext: .home,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Cortado",
            caption: "Shared memory",
            notes: nil,
            visibility: .friends,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            taggedCompanions: companions,
            images: [],
            posterPhotoIndex: 0
        )

        #expect(fixture.store.load(userId: userID)?.taggedCompanions == companions)

        let encoded = try JSONEncoder().encode(pending)
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "taggedCompanions")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let decodedLegacy = try JSONDecoder().decode(
            PendingVisitSubmissionRecord.self,
            from: legacyData
        )

        #expect(decodedLegacy.taggedCompanions == nil)
    }

    @Test func retryPayloadRejectsAnyRawNoteAboveTheDatabaseLimit() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }

        let limit = PendingVisitSubmissionRecord.maximumRawNoteLength
        let atLimit = String(repeating: "a", count: limit)
        let overLimit = atLimit + "b"

        let valid = try makePending(
            store: fixture.store,
            notes: atLimit,
            sipRawNote: atLimit,
            contextRawNote: atLimit
        )
        #expect(valid.hasValidRetryPayload)
        #expect(valid.retryPayloadIssue == nil)

        let oversizedLegacySip = try makePending(
            store: fixture.store,
            notes: overLimit,
            sipRawNote: nil,
            contextRawNote: nil
        )
        #expect(!oversizedLegacySip.hasValidRetryPayload)
        #expect(oversizedLegacySip.retryPayloadIssue == .sipRawNoteExceedsLimit)

        let normalizedV3Sip = try makePending(
            store: fixture.store,
            notes: nil,
            sipRawNote: overLimit,
            contextRawNote: nil
        )
        #expect(
            normalizedV3Sip.v3Reflection?.sipRawNote?.v3DatabaseCharacterCount
                == limit
        )
        let oversizedV3Sip = try pendingByInjectingLegacyV3RawNote(
            overLimit,
            key: "sipRawNote",
            into: normalizedV3Sip
        )
        #expect(!oversizedV3Sip.hasValidRetryPayload)
        #expect(oversizedV3Sip.retryPayloadIssue == .sipRawNoteExceedsLimit)

        let normalizedContext = try makePending(
            store: fixture.store,
            notes: nil,
            sipRawNote: nil,
            contextRawNote: overLimit
        )
        #expect(
            normalizedContext.v3Reflection?.contextRawNote?.v3DatabaseCharacterCount
                == limit
        )
        let oversizedContext = try pendingByInjectingLegacyV3RawNote(
            overLimit,
            key: "contextRawNote",
            into: normalizedContext
        )
        #expect(!oversizedContext.hasValidRetryPayload)
        #expect(oversizedContext.retryPayloadIssue == .contextRawNoteExceedsLimit)
    }

    private func makeStore() throws -> (
        store: PendingVisitSubmissionStore,
        cleanup: () -> Void
    ) {
        let suiteName = "PendingVisitRecoveryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return (
            PendingVisitSubmissionStore(
                defaults: defaults,
                baseDirectory: directory
            ),
            {
                defaults.removePersistentDomain(forName: suiteName)
                try? FileManager.default.removeItem(at: directory)
            }
        )
    }

    private func makePending(
        store: PendingVisitSubmissionStore,
        notes: String?,
        sipRawNote: String?,
        contextRawNote: String?
    ) throws -> PendingVisitSubmissionRecord {
        let visitID = UUID()
        return try store.prepare(
            visitId: visitID,
            userId: UUID(),
            cafe: nil,
            entryContext: .elsewhere,
            locationName: "Train",
            drinkType: .tea,
            customDrinkType: nil,
            drinkSubtype: "Iced tea",
            caption: "On the move",
            notes: notes,
            visibility: .private,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            v3Reflection: V3VisitReflection(
                visitID: visitID,
                sipScore: 4,
                contextScore: nil,
                contextCriteria: [],
                sipRawNote: sipRawNote,
                contextRawNote: contextRawNote,
                rawNoteVisibility: .private,
                photoFallback: .mugsyMissedPhoto,
                homeMakeAgain: nil
            ),
            images: [],
            posterPhotoIndex: 0
        )
    }

    private func pendingByInjectingLegacyV3RawNote(
        _ note: String,
        key: String,
        into record: PendingVisitSubmissionRecord
    ) throws -> PendingVisitSubmissionRecord {
        let encoded = try JSONEncoder().encode(record)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var reflection = try #require(object["v3Reflection"] as? [String: Any])
        reflection[key] = note
        object["v3Reflection"] = reflection
        return try JSONDecoder().decode(
            PendingVisitSubmissionRecord.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private func image(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}
