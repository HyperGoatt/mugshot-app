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
            .or("is_favorite.eq.true,want_to_try.eq.true")
            .execute()
            .value

        guard !rows.isEmpty else {
            return []
        }

        let cafeIds = rows.map { $0.cafeId.uuidString }
        let cafes: [SupabaseCafeSummary] = try await client
            .from("cafes")
            .select("id, name, address, city, latitude, longitude, apple_place_id, apple_maps_place_id, website_url, identity_key")
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
        wantToTry: Bool,
        discoveryNote: String? = nil,
        discoverySource: DiscoveryAttributionSource? = nil,
        discoveredAt: Date? = nil
    ) async throws -> RemoteCafeStateSummary {
        let remoteCafe = try await cafeService.findOrCreateCafe(from: cafe)
        if !isFavorite && !wantToTry {
            try await client
                .from("user_cafe_states")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("cafe_id", value: remoteCafe.id.uuidString)
                .execute()
            return RemoteCafeStateSummary(
                state: SupabaseCafeStateRow(
                    id: UUID(),
                    userId: userId,
                    cafeId: remoteCafe.id,
                    isFavorite: false,
                    wantToTry: false,
                    createdAt: nil,
                    updatedAt: nil
                ),
                cafe: remoteCafe
            )
        }
        let payload = SupabaseCafeStateUpsert(
            userId: userId,
            cafeId: remoteCafe.id,
            isFavorite: isFavorite,
            wantToTry: wantToTry,
            discoveryNote: discoveryNote,
            discoverySource: discoverySource?.rawValue,
            discoveredAt: discoveredAt
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

    func clearWantToTryAfterVisit(userId: UUID, cafeId: UUID) async throws {
        try await client
            .from("user_cafe_states")
            .update(SupabaseCafeWantToTryUpdate(wantToTry: false))
            .eq("user_id", value: userId.uuidString)
            .eq("cafe_id", value: cafeId.uuidString)
            .execute()
        try await client
            .from("user_cafe_states")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("cafe_id", value: cafeId.uuidString)
            .eq("is_favorite", value: false)
            .eq("want_to_try", value: false)
            .execute()
    }

    @discardableResult
    func reconcileVisitedWantToTry(userId: UUID) async throws -> Int {
        let states: [SupabaseCafeStateRow] = try await client
            .from("user_cafe_states")
            .select(stateColumns)
            .eq("user_id", value: userId.uuidString)
            .eq("want_to_try", value: true)
            .execute()
            .value
        guard !states.isEmpty else { return 0 }

        let cafeIds = states.map(\.cafeId)
        let visits: [VisitedCafeRow] = try await client
            .from("visits")
            .select("cafe_id")
            .eq("user_id", value: userId.uuidString)
            .eq("upload_state", value: VisitUploadState.complete.rawValue)
            .or("context_type.eq.Cafe,context_type.is.null")
            .in("cafe_id", values: cafeIds.map(\.uuidString))
            .execute()
            .value
        let visitedCafeIds = Array(Set(visits.compactMap(\.cafeId)))
        guard !visitedCafeIds.isEmpty else { return 0 }

        let identifiers = visitedCafeIds.map(\.uuidString)
        try await client
            .from("user_cafe_states")
            .update(SupabaseCafeWantToTryUpdate(wantToTry: false))
            .eq("user_id", value: userId.uuidString)
            .in("cafe_id", values: identifiers)
            .execute()
        try await client
            .from("user_cafe_states")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("is_favorite", value: false)
            .eq("want_to_try", value: false)
            .in("cafe_id", values: identifiers)
            .execute()
        return visitedCafeIds.count
    }
}

private struct VisitedCafeRow: Decodable {
    let cafeId: UUID?

    enum CodingKeys: String, CodingKey {
        case cafeId = "cafe_id"
    }
}

private struct SupabaseCafeWantToTryUpdate: Encodable {
    let wantToTry: Bool

    enum CodingKeys: String, CodingKey {
        case wantToTry = "want_to_try"
    }
}

struct SupabaseCafeStateUpsert: Encodable, Equatable {
    let userId: UUID
    let cafeId: UUID
    let isFavorite: Bool
    let wantToTry: Bool
    let discoveryNote: String?
    let discoverySource: String?
    let discoveredAt: Date?

    init(
        userId: UUID,
        cafeId: UUID,
        isFavorite: Bool,
        wantToTry: Bool,
        discoveryNote: String? = nil,
        discoverySource: String? = nil,
        discoveredAt: Date? = nil
    ) {
        self.userId = userId
        self.cafeId = cafeId
        self.isFavorite = isFavorite
        self.wantToTry = wantToTry
        self.discoveryNote = discoveryNote
        self.discoverySource = discoverySource
        self.discoveredAt = discoveredAt
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case cafeId = "cafe_id"
        case isFavorite = "is_favorite"
        case wantToTry = "want_to_try"
        case discoveryNote = "discovery_note"
        case discoverySource = "discovery_source"
        case discoveredAt = "discovered_at"
    }
}
