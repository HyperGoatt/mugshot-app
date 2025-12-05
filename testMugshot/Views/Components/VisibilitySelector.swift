//
//  VisibilitySelector.swift
//  testMugshot
//
//  Slim segmented control for visit visibility (Private / Friends / Public).
//

import SwiftUI

struct VisibilitySelector: View {
    @Binding var visibility: VisitVisibility
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Section label
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "eye.fill")
                    .foregroundColor(DS.Colors.primaryAccent)
                    .font(.system(size: 16))
                Text("Who can see?")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
            }
            
            // Segmented control
            HStack(spacing: 0) {
                VisibilitySegment(
                    icon: "lock.fill",
                    title: "Private",
                    isSelected: visibility == .private
                ) {
                    selectVisibility(.private)
                }
                
                VisibilitySegment(
                    icon: "person.2.fill",
                    title: "Friends",
                    isSelected: visibility == .friends
                ) {
                    selectVisibility(.friends)
                }
                
                VisibilitySegment(
                    icon: "globe",
                    title: "Public",
                    isSelected: visibility == .everyone
                ) {
                    selectVisibility(.everyone)
                }
            }
            .background(DS.Colors.cardBackgroundAlt)
            .cornerRadius(DS.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
    
    private func selectVisibility(_ newVisibility: VisitVisibility) {
        if visibility != newVisibility {
            hapticsManager.selectionChanged()
            withAnimation(.easeInOut(duration: 0.2)) {
                visibility = newVisibility
            }
        }
    }
}

// MARK: - Visibility Segment

private struct VisibilitySegment: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(DS.Typography.caption1(.medium))
            }
            .foregroundColor(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(isSelected ? DS.Colors.primaryAccentSoftFill : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? DS.Colors.primaryAccent : Color.clear)
                    .frame(height: 2)
                    .offset(y: 1),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}
