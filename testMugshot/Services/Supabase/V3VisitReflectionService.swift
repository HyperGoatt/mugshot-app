import Foundation
import Supabase

enum V3VisitReflectionServiceError: LocalizedError, Equatable {
    case missingUpsertedReflection
    case invalidRawNoteVisibility(String)

    var errorDescription: String? {
        switch self {
        case .missingUpsertedReflection:
            return "Mugshot saved the visit but could not confirm its reflection."
        case .invalidRawNoteVisibility:
            return "Mugshot received an unsupported raw-note audience."
        }
    }
}

/// RPC-only persistence for the V3 reflection envelope.
///
/// The underlying table is owner-readable and has no authenticated mutation
/// grant. Social reads must use the sanitized RPC so journal text can never be
/// recovered by selecting the owner table directly.
final class V3VisitReflectionService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    @discardableResult
    func upsert(_ reflection: V3VisitReflection) async throws -> V3VisitReflection {
        let rows: [V3VisitReflectionRPCRow] = try await client
            .rpc(
                "upsert_visit_v3_reflection_v1",
                params: V3VisitReflectionUpsertParameters(reflection: reflection)
            )
            .execute()
            .value

        guard let row = rows.first else {
            throw V3VisitReflectionServiceError.missingUpsertedReflection
        }
        return try row.reflection
    }

    /// Returns `nil` when the visit or its reflection is not visible. The RPC
    /// independently nulls raw notes when their narrower audience excludes the
    /// caller, even when the rest of the Mugshot is visible.
    func fetchVisible(visitID: UUID) async throws -> V3VisitReflection? {
        let rows: [V3VisitReflectionRPCRow] = try await client
            .rpc(
                "get_visit_v3_reflection_v1",
                params: V3VisitReflectionFetchParameters(visitID: visitID)
            )
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return try row.reflection
    }
}

private struct V3VisitReflectionUpsertParameters: Encodable {
    let visitID: UUID
    let schemaVersion: Int
    let contextScore: Double?
    let contextCriteria: [SipRatingCriterionSnapshot]
    let sipRawNote: String?
    let contextRawNote: String?
    let rawNoteVisibility: String
    let photoFallback: String?
    let homeMakeAgain: String?

    init(reflection: V3VisitReflection) {
        visitID = reflection.visitID
        schemaVersion = reflection.schemaVersion
        contextScore = reflection.contextScore
        contextCriteria = reflection.contextCriteria
        sipRawNote = reflection.sipRawNote
        contextRawNote = reflection.contextRawNote
        rawNoteVisibility = reflection.rawNoteVisibility.v3DatabaseValue
        photoFallback = reflection.photoFallback?.rawValue
        homeMakeAgain = reflection.homeMakeAgain?.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case visitID = "p_visit_id"
        case schemaVersion = "p_schema_version"
        case contextScore = "p_context_score"
        case contextCriteria = "p_context_criteria"
        case sipRawNote = "p_sip_raw_note"
        case contextRawNote = "p_context_raw_note"
        case rawNoteVisibility = "p_raw_note_visibility"
        case photoFallback = "p_photo_fallback"
        case homeMakeAgain = "p_home_make_again"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(visitID, forKey: .visitID)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(contextCriteria, forKey: .contextCriteria)
        try container.encode(rawNoteVisibility, forKey: .rawNoteVisibility)
        try container.v3EncodeNullable(contextScore, forKey: .contextScore)
        try container.v3EncodeNullable(sipRawNote, forKey: .sipRawNote)
        try container.v3EncodeNullable(contextRawNote, forKey: .contextRawNote)
        try container.v3EncodeNullable(photoFallback, forKey: .photoFallback)
        try container.v3EncodeNullable(homeMakeAgain, forKey: .homeMakeAgain)
    }
}

private struct V3VisitReflectionFetchParameters: Encodable {
    let visitID: UUID

    enum CodingKeys: String, CodingKey {
        case visitID = "p_visit_id"
    }
}

private struct V3VisitReflectionRPCRow: Decodable {
    let schemaVersion: Int
    let visitID: UUID
    let sipScore: Double
    let contextScore: Double?
    let contextCriteria: [SipRatingCriterionSnapshot]
    let sipRawNote: String?
    let contextRawNote: String?
    let rawNoteVisibilityValue: String
    let photoFallbackValue: String?
    let homeMakeAgainValue: String?
    let mugshotScore: Double
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case visitID = "visit_id"
        case sipScore = "sip_score"
        case contextScore = "context_score"
        case contextCriteria = "context_criteria"
        case sipRawNote = "sip_raw_note"
        case contextRawNote = "context_raw_note"
        case rawNoteVisibilityValue = "raw_note_visibility"
        case photoFallbackValue = "photo_fallback"
        case homeMakeAgainValue = "home_make_again"
        case mugshotScore = "mugshot_score"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var reflection: V3VisitReflection {
        get throws {
            guard let rawNoteVisibility = VisitVisibility(
                v3DatabaseValue: rawNoteVisibilityValue
            ) else {
                throw V3VisitReflectionServiceError.invalidRawNoteVisibility(
                    rawNoteVisibilityValue
                )
            }
            return V3VisitReflection(
                schemaVersion: schemaVersion,
                visitID: visitID,
                sipScore: sipScore,
                contextScore: contextScore,
                contextCriteria: contextCriteria,
                sipRawNote: sipRawNote,
                contextRawNote: contextRawNote,
                rawNoteVisibility: rawNoteVisibility,
                photoFallback: photoFallbackValue.flatMap(SipPhotoFallback.init(rawValue:)),
                homeMakeAgain: homeMakeAgainValue.flatMap(HomeMakeAgain.init(rawValue:)),
                mugshotScore: mugshotScore,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }
}

private extension KeyedEncodingContainer {
    mutating func v3EncodeNullable<T: Encodable>(
        _ value: T?,
        forKey key: Key
    ) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}
