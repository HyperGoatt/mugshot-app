//
//  EmptyStateView.swift
//  testMugshot
//
//  Generic centered empty-state component used across Saved tab segments.
//

import SwiftUI

struct EmptyStateView: View {
    let iconName: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: DS.Spacing.md) {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .accessibilityHidden(true)
                
                VStack(spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Typography.sectionTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.pagePadding * 2)
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.screenBackground)
    }
}


