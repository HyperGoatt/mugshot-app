//
//  LonelyMugEmptyState.swift
//  testMugshot
//
//  Reusable empty state view for Favorites using the “Dreaming Mug” illustration.
//

import SwiftUI

struct LonelyMugEmptyState: View {
    var title: String = "No favorite cafes… yet."
    var subtitle: String = "Go discover a new sip to save."
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: DS.Spacing.md) {
                Image("DreamingMug")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
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
                }
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.screenBackground.opacity(0.0001))
    }
}


