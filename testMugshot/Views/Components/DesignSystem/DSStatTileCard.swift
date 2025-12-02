//
//  DSStatTileCard.swift
//

import SwiftUI

struct DSStatTileCard: View {
    let label: String
    let value: String
    var subtitle: String?
    
    var body: some View {
        DSBaseCard(background: DS.Colors.cardBackgroundAlt, cornerRadius: DS.Radius.lg) {
            VStack(alignment: .center, spacing: DS.Spacing.sm) {
                Text(label.uppercased())
                    .font(DS.Typography.metaLabel)
                    .foregroundColor(DS.Colors.textSecondary)
                Text(value)
                    .font(DS.Typography.numericStat)
                    .foregroundColor(DS.Colors.textPrimary)
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}


