import Foundation
import Testing
import UIKit
@testable import testMugshot

struct SharedMemoryComposerIntegrationTests {
    @Test func recipeAudienceDefaultsPrivateIndependentlyFromThePost() {
        let draft = SipDraft(
            context: .recipe,
            drinkName: "Dialed-in V60",
            visibility: .everyone,
            brewDetails: BrewDetails(recipeName: "Dialed-in V60")
        )

        #expect(draft.visibility == .everyone)
        #expect(draft.recipePublication.visibility == .private)
        #expect(draft.recipePublication.sourceKind == .original)
        #expect(!draft.recipePublication.redistributionAllowed)
        #expect(draft.recipePublicationRequirement == .ready)
    }

    @Test func recipeRightsAndSharedInviteesRoundTripWhileLegacyDraftsStaySafe() throws {
        let sourceVersionID = UUID()
        let invitee = companion(named: "Amanda")
        let contract = SipRecipePublicationContract(
            visibility: .everyone,
            sourceKind: .adapted,
            redistributionAllowed: true,
            sourceRecipeVersionID: sourceVersionID,
            acknowledgesPublicReuse: true
        )
        let draft = SipDraft(
            context: .recipe,
            drinkName: "Amanda's V60 remix",
            visibility: .friends,
            sharedMemoryInvitees: [invitee],
            recipePublication: contract,
            brewDetails: BrewDetails(recipeName: "Amanda's V60 remix")
        )

        let encoded = try JSONEncoder().encode(draft)
        let restored = try JSONDecoder().decode(SipDraft.self, from: encoded)
        #expect(restored.recipePublication == contract)
        #expect(restored.sharedMemoryInvitees == [invitee])

        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "storedRecipePublication")
        legacyObject.removeValue(forKey: "sharedMemoryInvitees")
        let legacy = try JSONDecoder().decode(
            SipDraft.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )

        #expect(legacy.recipePublication == .privateOriginal)
        #expect(legacy.sharedMemoryInvitees == nil)
    }

    @Test func everyoneRecipeRequiresReusableRightsAndExplicitAcknowledgment() {
        var contract = SipRecipePublicationContract.privateOriginal
        contract.visibility = .everyone
        #expect(contract.requirement == .needsRedistributionPermission)

        contract.redistributionAllowed = true
        #expect(contract.requirement == .needsPublicReuseAcknowledgment)

        contract.acknowledgesPublicReuse = true
        #expect(contract.requirement == .ready)

        contract.selectSource(.purchased)
        #expect(!contract.redistributionAllowed)
        #expect(!contract.acknowledgesPublicReuse)
        #expect(contract.requirement == .sourceCannotBePublic)

        contract.visibility = .private
        contract.selectSource(.adapted)
        #expect(contract.requirement == .needsImmutableSource)
    }

    @Test func pendingUploadFreezesRecipeTagsAndConsentInvitationsByExactVisitID() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let userID = UUID()
        let unrelatedID = UUID()
        let recipeVisitID = UUID()
        let tagged = companion(named: "Public tag")
        let invitee = companion(named: "Consenting friend")
        let sourceVersionID = UUID()
        let contract = SipRecipePublicationContract(
            visibility: .friends,
            sourceKind: .adapted,
            redistributionAllowed: true,
            sourceRecipeVersionID: sourceVersionID,
            acknowledgesPublicReuse: false
        )

        _ = try fixture.store.prepare(
            visitId: unrelatedID,
            userId: userID,
            cafe: nil,
            entryContext: .home,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Earlier sip",
            caption: "Still queued",
            notes: nil,
            visibility: .private,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            images: [],
            posterPhotoIndex: 0
        )
        let frozen = try fixture.store.prepare(
            visitId: recipeVisitID,
            userId: userID,
            cafe: nil,
            entryContext: .recipe,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Shared recipe",
            caption: "Exact retry",
            notes: nil,
            brewDetails: BrewDetails(recipeName: "Shared recipe"),
            visibility: .friends,
            ratings: ["Taste": 4.5],
            overallScore: 4.5,
            ratingTemplate: RatingTemplate(),
            recipePublication: contract,
            taggedCompanions: [tagged],
            sharedMemoryInvitees: [invitee],
            images: [],
            posterPhotoIndex: 0
        )

        #expect(fixture.store.load(userId: userID)?.id == unrelatedID)
        let exact = try #require(
            fixture.store.load(visitId: recipeVisitID, userId: userID)
        )
        #expect(exact == frozen)
        #expect(exact.resolvedRecipePublication == contract)
        #expect(exact.taggedCompanions == [tagged])
        #expect(exact.sharedMemoryInvitees == [invitee])

        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(exact))
                as? [String: Any]
        )
        legacyObject.removeValue(forKey: "recipePublication")
        legacyObject.removeValue(forKey: "sharedMemoryInvitees")
        let legacy = try JSONDecoder().decode(
            PendingVisitSubmissionRecord.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )
        #expect(legacy.resolvedRecipePublication == .privateOriginal)
        #expect(legacy.sharedMemoryInvitees == nil)
        #expect(legacy.taggedCompanions == [tagged])
    }

    @Test func finalizedPartialReceiptsRetryOnlyMissingIdentityWork() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let userID = UUID()
        let tagged = companion(named: "Tagged account")
        let invitee = companion(named: "Invited friend")
        var finalized = try fixture.store.prepare(
            userId: userID,
            cafe: nil,
            entryContext: .home,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Cortado",
            caption: "Published once",
            notes: nil,
            visibility: .friends,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            taggedCompanions: [tagged],
            sharedMemoryInvitees: [invitee],
            images: [],
            posterPhotoIndex: 0
        )
        finalized.remoteFinalizedAt = .now
        try fixture.store.save(finalized)

        #expect(
            SipRemoteRecoveryPlanner.action(
                for: finalized,
                authenticatedUserID: userID
            ) == .finishLocalCompletion
        )
        let initialPlan = try #require(
            SipPostPublicationSetupPlan.make(from: finalized)
        )
        #expect(initialPlan.taggedUserIDs == [tagged.userID])
        #expect(initialPlan.sharedMemoryInviteeIDs == [invitee.userID])
        #expect(!finalized.isPostPublicationSetupComplete)

        var tagsFinished = finalized
        tagsFinished.visitTagsCompletedAt = .now
        try fixture.store.save(tagsFinished)
        let invitationsOnly = try #require(
            SipPostPublicationSetupPlan.make(from: tagsFinished)
        )
        #expect(invitationsOnly.taggedUserIDs == nil)
        #expect(invitationsOnly.sharedMemoryInviteeIDs == [invitee.userID])
        #expect(tagsFinished.needsSharedMemoryInvitationsCompletion)

        try fixture.store.save(finalized)
        let monotonicallyMerged = try #require(
            fixture.store.load(visitId: finalized.id, userId: userID)
        )
        #expect(monotonicallyMerged.visitTagsCompletedAt != nil)

        var complete = tagsFinished
        complete.sharedMemoryInvitationsCompletedAt = .now
        try fixture.store.save(complete)
        let noRemainingWork = try #require(
            SipPostPublicationSetupPlan.make(from: complete)
        )
        #expect(noRemainingWork.taggedUserIDs == nil)
        #expect(noRemainingWork.sharedMemoryInviteeIDs.isEmpty)
        #expect(complete.isPostPublicationSetupComplete)
        #expect(
            SipRemoteRecoveryPlanner.action(
                for: complete,
                authenticatedUserID: userID
            ) == .finishLocalCompletion
        )

        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(complete))
                as? [String: Any]
        )
        legacyObject.removeValue(forKey: "visitTagsCompletedAt")
        legacyObject.removeValue(forKey: "sharedMemoryInvitationsCompletedAt")
        let legacyFinalized = try JSONDecoder().decode(
            PendingVisitSubmissionRecord.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )
        #expect(legacyFinalized.needsVisitTagsCompletion)
        #expect(legacyFinalized.needsSharedMemoryInvitationsCompletion)
    }

    @Test func canonicalCommitSurvivesReflectionAndRecipeFailuresWithMonotonicReceipts() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let userID = UUID()
        let visitID = UUID()
        let reflection = V3VisitReflection(
            visitID: visitID,
            sipScore: 4.2,
            contextScore: nil,
            contextCriteria: [],
            sipRawNote: "Keep trying the post-publication projection",
            contextRawNote: nil,
            rawNoteVisibility: .friends,
            photoFallback: nil,
            homeMakeAgain: .yes
        )
        var pending = try fixture.store.prepare(
            visitId: visitID,
            userId: userID,
            cafe: nil,
            entryContext: .recipe,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "V60",
            caption: "Canonical post first",
            notes: nil,
            brewDetails: BrewDetails(recipeName: "V60"),
            visibility: .everyone,
            ratings: ["Taste": 4.2],
            overallScore: 4.2,
            ratingTemplate: RatingTemplate(),
            v3Reflection: reflection,
            recipePublication: .privateOriginal,
            images: [],
            posterPhotoIndex: 0
        )

        pending.phase = .photosUploaded
        pending.finalizationRequestedAt = .now
        try fixture.store.save(pending)
        #expect(pending.hasAmbiguousRemoteFinalization)
        #expect(
            SipRemoteRecoveryPlanner.action(
                for: pending,
                authenticatedUserID: userID
            ) == .reconcileRemotePublication
        )
        #expect(
            SipRemoteRecoveryPlanner.discardPolicy(for: pending)
                == .verifyRemoteThenDelete
        )

        // The canonical commit is durable before either downstream call. Their
        // simulated failures leave both receipts nil and therefore retryable.
        var committed = pending
        committed.remoteFinalizedAt = .now
        try fixture.store.save(committed)
        let failedActionsPlan = try #require(
            SipPostPublicationSetupPlan.make(from: committed)
        )
        #expect(failedActionsPlan.v3Reflection == reflection)
        #expect(failedActionsPlan.recipePublication == .privateOriginal)
        #expect(!committed.isPostPublicationSetupComplete)
        #expect(
            SipRemoteRecoveryPlanner.discardPolicy(for: committed)
                == .preservePublished
        )

        // Independent workers may finish from the same stale committed copy.
        // Saving either must union, never overwrite, the other's receipt.
        var reflectionFinished = committed
        reflectionFinished.v3ReflectionCompletedAt = .now
        try fixture.store.save(reflectionFinished)
        var recipeFinished = committed
        recipeFinished.recipePublicationCompletedAt = .now
        try fixture.store.save(recipeFinished)

        let merged = try #require(
            fixture.store.load(visitId: visitID, userId: userID)
        )
        #expect(merged.remoteFinalizedAt != nil)
        #expect(merged.v3ReflectionCompletedAt != nil)
        #expect(merged.recipePublicationCompletedAt != nil)
        #expect(merged.isPostPublicationSetupComplete)
        let completedPlan = try #require(
            SipPostPublicationSetupPlan.make(from: merged)
        )
        #expect(completedPlan.v3Reflection == nil)
        #expect(completedPlan.recipePublication == nil)

        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(committed))
                as? [String: Any]
        )
        legacyObject.removeValue(forKey: "v3ReflectionCompletedAt")
        legacyObject.removeValue(forKey: "recipePublicationCompletedAt")
        let legacyFinalized = try JSONDecoder().decode(
            PendingVisitSubmissionRecord.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )
        #expect(legacyFinalized.needsV3ReflectionCompletion)
        #expect(legacyFinalized.needsRecipePublicationCompletion)
    }

    @Test func discardPolicyFailsClosedAfterAnyRemoteVisitOrFinalizationRequest() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let userID = UUID()
        let prepared = try fixture.store.prepare(
            userId: userID,
            cafe: nil,
            entryContext: .home,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Cortado",
            caption: "Protected discard",
            notes: nil,
            visibility: .private,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            images: [],
            posterPhotoIndex: 0
        )
        #expect(SipRemoteRecoveryPlanner.discardPolicy(for: prepared) == .removeLocalOnly)

        var remoteCreated = prepared
        remoteCreated.phase = .visitCreated
        #expect(
            SipRemoteRecoveryPlanner.discardPolicy(for: remoteCreated)
                == .verifyRemoteThenDelete
        )

        var ambiguous = remoteCreated
        ambiguous.finalizationRequestedAt = .now
        #expect(ambiguous.isRemotePublicationProtected)
        #expect(
            SipRemoteRecoveryPlanner.action(
                for: ambiguous,
                authenticatedUserID: userID
            ) == .reconcileRemotePublication
        )
        #expect(!SipRemoteRecoveryPlanner.canDestructivelyDiscard(ambiguous))

        var finalized = ambiguous
        finalized.remoteFinalizedAt = .now
        #expect(
            SipRemoteRecoveryPlanner.discardPolicy(for: finalized)
                == .preservePublished
        )
        #expect(!SipRemoteRecoveryPlanner.canDestructivelyDiscard(finalized))
    }

    @Test func brewAgainUsesOnlyCallerBoundRecipeProjectionForVersionedVisits() throws {
        let visitID = UUID()
        let recipeIdentityID = UUID()
        let recipeVersionID = UUID()
        let ownerID = UUID()
        let leakedRawDetails = BrewDetails(
            beans: "Raw row must be ignored",
            doseGrams: 99,
            recipeName: "Raw private recipe",
            recipeVersion: "raw-v0",
            recipeIdentityID: UUID(),
            steps: [BrewRecipeStep(instruction: "Raw secret step")]
        )
        let row = SupabaseVisitRow(
            id: visitID,
            userId: ownerID,
            cafeId: nil,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "V60",
            caption: "Versioned recipe",
            notes: nil,
            visibility: "everyone",
            ratings: ["Taste": 4.5],
            overallScore: 4.5,
            posterPhotoURL: nil,
            contextType: JournalEntryContext.home.rawValue,
            locationName: "Home",
            cityState: nil,
            brewMethod: "Raw secret method",
            createdAt: "2026-07-21T12:00:00Z",
            equipment: "Raw secret equipment",
            brewDetails: leakedRawDetails,
            recipeVersionID: recipeVersionID
        )
        let summary = RemoteVisitSummary(visit: row, cafe: nil)

        #expect(row.journalContext == .recipe)
        let unavailable = SipDraft.brewAgain(
            from: summary,
            recipeProjection: nil,
            ownerUserID: ownerID
        )
        #expect(unavailable.brewMethod.isEmpty)
        #expect(unavailable.equipment.isEmpty)
        #expect(unavailable.brewDetails.beans == nil)
        #expect(unavailable.brewDetails.steps == nil)
        #expect(unavailable.launchContext.sourceRecipeIdentityID == nil)
        #expect(unavailable.launchContext.sourceRecipeVersion == nil)
        #expect(unavailable.recipePublication.sourceRecipeVersionID == recipeVersionID)

        let projection = RemoteVisitRecipeProjection(
            recipeIdentityID: recipeIdentityID,
            recipeVersionID: recipeVersionID,
            recipeName: "Confidential V60",
            versionNumber: 7,
            versionLabel: "v7",
            visibilityValue: "private",
            sourceKindValue: "original",
            sourceRecipeVersionID: nil,
            brewMethod: "Projected V60 method",
            equipment: "Projected dripper",
            brewDetails: BrewDetails(
                beans: "Allowed owner projection",
                doseGrams: 18,
                yieldGrams: 300,
                steps: [BrewRecipeStep(instruction: "Projected bloom")],
                additions: "Mineral concentrate: 2 drops"
            ),
            canSaveAndAdapt: false
        )
        let authorized = SipDraft.brewAgain(
            from: summary,
            recipeProjection: projection,
            ownerUserID: ownerID
        )
        #expect(authorized.brewMethod == "Projected V60 method")
        #expect(authorized.equipment == "Projected dripper")
        #expect(authorized.brewDetails.beans == "Allowed owner projection")
        #expect(authorized.brewDetails.doseGrams == 18)
        #expect(authorized.brewDetails.yieldGrams == 300)
        #expect(authorized.brewDetails.steps?.first?.instruction == "Projected bloom")
        #expect(authorized.brewDetails.additions == "Mineral concentrate: 2 drops")
        #expect(authorized.brewDetails.sourceRecipeIdentityID == recipeIdentityID)
        #expect(authorized.brewDetails.sourceRecipeVersion == "v7")
        #expect(authorized.launchContext.sourceRecipeIdentityID == recipeIdentityID)
        #expect(authorized.launchContext.sourceRecipeVersion == "v7")
        #expect(authorized.recipePublication.sourceRecipeVersionID == recipeVersionID)
    }

    @Test func contractV2VisitInsertCarriesOnlySafeRecipeDisplayMetadata() throws {
        let payload = try SupabaseVisitInsert.make(
            userId: UUID(),
            remoteCafe: nil,
            entryContext: .recipe,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "V60",
            brewMethod: nil,
            equipment: nil,
            brewDetails: BrewDetails(
                recipeName: "Confidential V60",
                recipeVersion: "v7"
            ),
            recipePayloadContractVersion: 2,
            caption: "Safe social shell",
            notes: nil,
            visibility: .everyone,
            ratings: ["Taste": 4.5],
            overallScore: 4.5,
            ratingTemplate: RatingTemplate(
                categories: [RatingCategory(name: "Taste", weight: 1)]
            ),
            uploadState: .uploading
        )

        #expect(payload.recipePayloadContractVersion == 2)
        #expect(payload.brewMethod == nil)
        #expect(payload.equipment == nil)
        #expect(payload.brewDetails.recipeName == "Confidential V60")
        #expect(payload.brewDetails.recipeVersion == "v7")
        #expect(payload.brewDetails.beans == nil)
        #expect(payload.brewDetails.steps == nil)
    }

    private func companion(named name: String) -> SipCompanion {
        SipCompanion(
            userID: UUID(),
            displayName: name,
            username: name.lowercased().replacingOccurrences(of: " ", with: "_"),
            avatarURL: nil
        )
    }

    private func makeStore() throws -> (
        store: PendingVisitSubmissionStore,
        cleanup: () -> Void
    ) {
        let suiteName = "SharedMemoryComposerIntegrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SharedMemoryComposerIntegration.\(UUID().uuidString)",
            isDirectory: true
        )
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
}
