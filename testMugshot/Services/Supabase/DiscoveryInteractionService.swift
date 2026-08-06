import Foundation
import Supabase

struct DiscoveryAttributionResult: Decodable, Equatable {
    let attributed: Bool
    let kind: String?
    let source: String?
    let alreadyRecorded: Bool?

    enum CodingKeys: String, CodingKey {
        case attributed
        case kind
        case source
        case alreadyRecorded = "already_recorded"
    }
}

final class DiscoveryInteractionService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    @discardableResult
    func record(
        id: UUID = UUID(),
        cafeID: UUID?,
        appleMapsPlaceID: String?,
        source: DiscoveryAttributionSource,
        kind: DiscoveryInteractionKind,
        sourceListID: UUID? = nil,
        rankingVersion: String? = nil,
        occurredAt: Date = .now
    ) async throws -> UUID {
        try await client.rpc(
            "record_discovery_interaction_v1",
            params: DiscoveryInteractionParameters(
                interactionID: id,
                cafeID: cafeID,
                appleMapsPlaceID: appleMapsPlaceID,
                source: source.rawValue,
                kind: kind.rawValue,
                sourceListID: sourceListID,
                rankingVersion: rankingVersion,
                occurredAt: occurredAt
            )
        ).execute().value
    }

    func consumeAttribution(visitID: UUID) async throws -> DiscoveryAttributionResult {
        try await client.rpc(
            "consume_discovery_attribution_v1",
            params: VisitAttributionParameters(visitID: visitID)
        ).execute().value
    }

    func consumeAttributionAndCapture(visitID: UUID) async {
        guard let result = try? await consumeAttribution(visitID: visitID),
              result.attributed,
              result.alreadyRecorded != true,
              let rawSource = result.source,
              let source = DiscoveryAttributionSource(rawValue: rawSource) else { return }
        MugshotAnalytics.shared.capture(.discovery(
            action: .assistedMugshotCreated,
            source: source,
            surface: .sipDetail,
            rankingVersion: nil,
            cafeID: nil
        ))
    }
}

private struct DiscoveryInteractionParameters: Encodable {
    let interactionID: UUID
    let cafeID: UUID?
    let appleMapsPlaceID: String?
    let source: String
    let kind: String
    let sourceListID: UUID?
    let rankingVersion: String?
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case interactionID = "p_interaction_id"
        case cafeID = "p_cafe_id"
        case appleMapsPlaceID = "p_apple_maps_place_id"
        case source = "p_source"
        case kind = "p_interaction_kind"
        case sourceListID = "p_source_list_id"
        case rankingVersion = "p_ranking_version"
        case occurredAt = "p_occurred_at"
    }
}

private struct VisitAttributionParameters: Encodable {
    let visitID: UUID
    enum CodingKeys: String, CodingKey { case visitID = "p_visit_id" }
}
