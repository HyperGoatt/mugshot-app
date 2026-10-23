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
}
