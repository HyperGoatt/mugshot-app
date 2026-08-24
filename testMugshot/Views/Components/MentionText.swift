//
//  MentionText.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import SwiftUI

struct MentionText: View {
    let text: String
    let mentions: [Mention]
    
    var body: some View {
        // For now, use AttributedString for mention highlighting
        // In a production app, you might want a more sophisticated text renderer
        Text(MentionTextFormatter.attributedString(for: text))
    }
}

enum MentionTextFormatter {
    static func selectedDisplayNameToken(_ displayName: String) -> String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func containsAccountBackedToken(_ token: String, in text: String) -> Bool {
        guard !token.isEmpty else { return false }
        let escaped = NSRegularExpression.escapedPattern(for: token)
        guard let expression = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])",
            options: [.caseInsensitive]
        ) else { return false }
        return expression.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) != nil
    }

    static func attributedString(for text: String) -> AttributedString {
        var attributed = AttributedString(text)
        
        // Find all mention ranges and apply styling
        let mentionRanges = MentionParser.findMentionRanges(in: text)
        
        for (range, _) in mentionRanges {
            if let swiftRange = Range(range, in: attributed) {
                attributed[swiftRange].foregroundColor = .mugshotMint
                attributed[swiftRange].font = .system(size: 14, weight: .semibold)
            }
        }
        
        return attributed
    }

    static func commentAttributedString(
        for text: String,
        mentions: [RemoteCommentMention]
    ) -> AttributedString {
        let source = text as NSString
        var replacements: [CommentMentionReplacement] = []

        for mention in mentions where containsAccountBackedToken(mention.token, in: text) {
            let escaped = NSRegularExpression.escapedPattern(for: mention.token)
            guard let expression = try? NSRegularExpression(
                pattern: "(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])",
                options: [.caseInsensitive]
            ) else { continue }
            let matches = expression.matches(
                in: text,
                range: NSRange(location: 0, length: source.length)
            )
            replacements.append(contentsOf: matches.map {
                CommentMentionReplacement(
                    range: $0.range,
                    displayName: mention.displayName,
                    userID: mention.userID
                )
            })
        }

        replacements.sort {
            if $0.range.location == $1.range.location {
                return $0.range.length > $1.range.length
            }
            return $0.range.location < $1.range.location
        }

        var result = AttributedString()
        var cursor = 0
        for replacement in replacements where replacement.range.location >= cursor {
            if replacement.range.location > cursor {
                result.append(AttributedString(source.substring(with: NSRange(
                    location: cursor,
                    length: replacement.range.location - cursor
                ))))
            }

            var mention = AttributedString(replacement.displayName)
            mention.foregroundColor = .mugshotMint
            mention.font = .system(size: 14, weight: .bold)
            if let destination = URL(
                string: "mugshot-mention://user/\(replacement.userID.uuidString)"
            ) {
                mention.link = destination
            }
            result.append(mention)
            cursor = NSMaxRange(replacement.range)
        }

        if cursor < source.length {
            result.append(AttributedString(source.substring(from: cursor)))
        }
        return result
    }
}

private struct CommentMentionReplacement {
    let range: NSRange
    let displayName: String
    let userID: UUID
}
