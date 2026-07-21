import CryptoKit
import Foundation
import Supabase

struct CafeSessionsCapability: Decodable, Equatable {
    let schemaVersion: Int
    let features: Features
    let communityMinimumUsers: Int
    let communityMinimumSessions: Int

    struct Features: Decodable, Equatable {
        let cafeSessions: Bool
        let cafePulse: Bool
        let multiSip: Bool
        let immutableSnapshots: Bool
        let lossyPublicProjections: Bool
        let ownerExportV2: Bool
        let batchCafeSummaries: Bool

        enum CodingKeys: String, CodingKey {
            case cafeSessions = "cafe_sessions"
            case cafePulse = "cafe_pulse"
            case multiSip = "multi_sip"
            case immutableSnapshots = "immutable_snapshots"
            case lossyPublicProjections = "lossy_public_projections"
            case ownerExportV2 = "owner_export_v2"
            case batchCafeSummaries = "batch_cafe_summaries"
        }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case features
        case communityMinimumUsers = "community_minimum_users"
        case communityMinimumSessions = "community_minimum_sessions"
    }

    var supportsCapture: Bool {
        schemaVersion >= 1 &&
            features.cafeSessions &&
            features.cafePulse &&
            features.immutableSnapshots
    }
}

enum CafeExperienceSummaryScope: String, Encodable, CaseIterable {
    case personal
    case friends
    case community
}

struct RemoteCafeExperienceSummary: Decodable, Equatable, Identifiable {
    let schemaVersion: Int
    let cafeID: UUID
    let scope: String
    let physicalSessionCount: Int
    let ratedSessionCount: Int
    let contributorCount: Int
    let averageCafeRating: Double?
    let latestNextMove: String?
    let relationshipStageValue: String?
    let communityThresholdMet: Bool

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case cafeID = "cafe_id"
        case scope
        case physicalSessionCount = "physical_session_count"
        case ratedSessionCount = "rated_session_count"
        case contributorCount = "contributor_count"
        case averageCafeRating = "average_cafe_rating"
        case latestNextMove = "latest_next_move"
        case relationshipStageValue = "relationship_stage"
        case communityThresholdMet = "community_threshold_met"
    }

    var id: UUID { cafeID }

    var relationshipStage: CafeRelationshipStage {
        switch relationshipStageValue {
        case "first_impression": return .firstImpression
        case "emerging_view": return .emergingView
        case "trend", "trend_ready": return .trendReady
        default: return .unrated
        }
    }

    var nextMove: CafeNextMoveKind? {
        latestNextMove.flatMap(CafeNextMoveKind.init(rawValue:))
    }
}

struct RemoteFriendMapSipSummary: Decodable, Equatable, Identifiable {
    let cafeID: UUID
    let averageSipRating: Double?
    let sipCount: Int
    let physicalSessionCount: Int
    let contributorCount: Int

    enum CodingKeys: String, CodingKey {
        case cafeID = "cafe_id"
        case averageSipRating = "average_sip_rating"
        case sipCount = "sip_count"
        case physicalSessionCount = "physical_session_count"
        case contributorCount = "contributor_count"
    }

    var id: UUID { cafeID }

    var mapPinScore: MapPinScore? {
        guard let averageSipRating, averageSipRating > 0 else { return nil }
        return MapPinScore(
            value: averageSipRating,
            source: .sip,
            audience: .friends,
            ratedCafeSessionCount: 0,
            physicalSessionCount: physicalSessionCount,
            sipCount: sipCount,
            contributorCount: contributorCount,
            relationshipStage: .unrated
        )
    }
}

struct RemoteCafeSessionSummary: Decodable, Equatable, Identifiable {
    let schemaVersion: Int
    let sessionID: UUID
    let cafeID: UUID
    let primaryVisitID: UUID?
    let sipCount: Int
    let cafeRating: Double?
    let nextMoveValue: String?
    let status: String
    let sips: [Sip]

