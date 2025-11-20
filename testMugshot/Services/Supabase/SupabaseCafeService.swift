//
//  SupabaseCafeService.swift
//  testMugshot
//

import Foundation
import CoreLocation

final class SupabaseCafeService {
    static let shared = SupabaseCafeService(client: SupabaseClientProvider.shared)
    
    private let client: SupabaseClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(client: SupabaseClient) {
        self.client = client
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    func fetchCafes(ids: [UUID]) async throws -> [RemoteCafe] {
        guard !ids.isEmpty else { return [] }
        let inClause = ids.map { $0.uuidString }.joined(separator: ",")
        let queryItems = [
            URLQueryItem(name: "id", value: "in.(\(inClause))"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        
        let (data, response) = try await client.request(
            path: "rest/v1/cafes",
            method: "GET",
            queryItems: queryItems
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        return try decoder.decode([RemoteCafe].self, from: data)
    }
    
    func findOrCreateCafe(from cafe: Cafe) async throws -> RemoteCafe {
        if let supabaseId = cafe.supabaseId,
           let existing = try await fetchCafe(by: "id", value: supabaseId.uuidString).first {
            return existing
        }
        
        if let applePlaceId = cafe.applePlaceId,
           let existing = try await fetchCafe(by: "apple_place_id", value: applePlaceId).first {
            return existing
        }
        
        if let city = cafe.city,
           let existing = try await fetchCafe(byName: cafe.name, city: city).first {
            return existing
        }
        
        return try await insertCafe(from: cafe)
    }
    
    private func fetchCafe(by column: String, value: String) async throws -> [RemoteCafe] {
        let queryItems = [
            URLQueryItem(name: column, value: "eq.\(value)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit", value: "1")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/cafes",
            method: "GET",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        return try decoder.decode([RemoteCafe].self, from: data)
    }
    
    private func fetchCafe(byName name: String, city: String) async throws -> [RemoteCafe] {
        let queryItems = [
            URLQueryItem(name: "name", value: "eq.\(name)"),
            URLQueryItem(name: "city", value: "eq.\(city)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit", value: "1")
        ]
        let (data, response) = try await client.request(
            path: "rest/v1/cafes",
            method: "GET",
            queryItems: queryItems
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
        return try decoder.decode([RemoteCafe].self, from: data)
    }
    
    private func insertCafe(from cafe: Cafe) async throws -> RemoteCafe {
        let payload = CafeInsertPayload(from: cafe)
        let body = try encoder.encode([payload])
        
        let (data, response) = try await client.request(
            path: "rest/v1/cafes",
            method: "POST",
            headers: ["Prefer": "return=representation,resolution=merge-duplicates"],
            body: body
        )
        
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(
                status: response.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let cafes = try decoder.decode([RemoteCafe].self, from: data)
        guard let saved = cafes.first else {
            throw SupabaseError.decoding("Cafe insert returned empty response.")
        }
        return saved
    }
}

private struct CafeInsertPayload: Encodable {
    let id: UUID
    let name: String
    let address: String?
    let city: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
    let applePlaceId: String?
    let websiteURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case city
        case country
        case latitude
        case longitude
        case applePlaceId = "apple_place_id"
        case websiteURL = "website_url"
    }
    
    init(from cafe: Cafe) {
        id = cafe.supabaseId ?? cafe.id
        name = cafe.name
        address = cafe.address.isEmpty ? nil : cafe.address
        city = cafe.city
        country = cafe.country
        latitude = cafe.location?.latitude
        longitude = cafe.location?.longitude
        applePlaceId = cafe.applePlaceId
        websiteURL = cafe.websiteURL
    }
}

