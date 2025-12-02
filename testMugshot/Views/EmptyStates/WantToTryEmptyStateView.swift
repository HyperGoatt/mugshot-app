//
//  WantToTryEmptyStateView.swift
//  testMugshot
//
//  Empty state for the Saved → Want to Try segment using the “Bookmark Mug” illustration.
//

import SwiftUI

struct WantToTryEmptyStateView: View {
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: DS.Spacing.md) {
                Image("BookmarkMug")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                    .accessibilityHidden(true)
                
                VStack(spacing: DS.Spacing.xs) {
                    Text("No “Want to Try” cafes yet.")
                        .font(DS.Typography.sectionTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Start a wish list for your next sip.")
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


