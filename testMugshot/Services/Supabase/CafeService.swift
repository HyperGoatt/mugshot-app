//
//  CafeService.swift
//  testMugshot
//

import Foundation
import Supabase

final class CafeService {
    private let client: SupabaseClient

    private let cafeColumns = """
    id, name, address, city, latitude, longitude, apple_place_id, website_url, identity_key
    """

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchCafe(id: UUID) async throws -> SupabaseCafeSummary? {
        let cafes: [SupabaseCafeSummary] = try await client
            .from("cafes")
            .select(cafeColumns)
            .eq("id", value: id.uuidString)
            .execute()
            .value

        return cafes.first
    }

    func fetchCafes(ids: some Collection<UUID>) async throws -> [SupabaseCafeSummary] {
        let identifiers = Array(Set(ids))
        guard !identifiers.isEmpty else { return [] }

        return try await client
            .from("cafes")
            .select(cafeColumns)
            .in("id", values: identifiers.map(\.uuidString))
            .execute()
            .value
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

        if let applePlaceId = cafe.mapItemURL?.remoteTrimmedNonEmpty,
           let existingCafe = try await fetchCafe(applePlaceId: applePlaceId) {
            return existingCafe
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
        let cafes: [SupabaseCafeSummary] = try await client
            .from("cafes")
            .select(cafeColumns)
            .eq("identity_key", value: identityKey)
            .limit(1)
            .execute()
            .value
        return cafes.first
    }

    private func fetchCafe(applePlaceId: String) async throws -> SupabaseCafeSummary? {
        let cafes: [SupabaseCafeSummary] = try await client
            .from("cafes")
            .select(cafeColumns)
            .eq("apple_place_id", value: applePlaceId)
            .limit(1)
            .execute()
            .value

        return cafes.first
    }

    private func fetchCafe(name: String, address: String) async throws -> SupabaseCafeSummary? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return nil
        }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        var query = client
            .from("cafes")
            .select(cafeColumns)
            .eq("name", value: trimmedName)

        if !trimmedAddress.isEmpty {
            query = query.eq("address", value: trimmedAddress)
        }

        let cafes: [SupabaseCafeSummary] = try await query
            .limit(1)
            .execute()
            .value

        return cafes.first
    }
}

struct SupabaseCafeInsert: Encodable, Equatable {
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let applePlaceId: String?
    let websiteURL: String?
    let identityKey: String

    enum CodingKeys: String, CodingKey {
        case name
        case address
        case latitude
        case longitude
        case applePlaceId = "apple_place_id"
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
            websiteURL: cafe.websiteURL?.remoteTrimmedNonEmpty,
            identityKey: CafeIdentity.key(for: cafe)
        )
    }
}
