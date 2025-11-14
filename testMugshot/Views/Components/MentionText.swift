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
    
    var body: some View {
        // For now, use AttributedString for mention highlighting
        // In a production app, you might want a more sophisticated text renderer
        Text(attributedString)
    }
    
    private var attributedString: AttributedString {
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
}