    struct Sip: Decodable, Equatable, Identifiable {
        let visitID: UUID
        let order: Int
        let role: String
        let drinkType: String?
        let drinkSubtype: String?
        let sipRating: Double
        let caption: String
        let posterPhotoURL: String?
        let createdAt: String
        let nextMoveValue: String?

        enum CodingKeys: String, CodingKey {
            case visitID = "visit_id"
            case order, role
            case drinkType = "drink_type"
            case drinkSubtype = "drink_subtype"
            case sipRating = "sip_rating"
            case caption
            case posterPhotoURL = "poster_photo_url"
            case createdAt = "created_at"
            case nextMoveValue = "next_move"
        }

        var id: UUID { visitID }
        var nextMove: CafeNextMoveKind? {
            nextMoveValue.flatMap(CafeNextMoveKind.init(rawValue:))
        }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sessionID = "session_id"
        case cafeID = "cafe_id"
        case primaryVisitID = "primary_visit_id"
        case sipCount = "sip_count"
        case cafeRating = "cafe_rating"
        case nextMoveValue = "next_move"
        case status, sips
    }

    var id: UUID { sessionID }
    var nextMove: CafeNextMoveKind? {
        nextMoveValue.flatMap(CafeNextMoveKind.init(rawValue:))
    }
}

enum CafeSessionServiceError: LocalizedError {
    case capabilityUnavailable
    case accountScopeMismatch
    case missingRemoteCafe
    case missingCafePulseSnapshotForSharing

    var errorDescription: String? {
        switch self {
        case .capabilityUnavailable:
            return "Cafe Sessions are not available on this Mugshot server yet."
        case .accountScopeMismatch:
            return "This Cafe Pulse belongs to a different Mugshot account."
        case .missingRemoteCafe:
            return "Mugshot could not connect this sip to its cafe."
        case .missingCafePulseSnapshotForSharing:
            return "Cafe stars and selected Cafe Pulse observations require a saved Cafe Pulse."
        }
    }
}

