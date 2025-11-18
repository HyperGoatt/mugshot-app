//
//  SignInView.swift
//  testMugshot
//
//  Sign in form view
//

import SwiftUI

struct SignInView: View {
    let onAuthSuccess: (AuthUserSummary) -> Void
    let onBack: () -> Void
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var validationErrors: [String] = []
    
    var body: some View {
        ZStack {
            DS.Colors.mintSoftFill
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DS.Colors.textPrimary)
                    }
                    .padding(.leading, DS.Spacing.pagePadding)
                    
                    Spacer()
                    
                    Text("Sign in")
                        .font(DS.Typography.sectionTitle)
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    Spacer()
                    
                    // Balance for centering
                    Color.clear
                        .frame(width: 44)
                        .padding(.trailing, DS.Spacing.pagePadding)
                }
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.mintSoftFill)
                
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        // Title
                        Text("Welcome back")
                            .font(DS.Typography.screenTitle)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.Spacing.pagePadding)
                            .padding(.top, DS.Spacing.xl)
                        
                        // Form fields
                        VStack(spacing: DS.Spacing.md) {
                            // Email
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Email")
                                    .font(DS.Typography.subheadline())
                                    .foregroundStyle(DS.Colors.textPrimary)
                                
                                TextField("your@email.com", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .tint(DS.Colors.primaryAccent)
                                    .padding(DS.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                                            .fill(DS.Colors.cardBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                                    )
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Password")
                                    .font(DS.Typography.subheadline())
                                    .foregroundStyle(DS.Colors.textPrimary)
                                
                                SecureField("Enter your password", text: $password)
                                    .textContentType(.password)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .tint(DS.Colors.primaryAccent)
                                    .padding(DS.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                                            .fill(DS.Colors.cardBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.lg)
                        
                        // Validation errors
                        if !validationErrors.isEmpty {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                ForEach(validationErrors, id: \.self) { error in
                                    Text(error)
                                        .font(DS.Typography.caption1())
                                        .foregroundStyle(DS.Colors.negativeChange)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                        
                        // Sign in button
                        Button(action: handleSignIn) {
                            Text("Sign in")
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
                        .padding(.top, DS.Spacing.lg)
                        
                        Spacer(minLength: DS.Spacing.xxl)
                    }
                }
            }
        }
    }
    
    private func handleSignIn() {
        validationErrors = []
        
        // Validate fields
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("Email is required")
        }
        
        if password.isEmpty {
            validationErrors.append("Password is required")
        }
        
        if !validationErrors.isEmpty {
            return
        }
        
        // TODO: Replace with Supabase sign-in call
        // For now, simulate success with placeholder user data
        // Extract username from email local part
        let emailLocalPart = email.components(separatedBy: "@").first ?? "user"
        let user = AuthUserSummary(
            displayName: emailLocalPart.capitalized,
            username: emailLocalPart.lowercased(),
            email: email.trimmingCharacters(in: .whitespaces)
        )
        
        onAuthSuccess(user)
    }
}

