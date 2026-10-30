//
//  SupabaseClientProvider.swift
//  testMugshot
//

import Foundation
import Supabase

final class SupabaseClientProvider {
    static let shared = SupabaseClientProvider()
    
    private var cachedClient: SupabaseClient?
    
    func client() throws -> SupabaseClient {
        if let cachedClient {
            return cachedClient
        }
        
        let configuration = try SupabaseConfiguration.load()
        let client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true),
                global: .init(session: URLSession(configuration: Self.requestConfiguration()))
            )
        )
        cachedClient = client
        return client
    }

    static func requestConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        configuration.waitsForConnectivity = false
        return configuration
    }

    /// The SDK normally reads whichever account is current at request time.
    /// Publication must never inherit a later account's token after an await.
    func publicationClient(userID: UUID) async throws -> SupabaseClient {
        let source = try client()
        try Task.checkCancellation()
        guard source.auth.currentUser?.id == userID else {
            throw AutomaticSipRecoveryError.accountMismatch
        }
        let session = try await source.auth.session
        guard session.user.id == userID, source.auth.currentUser?.id == userID else {
            throw AutomaticSipRecoveryError.accountMismatch
        }
        let configuration = try SupabaseConfiguration.load()
        return Self.makePublicationClient(
            configuration: configuration, source: source, userID: userID,
            session: URLSession(configuration: Self.requestConfiguration())
        )
    }

    static func makePublicationClient(
        configuration: SupabaseConfiguration,
        source: SupabaseClient,
        userID: UUID,
        session: URLSession
    ) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: .init(
                auth: .init(accessToken: {
                    try Task.checkCancellation()
                    guard source.auth.currentUser?.id == userID else {
                        throw AutomaticSipRecoveryError.accountMismatch
                    }
                    let session = try await source.auth.session
                    try Task.checkCancellation()
                    guard session.user.id == userID,
                          source.auth.currentUser?.id == userID else {
                        throw AutomaticSipRecoveryError.accountMismatch
                    }
                    return session.accessToken
                }),
                // supabase-swift 2.54 swallows access-token provider errors.
                // Fail closed with an invalid credential, never an anonymous
                // fallback or the newly signed-in account's credential.
                global: .init(
                    headers: ["Authorization": "Bearer mugshot-invalid-publication-session"],
                    session: session
                )
            )
        )
    }
}