/// Retry-safe orchestration for the cafe envelope around canonical sip visits.
/// Sip enjoyment remains on `visits`; this service never reads or writes it.
final class CafeSessionService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func capability() async throws -> CafeSessionsCapability {
        let capability: CafeSessionsCapability = try await client
            .rpc("get_cafe_sessions_capability_v1")
            .execute()
            .value
        guard capability.supportsCapture else {
            throw CafeSessionServiceError.capabilityUnavailable
        }
        return capability
    }

    func ensureSession(
        sessionID: UUID,
        remoteCafeID: UUID,
        startedAt: Date,
        context: CafeVisitContext,
        visibility: VisitVisibility = .private
    ) async throws {
        try await client.rpc(
            "ensure_cafe_session_v1",
            params: EnsureCafeSessionParameters(
                sessionID: sessionID,
                cafeID: remoteCafeID,
                startedAt: startedAt,
                visitMode: context.mode.backendValue,
                contextOverlays: context.overlays
                    .map(\.backendValue)
                    .sorted(),
                visibility: visibility.supabaseValue
            )
        )
        .execute()
    }

    func attachVisit(
        sessionID: UUID,
        visitID: UUID,
        order: Int,
        role: CafeSessionSipRole
    ) async throws {
        try await client.rpc(
            "attach_visit_to_cafe_session_v1",
            params: AttachCafeSessionVisitParameters(
                sessionID: sessionID,
                visitID: visitID,
                order: order,
                role: role.rawValue
            )
        )
        .execute()
    }

    func recordIntentions(
        sessionID: UUID,
        visitID: UUID,
        returnIntention: CafeReturnIntention?,
        reorderIntention: SipReorderIntention?
    ) async throws {
        try await client.rpc(
            "set_cafe_session_intentions_v1",
            params: CafeSessionIntentionsParameters(
                sessionID: sessionID,
                visitID: visitID,
                returnIntention: returnIntention?.rawValue,
                reorderIntention: reorderIntention?.rawValue
            )
        )
        .execute()
    }

    func recordExperience(
        _ snapshot: CafeExperienceSnapshot,
        primaryReorderIntention: SipReorderIntention?
    ) async throws {
        let parameters = try RecordCafeExperienceParameters.make(
            snapshot: snapshot,
            primaryReorderIntention: primaryReorderIntention
        )
        try await client
            .rpc("record_cafe_experience_v1", params: parameters)
            .execute()
    }

    func publishSession(
        sessionID: UUID,
        visibility: VisitVisibility,
        snapshot: CafeExperienceSnapshot?,
        sharing: CafeExperienceShareProjection,
        endedAt: Date = .now
    ) async throws {
        let needsPublicSnapshot =
            visibility != .private && sharing.requiresSnapshot
        guard !needsPublicSnapshot || snapshot != nil else {
            throw CafeSessionServiceError.missingCafePulseSnapshotForSharing
        }
        let projection = CafePublicProjectionPayload(
            snapshot: snapshot,
            sharing: sharing
        )
        try await client.rpc(
            "publish_cafe_session_v1",
            params: PublishCafeSessionParameters(
                sessionID: sessionID,
                visibility: visibility.supabaseValue,
                shareCafeSummary: !sharing.isEmpty,
                shareCafeRating: sharing.includesCafeRating,
                shareNextMove: sharing.includesNextMove,
                dimensionIDs: projection.dimensionIDs,
                descriptorIDs: projection.descriptorIDs,
                endedAt: endedAt
            )
        )
        .execute()
    }

    func appendSip(
        sessionID: UUID,
        visitID: UUID,
        order: Int,
        reorderIntention: SipReorderIntention?
    ) async throws {
        try await client.rpc(
            "append_cafe_session_sip_v1",
            params: AppendCafeSessionSipParameters(
                sessionID: sessionID,
                visitID: visitID,
                order: order,
                reorderIntention: reorderIntention?.rawValue
            )
        )
        .execute()
    }

    func finalizeSipUpload(
        sessionID: UUID,
        visitID: UUID
    ) async throws {
        try await client.rpc(
            "finalize_cafe_session_sip_v1",
            params: FinalizeCafeSessionSipParameters(
                sessionID: sessionID,
                visitID: visitID
            )
        )
        .execute()
    }

    func fetchSessionSummary(sessionID: UUID) async throws -> RemoteCafeSessionSummary {
        try await client.rpc(
            "get_cafe_session_summary_v1",
            params: CafeSessionIdentifierParameters(sessionID: sessionID)
        )
        .execute()
        .value
    }

    func fetchCafeSummary(
        cafeID: UUID,
        scope: CafeExperienceSummaryScope = .personal
    ) async throws -> RemoteCafeExperienceSummary {
        try await client.rpc(
            "get_cafe_experience_summary_v1",
            params: CafeExperienceSummaryParameters(
                cafeID: cafeID,
                scope: scope.rawValue
            )
        )
        .execute()
        .value
    }

    func fetchCafeSummaries(
        cafeIDs: [UUID],
        scope: CafeExperienceSummaryScope = .personal
    ) async throws -> [RemoteCafeExperienceSummary] {
        guard !cafeIDs.isEmpty else { return [] }
        return try await client.rpc(
            "get_cafe_experience_summaries_v1",
            params: CafeExperienceSummariesParameters(
                cafeIDs: Array(Set(cafeIDs)).sorted { $0.uuidString < $1.uuidString },
                scope: scope.rawValue
            )
        )
        .execute()
        .value
    }

    func fetchFriendMapSipSummaries(
        cafeIDs: [UUID]
    ) async throws -> [RemoteFriendMapSipSummary] {
        guard !cafeIDs.isEmpty else { return [] }
        return try await client.rpc(
            "get_friend_map_sip_summaries_v1",
            params: FriendMapSipSummariesParameters(
                cafeIDs: Array(Set(cafeIDs)).sorted { $0.uuidString < $1.uuidString }
            )
        )
        .execute()
        .value
    }

    func fetchOwnSnapshots(
        userID: UUID,
        cafeID: UUID? = nil,
        limit: Int = 300
    ) async throws -> [CafeExperienceSnapshot] {
        var query = client
            .from("cafe_experience_snapshots")
            .select("snapshot_payload")
            .eq("user_id", value: userID.uuidString)
        if let cafeID {
            query = query.eq("cafe_id", value: cafeID.uuidString)
        }
        let rows: [CafeExperienceSnapshotPayloadRow] = try await query
            .order("created_at", ascending: false)
            .limit(min(max(limit, 1), 500))
            .execute()
            .value
        let snapshots = rows.map(\.snapshotPayload)
        guard snapshots.allSatisfy({ $0.ownerUserID == userID }) else {
            throw CafeSessionServiceError.accountScopeMismatch
        }
        return snapshots
    }
}

