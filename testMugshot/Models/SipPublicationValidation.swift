import Foundation

/// One validation contract for publish enablement, visible feedback, and tap handling.
enum SipPublicationValidation {
    static func message(
        for draft: SipDraft,
        photoCount: Int,
        pending: PendingVisitSubmissionRecord?,
        authenticatedUserID: UUID?
    ) -> String? {
        if let ownerUserID = draft.ownerUserID,
           let authenticatedUserID,
           ownerUserID != authenticatedUserID {
            return "This draft belongs to the account that started it. Sign back into that account to save it."
        }
        if let pending {
            guard let authenticatedUserID,
                  pending.canResume(with: draft, authenticatedUserID: authenticatedUserID) else {
                return PendingVisitSubmissionStoreError.submissionIdentityMismatch.localizedDescription
            }
            // Retry the immutable payload. Local preview loss and changes to
            // today's form rules must not block an already uploaded/published sip.
            if pending.isRemoteFinalized { return nil }
            if let issue = pending.retryPayloadIssue { return issue.localizedDescription }
            return nil
        }
        if draft.context == .cafe && draft.cafe == nil {
            return "Choose a cafe before saving this sip."
        }
        if draft.context != .cafe && draft.locationName.remoteTrimmedNonEmpty == nil {
            return draft.context == .elsewhere
                ? "Name this setting before saving."
                : "Name this home context before saving."
        }
        if draft.drinkName.remoteTrimmedNonEmpty == nil {
            return "Add the drink you want to remember."
        }
        if photoCount == 0, draft.photoFallback == nil {
            return "Add a photo, or deliberately choose I missed the photo."
        }
        if let captionError = SipCaptionPolicy.validationError(for: draft.socialCaption) {
            return captionError.localizedDescription
        }
        if draft.privateNotes.v3DatabaseCharacterCount
            > V3VisitReflection.rawNoteCharacterLimit {
            return "Keep your sip journal note to 10,000 characters or fewer."
        }
        if draft.contextNotes.v3DatabaseCharacterCount
            > V3VisitReflection.rawNoteCharacterLimit {
            return "Keep your context journal note to 10,000 characters or fewer."
        }
        if draft.captureMode == .addDetails && draft.sensorySnapshot == nil {
            return "Finish or switch from Tasting Lens before saving this sip."
        }
        if !draft.resolvedOverallScore.isFinite || !(0.5...5).contains(draft.resolvedOverallScore) {
            return "Add your personal How was it? rating."
        }
        if draft.context == .cafe,
           !(1...5).contains(draft.contextScore ?? 0) {
            return "Add your cafe score before publishing this Mugshot."
        }
        switch draft.recipePublicationRequirement {
        case .ready:
            break
        case .needsImmutableSource:
            return "This adapted recipe needs its exact Mugshot source before it can publish."
        case .sourceCannotBePublic:
            return "Purchased and external recipes cannot share instructions with Everyone."
        case .needsRedistributionPermission:
            return "Confirm that people may save and adapt this recipe before sharing it with Everyone."
        case .needsPublicReuseAcknowledgment:
            return "Acknowledge public recipe reuse before sharing these instructions with Everyone."
        }
        if SipPublicationPolicy.requirement(
            visibility: draft.visibility,
            photoCount: photoCount + (draft.photoFallback == nil ? 0 : 1),
            socialCaption: draft.socialCaption,
            confirmedTextOnlyEveryone: false
        ) == .needsTextOrPhoto {
            return "Add a one-line thought or photo before sharing this sip with Everyone."
        }
        return nil
    }

}
