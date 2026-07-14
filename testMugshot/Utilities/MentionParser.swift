//
//  MentionParser.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

struct MentionParser {
    // Regex pattern to match @username mentions
    // Matches @ followed by alphanumeric characters and underscores
    static let mentionPattern = "@([a-zA-Z0-9_]+)"
    
    /// Parse mentions from text and return array of Mention objects
    static func parseMentions(from text: String) -> [Mention] {
        let regex = try? NSRegularExpression(pattern: mentionPattern, options: [])
        let nsString = text as NSString
        let results = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var mentions: [Mention] = []
        var seenUsernames = Set<String>()
        
        results?.forEach { match in
            if match.numberOfRanges > 1 {
                let usernameRange = match.range(at: 1)
                let username = nsString.substring(with: usernameRange)
                
                // Avoid duplicates
                if !seenUsernames.contains(username) {
                    seenUsernames.insert(username)
                    mentions.append(Mention(username: username))
                }
            }
        }
        
        return mentions
    }
    
    /// Find all mention ranges in text for highlighting
    static func findMentionRanges(in text: String) -> [(range: NSRange, username: String)] {
        let regex = try? NSRegularExpression(pattern: mentionPattern, options: [])
        let nsString = text as NSString
        let results = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var ranges: [(range: NSRange, username: String)] = []
        
        results?.forEach { match in
            if match.numberOfRanges > 1 {
                let fullRange = match.range(at: 0) // Full match including @
                let usernameRange = match.range(at: 1) // Just the username
                let username = nsString.substring(with: usernameRange)
                ranges.append((range: fullRange, username: username))
            }
        }
        
        return ranges
    }
}

