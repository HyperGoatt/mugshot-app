//
//  OnboardingPage7_FirstLog.swift
//  testMugshot
//
//  Page 7: Guided First Log Intro
//

import SwiftUI

struct FirstLogIntroPage: View {
    var onStartLog: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Icon
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundStyle(DS.Colors.primaryAccent)
                .padding(.bottom, DS.Spacing.lg)
            
            // Title
            Text("Log your first Mugshot")
                .font(DS.Typography.title1(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text("Pick a cafe, add a photo, and rate your drink.")
                .font(DS.Typography.title2(.regular))
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
            
            // Info
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                InfoRow(icon: "map", text: "Logs appear on your map")
                InfoRow(icon: "person", text: "Visible on your profile")
                InfoRow(icon: "square.grid.2x2", text: "Shared in your feed")
            }
            .padding(.top, DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Primary CTA Button
            Button(action: {
                onStartLog?()
            }) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                    Text("Start My First Log")
                        .font(DS.Typography.bodyText)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(DS.Colors.cardBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(DS.Colors.primaryAccent)
                )
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.top, DS.Spacing.xl)
            
            Spacer()
        }
        .padding(DS.Spacing.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(DS.Colors.primaryAccent)
                .frame(width: 24)
            
            Text(text)
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }
}

