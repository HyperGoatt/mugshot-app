//
//  DSStatTabs.swift
//  testMugshot
//
//  Instagram-style stat tabs with counts above labels and underline indicator.
//

import SwiftUI

struct DSStatTabs: View {
    struct Tab: Identifiable, Equatable {
        let id: String
        let count: Int
        let label: String
        
        static func == (lhs: Tab, rhs: Tab) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    let tabs: [Tab]
    @Binding var selectedTabId: String
    var onTabChange: ((String) -> Void)?
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.vertical, DS.Spacing.md)
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
            VStack(spacing: DS.Spacing.xs) {
                // Count number
                Text("\(tab.count)")
                    .font(DS.Typography.title2(.bold))
                    .foregroundColor(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                
                // Label
                Text(tab.label)
                    .font(DS.Typography.caption1(.medium))
                    .foregroundColor(isSelected ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                
                // Underline indicator
                Rectangle()
                    .fill(isSelected ? DS.Colors.primaryAccent : Color.clear)
                    .frame(height: 3)
                    .cornerRadius(1.5)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.xs)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        DSStatTabs(
            tabs: [
                .init(id: "favorites", count: 4, label: "Favorites"),
                .init(id: "wishlist", count: 2, label: "Wishlist"),
                .init(id: "library", count: 6, label: "My Cafes")
            ],
            selectedTabId: .constant("favorites")
        )
        .background(DS.Colors.appBarBackground)
        
        Spacer()
    }
    .background(DS.Colors.screenBackground)
}

