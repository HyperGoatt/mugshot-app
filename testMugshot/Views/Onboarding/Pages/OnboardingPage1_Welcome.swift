//
//  OnboardingPage1_Welcome.swift
//  testMugshot
//
//  Page 1: Welcome to Mugshot
//

import SwiftUI

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()
            
            // Icon/Illustration
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 80))
                .foregroundStyle(DS.Colors.primaryAccent)
                .padding(.bottom, DS.Spacing.lg)
            
            // Title
            Text("Welcome to Mugshot")
                .font(DS.Typography.display(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text("Your personal cafe journal and coffee feed.")
                .font(DS.Typography.title2(.regular))
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
            
            Spacer()
        }
        .padding(DS.Spacing.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

