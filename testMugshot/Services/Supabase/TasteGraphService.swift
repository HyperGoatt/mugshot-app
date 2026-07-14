import Foundation
import Supabase

struct RemoteVisitDrinkAnalysis: Decodable, Equatable {
    let visitID: UUID
    let rawDrinkName: String
    let canonicalFamily: String?
    let preparation: String?
    let temperature: String?
    let espressoShotCount: Int?
    let servingVolumeMilliliters: Double?
    let processingStatus: String
    let confidence: Double
    let userOverrides: [String: FlexibleJSONValue]

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case rawDrinkName = "raw_drink_name"
        case canonicalFamily = "canonical_family"
        case preparation, temperature
        case espressoShotCount = "espresso_shot_count"
        case servingVolumeMilliliters = "serving_volume_ml"
        case processingStatus = "processing_status"
        case confidence
        case userOverrides = "user_overrides"
    }
}

enum FlexibleJSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct DrinkAnalysisCorrection: Encodable, Equatable {
    var canonicalFamily: String?
    var preparation: String?
    var temperature: String?
    var espressoShotCount: Int?
    var servingVolumeMilliliters: Double?

    enum CodingKeys: String, CodingKey {
        case canonicalFamily = "canonical_family"
        case preparation, temperature
        case espressoShotCount = "espresso_shot_count"
        case servingVolumeMilliliters = "serving_volume_ml"
    }
}

private struct TasteSignalStateParameters: Encodable {
    let pSignalID: UUID
    let pState: String
    let pLabel: String?

    enum CodingKeys: String, CodingKey {
        case pSignalID = "p_signal_id"
        case pState = "p_state"
        case pLabel = "p_label"
    }
}

private struct DrinkAnalysisCorrectionParameters: Encodable {
    let pVisitID: UUID
    let pOverrides: DrinkAnalysisCorrection

    enum CodingKeys: String, CodingKey {
        case pVisitID = "p_visit_id"
        case pOverrides = "p_overrides"
    }
}

final class TasteGraphService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchSignals(userID: UUID) async throws -> [RemoteTasteSignal] {
        try await client
            .from("taste_signals")
            .select("id,user_id,signal_type,attribute,support_count,confidence,average_score,evidence_visit_ids,calculation_version,owner_state,owner_label,updated_at")
            .eq("user_id", value: userID.uuidString)
            .order("support_count", ascending: false)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func setOwnerState(
        signalID: UUID,
        state: TasteSignalOwnerState,
        label: String? = nil
    ) async throws {
        try await client.rpc(
            "set_taste_signal_owner_state",
            params: TasteSignalStateParameters(
                pSignalID: signalID,
                pState: state.rawValue,
                pLabel: label?.remoteTrimmedNonEmpty
            )
        ).execute()
    }

    func fetchDrinkAnalysis(visitID: UUID) async throws -> RemoteVisitDrinkAnalysis? {
        let rows: [RemoteVisitDrinkAnalysis] = try await client
            .from("visit_drink_analyses")
            .select("visit_id,raw_drink_name,canonical_family,preparation,temperature,espresso_shot_count,serving_volume_ml,processing_status,confidence,user_overrides")
            .eq("visit_id", value: visitID.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func correctDrinkAnalysis(
        visitID: UUID,
        correction: DrinkAnalysisCorrection,
        userID: UUID
    ) async throws {
        try await client.rpc(
            "request_visit_drink_analysis_correction",
            params: DrinkAnalysisCorrectionParameters(
                pVisitID: visitID,
                pOverrides: correction
            )
        ).execute()
        await DrinkAnalysisService(client: client).requestAnalysisDurably(visitId: visitID, userId: userID)
    }
}
