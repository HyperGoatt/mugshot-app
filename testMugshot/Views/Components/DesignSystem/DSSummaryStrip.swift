//
//  DSSummaryStrip.swift
//  testMugshot
//
//  Tappable collection summary strip showing counts for saved categories.
//

import SwiftUI

struct DSSummaryStrip: View {
    struct Stat: Identifiable {
        let id: String
        let icon: String
        let count: Int
        let label: String
        let iconColor: Color
    }
    
    let stats: [Stat]
    var onStatTap: ((String) -> Void)?
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                if index > 0 {
                    Text("·")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.md)
                }
                
                statButton(for: stat)
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(DS.Colors.cardBackgroundAlt)
    }
    
    @ViewBuilder
    private func statButton(for stat: Stat) -> some View {
        Button {
            onStatTap?(stat.id)
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: stat.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(stat.iconColor)
                
                Text("\(stat.count)")
                    .font(DS.Typography.headline(.bold))
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text(stat.label)
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        DSSummaryStrip(
            stats: [
                .init(id: "favorites", icon: "heart.fill", count: 4, label: "Favorites", iconColor: DS.Colors.redAccent),
                .init(id: "wishlist", icon: "bookmark.fill", count: 2, label: "To Try", iconColor: DS.Colors.primaryAccent),
                .init(id: "library", icon: "cup.and.saucer.fill", count: 6, label: "Cafes", iconColor: DS.Colors.textSecondary)
            ],
            onStatTap: { id in
                print("Tapped: \(id)")
            }
        )
    }
}

