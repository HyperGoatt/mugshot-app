//
//  GuideCard.swift
//  testMugshot
//
//  A card component for displaying Mugshot Guides (curated cafe collections).
//

import SwiftUI

struct GuideCard: View {
    let guide: Guide
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: DS.Spacing.lg) {
                // Emoji Icon Circle
                ZStack {
                    Circle()
                        .fill(Color(hex: guide.colorHex).opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Text(guide.coverEmoji)
                        .font(.system(size: 28))
                }
                
                // Title & Subtitle
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(guide.title)
                        .font(DS.Typography.headline())
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Text(guide.subtitle)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(DS.Colors.textTertiary)
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.lg)
            .dsCardShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.md) {
        ForEach(Guide.mockGuides()) { guide in
            GuideCard(guide: guide)
        }
    }
    .padding()
    .background(DS.Colors.screenBackground)
}

