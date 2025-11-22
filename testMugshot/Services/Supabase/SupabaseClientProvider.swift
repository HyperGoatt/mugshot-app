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
    
    /// User-friendly error message for display in UI
    var userFriendlyDescription: String {
        switch self {
        case .invalidSession:
            return "Your session has expired. Please sign in again."
        case .server(let status, let message):
            if status == 401 {
                return "You're not signed in. Please sign in and try again."
            } else if status == 403 {
                return "You don't have permission to perform this action."
            } else if status == 400 {
                // Try to extract a helpful message from the error
                if let msg = message, msg.contains("foreign key") || msg.contains("user_id") {
                    return "There was an issue with your account. Please try signing out and back in."
                } else if let msg = message, msg.contains("violates") || msg.contains("constraint") {
                    return "Invalid data. Please check your inputs and try again."
                }
                return "Invalid data. Please check your inputs and try again."
            } else if status == 422 {
                return "Invalid data format. Please check your inputs and try again."
            } else if status >= 500 {
                return "Our servers are having issues. Please try again in a moment."
            }
            return message ?? "Something went wrong. Please try again."
        case .network(let message):
            if message.contains("timed out") || message.contains("timeout") {
                return "Request timed out. Please check your connection and try again."
            }
            return "Network error. Please check your connection and try again."
        case .decoding(_):
            return "We received an unexpected response. Please try again."
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

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.network("Invalid HTTP response")
            }
            return (data, httpResponse)
        } catch let urlError as URLError {
            // Handle SSL errors specifically
            if urlError.code == .secureConnectionFailed || urlError.code == .serverCertificateUntrusted {
                print("[SupabaseClient] SSL Error: \(urlError.localizedDescription)")
                print("[SupabaseClient] Error code: \(urlError.code.rawValue)")
                // Check for underlying error in userInfo
                if let underlyingError = urlError.userInfo[NSUnderlyingErrorKey] as? Error {
                    print("[SupabaseClient] Underlying error: \(underlyingError)")
                }
                throw SupabaseError.network("SSL connection failed. Please check your network connection and try again. If this persists, try restarting the app or simulator.")
            }
            // Handle other network errors
            throw SupabaseError.network(urlError.localizedDescription)
        } catch {
            // Re-throw as network error
            throw SupabaseError.network("Network request failed: \(error.localizedDescription)")
        }
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

