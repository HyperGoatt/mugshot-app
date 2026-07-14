import Foundation
import Supabase

final class JournalService {
    private let client: SupabaseClient
    private let visitService: VisitService

    init(client: SupabaseClient) {
        self.client = client
        self.visitService = VisitService(client: client)
    }

    func fetchEntries(userID: UUID, limit: Int = 500) async throws -> [JournalEntryProjection] {
        async let summariesRequest = visitService.fetchRecentVisits(
            userId: userID,
            limit: limit,
            includeSocialState: false
        )
        async let notesRequest: [JournalPrivateNoteRow] = client
            .from("visit_private_notes")
            .select("visit_id, note")
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        async let bookmarksRequest: [JournalBookmarkRow] = client
            .from("visit_bookmarks")
            .select("visit_id")
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        let (summaries, notes, bookmarks) = try await (
            summariesRequest,
            notesRequest,
            bookmarksRequest
        )
        let notesByVisit = Dictionary(uniqueKeysWithValues: notes.map { ($0.visitID, $0.note) })
        let bookmarkedIDs = Set(bookmarks.map(\.visitID))
        return summaries.map { summary in
            JournalEntryProjection(
                summary: summary,
                privateNote: notesByVisit[summary.id],
                isBookmarked: bookmarkedIDs.contains(summary.id)
            )
        }
    }

    func setBookmarked(_ bookmarked: Bool, visitID: UUID, userID: UUID) async throws {
        if bookmarked {
            try await client
                .from("visit_bookmarks")
                .insert(JournalBookmarkInsert(userID: userID, visitID: visitID))
                .execute()
        } else {
            try await client
                .from("visit_bookmarks")
                .delete()
                .eq("user_id", value: userID.uuidString)
                .eq("visit_id", value: visitID.uuidString)
                .execute()
        }
    }
}

private struct JournalBookmarkInsert: Encodable {
    let userID: UUID
    let visitID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case visitID = "visit_id"
    }
}
