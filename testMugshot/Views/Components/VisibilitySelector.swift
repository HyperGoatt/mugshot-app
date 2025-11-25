//
//  VisibilitySelector.swift
//  testMugshot
//
//  Pill-style selector for visit visibility (Private / Friends / Everyone).
//

import SwiftUI

struct VisibilitySelector: View {
    @Binding var visibility: VisitVisibility
    @StateObject private var hapticsManager = HapticsManager.shared
    
    var body: some View {
        FormSectionCard(title: "Visibility") {
            HStack(spacing: DS.Spacing.md) {
                VisibilityPill(
                    title: "Private",
                    subtitle: "Only you",
                    isSelected: visibility == .private
                ) {
                    if visibility != .private {
                        // Haptic: confirm visibility change
                        hapticsManager.selectionChanged()
                    }
                    visibility = .private
                }
                
                VisibilityPill(
                    title: "Friends",
                    subtitle: "Friends can see",
                    isSelected: visibility == .friends
                ) {
                    if visibility != .friends {
                        // Haptic: confirm visibility change
                        hapticsManager.selectionChanged()
                    }
                    visibility = .friends
                }
                
                VisibilityPill(
                    title: "Everyone",
                    subtitle: "Visible to all",
                    isSelected: visibility == .everyone
                ) {
                    if visibility != .everyone {
                        // Haptic: confirm visibility change
                        hapticsManager.selectionChanged()
                    }
                    visibility = .everyone
                }
            }
        }
    }
}

private struct VisibilityPill: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(DS.Typography.bodyText)
                    .foregroundColor(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                
                Text(subtitle)
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.md)
            .background(isSelected ? DS.Colors.primaryAccentSoftFill : DS.Colors.cardBackgroundAlt)
            .cornerRadius(DS.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? DS.Colors.primaryAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}


