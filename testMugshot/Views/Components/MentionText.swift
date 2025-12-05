//
//  MentionText.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct MentionText: View {
    let text: String
    let mentions: [Mention]
    var onMentionTap: ((String) -> Void)? = nil
    
    var body: some View {
        // If no tap handler, use simple attributed string
        if onMentionTap == nil {
            Text(attributedString)
        } else {
            // Build interactive text with tappable mentions
            InteractiveMentionText(
                text: text,
                mentions: mentions,
                onMentionTap: onMentionTap
            )
        }
    }
    
    private var attributedString: AttributedString {
        // Replace @[Display Name] with just Display Name in the display text
        var displayText = text
        let mentionRanges = MentionParser.findMentionRanges(in: text)
        
        // Process mentions in reverse order to preserve indices
        for (range, displayName) in mentionRanges.reversed() {
            if let swiftRange = Range(range, in: displayText) {
                // Replace @[Display Name] with just Display Name
                displayText.replaceSubrange(swiftRange, with: displayName)
            }
        }
        
        var attributed = AttributedString(displayText)
        
        // Now apply styling to the display names in the modified text
        // We need to recalculate positions after replacement
        let updatedMentionRanges = MentionParser.findDisplayNameRanges(in: text, displayText: displayText)
        
        for range in updatedMentionRanges {
            if let swiftRange = Range(range, in: attributed) {
                attributed[swiftRange].foregroundColor = DS.Colors.primaryAccent
                attributed[swiftRange].font = DS.Typography.bodyText.bold()
            }
        }
        
        return attributed
    }
}

// MARK: - Interactive Mention Text

/// A text view that renders mentions as tappable links using proper Text concatenation
private struct InteractiveMentionText: View {
    let text: String
    let mentions: [Mention]
    let onMentionTap: ((String) -> Void)?
    
    var body: some View {
        // Parse text into segments and build concatenated Text for proper inline flow
        buildConcatenatedText()
    }
    
    @ViewBuilder
    private func buildConcatenatedText() -> some View {
        // Use AttributedString with links for proper tap handling
        Text(attributedStringWithLinks)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "mugshot", url.host == "mention",
                   let username = url.pathComponents.last {
                    onMentionTap?(username)
                }
                return .handled
            })
    }
    
    private var attributedStringWithLinks: AttributedString {
        // Replace @[Display Name] with just Display Name in the display text
        var displayText = text
        let mentionRanges = MentionParser.findMentionRanges(in: text)
        
        // Create a map of display name to username for link handling
        // Use the mentions array to get the actual username for each display name
        var displayNameToUsername: [String: String] = [:]
        for mention in mentions {
            displayNameToUsername[mention.displayName] = mention.username
        }
        
        // Process mentions in reverse order to preserve indices
        for (range, displayName) in mentionRanges.reversed() {
            if let swiftRange = Range(range, in: displayText) {
                // Replace @[Display Name] with just Display Name
                displayText.replaceSubrange(swiftRange, with: displayName)
            }
        }
        
        var attributed = AttributedString(displayText)
        
        // Now apply styling and links to the display names in the modified text
        let updatedMentionRanges = MentionParser.findDisplayNameRanges(in: text, displayText: displayText)
        let displayNames = mentionRanges.map { $0.displayName }
        
        for (index, range) in updatedMentionRanges.enumerated() {
            if let swiftRange = Range(range, in: attributed),
               index < displayNames.count {
                let displayName = displayNames[index]
                // Get the username for this display name from the mentions array
                let username = displayNameToUsername[displayName] ?? displayName
                attributed[swiftRange].foregroundColor = DS.Colors.primaryAccent
                attributed[swiftRange].font = DS.Typography.bodyText.bold()
                // Add link for tap handling using USERNAME (not display name)
                if let url = URL(string: "mugshot://mention/\(username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username)") {
                    attributed[swiftRange].link = url
                }
            }
        }
        
        return attributed
    }
    
    private struct TextSegment {
        let text: String
        let isMention: Bool
    }
    
    private func parseTextSegments() -> [TextSegment] {
        var segments: [TextSegment] = []
        let mentionRanges = MentionParser.findMentionRanges(in: text)
        
        var currentIndex = text.startIndex
        
        for (range, displayName) in mentionRanges {
            guard let rangeStart = Range(NSRange(location: range.location, length: 0), in: text)?.lowerBound,
                  let rangeEnd = Range(NSRange(location: range.location + range.length, length: 0), in: text)?.lowerBound else {
                continue
            }
            
            // Add text before mention if any
            if currentIndex < rangeStart {
                let beforeText = String(text[currentIndex..<rangeStart])
                if !beforeText.isEmpty {
                    segments.append(TextSegment(text: beforeText, isMention: false))
                }
            }
            
            // Add mention using just the display name (not the full @[Display Name])
            segments.append(TextSegment(text: displayName, isMention: true))
            
            currentIndex = rangeEnd
        }
        
        // Add remaining text after last mention
        if currentIndex < text.endIndex {
            let afterText = String(text[currentIndex...])
            if !afterText.isEmpty {
                segments.append(TextSegment(text: afterText, isMention: false))
            }
        }
        
        // If no segments were created, just return the whole text
        if segments.isEmpty {
            segments.append(TextSegment(text: text, isMention: false))
        }
        
        return segments
    }
}

