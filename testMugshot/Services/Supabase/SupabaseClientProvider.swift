//
//  SupabaseClientProvider.swift
//  testMugshot
//
//  Lightweight container that exposes a configured Supabase client to the app.
//

import Foundation

enum SupabaseError: Error, LocalizedError {
    case network(String)
    case decoding(String)
    case server(status: Int, message: String?)
    case invalidSession

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return message
        case .decoding(let message):
            return "Failed to decode Supabase response: \(message)"
        case .server(let status, let message):
            return message ?? "Supabase server error (\(status))"
        case .invalidSession:
            return "Missing Supabase session"
        }
    }
}

/// Minimal HTTP-based Supabase client used by our services.
final class SupabaseClient {
    let baseURL: URL
    let anonKey: String

    /// Access token for the currently authenticated user (if any).
    var accessToken: String?

    init(baseURL: URL = SupabaseConfig.url, anonKey: String = SupabaseConfig.anonKey) {
        self.baseURL = baseURL
        self.anonKey = anonKey
    }

    /// Performs an HTTP request against the Supabase project.
    @discardableResult
    func request(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        headers extraHeaders: [String: String] = [:],
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard var urlComponents = URLComponents(
            url: URL(string: path, relativeTo: baseURL) ?? baseURL,
            resolvingAgainstBaseURL: true
        ) else {
            throw SupabaseError.network("Invalid URL for path \(path)")
        }

        if let queryItems = queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw SupabaseError.network("Unable to compose URL for \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        // Common headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil && request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken ?? anonKey)", forHTTPHeaderField: "Authorization")

        // Custom headers (can override the defaults)
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.network("Invalid HTTP response")
        }
        return (data, httpResponse)
    }
}

/// Shared provider for dependency injection. Views/services should depend on this rather than
/// hard-coding Supabase credentials.
enum SupabaseClientProvider {
    static let shared = SupabaseClient()
}

/// Environment container so SwiftUI views (or coordinators) can access Supabase config without
/// recreating clients.
final class SupabaseEnvironment: ObservableObject {
    let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }
}

