//
//  SupabaseConfiguration.swift
//  testMugshot
//

import Foundation

struct SupabaseConfiguration {
    let url: URL
    let publishableKey: String
    
    static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> SupabaseConfiguration {
        let urlString = firstUsableValue(
            environment["MUGSHOT_SUPABASE_URL"],
            bundle.object(forInfoDictionaryKey: "MUGSHOT_SUPABASE_URL") as? String
        )
        let keyString = firstUsableValue(
            environment["MUGSHOT_SUPABASE_PUBLISHABLE_KEY"],
            bundle.object(forInfoDictionaryKey: "MUGSHOT_SUPABASE_PUBLISHABLE_KEY") as? String
        )
        
        guard let urlString else {
            throw SupabaseConfigurationError.missingURL
        }
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else {
            throw SupabaseConfigurationError.invalidURL
        }
        guard let keyString else {
            throw SupabaseConfigurationError.missingPublishableKey
        }
        
        let loweredKey = keyString.lowercased()
        if loweredKey.hasPrefix("sb_secret_") || loweredKey.contains("service_role") {
            throw SupabaseConfigurationError.secretKeyRejected
        }
        
        return SupabaseConfiguration(url: url, publishableKey: keyString)
    }
    
    private static func firstUsableValue(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { value in
                !value.isEmpty &&
                !value.contains("REPLACE_ME") &&
                !value.contains("YOUR_PROJECT_REF") &&
                !value.contains("$(")
            }
    }
}

enum SupabaseConfigurationError: LocalizedError, Equatable {
    case missingURL
    case invalidURL
    case missingPublishableKey
    case secretKeyRejected
    
    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "Supabase URL is not configured."
        case .invalidURL:
            return "Supabase URL is invalid."
        case .missingPublishableKey:
            return "Supabase publishable key is not configured."
        case .secretKeyRejected:
            return "A secret or service-role Supabase key cannot be used in the iOS app."
        }
    }
}

