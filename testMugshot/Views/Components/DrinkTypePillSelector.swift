//
//  DrinkTypePillSelector.swift
//  testMugshot
//
//  Horizontal scrolling pill selector for drink types.
//

import SwiftUI

struct DrinkTypePillSelector: View {
    @Binding var drinkType: DrinkType
    @Binding var customDrinkType: String
    @StateObject private var hapticsManager = HapticsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section label
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(DS.Colors.primaryAccent)
                    .font(.system(size: 16))
                Text("What'd you get?")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
            }
            
            // Horizontal scrolling pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(DrinkType.allCases, id: \.self) { type in
                        DrinkPill(
                            title: type.rawValue,
                            isSelected: drinkType == type
                        ) {
                            if drinkType != type {
                                hapticsManager.selectionChanged()
                            }
                            drinkType = type
                            if type != .other {
                                customDrinkType = ""
                            }
                        }
                    }
                }
            }
            
            // Custom drink type field (shown when "Other" is selected)
            if drinkType == .other {
                TextField("What are you drinking?", text: $customDrinkType)
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: drinkType)
    }
}

// MARK: - Drink Pill

private struct DrinkPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.pillLabel)
                .foregroundColor(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(isSelected ? DS.Colors.primaryAccentSoftFill : DS.Colors.cardBackgroundAlt)
                .cornerRadius(DS.Radius.pill)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.pill)
                        .stroke(isSelected ? DS.Colors.primaryAccent : DS.Colors.borderSubtle.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

