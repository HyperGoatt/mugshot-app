import Foundation
import UIKit

struct SipPostEditPhoto: Identifiable {
    enum Source {
        case existing(String)
        case added(UIImage)
    }

    let id: String
    let source: Source

    static func existing(id: UUID, storedValue: String) -> Self {
        Self(id: "existing-\(id.uuidString.lowercased())", source: .existing(storedValue))
    }

    static func legacyExisting(storedValue: String) -> Self {
        Self(id: "existing-legacy-\(storedValue)", source: .existing(storedValue))
    }

    static func added(_ image: UIImage, id: UUID = UUID()) -> Self {
        Self(id: "added-\(id.uuidString.lowercased())", source: .added(image))
    }

    var existingStoredValue: String? {
        guard case .existing(let value) = source else { return nil }
        return value
    }

    var addedImage: UIImage? {
        guard case .added(let image) = source else { return nil }
        return image
    }
}

struct SipPostEditDraft {
    var caption: String
    var postAudience: VisitVisibility
    var journalAudience: VisitVisibility
    var sipScore: Double
    var sipCriteria: [SipRatingCriterionSnapshot]
    var contextScore: Double?
    var contextCriteria: [SipRatingCriterionSnapshot]
    var sipJournalNote: String
    var contextJournalNote: String
    var legacyPrivateJournalNote: String
    var photos: [SipPostEditPhoto]
    var coverPhotoID: String?
}

struct SipPostEditSeed: Identifiable {
    let detail: RemoteVisitDetail
    let currentUserID: UUID

    var id: UUID { detail.id }

    var draft: SipPostEditDraft {
        let visit = detail.summary.visit
        let orderedRows = detail.photos.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder { return lhs.createdAt < rhs.createdAt }
            return lhs.sortOrder < rhs.sortOrder
        }
        var photos = orderedRows.map {
            SipPostEditPhoto.existing(id: $0.id, storedValue: $0.photoURL)
        }

        if let poster = visit.posterPhotoURL?.remoteTrimmedNonEmpty,
           !photos.contains(where: { $0.existingStoredValue == poster }) {
            photos.insert(.legacyExisting(storedValue: poster), at: 0)
        }

        let coverPhotoID = photos.first(where: {
            $0.existingStoredValue == visit.posterPhotoURL
        })?.id ?? photos.first?.id

        let sipCriteria = visit.orderedRatingScores.enumerated().map { index, score in
            SipRatingCriterionSnapshot(
                name: score.name,
                score: score.score,
                weight: score.weight,
                sortOrder: index,
                relevanceOverride: true
            )
        }
        let reflection = detail.v3Reflection

        return SipPostEditDraft(
            caption: visit.caption,
            postAudience: VisitVisibility.supabaseValue(visit.visibility),
            journalAudience: reflection?.rawNoteVisibility ?? .private,
            sipScore: reflection?.sipScore ?? visit.overallScore,
            sipCriteria: sipCriteria,
            contextScore: reflection?.contextScore,
            contextCriteria: reflection?.contextCriteria.sorted { $0.sortOrder < $1.sortOrder } ?? [],
            sipJournalNote: reflection?.sipRawNote ?? "",
            contextJournalNote: reflection?.contextRawNote ?? "",
            legacyPrivateJournalNote: reflection == nil ? detail.privateNote ?? "" : "",
            photos: photos,
            coverPhotoID: coverPhotoID
        )
    }
}

enum SipPostEditValidationError: LocalizedError, Equatable {
    case notOwner
    case invalidSipScore
    case invalidContextScore
    case invalidCriterionName
    case invalidCriterionScore
    case duplicateCriterionName
    case tooManyCriteria
    case journalNoteTooLong
    case journalAudienceTooBroad
    case tooManyPhotos

    var errorDescription: String? {
        switch self {
        case .notOwner:
            "Only the person who posted this Mugshot can edit it."
        case .invalidSipScore:
            "Choose a sip score between 0.5 and 5."
        case .invalidContextScore:
            "Choose a context score between 0.5 and 5."
        case .invalidCriterionName:
            "Each criterion needs a name between 1 and 80 characters."
        case .invalidCriterionScore:
            "Each criterion needs a score between 0.5 and 5."
        case .duplicateCriterionName:
            "Each criterion name must be unique."
        case .tooManyCriteria:
            "A sip can have up to 40 criteria in each section."
        case .journalNoteTooLong:
            "Each journal note can contain up to 10,000 characters."
        case .journalAudienceTooBroad:
            "The journal audience cannot be broader than the post audience."
        case .tooManyPhotos:
            "A Mugshot can contain up to 10 photos."
        }
    }
}

