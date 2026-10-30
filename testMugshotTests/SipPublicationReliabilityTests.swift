import Foundation
import Testing
import UIKit
@testable import testMugshot

struct SipPublicationReliabilityTests {
    @MainActor @Test func frozenUploadedSubmissionCanRetryWithoutLocalPhotosOrFreshFormValidation() throws {
        let owner = UUID()
        var draft = SipDraft(ownerUserID: owner, context: .home, locationName: "Home", drinkName: "Latte", overallScore: 4, socialCaption: "Fixture", visibility: .friends)
        let suite = "PublicationRegression-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = PendingVisitSubmissionStore(defaults: defaults, baseDirectory: directory)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        var pending = try store.prepare(
            visitId: draft.id, userId: owner, cafe: nil, entryContext: .home,
            locationName: "Home", drinkType: .coffee, customDrinkType: nil,
            drinkSubtype: "Latte", caption: "Fixture", notes: nil,
            visibility: .friends, ratings: [:], overallScore: 4,
            ratingTemplate: RatingTemplate(), images: [image], posterPhotoIndex: 0
        )
        pending.phase = .photosUploaded
        pending.uploadedPhotoURLs = ["fixture-reference"]
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner) != nil)
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: pending, authenticatedUserID: owner) == nil)
        draft.socialCaption = ""
        pending.remoteFinalizedAt = .now
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: pending, authenticatedUserID: owner) == nil)
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: pending, authenticatedUserID: UUID()) != nil)
    }

    @Test func sharedValidationExplainsEveryBoundaryInsteadOfSilentlyDisablingPublish() {
        let owner = UUID()
        var draft = SipDraft(ownerUserID: owner, context: .elsewhere, locationName: "Train", drinkName: "Tea", overallScore: 0.5, socialCaption: "Fixture", visibility: .friends, photoFallback: .mugsyMissedPhoto)
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner) == nil)
        draft.overallScore = .nan
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner) != nil)
        draft.overallScore = 4
        draft.privateNotes = String(repeating: "x", count: 10_001)
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner)?.contains("10,000") == true)
        draft.privateNotes = ""
        draft.socialCaption = ""
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner) == SipCaptionValidationError.required.localizedDescription)
    }

    @MainActor @Test func publicationGateRejectsRepeatedTapsAndConcurrentRecoveryUntilReleased() {
        let gate = SipPublicationGate()
        let owner = UUID(), visit = UUID()
        let token = gate.begin(userID: owner, visitID: visit)
        #expect(token != nil)
        #expect(gate.begin(userID: owner, visitID: visit) == nil)
        gate.finish(token: UUID())
        #expect(gate.begin(userID: owner, visitID: visit) == nil)
        gate.finish(token: token!)
        #expect(gate.begin(userID: owner, visitID: visit) != nil)
    }

    @Test func uploadPlanRejectsMissingDuplicateAndForeignAccountPhotos() throws {
        let owner = UUID(), visit = UUID()
        let paths = VisitPhotoUploadPlan.objectPaths(userId: owner, visitId: visit, objectIds: [UUID(), UUID()])
        try VisitPhotoUploadPlan.validate(userID: owner, visitID: visit, imageCount: 2, paths: paths, completedPaths: [])
        #expect(throws: VisitPhotoUploadError.invalidUploadPlan) {
            try VisitPhotoUploadPlan.validate(userID: owner, visitID: visit, imageCount: 0, paths: paths, completedPaths: [])
        }
        #expect(throws: VisitPhotoUploadError.invalidUploadPlan) {
            try VisitPhotoUploadPlan.validate(userID: owner, visitID: visit, imageCount: 2, paths: [paths[0], paths[0]], completedPaths: [])
        }
        #expect(throws: VisitPhotoUploadError.invalidUploadPlan) {
            try VisitPhotoUploadPlan.validate(userID: UUID(), visitID: visit, imageCount: 2, paths: paths, completedPaths: [])
        }
    }
}
