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
        async let analysesRequest: [JournalDrinkAnalysis] = client
            .from("visit_drink_analyses")
            .select("visit_id,processing_status,preparation,caffeine_modifier,estimated_caffeine_mg,caffeine_calculation_basis,caffeine_coverage,caffeine_reference_version,parser_version,confidence")
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        let (summaries, notes, bookmarks, analyses) = try await (
            summariesRequest,
            notesRequest,
            bookmarksRequest,
            analysesRequest
        )
        let notesByVisit = Dictionary(uniqueKeysWithValues: notes.map { ($0.visitID, $0.note) })
        let bookmarkedIDs = Set(bookmarks.map(\.visitID))
        let analysesByVisit = Dictionary(uniqueKeysWithValues: analyses.map { ($0.visitID, $0) })
        return summaries.map { summary in
            JournalEntryProjection(
                summary: summary,
                privateNote: notesByVisit[summary.id],
                isBookmarked: bookmarkedIDs.contains(summary.id),
                drinkAnalysis: analysesByVisit[summary.id]
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

    func fetchPeopleCounts(
        startAt: Date,
        endAt: Date,
        limit: Int = 3
    ) async throws -> [JournalPeopleCount] {
        try await client.rpc(
            "get_journal_people_counts_v1",
            params: JournalPeopleCountParameters(
                startAt: startAt.ISO8601Format(),
                endAt: endAt.ISO8601Format(),
                limit: min(max(limit, 1), 25)
            )
        ).execute().value
    }
}

private struct JournalPeopleCountParameters: Encodable {
    let startAt: String
    let endAt: String
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case startAt = "p_start_at"
        case endAt = "p_end_at"
        case limit = "p_limit"
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
