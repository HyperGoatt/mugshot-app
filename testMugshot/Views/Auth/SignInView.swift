//
//  SignInView.swift
//  testMugshot
//
//  Sign in form view - minimal, fast entry for returning users
//

import SwiftUI

struct SignInView: View {
    let onAuthSuccess: () -> Void
    let onBack: () -> Void
    let onCreateAccount: () -> Void
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var hapticsManager: HapticsManager
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var validationErrors: [String] = []
    @State private var authError: String?
    @State private var isSubmitting = false
    
    var body: some View {
        ZStack {
            DS.Colors.mintSoftFill
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation bar - back chevron only
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .padding(.leading, DS.Spacing.sm)
                    
                    Spacer()
                }
                .padding(.top, 36)
                .padding(.bottom, DS.Spacing.xs)
                .background(DS.Colors.mintSoftFill)
                
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        // Title Section - no icon, clean and fast
                        VStack(spacing: DS.Spacing.sm) {
                            Text("Welcome back")
                                .font(DS.Typography.screenTitle)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("Sign in to continue your coffee journey")
                                .font(DS.Typography.subheadline())
                                .foregroundStyle(DS.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.xxl)
                        
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
                        if !validationErrors.isEmpty || authError != nil {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                ForEach(validationErrors, id: \.self) { error in
                                    Text(error)
                                        .font(DS.Typography.caption1())
                                        .foregroundStyle(DS.Colors.negativeChange)
                                }
                                
                                if let authError = authError {
                                    Text(authError)
                                        .font(DS.Typography.caption1())
                                        .foregroundStyle(DS.Colors.negativeChange)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                        
                        // Sign in button
                        Button(action: handleSignIn) {
                            Text(isSubmitting ? "Signing in..." : "Sign in")
                                .font(DS.Typography.buttonLabel)
                                .foregroundStyle(DS.Colors.textOnMint)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md + 2)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .fill(isSubmitting ? DS.Colors.primaryAccent.opacity(0.5) : DS.Colors.primaryAccent)
                                )
                        }
                        .disabled(isSubmitting)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.lg)
                        
                        // Forgot password link
                        Button(action: {
                            // TODO: Implement forgot password flow
                        }) {
                            Text("Forgot password?")
                                .font(DS.Typography.subheadline())
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        .padding(.top, DS.Spacing.sm)
                        
                        Spacer(minLength: DS.Spacing.section)
                        
                        // Cross-navigation footer
                        HStack(spacing: DS.Spacing.xs) {
                            Text("Don't have an account?")
                                .font(DS.Typography.subheadline())
                                .foregroundStyle(DS.Colors.textSecondary)
                            
                            Button(action: onCreateAccount) {
                                Text("Create one")
                                    .font(DS.Typography.subheadline(.semibold))
                                    .foregroundStyle(DS.Colors.primaryAccentHover)
                            }
                        }
                        .padding(.bottom, DS.Spacing.xxl)
                    }
                }
            }
        }
    }
    
    private func handleSignIn() {
        print("[SignInView] Starting sign in")
        validationErrors = []
        authError = nil
        
        // Haptic: confirm sign in button tap
        hapticsManager.mediumTap()
        
        // Validate fields
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("Email is required")
        }
        
        if password.isEmpty {
            validationErrors.append("Password is required")
        }
        
        if !validationErrors.isEmpty {
            // Haptic: validation error
            hapticsManager.playError()
            return
        }
        
        isSubmitting = true
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedPassword = password
        
        Task { @MainActor in
            do {
                print("[SignInView] Calling dataManager.signIn...")
                try await dataManager.signIn(email: trimmedEmail, password: trimmedPassword)
                print("[SignInView] Sign in finished successfully")
                isSubmitting = false
                // Haptic: sign in success (AuthFlowRootView will also call success, but this is fine)
                hapticsManager.playSuccess()
                onAuthSuccess()
            } catch {
                print("[SignInView] Sign in finished with error: \(error.localizedDescription)")
                isSubmitting = false
                // Haptic: sign in error
                hapticsManager.playError()
                authError = formatSignInError(error)
            }
        }
    }
    
    private func formatSignInError(_ error: Error) -> String {
        // Check for user-friendly MugshotError first
        if let mugshotError = error as? MugshotError {
            return mugshotError.localizedDescription
        }
        
        if let supabaseError = error as? SupabaseError {
            switch supabaseError {
            case .server(let status, let message):
                if status == 401 {
                    return "We couldn't sign you in. Please check your email and password and try again."
                }
                return message ?? "We couldn't sign you in. Please try again."
            case .network(_):
                return "Network error. Please check your connection and try again."
            case .decoding(_):
                return "We couldn't sign you in. Please try again."
            case .invalidSession:
                return "We couldn't sign you in. Please try again."
            }
        }
        
        // Generic fallback - user-friendly message
        return "We couldn't sign you in. Please check your email and password and try again."
    }
}
