//
//  AuthService.swift
//  testMugshot
//

import Foundation
import Supabase

struct AuthenticatedUser: Equatable {
    let id: UUID
    let email: String?
}

struct SignUpResult: Equatable {
    let user: AuthenticatedUser?
    let requiresEmailConfirmation: Bool
}

final class AuthService {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func restoreSession() async throws -> AuthenticatedUser? {
        do {
            let session = try await client.auth.session
            return authenticatedUser(from: session.user)
        } catch {
            return nil
        }
    }
    
    func signIn(email: String, password: String) async throws -> AuthenticatedUser {
        let session = try await client.auth.signIn(email: email, password: password)
        return authenticatedUser(from: session.user)
    }
    
    func signUp(email: String, password: String) async throws -> SignUpResult {
        let response = try await client.auth.signUp(email: email, password: password)
        if let session = response.session {
            return SignUpResult(
                user: authenticatedUser(from: session.user),
                requiresEmailConfirmation: false
            )
        }
        
        return SignUpResult(
            user: authenticatedUser(from: response.user),
            requiresEmailConfirmation: true
        )
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthenticatedUser {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        return authenticatedUser(from: session.user)
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    private func authenticatedUser(from user: Supabase.User) -> AuthenticatedUser {
        AuthenticatedUser(id: user.id, email: user.email)
    }
}