private struct CafeExperienceSnapshotPayloadRow: Decodable {
    let snapshotPayload: CafeExperienceSnapshot

    enum CodingKeys: String, CodingKey {
        case snapshotPayload = "snapshot_payload"
    }
}

private struct EnsureCafeSessionParameters: Encodable {
    let sessionID: UUID
    let cafeID: UUID
    let startedAt: Date
    let visitMode: String
    let contextOverlays: [String]
    let visibility: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "p_session_id"
        case cafeID = "p_cafe_id"
        case startedAt = "p_started_at"
        case visitMode = "p_visit_mode"
        case contextOverlays = "p_context_overlays"
        case visibility = "p_visibility"
    }
}

private struct AttachCafeSessionVisitParameters: Encodable {
    let sessionID: UUID
    let visitID: UUID
    let order: Int
    let role: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "p_session_id"
        case visitID = "p_visit_id"
        case order = "p_order"
        case role = "p_role"
    }
}

private struct CafeSessionIntentionsParameters: Encodable {
    let sessionID: UUID
    let visitID: UUID
    let returnIntention: String?
    let reorderIntention: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "p_session_id"
        case visitID = "p_visit_id"
        case returnIntention = "p_return_intention"
        case reorderIntention = "p_reorder_intention"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(visitID, forKey: .visitID)
        try container.encodeIfPresent(returnIntention, forKey: .returnIntention)
        if returnIntention == nil { try container.encodeNil(forKey: .returnIntention) }
        try container.encodeIfPresent(reorderIntention, forKey: .reorderIntention)
        if reorderIntention == nil { try container.encodeNil(forKey: .reorderIntention) }
    }
}

