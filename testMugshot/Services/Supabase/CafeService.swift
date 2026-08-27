//
//  CafeService.swift
//  testMugshot
//

import Foundation
import Supabase

final class CafeService {
    private let client: SupabaseClient

    private let cafeColumns = """
    id, name, address, city, latitude, longitude, apple_place_id, apple_maps_place_id, website_url, identity_key
    """

    private let legacyCafeColumns = """
    id, name, address, city, latitude, longitude, apple_place_id, website_url, identity_key
    """

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchCafe(id: UUID) async throws -> SupabaseCafeSummary? {
        let cafes: [SupabaseCafeSummary] = try await withCafeColumnCompatibility { columns in
            try await client
                .from("cafes")
                .select(columns)
                .eq("id", value: id.uuidString)
                .execute()
                .value
        }

        return cafes.first
    }

    func fetchCafes(ids: some Collection<UUID>) async throws -> [SupabaseCafeSummary] {
        let identifiers = Array(Set(ids))
        guard !identifiers.isEmpty else { return [] }

        return try await withCafeColumnCompatibility { columns in
            try await client
                .from("cafes")
                .select(columns)
                .in("id", values: identifiers.map(\.uuidString))
                .execute()
                .value
        }
    }

    /// Finds provider records that represent the same physical cafe without
    /// rewriting production data. Callers can read visits across every
    /// returned ID while retaining one canonical local presentation.
    func fetchEquivalentCafes(to cafe: Cafe) async throws -> [SupabaseCafeSummary] {
        let candidates: [SupabaseCafeSummary]
        if let location = cafe.location {
            let radiusMeters = 125.0
            let latitudeDelta = radiusMeters / 111_000
            let longitudeScale = max(
                cos(location.latitude * .pi / 180),
                0.2
            )
            let longitudeDelta = radiusMeters / (111_000 * longitudeScale)
            candidates = try await withCafeColumnCompatibility { columns in
                try await client
                    .from("cafes")
                    .select(columns)
                    .gte("latitude", value: location.latitude - latitudeDelta)
                    .lte("latitude", value: location.latitude + latitudeDelta)
                    .gte("longitude", value: location.longitude - longitudeDelta)
                    .lte("longitude", value: location.longitude + longitudeDelta)
                    .limit(100)
                    .execute()
                    .value
            }
        } else {
            let trimmedName = cafe.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return [] }
            candidates = try await withCafeColumnCompatibility { columns in
                try await client
                    .from("cafes")
                    .select(columns)
                    .eq("name", value: trimmedName)
                    .limit(100)
                    .execute()
                    .value
            }
        }

