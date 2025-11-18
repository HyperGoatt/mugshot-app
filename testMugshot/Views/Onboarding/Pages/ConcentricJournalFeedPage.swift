//
//  ConcentricJournalFeedPage.swift
//  testMugshot
//
//  Page 2: Journal & Feed
//

import SwiftUI

struct ConcentricJournalFeedPage: View {
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Icon in circular mint background
            ZStack {
                Circle()
                    .fill(DS.Colors.primaryAccent)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(DS.Colors.textOnMint)
            }
            .padding(.bottom, DS.Spacing.lg)
            
            // Title
            Text("Capture your coffee story")
                .font(DS.Typography.screenTitle)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Body
            Text("Log visits with photos, ratings, and notes. Relive your best pours in your feed.")
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

