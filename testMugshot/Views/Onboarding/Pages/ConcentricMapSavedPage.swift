//
//  ConcentricMapSavedPage.swift
//  testMugshot
//
//  Page 3: Map & Saved
//

import SwiftUI

struct ConcentricMapSavedPage: View {
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Icon in circular mint background
            ZStack {
                Circle()
                    .fill(DS.Colors.primaryAccent)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(DS.Colors.textOnMint)
            }
            .padding(.bottom, DS.Spacing.lg)
            
            // Title
            Text("Map your favorite spots")
                .font(DS.Typography.screenTitle)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Body
            Text("Find cafés you've visited, save favorites, and track your want-to-try list.")
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