        var equivalents = candidates.filter {
            CafeIdentity.shouldStitch(cafe, $0.localCafe())
        }
        if let remoteCafeID = cafe.remoteCafeId,
           !equivalents.contains(where: { $0.id == remoteCafeID }),
           let primary = try await fetchCafe(id: remoteCafeID) {
            equivalents.append(primary)
        }
        return equivalents.sorted { lhs, rhs in
            if lhs.id == cafe.remoteCafeId { return true }
            if rhs.id == cafe.remoteCafeId { return false }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func resolveSummary(for cafe: Cafe) async throws -> ResolvedCafeSummary? {
        let summaries: [ResolvedCafeSummary] = try await client.rpc(
            "resolve_cafe_summary",
            params: ResolveCafeParameters(
                pName: cafe.name,
                pLatitude: cafe.location?.latitude,
                pLongitude: cafe.location?.longitude,
                pApplePlaceID: cafe.appleMapsPlaceID ?? cafe.mapItemURL
            )
        )
        .execute()
        .value

        return summaries.first
    }

    func findOrCreateCafe(from cafe: Cafe) async throws -> SupabaseCafeSummary {
        if let remoteCafeId = cafe.remoteCafeId,
           let existingCafe = try await fetchCafe(id: remoteCafeId) {
            return existingCafe
        }

        let identityKey = CafeIdentity.key(for: cafe)
        if let existingCafe = try await fetchCafe(identityKey: identityKey) {
            return existingCafe
        }

        if let appleMapsPlaceID = cafe.appleMapsPlaceID?.remoteTrimmedNonEmpty,
           let existingCafe = try await fetchCafe(appleMapsPlaceID: appleMapsPlaceID) {
            return existingCafe
        }

        if let applePlaceId = cafe.mapItemURL?.remoteTrimmedNonEmpty,
           let existingCafe = try await fetchCafe(legacyApplePlaceId: applePlaceId) {
            return existingCafe
        }

        if let equivalentCafe = try await fetchEquivalentCafes(to: cafe).first {
            return equivalentCafe
        }

        if let existingCafe = try await fetchCafe(name: cafe.name, address: cafe.address) {
            return existingCafe
        }

        let payload = SupabaseCafeInsert.from(cafe: cafe)

        do {
            return try await client
                .from("cafes")
                .insert(payload)
                .select(cafeColumns)
                .single()
                .execute()
                .value
        } catch {
            // A concurrent visit/state mutation may have inserted the same
            // identity after our lookup. Resolve that unique-key race without
            // creating a second cafe or masking unrelated failures.
            do {
                if let racedCafe = try await fetchCafe(identityKey: identityKey) {
                    return racedCafe
                }
            } catch {
                // Preserve the original insert failure below.
            }
            throw error
        }
    }

    private func fetchCafe(identityKey: String) async throws -> SupabaseCafeSummary? {
        let cafes: [SupabaseCafeSummary] = try await withCafeColumnCompatibility { columns in
            try await client
                .from("cafes")
                .select(columns)
                .eq("identity_key", value: identityKey)
                .limit(1)
                .execute()
                .value
        }
        return cafes.first
    }

    private func fetchCafe(appleMapsPlaceID: String) async throws -> SupabaseCafeSummary? {
        let cafes: [SupabaseCafeSummary]
        do {
            cafes = try await client
                .from("cafes")
                .select(cafeColumns)
                .eq("apple_maps_place_id", value: appleMapsPlaceID)
                .limit(1)
                .execute()
                .value
        } catch {
            guard SupabaseBackendCompatibility.isMissingAppleMapsPlaceIDColumn(error) else {
                throw error
            }
            return nil
        }

        return cafes.first
    }

    private func fetchCafe(legacyApplePlaceId: String) async throws -> SupabaseCafeSummary? {
        let cafes: [SupabaseCafeSummary] = try await withCafeColumnCompatibility { columns in
            try await client
                .from("cafes")
                .select(columns)
                .eq("apple_place_id", value: legacyApplePlaceId)
                .limit(1)
                .execute()
                .value
        }

        return cafes.first
    }

    private func fetchCafe(name: String, address: String) async throws -> SupabaseCafeSummary? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return nil
        }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let cafes: [SupabaseCafeSummary] = try await withCafeColumnCompatibility { columns in
            var query = client
                .from("cafes")
                .select(columns)
                .eq("name", value: trimmedName)

            if !trimmedAddress.isEmpty {
                query = query.eq("address", value: trimmedAddress)
            }

            return try await query
                .limit(1)
                .execute()
                .value
        }

        return cafes.first
    }

    private func withCafeColumnCompatibility<Value>(
        _ operation: (String) async throws -> Value
    ) async throws -> Value {
        do {
            return try await operation(cafeColumns)
        } catch {
            guard SupabaseBackendCompatibility.isMissingAppleMapsPlaceIDColumn(error) else {
                throw error
            }
            return try await operation(legacyCafeColumns)
        }
    }
}

private struct ResolveCafeParameters: Encodable {
    let pName: String
    let pLatitude: Double?
    let pLongitude: Double?
    let pApplePlaceID: String?

    enum CodingKeys: String, CodingKey {
        case pName = "p_name"
        case pLatitude = "p_latitude"
        case pLongitude = "p_longitude"
        case pApplePlaceID = "p_apple_place_id"
    }
}

struct SupabaseCafeInsert: Encodable, Equatable {
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let applePlaceId: String?
    let appleMapsPlaceID: String?
    let websiteURL: String?
    let identityKey: String

    enum CodingKeys: String, CodingKey {
        case name
        case address
        case latitude
        case longitude
        case applePlaceId = "apple_place_id"
        case appleMapsPlaceID = "apple_maps_place_id"
        case websiteURL = "website_url"
        case identityKey = "identity_key"
    }

    static func from(cafe: Cafe) -> SupabaseCafeInsert {
        SupabaseCafeInsert(
            name: cafe.name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: cafe.address.remoteTrimmedNonEmpty,
            latitude: cafe.location?.latitude,
            longitude: cafe.location?.longitude,
            applePlaceId: cafe.mapItemURL?.remoteTrimmedNonEmpty,
            appleMapsPlaceID: cafe.appleMapsPlaceID?.remoteTrimmedNonEmpty,
            websiteURL: cafe.websiteURL?.remoteTrimmedNonEmpty,
            identityKey: CafeIdentity.key(for: cafe)
        )
    }
}
