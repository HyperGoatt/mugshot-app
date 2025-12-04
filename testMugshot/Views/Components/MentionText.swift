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
                onMentionTap: onMentionTap
            )
        }
    }
    
    private var attributedString: AttributedString {
        var attributed = AttributedString(text)
        
        // Find all mention ranges and apply styling
        let mentionRanges = MentionParser.findMentionRanges(in: text)
        
        for (range, _) in mentionRanges {
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
        var attributed = AttributedString(text)
        let mentionRanges = MentionParser.findMentionRanges(in: text)
        
        for (range, username) in mentionRanges {
            if let swiftRange = Range(range, in: attributed) {
                attributed[swiftRange].foregroundColor = DS.Colors.primaryAccent
                attributed[swiftRange].font = DS.Typography.bodyText.bold()
                // Add link for tap handling
                if let url = URL(string: "mugshot://mention/\(username)") {
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
        
        for (range, _) in mentionRanges {
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
            
            // Add mention
            let mentionText = String(text[rangeStart..<rangeEnd])
            segments.append(TextSegment(text: mentionText, isMention: true))
            
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
    let onMentionTap: ((String) -> Void)?
    @State private var tappedMention: String?
    @State private var showProfile = false
    
    var body: some View {
        // Parse and build attributed text
        let segments = parseSegments()
        
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                if segment.isMention {
                    Text(segment.text)
                        .foregroundColor(DS.Colors.primaryAccent)
                        .fontWeight(.semibold)
                        .onTapGesture {
                            let username = segment.text.hasPrefix("@") 
                                ? String(segment.text.dropFirst()) 
                                : segment.text
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
        
        for (range, _) in mentionRanges {
            guard let rangeStart = Range(NSRange(location: range.location, length: 0), in: text)?.lowerBound,
                  let rangeEnd = Range(NSRange(location: range.location + range.length, length: 0), in: text)?.lowerBound else {
                continue
            }
            
            if currentIndex < rangeStart {
                segments.append(Segment(text: String(text[currentIndex..<rangeStart]), isMention: false))
            }
            
            segments.append(Segment(text: String(text[rangeStart..<rangeEnd]), isMention: true))
            currentIndex = rangeEnd
        }
        
        if currentIndex < text.endIndex {
            segments.append(Segment(text: String(text[currentIndex...]), isMention: false))
        }
        
        return segments
    }
}

