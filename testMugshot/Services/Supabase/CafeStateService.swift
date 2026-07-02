//
//  CafeStateService.swift
//  testMugshot
//

import Foundation
import Supabase

final class CafeStateService {
    private let client: SupabaseClient
    private let cafeService: CafeService

    private let stateColumns = """
    id, user_id, cafe_id, is_favorite, want_to_try, created_at, updated_at
    """

    init(
        client: SupabaseClient,
        cafeService: CafeService? = nil
    ) {
        self.client = client
        self.cafeService = cafeService ?? CafeService(client: client)
    }

    func fetchCafeStates(userId: UUID) async throws -> [RemoteCafeStateSummary] {
        let rows: [SupabaseCafeStateRow] = try await client
            .from("user_cafe_states")
            .select(stateColumns)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        guard !rows.isEmpty else {
            return []
        }

        let cafeIds = rows.map { $0.cafeId.uuidString }
        let cafes: [SupabaseCafeSummary] = try await client
            .from("cafes")
            .select("id, name, address, city, latitude, longitude, apple_place_id, website_url")
            .in("id", values: cafeIds)
            .execute()
            .value
        let cafesById = Dictionary(uniqueKeysWithValues: cafes.map { ($0.id, $0) })

        return rows.compactMap { row in
            guard let cafe = cafesById[row.cafeId] else {
                return nil
            }

            return RemoteCafeStateSummary(state: row, cafe: cafe)
        }
    }

    func setCafeState(
        userId: UUID,
        cafe: Cafe,
        isFavorite: Bool,
        wantToTry: Bool
    ) async throws -> RemoteCafeStateSummary {
        let remoteCafe = try await cafeService.findOrCreateCafe(from: cafe)
        let payload = SupabaseCafeStateUpsert(
            userId: userId,
            cafeId: remoteCafe.id,
            isFavorite: isFavorite,
            wantToTry: wantToTry
        )

        let row: SupabaseCafeStateRow = try await client
            .from("user_cafe_states")
            .upsert(payload, onConflict: "user_id,cafe_id")
            .select(stateColumns)
            .single()
            .execute()
            .value

        return RemoteCafeStateSummary(state: row, cafe: remoteCafe)
    }
}

struct SupabaseCafeStateUpsert: Encodable, Equatable {
    let userId: UUID
    let cafeId: UUID
    let isFavorite: Bool
    let wantToTry: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case cafeId = "cafe_id"
        case isFavorite = "is_favorite"
        case wantToTry = "want_to_try"
    }
}
