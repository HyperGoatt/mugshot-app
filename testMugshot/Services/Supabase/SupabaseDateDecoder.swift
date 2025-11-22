//
//  SupabaseDateDecoder.swift
//  testMugshot
//
//  Shared JSON decoder for Supabase responses with tolerant date parsing.
//  Handles Postgres-style timestamps and ISO8601 variants.
//

import Foundation

/// Shared JSON decoder for Supabase responses that handles various date formats.
/// 
/// Supabase/Postgres returns timestamps in formats like:
/// - "2025-11-19 15:59:43.65175+00" (Postgres style)
/// - "2025-11-19T15:59:43.65175+00:00" (ISO8601 with fractional seconds)
/// - "2025-11-19T15:59:43+00:00" (ISO8601 without fractional seconds)
///
/// This decoder tries multiple formats to ensure robust parsing.
enum SupabaseDateDecoder {
    static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            #if DEBUG
            // Log date strings being decoded for debugging (only in debug builds)
            print("🔍 [SupabaseDateDecoder] Attempting to decode date: \(dateString)")
            #endif
            
            // Try multiple date formats in order of likelihood
            
            // 1. Postgres timestamp format: "yyyy-MM-dd HH:mm:ss.SSSSS+XX" or "yyyy-MM-dd HH:mm:ss.SSSSS+XX:XX"
            // Examples: "2025-11-19 15:59:43.65175+00" or "2025-11-19 15:59:43.65175+00:00"
            // Note: Postgres often returns "+00" (2 chars) or "+00:00" (5 chars) for timezone
            let postgresFormats = [
                "yyyy-MM-dd HH:mm:ss.SSSSSXXXXX",  // 6-digit fractional seconds with timezone (+00:00)
                "yyyy-MM-dd HH:mm:ss.SSSSSXXXX",   // 6-digit fractional seconds with short timezone (+00)
                "yyyy-MM-dd HH:mm:ss.SSSSS",       // 6-digit fractional seconds without timezone
                "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX", // 6-digit fractional seconds (alternative) with timezone
                "yyyy-MM-dd HH:mm:ss.SSSSSSXXXX",  // 6-digit fractional seconds (alternative) with short timezone
                "yyyy-MM-dd HH:mm:ss.SSSSSS",      // 6-digit fractional seconds (alternative) without timezone
                "yyyy-MM-dd HH:mm:ss.SSSXXXXX",    // 3-digit fractional seconds with timezone
                "yyyy-MM-dd HH:mm:ss.SSSXXXX",     // 3-digit fractional seconds with short timezone
                "yyyy-MM-dd HH:mm:ss.SSS",         // 3-digit fractional seconds without timezone
                "yyyy-MM-dd HH:mm:ssXXXXX",        // No fractional seconds with timezone (+00:00)
                "yyyy-MM-dd HH:mm:ssXXXX",         // No fractional seconds with short timezone (+00)
                "yyyy-MM-dd HH:mm:ss"              // No fractional seconds, no timezone
            ]
            
            let posixLocale = Locale(identifier: "en_US_POSIX")
            for format in postgresFormats {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = posixLocale
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = formatter.date(from: dateString) {
                    #if DEBUG
                    print("✅ [SupabaseDateDecoder] Parsed with Postgres format '\(format)': \(dateString)")
                    #endif
                    return date
                }
            }
            
            // 2. ISO8601DateFormatter with fractional seconds (iOS 11+)
            if #available(iOS 11.0, *) {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    #if DEBUG
                    print("✅ [SupabaseDateDecoder] Parsed with ISO8601DateFormatter (fractional): \(dateString)")
                    #endif
                    return date
                }
            }
            
            // 3. ISO8601DateFormatter without fractional seconds
            let standardISOFormatter = ISO8601DateFormatter()
            standardISOFormatter.formatOptions = [.withInternetDateTime]
            if let date = standardISOFormatter.date(from: dateString) {
                #if DEBUG
                print("✅ [SupabaseDateDecoder] Parsed with ISO8601DateFormatter (standard): \(dateString)")
                #endif
                return date
            }
            
            // 4. ISO8601-like formats with 'T' separator
            let isoFormats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",  // 6-digit fractional seconds with timezone
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSZZZZZ",    // 5-digit fractional seconds
                "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",      // 3-digit fractional seconds
                "yyyy-MM-dd'T'HH:mm:ssZZZZZ",         // No fractional seconds
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",     // 6-digit fractional seconds with Z
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",       // 3-digit fractional seconds with Z
                "yyyy-MM-dd'T'HH:mm:ss'Z'"            // No fractional seconds with Z
            ]
            
            for format in isoFormats {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = posixLocale
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = formatter.date(from: dateString) {
                    #if DEBUG
                    print("✅ [SupabaseDateDecoder] Parsed with ISO format '\(format)': \(dateString)")
                    #endif
                    return date
                }
            }
            
            // If all formats fail, log error and throw
            #if DEBUG
            print("❌ [SupabaseDateDecoder] Failed to parse date string: \(dateString)")
            print("❌ [SupabaseDateDecoder] Date string length: \(dateString.count)")
            #endif
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: '\(dateString)'. Expected Postgres timestamp or ISO8601 format."
            )
        }
        return decoder
    }()
}

#if DEBUG
/// Test function to verify date parsing works with sample formats.
/// Call this from a debugger or test to verify the decoder handles all expected formats.
func testSupabaseDateDecoder() {
    let samples = [
        "2025-11-19 15:59:43.65175+00",
        "2025-11-19 15:59:43+00",
        "2025-11-19T15:59:43.65175+00:00",
        "2025-11-19T15:59:43+00:00",
        "2025-11-19T15:59:43.65175Z",
        "2025-11-19T15:59:43Z"
    ]
    
    let decoder = SupabaseDateDecoder.shared
    
    for sample in samples {
        let json = """
        {"date": "\(sample)"}
        """
        struct TestStruct: Codable {
            let date: Date
        }
        
        if let data = json.data(using: .utf8),
           let decoded = try? decoder.decode(TestStruct.self, from: data) {
            print("✅ Successfully decoded: \(sample) -> \(decoded.date)")
        } else {
            print("❌ Failed to decode: \(sample)")
        }
    }
}
#endif

