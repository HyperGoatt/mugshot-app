//
//  AuthLandingView.swift
//  testMugshot
//
//  Landing screen for authentication flow - Brand-first design
//

import SwiftUI

struct AuthLandingView: View {
    let onCreateAccount: () -> Void
    let onSignIn: () -> Void
    
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            DS.Colors.mintSoftFill
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Hero Section - Brand Identity
                VStack(spacing: DS.Spacing.lg) {
                    // Large app icon with soft shadow
                    ZStack {
                        Circle()
                            .fill(DS.Colors.primaryAccent)
                            .frame(width: 140, height: 140)
                            .shadow(color: DS.Colors.mintDark.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(DS.Colors.textOnMint)
                    }
                    .scaleEffect(showContent ? 1 : 0.8)
                    .opacity(showContent ? 1 : 0)
                    
                    // App wordmark
                    Text("Mugshot")
                        .font(DS.Typography.display())
                        .foregroundStyle(DS.Colors.textPrimary)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    
                    // Tagline
                    Text("Your sipping journey starts here")
                        .font(DS.Typography.bodyText)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                }
                .padding(.bottom, DS.Spacing.xxl)
                
                Spacer()
                
                // Action Section
                VStack(spacing: DS.Spacing.lg) {
                    // Primary CTA - Get Started
                    Button(action: onCreateAccount) {
                        Text("Get Started")
                            .font(DS.Typography.buttonLabel)
                            .foregroundStyle(DS.Colors.textOnMint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md + 2)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .fill(DS.Colors.primaryAccent)
                            )
                            .shadow(color: DS.Colors.mintDark.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    // Secondary - Text link style
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Already have an account?")
                            .font(DS.Typography.subheadline())
                            .foregroundStyle(DS.Colors.textSecondary)
                        
                        Button(action: onSignIn) {
                            Text("Sign in")
                                .font(DS.Typography.subheadline(.semibold))
                                .foregroundStyle(DS.Colors.primaryAccentHover)
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                }
                .padding(.bottom, DS.Spacing.xl)
                
                // Legal text
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(DS.Typography.caption1())
                    .foregroundStyle(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding * 2)
                    .padding(.bottom, DS.Spacing.xl)
                    .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }
}
