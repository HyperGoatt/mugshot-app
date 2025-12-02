//
//  CaptionField.swift
//  testMugshot
//
//  Single caption text field for visit posts.
//

import SwiftUI

struct CaptionField: View {
    @Binding var caption: String
    let captionLimit: Int
    
    init(caption: Binding<String>, captionLimit: Int = 200) {
        self._caption = caption
        self.captionLimit = captionLimit
    }
    
    // Only show character count when approaching limit
    private var shouldShowCharCount: Bool {
        caption.count >= 160
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Section label
            HStack {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(DS.Colors.primaryAccent)
                        .font(.system(size: 16))
                    Text("Caption")
                        .font(DS.Typography.sectionTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                }
                
                Spacer()
                
                // Character count - only show when approaching limit
                if shouldShowCharCount {
                    Text("\(caption.count)/\(captionLimit)")
                        .font(DS.Typography.caption2())
                        .foregroundColor(caption.count >= captionLimit ? DS.Colors.negativeChange : DS.Colors.textTertiary)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: shouldShowCharCount)
            
            // Text field
            TextField(
                "What made this moment special?",
                text: Binding(
                    get: { caption },
                    set: { newValue in
                        if newValue.count <= captionLimit {
                            caption = newValue
                        } else {
                            caption = String(newValue.prefix(captionLimit))
                        }
                    }
                ),
                axis: .vertical
            )
            .lineLimit(3...8)
            .font(DS.Typography.bodyText)
            .foregroundColor(DS.Colors.textPrimary)
            .tint(DS.Colors.primaryAccent)
            .padding(DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
}

