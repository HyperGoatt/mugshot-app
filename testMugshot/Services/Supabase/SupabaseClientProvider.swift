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
            supabaseKey: configuration.publishableKey
        )
        cachedClient = client
        return client
    }
}

