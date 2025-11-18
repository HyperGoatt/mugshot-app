//
//  AuthLandingView.swift
//  testMugshot
//
//  Landing screen for authentication flow
//

import SwiftUI

struct AuthLandingView: View {
    let onCreateAccount: () -> Void
    let onSignIn: () -> Void
    
    var body: some View {
        ZStack {
            DS.Colors.mintSoftFill
                .ignoresSafeArea()
            
            VStack(spacing: DS.Spacing.xl) {
                Spacer()
                
                // Mugshot icon
                ZStack {
                    Circle()
                        .fill(DS.Colors.primaryAccent)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(DS.Colors.textOnMint)
                }
                .padding(.bottom, DS.Spacing.lg)
                
                // Title
                Text("Set up your Mugshot account")
                    .font(DS.Typography.screenTitle)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Subtitle
                Text("Create an account to save visits, sync your profile, and keep your coffee journey in one place.")
                    .font(DS.Typography.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding * 2)
                    .padding(.top, DS.Spacing.sm)
                
                Spacer()
                
                // Primary button
                Button(action: onCreateAccount) {
                    Text("Create an account")
                        .font(DS.Typography.buttonLabel)
                        .foregroundStyle(DS.Colors.textOnMint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .fill(DS.Colors.primaryAccent)
                        )
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Secondary button
                Button(action: onSignIn) {
                    Text("Sign in")
                        .font(DS.Typography.buttonLabel)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .fill(DS.Colors.cardBackground)
                                )
                        )
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.sm)
                
                // Legal text
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(DS.Typography.caption1())
                    .foregroundStyle(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding * 2)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xl)
            }
        }
    }
}

