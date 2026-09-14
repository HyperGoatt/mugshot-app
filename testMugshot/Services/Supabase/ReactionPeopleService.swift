import Foundation
import Supabase

struct ReactionPeoplePage: Decodable {
    struct Person: Decodable, Identifiable {
        let user_id: UUID
        let display_name: String
        let username: String
        let avatar_url: String?
        let reaction_kind: PostReactionKind
        var id: UUID { user_id }
    }
    struct Cursor: Codable { let created_at: String; let user_id: UUID }
    let people: [Person]
    let counts: VisitReactionState
    let next_cursor: Cursor?
}

struct ReactionPeopleService {
    func page(visitID: UUID, kind: PostReactionKind? = nil, cursor: ReactionPeoplePage.Cursor? = nil, limit: Int = 25) async throws -> ReactionPeoplePage {
        let client = try SupabaseClientProvider.shared.client()
        guard let account = client.auth.currentUser?.id else { throw SocialSafetyServiceError.accountScopeChanged }
        struct Parameters: Encodable {
            let p_visit_id: UUID
            let p_reaction_kind: String?
            let p_cursor: ReactionPeoplePage.Cursor?
            let p_limit: Int
        }
        let result: ReactionPeoplePage = try await client.rpc("list_visit_reaction_people_v1",
            params: Parameters(p_visit_id: visitID, p_reaction_kind: kind?.rawValue, p_cursor: cursor, p_limit: limit)).execute().value
        guard client.auth.currentUser?.id == account else { throw SocialSafetyServiceError.accountScopeChanged }
        try Task.checkCancellation()
        return result
    }
}
