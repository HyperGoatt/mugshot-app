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

    let accessToken: String?
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
            print("[SupabaseAuthService] Init: Loaded existing session for userId: \(session.userId)")
            client.accessToken = session.accessToken
        } else {
            print("[SupabaseAuthService] Init: No existing session found")
        }
    }

    func restoreSession() -> SupabaseSession? {
        guard let session = loadSession() else { return nil }
        
        // Basic validation - ensure token is not empty
        guard !session.accessToken.isEmpty else {
            print("[SupabaseAuthService] restoreSession: Found session with empty token - clearing")
            clearSession()
            return nil
        }
        
        return session
    }

    @discardableResult
    func signUp(email: String, password: String, displayName: String, username: String) async throws -> (session: SupabaseSession?, userId: String) {
        print("[SupabaseAuthService] signUp: Starting for email=\(email)")
        
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

        print("[SupabaseAuthService] signUp: Response status=\(response.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
             // Log truncated body to avoid leaking sensitive info if any, 
             // though signup response usually just has user/metadata
             print("[SupabaseAuthService] signUp: Response body prefix: \(responseString.prefix(500))")
        }

        guard (200..<300).contains(response.statusCode) else {
            handleErrorResponse(data: data, response: response)
            throw SupabaseError.server(status: response.statusCode, message: "Unknown error") // Fallback
        }

        let result = try parseAuthResponse(data: data)
        if result.session != nil {
            print("[SupabaseAuthService] signUp: Success - Session created for userId=\(result.userId)")
        } else {
            print("[SupabaseAuthService] signUp: Success - User created (userId=\(result.userId)), awaiting verification (no session)")
        }
        
        return result
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> SupabaseSession {
        print("[SupabaseAuthService] signIn: Starting for email=\(email)")
        let payload: [String: Any] = [
            "email": email,
            "password": password
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await client.request(
            path: "auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            headers: [:],
            body: body
        )

        print("[SupabaseAuthService] signIn: Response status=\(response.statusCode)")

        guard (200..<300).contains(response.statusCode) else {
            handleErrorResponse(data: data, response: response)
            throw SupabaseError.server(status: response.statusCode, message: "Unknown error")
        }

        let result = try parseAuthResponse(data: data)
        guard let session = result.session else {
            print("[SupabaseAuthService] signIn: Error - Successful response but no access token found")
            throw SupabaseError.server(status: 200, message: "No access token returned")
        }
        
        print("[SupabaseAuthService] signIn: Success - userId: \(session.userId)")
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
            print("[SupabaseAuthService] refreshSession: Failed - status: \(response.statusCode)")
            // If refresh fails (e.g. token expired/revoked), clear the session
            clearSession()
            handleErrorResponse(data: data, response: response)
            throw SupabaseError.server(status: response.statusCode, message: "Refresh failed")
        }

        let result = try parseAuthResponse(data: data)
        guard let newSession = result.session else {
             throw SupabaseError.server(status: 200, message: "No access token returned from refresh")
        }
        
        print("[SupabaseAuthService] refreshSession: Success - new access token stored")
        return newSession
    }

    func signOut() async {
        print("[SupabaseAuthService] signOut: Clearing session")
        // Try to call logout endpoint, but don't fail if it errors
        if let session = restoreSession() {
            client.accessToken = session.accessToken
             _ = try? await client.request(path: "auth/v1/logout", method: "POST")
        }
        
        clearSession()
        client.accessToken = nil
    }
    
    func resendVerificationEmail(email: String) async throws {
        print("[SupabaseAuthService] resendVerificationEmail: Starting for email: \(email)")
        
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
            print("[SupabaseAuthService] resendVerificationEmail: Using authenticated request - userId=\(session.userId)")
        } else {
            // Clear access token to use unauthenticated request
            client.accessToken = nil
            print("[SupabaseAuthService] resendVerificationEmail: Using unauthenticated request")
        }
        
        let (data, response) = try await client.request(
            path: "auth/v1/resend",
            method: "POST",
            headers: [:],
            body: body
        )
        
        print("[SupabaseAuthService] resendVerificationEmail: Response status: \(response.statusCode)")
        
        guard (200..<300).contains(response.statusCode) else {
            // If we got 401 with auth, try to refresh and retry, then fall back to unauthenticated
            if response.statusCode == 401 && useAuth {
                print("[SupabaseAuthService] resendVerificationEmail: Got 401 with auth, attempting token refresh")
                do {
                    let refreshedSession = try await refreshSession()
                    client.accessToken = refreshedSession.accessToken
                    let (_, refreshResponse) = try await client.request(
                        path: "auth/v1/resend",
                        method: "POST",
                        headers: [:],
                        body: body
                    )

                    if (200..<300).contains(refreshResponse.statusCode) {
                        print("[SupabaseAuthService] resendVerificationEmail: Success after refresh")
                        return
                    }
                } catch {
                    print("[SupabaseAuthService] resendVerificationEmail: Refresh failed, will retry unauthenticated")
                }

                print("[SupabaseAuthService] resendVerificationEmail: Retrying without auth")
                client.accessToken = nil
                let (retryData, retryResponse) = try await client.request(
                    path: "auth/v1/resend",
                    method: "POST",
                    headers: [:],
                    body: body
                )

                guard (200..<300).contains(retryResponse.statusCode) else {
                    handleErrorResponse(data: retryData, response: retryResponse)
                    throw SupabaseError.server(status: retryResponse.statusCode, message: "Retry failed")
                }
                
                print("[SupabaseAuthService] resendVerificationEmail: Success on retry (unauthenticated)")
                return
            }

            handleErrorResponse(data: data, response: response)
            throw SupabaseError.server(status: response.statusCode, message: "Failed")
        }
        
        print("[SupabaseAuthService] resendVerificationEmail: Success")
    }
    
    func checkEmailVerificationStatus(userId: String) async throws -> Bool {
        print("[SupabaseAuthService] checkEmailVerificationStatus: Fetching user info for userId: \(userId)")
        
        // IMPORTANT: This often requires a valid session/token if RLS is strict,
        // OR it relies on the user already being logged in. 
        // If we don't have a session, we can't easily check auth.users unless we have a specialized endpoint 
        // or we try to refresh.
        
        // If we have a session, ensure client uses it
        if let session = restoreSession() {
            client.accessToken = session.accessToken
        }
        
        // Using auth/v1/user endpoint (requires valid access token)
        let (data, response) = try await client.request(
            path: "auth/v1/user",
            method: "GET",
            headers: [:],
            body: nil
        )
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[SupabaseAuthService] checkEmailVerificationStatus: Failed - status \(response.statusCode), message: \(errorMsg)")
            throw SupabaseError.server(status: response.statusCode, message: errorMsg)
        }
        
        // Parse user response to check email_confirmed_at
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let emailConfirmedAt = json["email_confirmed_at"] {
                if let confirmedAtString = emailConfirmedAt as? String, !confirmedAtString.isEmpty {
                    print("[SupabaseAuthService] checkEmailVerificationStatus: Email is confirmed (email_confirmed_at=\(confirmedAtString))")
                    return true
                } else {
                    print("[SupabaseAuthService] checkEmailVerificationStatus: Email not confirmed (email_confirmed_at is null/empty)")
                }
            } else {
                print("[SupabaseAuthService] checkEmailVerificationStatus: email_confirmed_at key not found")
            }
        }
        
        return false
    }
    
    /// Fetches the current authenticated user from Supabase Auth
    func fetchCurrentUser() async throws -> [String: Any] {
        print("[SupabaseAuthService] fetchCurrentUser: Fetching from Supabase")
        
        guard var session = restoreSession() else {
            print("[SupabaseAuthService] fetchCurrentUser: No session found")
            throw SupabaseError.invalidSession
        }
        
        client.accessToken = session.accessToken
        
        let (data, response) = try await client.request(
            path: "auth/v1/user",
            method: "GET",
            headers: [:],
            body: nil
        )
        
        guard (200..<300).contains(response.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[SupabaseAuthService] fetchCurrentUser: Failed - status \(response.statusCode)")
            
            // Check if error indicates expired token (401 or 403 with "expired" in message)
            let isExpiredToken = response.statusCode == 401 || 
                                (response.statusCode == 403 && errorMsg.localizedCaseInsensitiveContains("expired"))
            
            if isExpiredToken {
                print("[SupabaseAuthService] fetchCurrentUser: Token expired (\(response.statusCode)) - attempting refresh")
                do {
                    session = try await refreshSession()
                    client.accessToken = session.accessToken
                    print("[SupabaseAuthService] fetchCurrentUser: Session refreshed, retrying request")
                    
                    let (retryData, retryResponse) = try await client.request(
                        path: "auth/v1/user",
                        method: "GET",
                        headers: [:],
                        body: nil
                    )

                    guard (200..<300).contains(retryResponse.statusCode) else {
                        let retryErrorMsg = String(data: retryData, encoding: .utf8) ?? "Unknown error"
                        print("[SupabaseAuthService] fetchCurrentUser: Refresh retry failed - status \(retryResponse.statusCode), message: \(retryErrorMsg)")
                        clearSession()
                        client.accessToken = nil
                        throw SupabaseError.invalidSession
                    }

                    print("[SupabaseAuthService] fetchCurrentUser: Refresh retry succeeded")
                    return try parseUserResponse(retryData)
                } catch {
                    print("[SupabaseAuthService] fetchCurrentUser: Refresh failed - \(error.localizedDescription). Clearing session.")
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

    private func handleErrorResponse(data: Data, response: HTTPURLResponse) {
        // Helper to parse and print error
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        
        // Parse error response for better debugging
        if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let errorMsg = errorData["error_description"] as? String ?? errorData["msg"] as? String ?? errorMessage
            print("[SupabaseAuthService] Error: \(errorMsg) (Status: \(response.statusCode))")
        } else {
            print("[SupabaseAuthService] Error: \(errorMessage) (Status: \(response.statusCode))")
        }
    }

    private func parseAuthResponse(data: Data) throws -> (session: SupabaseSession?, userId: String) {
        let decoder = JSONDecoder()
        let response = try decoder.decode(SupabaseAuthResponse.self, from: data)
        
        if let accessToken = response.accessToken, !accessToken.isEmpty {
            let session = SupabaseSession(
                accessToken: accessToken,
                refreshToken: response.refreshToken,
                userId: response.user.id
            )
            store(session: session)
            client.accessToken = session.accessToken
            return (session, response.user.id)
        } else {
            // User created but no session (likely needs email verification)
            return (nil, response.user.id)
        }
    }

    private func parseUserResponse(_ data: Data) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[SupabaseAuthService] parseUserResponse: Failed to parse JSON")
            throw SupabaseError.decoding("Invalid user response format")
        }

        let userId = json["id"] as? String ?? "nil"
        let email = json["email"] as? String ?? "nil"
        let emailConfirmedAt = json["email_confirmed_at"]
        
        // Log available keys to help debug
        print("[SupabaseAuthService] parseUserResponse: Keys found: \(json.keys.joined(separator: ", "))")
        if let metadata = json["user_metadata"] as? [String: Any] {
            print("[SupabaseAuthService] parseUserResponse: user_metadata found: \(metadata)")
        }
        
        print("[SupabaseAuthService] parseUserResponse: Success - userId=\(userId), email=\(email), confirmed=\(String(describing: emailConfirmedAt))")
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
