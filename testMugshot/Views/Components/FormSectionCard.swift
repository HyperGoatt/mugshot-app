//
//  FormSectionCard.swift
//  testMugshot
//
//  Generic card wrapper for grouped form sections in LogVisitView and similar screens.
//

import SwiftUI

struct FormSectionCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let content: Content
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if let title = title {
                    Text(title)
                        .font(DS.Typography.sectionTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                
                content
            }
        }
    }
}


