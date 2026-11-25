import Foundation

enum WeeklyPourDataSource {
    static func moment(_ summary: RemoteVisitSummary) -> WeeklyPourMoment {
        let visit = summary.visit
        let visibility = visit.visibility.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return WeeklyPourMoment(id: visit.id, ownerID: visit.userId, date: visit.createdAtDate,
            drink: visit.drinkDisplayName, location: summary.locationTitle, cafeID: visit.cafeId,
            isAtHome: [.home, .recipe].contains(visit.journalContext), rating: visit.overallScore,
            caption: visit.caption.remoteTrimmedNonEmpty,
            photo: visit.posterPhotoURL?.remoteTrimmedNonEmpty.map(WeeklyPourPhoto.remote),
            isPrivate: !["everyone", "friends"].contains(visibility),
            isComplete: visit.uploadState == VisitUploadState.complete.rawValue,
            origin: .journal, linkedVisitID: nil)
    }

    static func privateMoments(_ attempts: [HomeAttemptRecord], ownerID: UUID) -> [WeeklyPourMoment] {
        attempts.compactMap { attempt in
            guard let savedAt = attempt.savedAt, attempt.publicationStatus != .published else { return nil }
            return WeeklyPourMoment(id: attempt.id, ownerID: ownerID, date: savedAt,
                drink: attempt.name.remoteTrimmedNonEmpty ?? "Home sip", location: "At home", cafeID: nil,
                isAtHome: true, rating: attempt.resolvedRating, caption: attempt.reaction.remoteTrimmedNonEmpty,
                photo: attempt.photoNames.first.map(WeeklyPourPhoto.local), isPrivate: true,
                isComplete: true, origin: .home, linkedVisitID: attempt.publicationDraftID)
        }
    }
}
