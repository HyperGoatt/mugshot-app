//
//  DSIconTabBar.swift
//  testMugshot
//
//  Icon-based tab bar with icon + short label for the Saved tab.
//

import SwiftUI

struct DSIconTabBar: View {
    struct Tab: Identifiable, Equatable {
        let id: String
        let icon: String        // SF Symbol name
        let selectedIcon: String // SF Symbol for selected state (typically .fill variant)
        let label: String       // Short label
        
        static func == (lhs: Tab, rhs: Tab) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    let tabs: [Tab]
    @Binding var selectedTabId: String
    var onTabChange: ((String) -> Void)?
    
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(tabs) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.pill)
    }
    
    @ViewBuilder
    private func tabButton(for tab: Tab) -> some View {
        let isSelected = selectedTabId == tab.id
        
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedTabId != tab.id {
                    selectedTabId = tab.id
                    onTabChange?(tab.id)
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? DS.Colors.primaryAccent : DS.Colors.iconDefault)
                
                Text(tab.label)
                    .font(DS.Typography.caption1(.medium))
                    .foregroundColor(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Group {
                    if isSelected {
                        DS.Colors.cardBackground
                            .shadow(color: DS.Shadow.cardSoft.color, radius: 4, x: 0, y: 2)
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(DS.Radius.pill)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        DSIconTabBar(
            tabs: [
                .init(id: "favorites", icon: "heart", selectedIcon: "heart.fill", label: "Favorites"),
                .init(id: "wishlist", icon: "bookmark", selectedIcon: "bookmark.fill", label: "Wishlist"),
                .init(id: "library", icon: "cup.and.saucer", selectedIcon: "cup.and.saucer.fill", label: "My Cafes")
            ],
            selectedTabId: .constant("favorites")
        )
        .padding()
    }
    .background(DS.Colors.appBarBackground)
}

