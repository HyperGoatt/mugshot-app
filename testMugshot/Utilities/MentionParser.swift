//
//  MentionParser.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

struct MentionParser {
    // Regex pattern to match @[Display Name|username] mentions
    // Matches @[ followed by display name, pipe, username, then ]
    static let mentionPattern = "@\\[([^|\\]]+)\\|([^\\]]+)\\]"
    // Fallback pattern for @[Display Name] (without username)
    static let displayOnlyPattern = "@\\[([^\\]]+)\\]"
    // Legacy pattern for backward compatibility with old @username format
    static let legacyMentionPattern = "@([a-zA-Z0-9_]+)"
    
    /// Parse mentions from text and return array of Mention objects
    /// Supports @[displayName|username], @[displayName], and legacy @username formats
    static func parseMentions(from text: String) -> [Mention] {
        let nsString = text as NSString
        var mentions: [Mention] = []
        var seenKeys = Set<String>()
        
        // First, try to parse @[displayName|username] format (NEW)
        if let regex = try? NSRegularExpression(pattern: mentionPattern, options: []) {
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            results.forEach { match in
                if match.numberOfRanges > 2 {
                    let displayNameRange = match.range(at: 1)
                    let usernameRange = match.range(at: 2)
                    let displayName = nsString.substring(with: displayNameRange)
                    let username = nsString.substring(with: usernameRange)
                    
                    let key = "\(displayName)|\(username)"
                    if !seenKeys.contains(key) {
                        seenKeys.insert(key)
                        mentions.append(Mention(username: username, displayName: displayName))
                    }
                }
            }
        }
        
        // Second, try @[Display Name] format (display name only)
        if mentions.isEmpty {
            if let regex = try? NSRegularExpression(pattern: displayOnlyPattern, options: []) {
                let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                results.forEach { match in
                    if match.numberOfRanges > 1 {
                        let displayNameRange = match.range(at: 1)
                        let displayName = nsString.substring(with: displayNameRange)
                        
                        if !seenKeys.contains(displayName) {
                            seenKeys.insert(displayName)
                            // No username available, use display name for both
                            mentions.append(Mention(username: displayName, displayName: displayName))
                        }
                    }
                }
            }
        }
        
        // Fallback: Parse legacy @username format for backward compatibility
        if mentions.isEmpty {
            if let regex = try? NSRegularExpression(pattern: legacyMentionPattern, options: []) {
                let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                results.forEach { match in
                    if match.numberOfRanges > 1 {
                        let usernameRange = match.range(at: 1)
                        let username = nsString.substring(with: usernameRange)
                        
                        if !seenKeys.contains(username) {
                            seenKeys.insert(username)
                            mentions.append(Mention(username: username, displayName: username))
                        }
                    }
                }
            }
        }
        
        return mentions
    }
    
    /// Find all mention ranges in text for highlighting
    /// Returns the display name and the range to highlight
    static func findMentionRanges(in text: String) -> [(range: NSRange, displayName: String)] {
        let nsString = text as NSString
        var ranges: [(range: NSRange, displayName: String)] = []
        
        // First, try @[displayName|username] format (NEW)
        if let regex = try? NSRegularExpression(pattern: mentionPattern, options: []) {
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            results.forEach { match in
                if match.numberOfRanges > 2 {
                    let fullRange = match.range(at: 0) // Full match including @[...|...]
                    let displayNameRange = match.range(at: 1) // Just the display name
                    let displayName = nsString.substring(with: displayNameRange)
                    ranges.append((range: fullRange, displayName: displayName))
                }
            }
        }
        
        // Second, try @[Display Name] format (display name only)
        if ranges.isEmpty {
            if let regex = try? NSRegularExpression(pattern: displayOnlyPattern, options: []) {
                let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                results.forEach { match in
                    if match.numberOfRanges > 1 {
                        let fullRange = match.range(at: 0)
                        let displayNameRange = match.range(at: 1)
                        let displayName = nsString.substring(with: displayNameRange)
                        ranges.append((range: fullRange, displayName: displayName))
                    }
                }
            }
        }
        
        // Fallback: Parse legacy @username format
        if ranges.isEmpty {
            if let regex = try? NSRegularExpression(pattern: legacyMentionPattern, options: []) {
                let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                results.forEach { match in
                    if match.numberOfRanges > 1 {
                        let fullRange = match.range(at: 0) // Full match including @
                        let usernameRange = match.range(at: 1) // Just the username
                        let username = nsString.substring(with: usernameRange)
                        ranges.append((range: fullRange, displayName: username))
                    }
                }
            }
        }
        
        return ranges
    }
    
    /// Calculate the display ranges of mention display names in the processed text
    /// This is used after @[Display Name] has been replaced with just Display Name
    static func findDisplayNameRanges(in originalText: String, displayText: String) -> [NSRange] {
        let mentionRanges = findMentionRanges(in: originalText)
        var displayRanges: [NSRange] = []
        
        var offset = 0 // Track how much the position has shifted
        
        for (originalRange, displayName) in mentionRanges {
            // The original range includes @[Display Name]
            // After replacement, it's just Display Name
            // Calculate new position accounting for previous replacements
            let newLocation = originalRange.location - offset
            let newLength = displayName.count
            
            displayRanges.append(NSRange(location: newLocation, length: newLength))
            
            // Update offset: we removed "@[" and "]" (3 chars total)
            offset += (originalRange.length - displayName.count)
        }
        
        return displayRanges
    }
}

