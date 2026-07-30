import Foundation
import Supabase

struct SipPostPublicationSetupPlan: Equatable {
    let visitID: UUID
    let cafeSession: PendingCafeSessionLink?
    let v3Reflection: V3VisitReflection?
    let recipePublication: SipRecipePublicationContract?
    let taggedUserIDs: [UUID]?
    let sharedMemoryInviteeIDs: [UUID]

    static func make(
        from submission: PendingVisitSubmissionRecord
    ) -> SipPostPublicationSetupPlan? {
        guard submission.isRemoteFinalized else { return nil }
        return SipPostPublicationSetupPlan(
            visitID: submission.id,
            cafeSession: submission.needsCafeSessionPublicationCompletion
                ? submission.cafeSession
                : nil,
            v3Reflection: submission.needsV3ReflectionCompletion
                ? submission.v3Reflection
                : nil,
            recipePublication: submission.needsRecipePublicationCompletion
                ? submission.recipePublication
                : nil,
            taggedUserIDs: submission.needsVisitTagsCompletion
                ? submission.taggedCompanions?.map(\.userID)
                : nil,
            sharedMemoryInviteeIDs: submission.needsSharedMemoryInvitationsCompletion
                ? submission.sharedMemoryInvitees?.map(\.userID) ?? []
                : []
        )
    }
}

struct SipPostPublicationSetupResult {
    let submission: PendingVisitSubmissionRecord
    let warning: String?
}

/// Completes projections that deliberately sit beyond the canonical visit
/// commit. Automatic outbox recovery uses the composer's frozen setup plan
/// and monotonic receipts so it cannot infer a different audience or repeat
/// completed actions.
struct SipPostPublicationSetupWorker {
    let client: SupabaseClient
    var pendingStore: PendingVisitSubmissionStore = .shared

    func finish(
        submission: PendingVisitSubmissionRecord
    ) async -> SipPostPublicationSetupResult {
        guard let plan = SipPostPublicationSetupPlan.make(from: submission) else {
            return SipPostPublicationSetupResult(
                submission: submission,
                warning: nil
            )
        }
        let social = SocialDiscoveryService(client: client)
        let cafeSessions = CafeSessionService(client: client)
        var updatedSubmission = submission
        var failedActions: [String] = []
        var canonicalAudienceReady = true

        if let session = plan.cafeSession {
            do {
                switch session.sipRole {
                case .primary:
                    try await cafeSessions.publishSession(
                        sessionID: session.sessionID,
                        visibility: submission.visibility,
                        snapshot: session.experienceSnapshot,
                        sharing: session.shareProjection
                    )
                case .secondary:
                    try await cafeSessions.appendSip(
                        sessionID: session.sessionID,
                        visitID: submission.id,
                        order: session.sipOrder,
                        reorderIntention: session.reorderIntention
                    )
                }
                updatedSubmission = try saveReceipt(updatedSubmission) {
                    $0.cafeSessionPublicationCompletedAt = .now
                }
            } catch {
                canonicalAudienceReady = false
                failedActions.append("its cafe publication")
            }
        }

        // A cafe session visit remains private until its canonical session
        // audience is ready. Downstream projections remain retryable.
        guard canonicalAudienceReady else {
            return SipPostPublicationSetupResult(
                submission: updatedSubmission,
                warning: "Your MugShot is safely saved. Mugshot will retry its cafe publication without creating a duplicate."
            )
        }

        if let reflection = plan.v3Reflection {
            do {
                _ = try await V3VisitReflectionService(client: client).upsert(reflection)
                updatedSubmission = try saveReceipt(updatedSubmission) {
                    $0.v3ReflectionCompletedAt = .now
                }
            } catch {
                failedActions.append("its reflection")
            }
        }

        if let recipePublication = plan.recipePublication {
            do {
                _ = try await social.configureRecipePublication(
                    for: plan.visitID,
                    contract: recipePublication
                )
                updatedSubmission = try saveReceipt(updatedSubmission) {
                    $0.recipePublicationCompletedAt = .now
                }
            } catch {
                failedActions.append("its recipe sharing")
            }
        }

        if let taggedUserIDs = plan.taggedUserIDs {
            do {
                try await social.setVisitTags(taggedUserIDs, for: plan.visitID)
                updatedSubmission = try saveReceipt(updatedSubmission) {
                    $0.visitTagsCompletedAt = .now
                }
            } catch {
                failedActions.append("its people tags")
            }
        }

        if !plan.sharedMemoryInviteeIDs.isEmpty {
            do {
                _ = try await social.createSharedMemoryInvitations(
                    for: plan.visitID,
                    inviteeIDs: plan.sharedMemoryInviteeIDs
                )
                updatedSubmission = try saveReceipt(updatedSubmission) {
                    $0.sharedMemoryInvitationsCompletedAt = .now
                }
            } catch {
                failedActions.append("its shared MugShot invitations")
            }
        }

        let warning = failedActions.isEmpty
            ? nil
            : "Your MugShot is safely published. Mugshot will retry \(failedActions.joined(separator: ", ")) without publishing a duplicate."
        return SipPostPublicationSetupResult(
            submission: updatedSubmission,
            warning: warning
        )
    }

    private func saveReceipt(
        _ submission: PendingVisitSubmissionRecord,
        mutation: (inout PendingVisitSubmissionRecord) -> Void
    ) throws -> PendingVisitSubmissionRecord {
        var receipt = submission
        mutation(&receipt)
        try pendingStore.save(receipt)
        return pendingStore.load(
            visitId: receipt.id,
            userId: receipt.userId
        ) ?? receipt
    }
}
