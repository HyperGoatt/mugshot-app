//
//  AuthService.swift
//  testMugshot
//

import Foundation
import Supabase

enum MugshotAuthProvider: String, CaseIterable, Hashable {
    case email
    case apple
    case google
}

struct AuthenticatedUser: Equatable {
    let id: UUID
    let email: String?
    let providers: Set<MugshotAuthProvider>
    let preferredDisplayName: String?

    init(
        id: UUID,
        email: String?,
        providers: Set<MugshotAuthProvider> = [],
        preferredDisplayName: String? = nil
    ) {
        self.id = id
        self.email = email
        self.providers = providers
        self.preferredDisplayName = preferredDisplayName
    }

    /// Accounts restored from older sessions may not expose identity metadata.
    /// Preserve the pre-provider-aware deletion choices only for that legacy
    /// state; known OAuth-only accounts must never be asked for a password.
    var canVerifyWithPassword: Bool {
        providers.contains(.email) || (providers.isEmpty && email != nil)
    }

    var canVerifyWithApple: Bool {
        providers.contains(.apple) || providers.isEmpty
    }

    var canVerifyWithGoogle: Bool {
        providers.contains(.google)
    }
}

struct SignUpResult: Equatable {
    let user: AuthenticatedUser?
    let requiresEmailConfirmation: Bool
}

enum TransientSessionAccountResolver {
    static func accountToPreserve(
        cachedUser: AuthenticatedUser?,
        establishedUser: AuthenticatedUser?
    ) -> AuthenticatedUser? {
        cachedUser ?? establishedUser
    }
}

final class AuthService {
    static let callbackURL = URL(string: "mugshot://auth/callback")!
    static let passwordRecoveryURL = URL(string: "mugshot://auth/recovery")!

    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }

    var currentUserID: UUID? {
        client.auth.currentUser?.id
    }

    /// Supabase keeps the last decoded session user in memory even when an
    /// expired token cannot be refreshed. That cached identity is sufficient
    /// to preserve the matching on-device account scope while the app exposes
    /// a retry state; it is not treated as proof of a valid server session.
    var cachedAuthenticatedUser: AuthenticatedUser? {
        client.auth.currentUser.map { authenticatedUser(from: $0) }
    }
    
    func restoreSession() async throws -> AuthenticatedUser? {
        do {
            let session = try await client.auth.session
            return authenticatedUser(from: session.user)
        } catch let error as AuthError where error == .sessionMissing {
            return nil
        }
    }
    
    func signIn(email: String, password: String) async throws -> AuthenticatedUser {
        let session = try await client.auth.signIn(
            email: email.normalizedAuthEmail,
            password: password
        )
        return authenticatedUser(from: session.user)
    }

    /// Creates a new Auth session for the account-deletion challenge without
    /// bootstrapping profile or guest state. The server verifies that its
    /// session and AMR evidence are newer than the challenge.
    func createFreshAccountDeletionSession(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        try await signIn(email: email, password: password)
    }
    
    func signUp(email: String, password: String) async throws -> SignUpResult {
        let response = try await client.auth.signUp(
            email: email.normalizedAuthEmail,
            password: password,
            redirectTo: Self.callbackURL
        )
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

    func signInWithApple(
        idToken: String,
        nonce: String,
        preferredDisplayName: String? = nil
    ) async throws -> AuthenticatedUser {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        let restoredUser = authenticatedUser(from: session.user)
        return AuthenticatedUser(
            id: restoredUser.id,
            email: restoredUser.email,
            providers: restoredUser.providers,
            preferredDisplayName: preferredDisplayName?.trimmedAuthValue
                ?? restoredUser.preferredDisplayName
        )
    }

    func signInWithGoogle() async throws -> AuthenticatedUser {
        let session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: Self.callbackURL,
            scopes: "openid email profile",
            configure: { _ in }
        )
        return authenticatedUser(from: session.user)
    }

    func createFreshAccountDeletionSessionWithApple(
        idToken: String,
        nonce: String
    ) async throws -> AuthenticatedUser {
        try await signInWithApple(idToken: idToken, nonce: nonce)
    }

    func createFreshAccountDeletionSessionWithGoogle() async throws -> AuthenticatedUser {
        try await signInWithGoogle()
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }

    @discardableResult
    func discardCurrentLocalSession() async -> Bool {
        try? await client.auth.signOut(scope: .local)
        return currentUserID == nil
    }

    func requestPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: Self.passwordRecoveryURL
        )
    }

    func resendSignupConfirmation(email: String) async throws {
        try await client.auth.resend(
            email: email,
            type: .signup,
            emailRedirectTo: Self.callbackURL
        )
    }

    func restoreSession(from callbackURL: URL) async throws -> AuthenticatedUser {
        let session = try await client.auth.session(from: callbackURL)
        return authenticatedUser(from: session.user)
    }

    func updatePassword(_ password: String) async throws {
        try await client.auth.update(user: UserAttributes(password: password))
    }
    
    private func authenticatedUser(from user: Supabase.User) -> AuthenticatedUser {
        var providers = Set(
            (user.identities ?? []).compactMap {
                MugshotAuthProvider(rawValue: $0.provider.lowercased())
            }
        )

        if providers.isEmpty {
            if let provider = user.appMetadata["provider"]?.stringValue,
               let recognized = MugshotAuthProvider(rawValue: provider.lowercased()) {
                providers.insert(recognized)
            }
            for rawProvider in user.appMetadata["providers"]?.arrayValue ?? [] {
                guard let value = rawProvider.stringValue,
                      let recognized = MugshotAuthProvider(rawValue: value.lowercased()) else {
                    continue
                }
                providers.insert(recognized)
            }
        }

        let preferredDisplayName = ["full_name", "name"]
            .compactMap { user.userMetadata[$0]?.stringValue?.trimmedAuthValue }
            .first

        return AuthenticatedUser(
            id: user.id,
            email: user.email,
            providers: providers,
            preferredDisplayName: preferredDisplayName
        )
    }
}

private extension String {
    var normalizedAuthEmail: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var trimmedAuthValue: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

enum MugshotAuthCallbackRoute: Equatable {
    case confirmation
    case passwordRecovery

    static func resolve(_ url: URL) -> Self? {
        guard url.scheme?.lowercased() == "mugshot",
              url.host?.lowercased() == "auth" else {
            return nil
        }

        switch url.path.lowercased() {
        case "/callback":
            return .confirmation
        case "/recovery":
            return .passwordRecovery
        default:
            return nil
        }
    }
}
