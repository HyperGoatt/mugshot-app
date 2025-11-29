//
//  DSScoreBadge.swift
//

import SwiftUI

struct DSScoreBadge: View {
    let scoreText: String
    let systemIcon: String?
    
    init(score: Double, icon: String? = "star.fill") {
        self.scoreText = String(format: "%.1f", score)
        self.systemIcon = icon
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let systemIcon = systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.secondaryAccent)
            }
            Text(scoreText)
                .font(DS.Typography.caption1(.medium))
                .foregroundColor(DS.Colors.secondaryAccent)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 4)
        .background(DS.Colors.blueSoftFill)
        .cornerRadius(DS.Radius.chip)
        .fixedSize()
    }
}


