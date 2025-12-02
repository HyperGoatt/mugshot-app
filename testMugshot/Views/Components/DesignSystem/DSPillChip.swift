//
//  DSPillChip.swift
//

import SwiftUI

struct DSPillChip: View {
    let label: String
    var isSelected: Bool = false
    
    var body: some View {
        Text(label)
            .font(DS.Typography.pillLabel)
            .foregroundColor(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.listItemGap)
            .padding(.vertical, 6)
            .background(isSelected ? DS.Colors.primaryAccentSoftFill : DS.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
            .cornerRadius(DS.Radius.chip)
    }
}