struct SipPostEditNormalizedValues: Equatable {
    let caption: String
    let postAudience: VisitVisibility
    let journalAudience: VisitVisibility
    let sipScore: Double
    let sipCriteria: [SipRatingCriterionSnapshot]
    let contextScore: Double?
    let contextCriteria: [SipRatingCriterionSnapshot]
    let sipJournalNote: String?
    let contextJournalNote: String?
    let legacyPrivateJournalNote: String?
}

enum SipPostEditPolicy {
    static let maximumCriteriaCount = 40
    static let maximumCriterionNameLength = 80

    static func normalize(
        _ draft: SipPostEditDraft,
        context: JournalEntryContext,
        hasV3Reflection: Bool
    ) throws -> SipPostEditNormalizedValues {
        guard draft.photos.count <= VisitPhotoUploadPlan.maxPhotoCount else {
            throw SipPostEditValidationError.tooManyPhotos
        }
        guard draft.postAudience.breadth >= draft.journalAudience.breadth else {
            throw SipPostEditValidationError.journalAudienceTooBroad
        }
        let caption = try SipCaptionPolicy.validateAndNormalize(draft.caption)
        let sipScore = try normalizedScore(draft.sipScore, error: .invalidSipScore)
        let sipCriteria = try normalizedCriteria(draft.sipCriteria)

        let isHome = context == .home || context == .recipe
        let contextScore = isHome
            ? nil
            : try draft.contextScore.map {
                try normalizedScore($0, error: .invalidContextScore)
            }
        let contextCriteria = isHome ? [] : try normalizedCriteria(draft.contextCriteria)

        let sipNote = try normalizedJournalNote(draft.sipJournalNote)
        let contextNote = try normalizedJournalNote(draft.contextJournalNote)
        let legacyNote = try normalizedJournalNote(draft.legacyPrivateJournalNote)

        return SipPostEditNormalizedValues(
            caption: caption,
            postAudience: draft.postAudience,
            journalAudience: hasV3Reflection ? draft.journalAudience : .private,
            sipScore: sipScore,
            sipCriteria: sipCriteria,
            contextScore: contextScore,
            contextCriteria: contextCriteria,
            sipJournalNote: hasV3Reflection ? sipNote : nil,
            contextJournalNote: hasV3Reflection ? contextNote : nil,
            legacyPrivateJournalNote: hasV3Reflection ? nil : legacyNote
        )
    }

    static func moveCoverFirst(in draft: inout SipPostEditDraft) {
        guard let coverPhotoID = draft.coverPhotoID,
              let coverIndex = draft.photos.firstIndex(where: { $0.id == coverPhotoID }),
              coverIndex != 0 else { return }
        let cover = draft.photos.remove(at: coverIndex)
        draft.photos.insert(cover, at: 0)
    }

    private static func normalizedScore(
        _ score: Double,
        error: SipPostEditValidationError
    ) throws -> Double {
        guard score.isFinite, (0.5...5).contains(score) else { throw error }
        return (score * 10).rounded() / 10
    }

    private static func normalizedCriteria(
        _ criteria: [SipRatingCriterionSnapshot]
    ) throws -> [SipRatingCriterionSnapshot] {
        guard criteria.count <= maximumCriteriaCount else {
            throw SipPostEditValidationError.tooManyCriteria
        }
        var names: Set<String> = []
        return try criteria.enumerated().map { index, source in
            let name = source.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.unicodeScalars.count <= maximumCriterionNameLength else {
                throw SipPostEditValidationError.invalidCriterionName
            }
            guard names.insert(name.lowercased()).inserted else {
                throw SipPostEditValidationError.duplicateCriterionName
            }
            guard source.score.isFinite, (0.5...5).contains(source.score) else {
                throw SipPostEditValidationError.invalidCriterionScore
            }
            return SipRatingCriterionSnapshot(
                id: source.id,
                name: name,
                score: (source.score * 10).rounded() / 10,
                weight: source.importance.weight,
                sortOrder: index,
                relevanceOverride: true,
                isPinned: source.isPinned
            )
        }
    }

    private static func normalizedJournalNote(_ note: String) throws -> String? {
        guard note.unicodeScalars.count <= V3VisitReflection.rawNoteCharacterLimit else {
            throw SipPostEditValidationError.journalNoteTooLong
        }
        return note.trimmingCharacters(in: .whitespacesAndNewlines).remoteTrimmedNonEmpty
    }
}