private struct RecordCafeExperienceParameters: Encodable {
    let sessionID: UUID
    let snapshotID: UUID
    let schemaVersion: Int
    let bundleID: String
    let bundleContentVersion: String
    let depth: String
    let cafeRating: Double?
    let repeatComparison: String?
    let responses: [CafeExperienceRPCObservation]
    let ownWords: String
    let returnIntention: String?
    let primaryReorderIntention: String?
    let snapshotPayload: CafeExperienceSnapshot
    let payloadHash: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case sessionID = "p_session_id"
        case snapshotID = "p_snapshot_id"
        case schemaVersion = "p_schema_version"
        case bundleID = "p_bundle_id"
        case bundleContentVersion = "p_bundle_content_version"
        case depth = "p_depth"
        case cafeRating = "p_cafe_rating"
        case repeatComparison = "p_repeat_comparison"
        case responses = "p_responses"
        case ownWords = "p_own_words"
        case returnIntention = "p_return_intention"
        case primaryReorderIntention = "p_primary_reorder_intention"
        case snapshotPayload = "p_snapshot_payload"
        case payloadHash = "p_payload_hash"
        case createdAt = "p_created_at"
    }

    static func make(
        snapshot: CafeExperienceSnapshot,
        primaryReorderIntention: SipReorderIntention?
    ) throws -> Self {
        Self(
            sessionID: snapshot.sessionID,
            snapshotID: snapshot.id,
            schemaVersion: snapshot.schemaVersion,
            bundleID: "mugshot.cafe-pulse",
            bundleContentVersion: "1.0.0",
            depth: snapshot.depth.rawValue,
            cafeRating: snapshot.cafeRating?.value,
            repeatComparison: snapshot.repeatComparison?.rawValue,
            responses: snapshot.observations.compactMap(CafeExperienceRPCObservation.init),
            ownWords: snapshot.ownWords ?? "",
            returnIntention: snapshot.returnIntention?.rawValue,
            primaryReorderIntention: primaryReorderIntention?.rawValue,
            snapshotPayload: snapshot,
            payloadHash: try CafeExperiencePayloadHash.make(snapshot),
            createdAt: snapshot.createdAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(snapshotID, forKey: .snapshotID)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(bundleID, forKey: .bundleID)
        try container.encode(bundleContentVersion, forKey: .bundleContentVersion)
        try container.encode(depth, forKey: .depth)
        try container.encodeIfPresent(cafeRating, forKey: .cafeRating)
        if cafeRating == nil { try container.encodeNil(forKey: .cafeRating) }
        try container.encodeIfPresent(repeatComparison, forKey: .repeatComparison)
        if repeatComparison == nil { try container.encodeNil(forKey: .repeatComparison) }
        try container.encode(responses, forKey: .responses)
        try container.encode(ownWords, forKey: .ownWords)
        try container.encodeIfPresent(returnIntention, forKey: .returnIntention)
        if returnIntention == nil { try container.encodeNil(forKey: .returnIntention) }
        try container.encodeIfPresent(primaryReorderIntention, forKey: .primaryReorderIntention)
        if primaryReorderIntention == nil {
            try container.encodeNil(forKey: .primaryReorderIntention)
        }
        try container.encode(snapshotPayload, forKey: .snapshotPayload)
        try container.encode(payloadHash, forKey: .payloadHash)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

private struct CafeExperienceRPCObservation: Encodable {
    let dimensionID: String
    let observationID: String
    let state: String
    let impact: String?
    let descriptorIDs: [String]

    init?(_ observation: CafeExperienceObservation) {
        switch observation.state {
        case .notAsked, .skipped:
            return nil
        case .notObserved, .notRelevant, .observed:
            break
        }
        dimensionID = observation.dimension.backendValue
        observationID = "cafe.observation." +
            observation.id.uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        state = observation.state.backendValue
        impact = observation.impact?.rawValue
        descriptorIDs = observation.facet.map {
            ["cafe.descriptor.\($0.rawValue)"]
        } ?? []
    }

    enum CodingKeys: String, CodingKey {
        case dimensionID
        case observationID
        case state, impact
        case descriptorIDs
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dimensionID, forKey: .dimensionID)
        try container.encode(observationID, forKey: .observationID)
        try container.encode(state, forKey: .state)
        try container.encodeIfPresent(impact, forKey: .impact)
        try container.encode(descriptorIDs, forKey: .descriptorIDs)
    }
}

private struct PublishCafeSessionParameters: Encodable {
    let sessionID: UUID
    let visibility: String
    let shareCafeSummary: Bool
    let shareCafeRating: Bool
    let shareNextMove: Bool
    let dimensionIDs: [String]
    let descriptorIDs: [String]
    let endedAt: Date

    enum CodingKeys: String, CodingKey {
        case sessionID = "p_session_id"
        case visibility = "p_visibility"
        case shareCafeSummary = "p_share_cafe_summary"
        case shareCafeRating = "p_share_cafe_rating"
        case shareNextMove = "p_share_next_move"
        case dimensionIDs = "p_dimension_ids"
        case descriptorIDs = "p_descriptor_ids"
        case endedAt = "p_ended_at"
    }
}

private struct AppendCafeSessionSipParameters: Encodable {
    let sessionID: UUID
    let visitID: UUID
    let order: Int
    let reorderIntention: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "p_session_id"
        case visitID = "p_visit_id"
        case order = "p_order"
        case reorderIntention = "p_reorder_intention"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(visitID, forKey: .visitID)
        try container.encode(order, forKey: .order)
        try container.encodeIfPresent(reorderIntention, forKey: .reorderIntention)
        if reorderIntention == nil { try container.encodeNil(forKey: .reorderIntention) }
    }
}

