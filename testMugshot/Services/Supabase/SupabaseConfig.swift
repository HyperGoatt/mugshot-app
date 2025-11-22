//
//  SupabaseConfig.swift
//  testMugshot
//
//  Central place to read Supabase credentials from Info.plist.
//

import Foundation

enum SupabaseConfig {
    private static let urlPlistKey = "SUPABASE_URL"
    private static let anonKeyPlistKey = "SUPABASE_ANON_KEY"

    static var url: URL {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: urlPlistKey) as? String,
            let url = URL(string: urlString)
        else {
            let info = Bundle.main.infoDictionary ?? [:]
            let keys = Array(info.keys).sorted()
            fatalError("SupabaseConfig: Missing or invalid \(urlPlistKey) in Info.plist. Info keys: \(keys)")
        }
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: anonKeyPlistKey) as? String else {
            let info = Bundle.main.infoDictionary ?? [:]
            let keys = Array(info.keys).sorted()
            fatalError("SupabaseConfig: Missing \(anonKeyPlistKey) in Info.plist. Info keys: \(keys)")
        }
        return key
    }

    /// Convenience helper to log a redacted view of the Supabase configuration for debugging.
    static func logConfigurationIfAvailable() {
        let urlDescription: String
        if let urlString = Bundle.main.object(forInfoDictionaryKey: urlPlistKey) as? String {
            urlDescription = urlString
        } else {
            urlDescription = "<missing>"
        }

        let anonKeyDescription: String
        if let key = Bundle.main.object(forInfoDictionaryKey: anonKeyPlistKey) as? String {
            let prefix = String(key.prefix(6))
            anonKeyDescription = "\(prefix)… (length: \(key.count))"
        } else {
            anonKeyDescription = "<missing>"
        }

        print("[SupabaseConfig] URL=\(urlDescription), anonKey=\(anonKeyDescription)")
    }

    /// Debug helper to inspect the raw Info.plist contents at runtime.
    static func debugPrintConfig() {
        let info = Bundle.main.infoDictionary ?? [:]
        let keys = Array(info.keys).sorted()
        print("[SupabaseConfig] Keys:", keys)
        print("[SupabaseConfig] SUPABASE_URL =", info["SUPABASE_URL"] ?? "nil")
        print("[SupabaseConfig] SUPABASE_ANON_KEY =", info["SUPABASE_ANON_KEY"] ?? "nil")
    }
}


