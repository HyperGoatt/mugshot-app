import Foundation
import Supabase

final class PublicCafeListService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func browse(limit: Int = 20, before: Date? = nil) async throws -> [PublicCafeList] {
        try await client.rpc(
            "browse_public_cafe_lists_v1",
            params: BrowseParameters(pLimit: limit, pBefore: before)
        ).execute().value
    }

    func list(slug: String) async throws -> PublicCafeList {
        try await client.rpc(
            "get_public_cafe_list_v1",
            params: SlugParameters(pSlug: slug)
        ).execute().value
    }

    func setPublication(
        listID: UUID,
        isPublic: Bool,
        commentsEnabled: Bool = true
    ) async throws -> CollaborativeCafeList {
        try await client.rpc(
            "set_cafe_list_publication_v1",
            params: PublicationParameters(
                pListID: listID,
                pIsPublic: isPublic,
                pCommentsEnabled: commentsEnabled
            )
        ).execute().value
    }

    func setFollowing(listID: UUID, following: Bool) async throws {
        _ = try await client.rpc(
            "follow_cafe_list_v1",
            params: FollowParameters(pListID: listID, pFollow: following)
        ).execute()
    }

    func copy(listID: UUID) async throws -> CollaborativeCafeList {
        try await client.rpc(
            "copy_public_cafe_list_v1",
            params: ListIDParameters(pListID: listID)
        ).execute().value
    }

    func comment(listID: UUID, body: String) async throws -> PublicCafeListComment {
        try await client.rpc(
            "comment_on_cafe_list_v1",
            params: CommentParameters(pListID: listID, pBody: body)
        ).execute().value
    }

    func delete(commentID: UUID) async throws {
        _ = try await client.rpc(
            "delete_cafe_list_comment_v1",
            params: CommentIDParameters(pCommentID: commentID)
        ).execute()
    }

    func report(commentID: UUID, reason: ReportReason, details: String? = nil) async throws {
        _ = try await client.rpc(
            "report_cafe_list_comment_v1",
            params: ReportParameters(
                pCommentID: commentID,
                pReason: reason == .inappropriateContent ? "other" : reason.rawValue,
                pDetails: details
            )
        ).execute()
    }
}

private struct BrowseParameters: Encodable {
    let pLimit: Int
    let pBefore: Date?
    enum CodingKeys: String, CodingKey {
        case pLimit = "p_limit"
        case pBefore = "p_before"
    }
}

private struct SlugParameters: Encodable {
    let pSlug: String
    enum CodingKeys: String, CodingKey { case pSlug = "p_slug" }
}

private struct ListIDParameters: Encodable {
    let pListID: UUID
    enum CodingKeys: String, CodingKey { case pListID = "p_list_id" }
}

private struct PublicationParameters: Encodable {
    let pListID: UUID
    let pIsPublic: Bool
    let pCommentsEnabled: Bool
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pIsPublic = "p_is_public"
        case pCommentsEnabled = "p_comments_enabled"
    }
}

private struct FollowParameters: Encodable {
    let pListID: UUID
    let pFollow: Bool
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pFollow = "p_follow"
    }
}

private struct CommentParameters: Encodable {
    let pListID: UUID
    let pBody: String
    enum CodingKeys: String, CodingKey {
        case pListID = "p_list_id"
        case pBody = "p_body"
    }
}

private struct CommentIDParameters: Encodable {
    let pCommentID: UUID
    enum CodingKeys: String, CodingKey { case pCommentID = "p_comment_id" }
}

private struct ReportParameters: Encodable {
    let pCommentID: UUID
    let pReason: String
    let pDetails: String?
    enum CodingKeys: String, CodingKey {
        case pCommentID = "p_comment_id"
        case pReason = "p_reason"
        case pDetails = "p_details"
    }
}
