//
//  SupabaseAuthService.swift
//  testMugshot
//
//  Handles user authentication against Supabase GoTrue.
//

import Foundation

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String?
    let userId: String
}

private struct SupabaseAuthResponse: Codable {
    struct User: Codable {
        let id: String
        let email: String?
    }

    let accessToken: String
    let refreshToken: String?
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

final class SupabaseAuthService {
    static let shared = SupabaseAuthService(client: SupabaseClientProvider.shared)

    private let client: SupabaseClient
    private let sessionKey = "SupabaseSession"

    private init(client: SupabaseClient) {
        self.client = client
        if let session = loadSession() {
            client.accessToken = session.accessToken
        }
    }

    func restoreSession() -> SupabaseSession? {
        loadSession()
    }

    @discardableResult
    func signUp(email: String, password: String, displayName: String, username: String) async throws -> SupabaseSession {
        let payload: [String: Any] = [
            "email": email,
            "password": password,
            "data": [
                "display_name": displayName,
                "username": username
            ],
            "options": [
                "email_redirect_to": "https://mugshotapp.co/verify"
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await client.request(
            path: "auth/v1/signup",
            method: "POST",
            headers: [:],
            body: body
        )

        guard (200..<300).contains(response.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            // Parse error response for better error messages
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorData["error_description"] as? String ?? errorData["msg"] as? String {
                // Check for rate limit errors and convert to user-friendly error
                if response.statusCode == 429 || errorMsg.contains("over_email_send_rate_limit") {
                    throw MugshotError.userFriendly("Whoa there ☕️\nWe just sent you an email.\nTry again in a few seconds!")
                }
                throw SupabaseError.server(status: response.statusCode, message: errorMsg)
            }
            // Check for rate limit by status code
            if response.statusCode == 429 {
                throw MugshotError.userFriendly("Whoa there ☕️\nWe just sent you an email.\nTry again in a few seconds!")
            }
            throw SupabaseError.server(status: response.statusCode, message: errorMessage)
        }

        return try handleAuthResponse(data: data)
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> SupabaseSession {
        print("[SupabaseAuthService] signIn called for email: \(email)")
        let payload: [String: Any] = [
            "email": email,
            "password": password
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])

        print("[SupabaseAuthService] Sending sign-in request to auth/v1/token")
        let (data, response) = try await client.request(
            path: "auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            headers: [:],
            body: body
        )

        print("[SupabaseAuthService] Sign-in response status: \(response.statusCode)")
        guard (200..<300).contains(response.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            print("[SupabaseAuthService] Sign-in failed - status: \(response.statusCode), message: \(errorMessage ?? "unknown")")
            // Parse error response for better error messages
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorData["error_description"] as? String ?? errorData["msg"] as? String {
                throw SupabaseError.server(status: response.statusCode, message: errorMsg)
            }
            throw SupabaseError.server(status: response.statusCode, message: errorMessage)
        }

        let session = try handleAuthResponse(data: data)
        print("[SupabaseAuthService] Sign-in successful - userId: \(session.userId)")
        return session
    }

    /// Attempts to refresh the current session using the stored refresh token.
    /// Returns a new session if successful and persists it for future requests.
    @discardableResult
    func refreshSession() async throws -> SupabaseSession {
        print("[SupabaseAuthService] refreshSession: Attempting refresh")

        guard let storedSession = restoreSession(),
              let refreshToken = storedSession.refreshToken else {
            print("[SupabaseAuthService] refreshSession: No refresh token available")
            throw SupabaseError.invalidSession
        }

        let payload: [String: Any] = [
            "refresh_token": refreshToken
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await client.request(
            path: "auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            headers: [:],
            body: body
        )

        guard (200..<300).contains(response.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            print("[SupabaseAuthService] refreshSession: Failed - status: \(response.statusCode), message: \(errorMessage ?? "unknown")")
            clearSession()
            throw SupabaseError.server(status: response.statusCode, message: errorMessage)
        }

        let newSession = try handleAuthResponse(data: data)
        print("[SupabaseAuthService] refreshSession: Success - new access token stored")
        return newSession
    }

    func signOut() async {
        _ = try? await client.request(path: "auth/v1/logout", method: "POST")
        clearSession()
        client.accessToken = nil
    }
    
    func resendVerificationEmail(email: String) async throws {
        print("[Auth] resendVerificationEmail: Starting for email: \(email)")
        
        let payload: [String: Any] = [
            "email": email,
            "type": "signup",
            "options": [
                "email_redirect_to": "https://mugshotapp.co/verify"
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        // Try with authentication first if we have a session
        var useAuth = false
        if let session = restoreSession() {
            client.accessToken = session.accessToken
            useAuth = true
            print("[Auth] resendVerificationEmail: Using authenticated request - userId=\(session.userId)")
        } else {
            // Clear access token to use unauthenticated request
            client.accessToken = nil
            print("[Auth] resendVerificationEmail: Using unauthenticated request")
        }
        
        print("[Auth] resendVerificationEmail: Sending request to auth/v1/resend")
        let (data, response) = try await client.request(
            path: "auth/v1/resend",
            method: "POST",
            headers: [:],
            body: body
        )
        
        print("[Auth] resendVerificationEmail: Response status: \(response.statusCode)")
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Auth] resendVerificationEmail: Failed - status: \(response.statusCode), message: \(errorMessage)")

            // If we got 401 with auth, try to refresh and retry, then fall back to unauthenticated
            if response.statusCode == 401 && useAuth {
                print("[Auth] resendVerificationEmail: Got 401 with auth, attempting token refresh")
                do {
                    let refreshedSession = try await refreshSession()
                    client.accessToken = refreshedSession.accessToken
                    let (refreshData, refreshResponse) = try await client.request(
                        path: "auth/v1/resend",
                        method: "POST",
                        headers: [:],
                        body: body
                    )

                    if (200..<300).contains(refreshResponse.statusCode) {
                        print("[Auth] resendVerificationEmail: Success after refresh - verification email sent")
                        return
                    }

                    let refreshError = String(data: refreshData, encoding: .utf8) ?? "Unknown error"
                    print("[Auth] resendVerificationEmail: Refresh retry failed - status: \(refreshResponse.statusCode), message: \(refreshError)")
                } catch {
                    print("[Auth] resendVerificationEmail: Refresh failed, will retry unauthenticated")
                }

                print("[Auth] resendVerificationEmail: Retrying without auth")
                client.accessToken = nil
                let (retryData, retryResponse) = try await client.request(
                    path: "auth/v1/resend",
                    method: "POST",
                    headers: [:],
                    body: body
                )

                guard (200..<300).contains(retryResponse.statusCode) else {
                    let retryErrorMessage = String(data: retryData, encoding: .utf8) ?? "Unknown error"
                    print("[Auth] resendVerificationEmail: Retry also failed - status: \(retryResponse.statusCode), message: \(retryErrorMessage)")

                    // Parse error response for better error messages
                    if let errorData = try? JSONSerialization.jsonObject(with: retryData) as? [String: Any],
                       let errorMsg = errorData["error_description"] as? String ?? errorData["msg"] as? String {
                        if retryResponse.statusCode == 429 || errorMsg.contains("over_email_send_rate_limit") {
                            throw MugshotError.userFriendly("Whoa there ☕️\nWe just sent you an email.\nTry again in a few seconds!")
                        }
                        throw SupabaseError.server(status: retryResponse.statusCode, message: errorMsg)
                    }
                    if retryResponse.statusCode == 429 {
                        throw MugshotError.userFriendly("Whoa there ☕️\nWe just sent you an email.\nTry again in a few seconds!")
                    }
                    throw SupabaseError.server(status: retryResponse.statusCode, message: retryErrorMessage)
                }

                print("[Auth] resendVerificationEmail: Success on retry (unauthenticated) - verification email sent")
                return
            }

            // Parse error response for better error messages
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorData["error_description"] as? String ?? errorData["msg"] as? String {
                // Check for rate limit errors and convert to user-friendly error
                if response.statusCode == 429 || errorMsg.contains("over_email_send_rate_limit") {
                    throw MugshotError.userFriendly("Whoa there ☕️\nWe just sent you an email.\nTry again in a few seconds!")
                }
                throw SupabaseError.server(status: response.statusCode, message: errorMsg)
            }
            // Check for rate limit by status code
            if response.statusCode == 429 {
                throw MugshotError.userFriendly("Whoa there ☕️\nWe just sent you an email.\nTry again in a few seconds!")
            }
            throw SupabaseError.server(status: response.statusCode, message: errorMessage)
        }
        
        print("[Auth] resendVerificationEmail: Success - verification email sent")
    }
    
    func checkEmailVerificationStatus(userId: String) async throws -> Bool {
        // Fetch user info to check if email is confirmed
        print("[Auth] checkEmailVerificationStatus: Fetching user info for userId: \(userId)")
        let (data, response) = try await client.request(
            path: "auth/v1/user",
            method: "GET",
            headers: [:],
            body: nil
        )
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Auth] checkEmailVerificationStatus: Failed - status \(response.statusCode), message: \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }
        
        // Parse user response to check email_confirmed_at
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let emailConfirmedAt = json["email_confirmed_at"] {
                if let confirmedAtString = emailConfirmedAt as? String, !confirmedAtString.isEmpty {
                    print("[Auth] checkEmailVerificationStatus: Email is confirmed (email_confirmed_at=\(confirmedAtString))")
                    return true
                } else if emailConfirmedAt is NSNull {
                    print("[Auth] checkEmailVerificationStatus: Email not confirmed (email_confirmed_at is null)")
                }
            } else {
                print("[Auth] checkEmailVerificationStatus: email_confirmed_at key not found")
            }
        } else {
            print("[Auth] checkEmailVerificationStatus: Failed to parse JSON response")
        }
        
        return false
    }
    
