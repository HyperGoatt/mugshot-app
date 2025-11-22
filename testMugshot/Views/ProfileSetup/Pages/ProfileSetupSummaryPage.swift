//
//  ProfileSetupSummaryPage.swift
//  testMugshot
//
//  Page 6: Profile Setup Summary
//

import SwiftUI

struct ProfileSetupSummaryPage: View {
    let user: AppData
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(DS.Colors.primaryAccent)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(DS.Colors.textOnMint)
            }
            .padding(.bottom, DS.Spacing.lg)
            
            // Title
            Text("You're all set!")
                .font(DS.Typography.screenTitle)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Subtitle
            Text("Your profile is complete. Start exploring Mugshot!")
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
                .padding(.top, DS.Spacing.sm)
            
            // Profile preview card
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Banner placeholder
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(DS.Colors.cardBackgroundAlt)
                    .frame(height: 80)
                    .overlay(
                        Group {
                            if user.currentUserBannerImageId != nil {
                                Text("Banner")
                                    .font(DS.Typography.caption1())
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }
                        }
                    )
                
                HStack(spacing: DS.Spacing.md) {
                    // Profile pic placeholder
                    Circle()
                        .fill(DS.Colors.cardBackgroundAlt)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Group {
                                if user.currentUserProfileImageId != nil {
                                    Text("Photo")
                                        .font(DS.Typography.caption1())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 30))
                                }
                            }
                            .foregroundStyle(DS.Colors.iconDefault)
                        )
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        // Use display name from onboarding, fallback to username, never email
                        let displayName = user.currentUserDisplayName?.isEmpty == false 
                            ? user.currentUserDisplayName! 
                            : (user.currentUserUsername?.isEmpty == false 
                                ? user.currentUserUsername!.capitalized 
                                : "Your Name")
                        Text(displayName)
                            .font(DS.Typography.sectionTitle)
                            .foregroundStyle(DS.Colors.textPrimary)
                        
                        // Use username from onboarding, never email
                        if let username = user.currentUserUsername, !username.isEmpty {
                            Text("@\(username)")
                                .font(DS.Typography.bodyText)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                }
                .offset(y: -30)
                .padding(.horizontal, DS.Spacing.md)
                
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    if let bio = user.currentUserBio, !bio.isEmpty {
                        Text(bio)
                            .font(DS.Typography.bodyText)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .padding(.horizontal, DS.Spacing.md)
                    }
                    
                    if let location = user.currentUserLocation, !location.isEmpty {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.Colors.textSecondary)
                            Text(location)
                                .font(DS.Typography.caption1())
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                    }
                    
                    if let drink = user.currentUserFavoriteDrink {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.Colors.textSecondary)
                            Text(drink)
                                .font(DS.Typography.caption1())
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                    }
                    
                    if user.currentUserInstagramHandle != nil || user.currentUserWebsite != nil {
                        HStack(spacing: DS.Spacing.md) {
                            if user.currentUserInstagramHandle != nil {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }
                            if user.currentUserWebsite != nil {
                                Image(systemName: "link")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.md)
                    }
                }
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.md)
            }
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

