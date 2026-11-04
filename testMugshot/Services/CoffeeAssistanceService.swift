import CryptoKit
import Foundation
import Supabase

@MainActor
protocol CoffeeAssistanceTransport {
    func suggest(_ request: CoffeeAssistanceRequest) async throws -> CoffeeAssistanceResult
}

@MainActor
struct CoffeeAssistanceService: CoffeeAssistanceTransport {
    func suggest(_ request: CoffeeAssistanceRequest) async throws -> CoffeeAssistanceResult {
        let source = try SupabaseClientProvider.shared.client()
        guard source.auth.currentUser?.id == request.ownerID else { throw CoffeeAssistanceError.accountChanged }
        let session = try await source.auth.session
        try Task.checkCancellation()
        guard session.user.id == request.ownerID, source.auth.currentUser?.id == request.ownerID else {
            throw CoffeeAssistanceError.accountChanged
        }
        let config = try SupabaseConfiguration.load()
        let url = config.url.appendingPathComponent("functions/v1/coffee-assistance")
        var call = URLRequest(url: url)
        call.httpMethod = "POST"
        call.timeoutInterval = 25
        call.setValue("application/json", forHTTPHeaderField: "Content-Type")
        call.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        // Bind credentials before the network suspension, never inherit a new account.
        call.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        call.httpBody = try JSONEncoder().encode(request)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        let transport = URLSession(configuration: configuration)
        defer { transport.invalidateAndCancel() }
        let (data, response) = try await transport.data(for: call)
        try Task.checkCancellation()
        guard source.auth.currentUser?.id == request.ownerID else { throw CoffeeAssistanceError.accountChanged }
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 24_000 else {
            throw CoffeeAssistanceError.unavailable
        }
        let result = try JSONDecoder().decode(Envelope.self, from: data).result
        try result.validate(for: request)
        return result
    }
    private struct Envelope: Decodable { let result: CoffeeAssistanceResult }
}

/// Memory-only reuse: no prompts or results are written to disk or analytics.
@MainActor
final class CoffeeAssistanceCache {
    static let shared = CoffeeAssistanceCache()
    private var ownerID: UUID?
    private var values: [String: (Date, CoffeeAssistanceResult)] = [:]
    func key(for request: CoffeeAssistanceRequest) -> String {
        let stable = CoffeeAssistanceRequest(ownerID: request.ownerID,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000000")!,
            task: request.task, query: request.query, evidence: request.evidence, image: request.image)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return SHA256.hash(data: (try? encoder.encode(stable)) ?? Data()).map { String(format: "%02x", $0) }.joined()
    }
    func result(for request: CoffeeAssistanceRequest, now: Date = .now) -> CoffeeAssistanceResult? {
        activate(request.ownerID)
        guard let value = values[key(for: request)], now.timeIntervalSince(value.0) < 300 else { return nil }
        return value.1
    }
    func store(_ result: CoffeeAssistanceResult, for request: CoffeeAssistanceRequest, now: Date = .now) {
        activate(request.ownerID)
        if values.count >= 30 { values.removeAll() }
        values[key(for: request)] = (now, result)
    }
    func clear() { values.removeAll(); ownerID = nil }
    private func activate(_ id: UUID) {
        if ownerID != id { clear(); ownerID = id }
    }
}
