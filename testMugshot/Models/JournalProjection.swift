import Foundation

struct JournalEntryProjection: Identifiable, Equatable {
    let summary: RemoteVisitSummary
    let privateNote: String?
    let isBookmarked: Bool

    var id: UUID { summary.id }
    var date: Date { summary.visit.createdAtDate }
    var context: JournalEntryContext { summary.visit.journalContext }
    var tags: [String] { summary.visit.structuredBrewDetails.tags ?? [] }

    func matches(_ rawQuery: String) -> Bool {
        guard let query = rawQuery.remoteTrimmedNonEmpty?.localizedLowercase else { return true }
        let searchable = [
            summary.visit.drinkDisplayName,
            summary.locationTitle,
            summary.visit.caption,
            privateNote ?? "",
            summary.visit.brewMethod ?? "",
            summary.visit.equipment ?? ""
        ] + tags
        return searchable.contains { $0.localizedLowercase.contains(query) }
    }
}
struct JournalBookmarkRow: Decodable, Equatable {
    let visitID: UUID

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
    }
}

struct JournalPrivateNoteRow: Decodable, Equatable {
    let visitID: UUID
    let note: String

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case note
    }
}
