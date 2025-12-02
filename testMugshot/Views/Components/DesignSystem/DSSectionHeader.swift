//
//  DSSectionHeader.swift
//

import SwiftUI

struct DSSectionHeader: View {
    let title: String
    let subtitle: String?
    
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(DS.Typography.cardSubtitle)
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
    }
}