    /// Fetches the current authenticated user from Supabase Auth
    func fetchCurrentUser() async throws -> [String: Any] {
        print("[Auth] fetchCurrentUser: Fetching current user from Supabase")
        
        // Ensure we have a valid session with access token
        guard var session = restoreSession() else {
            print("[Auth] fetchCurrentUser: No session found")
            throw SupabaseError.invalidSession
        }
        
        // Ensure client has the access token set
        client.accessToken = session.accessToken
        print("[Auth] fetchCurrentUser: Using session - userId=\(session.userId)")
        
        let (data, response) = try await client.request(
            path: "auth/v1/user",
            method: "GET",
            headers: [:],
            body: nil
        )
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Auth] fetchCurrentUser: Failed - status \(response.statusCode), message: \(errorMsg)")
            
            // If we get 401, the session might be expired
            if response.statusCode == 401 {
                print("[Auth] fetchCurrentUser: Session expired (401) - attempting refresh")
                do {
                    session = try await refreshSession()
                    client.accessToken = session.accessToken
                    let (retryData, retryResponse) = try await client.request(
                        path: "auth/v1/user",
                        method: "GET",
                        headers: [:],
                        body: nil
                    )

                    guard (200..<300).contains(retryResponse.statusCode) else {
                        let retryMsg = String(data: retryData, encoding: .utf8) ?? "Unknown error"
                        print("[Auth] fetchCurrentUser: Refresh retry failed - status \(retryResponse.statusCode), message: \(retryMsg)")
                        clearSession()
                        client.accessToken = nil
                        throw SupabaseError.invalidSession
                    }

                    return try parseUserResponse(retryData)
                } catch {
                    print("[Auth] fetchCurrentUser: Refresh failed - clearing session")
                    clearSession()
                    client.accessToken = nil
                    throw SupabaseError.invalidSession
                }
            }
            
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }
        
        return try parseUserResponse(data)
    }

    // MARK: - Private helpers

    private func handleAuthResponse(data: Data) throws -> SupabaseSession {
        let decoder = JSONDecoder()
        let response = try decoder.decode(SupabaseAuthResponse.self, from: data)
        let session = SupabaseSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            userId: response.user.id
        )
        store(session: session)
        client.accessToken = session.accessToken
        return session
    }

    private func parseUserResponse(_ data: Data) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[Auth] fetchCurrentUser: Failed to parse JSON response")
            throw SupabaseError.decoding("Invalid user response format")
        }

        let userId = json["id"] as? String ?? "nil"
        let email = json["email"] as? String ?? "nil"
        let emailConfirmedAt = json["email_confirmed_at"]
        print("[Auth] fetchCurrentUser: Success - userId=\(userId), email=\(email), email_confirmed_at=\(String(describing: emailConfirmedAt))")
        return json
    }

    private func store(session: SupabaseSession) {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }

    private func loadSession() -> SupabaseSession? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}