private struct FinalizeCafeSessionSipParameters: Encodable {
    let sessionID: UUID
    let visitID: UUID

    enum CodingKeys: String, CodingKey {
        case sessionID = "p_session_id"
        case visitID = "p_visit_id"
    }
}

private struct CafeSessionIdentifierParameters: Encodable {
    let sessionID: UUID

    enum CodingKeys: String, CodingKey {
        case sessionID = "p_session_id"
    }
}

private struct CafeExperienceSummaryParameters: Encodable {
    let cafeID: UUID
    let scope: String

    enum CodingKeys: String, CodingKey {
        case cafeID = "p_cafe_id"
        case scope = "p_scope"
    }
}

private struct CafeExperienceSummariesParameters: Encodable {
    let cafeIDs: [UUID]
    let scope: String

    enum CodingKeys: String, CodingKey {
        case cafeIDs = "p_cafe_ids"
        case scope = "p_scope"
    }
}

private struct FriendMapSipSummariesParameters: Encodable {
    let cafeIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case cafeIDs = "p_cafe_ids"
    }
}

private struct CafePublicProjectionPayload {
    let dimensionIDs: [String]
    let descriptorIDs: [String]

    init(
        snapshot: CafeExperienceSnapshot?,
        sharing: CafeExperienceShareProjection
    ) {
        guard let snapshot else {
            dimensionIDs = []
            descriptorIDs = []
            return
        }
        let selected = snapshot.observations.filter {
            sharing.observationIDs.contains($0.id) &&
                $0.state == .observed
        }
        dimensionIDs = selected
            .map { $0.dimension.backendValue }
            .unique
            .prefix(6)
            .map { $0 }
        descriptorIDs = selected
            .compactMap(\.facet)
            .map { "cafe.descriptor.\($0.rawValue)" }
            .unique
            .prefix(12)
            .map { $0 }
    }
}

private enum CafeExperiencePayloadHash {
    static func make(_ snapshot: CafeExperienceSnapshot) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(snapshot)
        let object = try JSONSerialization.jsonObject(with: encoded)
        let canonical = canonicalize(object)
        let canonicalData = try JSONSerialization.data(
            withJSONObject: canonical,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return SHA256.hash(data: canonicalData)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func canonicalize(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues(canonicalize)
        }
        if let array = value as? [Any] {
            return array
                .map(canonicalize)
                .sorted { canonicalSortKey($0) < canonicalSortKey($1) }
        }
        return value
    }

    private static func canonicalSortKey(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(["value": value]),
              let data = try? JSONSerialization.data(
                withJSONObject: ["value": value],
                options: [.sortedKeys, .withoutEscapingSlashes]
              ) else {
            return String(describing: value)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

private extension CafeVisitMode {
    var backendValue: String {
        switch self {
        case .grabAndGo: return "grab_and_go"
        case .stayAwhile: return "stay_a_while"
        case .workStudy: return "work_study"
        case .social: return "social"
        case .foodFocused: return "food_focused"
        }
    }
}

private extension CafeVisitOverlay {
    var backendValue: String {
        switch self {
        case .outdoorSeating: return "outdoor"
        case .busyQueue: return "busy_queue"
        }
    }
}

private extension CafeExperienceDimension {
    var backendValue: String {
        switch self {
        case .atmosphere: return "atmosphere"
        case .musicAndSound: return "music_sound"
        case .hospitality: return "hospitality"
        case .menuAndValue: return "menu_value"
        case .comfortAndPracticality: return "comfort_practicality"
        case .communityAndCharacter: return "community_character"
        }
    }
}

private extension CafeExperienceObservationState {
    var backendValue: String {
        switch self {
        case .notObserved: return "not_observed"
        case .notRelevant: return "not_relevant"
        case .observed: return "observed"
        case .notAsked: return "not_asked"
        case .skipped: return "skipped"
        }
    }
}

private extension Array where Element: Hashable {
    var unique: [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