// MARK: - Wrapping HStack

/// A simple wrapping horizontal stack for inline text layout
private struct WrappingHStack: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: [AnyView]
    
    init<Content: View>(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        
        // Extract views - this is a simplified approach
        // For complex layouts, consider using Layout protocol (iOS 16+)
        let contentView = content()
        self.content = [AnyView(contentView)]
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(content.indices, id: \.self) { index in
                content[index]
            }
        }
    }
}

// MARK: - Simplified Interactive Text for Comments

/// A simpler approach using Text concatenation
struct TappableMentionText: View {
    let text: String
    let mentions: [Mention]
    let onMentionTap: ((String) -> Void)?
    @State private var tappedMention: String?
    @State private var showProfile = false
    
    var body: some View {
        // Create a map of display name to username
        let displayNameToUsername = Dictionary(uniqueKeysWithValues: mentions.map { ($0.displayName, $0.username) })
        
        // Parse and build attributed text
        let segments = parseSegments()
        
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                if segment.isMention {
                    Text(segment.text)
                        .foregroundColor(DS.Colors.primaryAccent)
                        .fontWeight(.semibold)
                        .onTapGesture {
                            // segment.text is the display name, we need to map it to username
                            let username = displayNameToUsername[segment.text] ?? segment.text
                            tappedMention = username
                            onMentionTap?(username)
                        }
                } else {
                    Text(segment.text)
                }
            }
        }
    }
    
    private struct Segment {
        let text: String
        let isMention: Bool
    }
    
    private func parseSegments() -> [Segment] {
        var segments: [Segment] = []
        let mentionRanges = MentionParser.findMentionRanges(in: text)
        
        if mentionRanges.isEmpty {
            return [Segment(text: text, isMention: false)]
        }
        
        var currentIndex = text.startIndex
        
        for (range, displayName) in mentionRanges {
            guard let rangeStart = Range(NSRange(location: range.location, length: 0), in: text)?.lowerBound,
                  let rangeEnd = Range(NSRange(location: range.location + range.length, length: 0), in: text)?.lowerBound else {
                continue
            }
            
            if currentIndex < rangeStart {
                segments.append(Segment(text: String(text[currentIndex..<rangeStart]), isMention: false))
            }
            
            // Use display name instead of full @[Display Name] text
            segments.append(Segment(text: displayName, isMention: true))
            currentIndex = rangeEnd
        }
        
        if currentIndex < text.endIndex {
            segments.append(Segment(text: String(text[currentIndex...]), isMention: false))
        }
        
        return segments
    }
}

