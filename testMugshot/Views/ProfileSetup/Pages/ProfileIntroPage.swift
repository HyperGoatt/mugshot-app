//
//  ProfileIntroPage.swift
//  testMugshot
//
//  Page 1: Profile Intro
//

import SwiftUI

struct ProfileIntroPage: View {
    let displayName: String
    let username: String
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(DS.Colors.primaryAccent)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(DS.Colors.textOnMint)
            }
            .padding(.bottom, DS.Spacing.lg)
            
            // Title
            Text("Let's complete your Mugshot profile")
                .font(DS.Typography.screenTitle)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Subtitle
            Text("We've pulled in your display name and username. Now let's add your details.")
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
                .padding(.top, DS.Spacing.sm)
            
            // Profile card preview
            VStack(spacing: DS.Spacing.md) {
                Text(displayName.isEmpty ? "Your Name" : displayName)
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Text("@\(username.isEmpty ? "username" : username)")
                    .font(DS.Typography.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(DS.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.top, DS.Spacing.xl)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

