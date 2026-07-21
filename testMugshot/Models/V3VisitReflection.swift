import Foundation

/// The V3-only reflection envelope that complements the canonical visit row.
///
/// `visits.overall_score` remains the independent sip score. This payload keeps
/// context reflection and raw journal writing separate so social projections
/// never need direct access to owner-private journal storage.
struct V3VisitReflection: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let rawNoteCharacterLimit = 10_000

    let schemaVersion: Int
    let visitID: UUID
    var sipScore: Double
    var contextScore: Double?
    var contextCriteria: [SipRatingCriterionSnapshot]
    var sipRawNote: String?
    var contextRawNote: String?
    var rawNoteVisibility: VisitVisibility
    var photoFallback: SipPhotoFallback?
    var homeMakeAgain: HomeMakeAgain?
    var mugshotScore: Double
    var createdAt: Date?
    var updatedAt: Date?

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        visitID: UUID,
        sipScore: Double,
        contextScore: Double?,
        contextCriteria: [SipRatingCriterionSnapshot],
        sipRawNote: String?,
        contextRawNote: String?,
        rawNoteVisibility: VisitVisibility,
        photoFallback: SipPhotoFallback?,
        homeMakeAgain: HomeMakeAgain?,
        mugshotScore: Double? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        let normalizedSipScore = Self.roundedToOneDecimal(sipScore)
        let normalizedContextScore = contextScore.map(Self.roundedToOneDecimal)

        self.schemaVersion = schemaVersion
        self.visitID = visitID
        self.sipScore = normalizedSipScore
        self.contextScore = normalizedContextScore
        self.contextCriteria = contextCriteria
        self.sipRawNote = sipRawNote?
            .v3PrefixDatabaseCharacters(Self.rawNoteCharacterLimit)
            .v3TrimmedNonEmpty
        self.contextRawNote = contextRawNote?
            .v3PrefixDatabaseCharacters(Self.rawNoteCharacterLimit)
            .v3TrimmedNonEmpty
        self.rawNoteVisibility = rawNoteVisibility
        self.photoFallback = photoFallback
        self.homeMakeAgain = homeMakeAgain
        self.mugshotScore = Self.roundedToOneDecimal(
            mugshotScore ?? Self.deriveMugshotScore(
                sipScore: normalizedSipScore,
                contextScore: normalizedContextScore
            )
        )
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Creates the persisted V3 envelope from the autosaved composer draft.
    /// The remote visit identifier is explicit because draft and server IDs are
    /// intentionally not assumed to be interchangeable by the upload pipeline.
    init(visitID: UUID, draft: SipDraft) {
        let isHomeContext = draft.context == .home || draft.context == .recipe
        let normalizedContextScore = isHomeContext ? nil : draft.contextScore
        let constrainedRawVisibility = draft.rawNoteVisibility.v3Constrained(
            to: draft.visibility
        )

        self.init(
            visitID: visitID,
            sipScore: draft.resolvedOverallScore,
            contextScore: normalizedContextScore,
            contextCriteria: isHomeContext ? [] : Array(
                draft.contextRatingCriteria
                    .filter {
                        $0.isRelevant && $0.score >= 0.5 && $0.score <= 5
                            && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .prefix(40)
            ),
            sipRawNote: draft.privateNotes,
            contextRawNote: draft.contextNotes,
            rawNoteVisibility: constrainedRawVisibility,
            photoFallback: draft.localPhotoNames.isEmpty ? draft.photoFallback : nil,
            homeMakeAgain: isHomeContext ? draft.homeMakeAgain : nil
        )
    }

    static func make(visitID: UUID, from draft: SipDraft) -> Self {
        Self(visitID: visitID, draft: draft)
    }

    /// A Mugshot is the one-decimal blend of sip and context. When a context
    /// score is intentionally absent (Home or an optional Elsewhere reflection),
    /// the independent sip score remains the Mugshot score.
    static func deriveMugshotScore(
        sipScore: Double,
        contextScore: Double?
    ) -> Double {
        let result = contextScore.map { (sipScore + $0) / 2 } ?? sipScore
        return roundedToOneDecimal(result)
    }

    static func roundedToOneDecimal(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    /// Keeps journal writing private while a visit is still being uploaded.
    /// The save pipeline writes this projection before publication, then
    /// promotes the user's intended raw-note audience after the canonical
    /// visit audience has been finalized.
    var privateUploadProjection: Self {
        var projection = self
        projection.rawNoteVisibility = .private
        return projection
    }
}

extension String {
    /// PostgreSQL `char_length` counts Unicode scalars. Keep client-side limits
    /// aligned with the database so a durable retry can never freeze an
    /// unpublishable journal note.
    var v3DatabaseCharacterCount: Int {
        unicodeScalars.count
    }

    func v3PrefixDatabaseCharacters(_ maximumCount: Int) -> String {
        guard maximumCount >= 0,
              unicodeScalars.count > maximumCount else {
            return self
        }
        var result = ""
        result.reserveCapacity(maximumCount)
        for scalar in unicodeScalars.prefix(maximumCount) {
            result.unicodeScalars.append(scalar)
        }
        return result
    }
}

extension VisitVisibility {
    var v3DatabaseValue: String {
        switch self {
        case .private: return "private"
        case .friends: return "friends"
        case .everyone: return "everyone"
        }
    }

    init?(v3DatabaseValue: String) {
        switch v3DatabaseValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "private": self = .private
        case "friends": self = .friends
        case "everyone": self = .everyone
        default: return nil
        }
    }

    fileprivate var v3AudienceBreadth: Int {
        switch self {
        case .private: return 0
        case .friends: return 1
        case .everyone: return 2
        }
    }

    fileprivate func v3Constrained(to visitVisibility: VisitVisibility) -> VisitVisibility {
        v3AudienceBreadth <= visitVisibility.v3AudienceBreadth ? self : visitVisibility
    }
}

private extension String {
    var v3TrimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
