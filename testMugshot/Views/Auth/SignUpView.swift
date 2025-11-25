//
//  SignUpView.swift
//  testMugshot
//
//  Sign up form view
//

import SwiftUI

struct SignUpView: View {
    let onSignUpSuccess: (String) -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var hapticsManager: HapticsManager
    
    @State private var displayName: String = ""
    @State private var username: String = ""
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
                // Navigation bar
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DS.Colors.textPrimary)
                    }
                    .padding(.leading, DS.Spacing.pagePadding)
                    
                    Spacer()
                    
                    Text("Create account")
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
                        Text("Create your account")
                            .font(DS.Typography.screenTitle)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.Spacing.pagePadding)
                            .padding(.top, DS.Spacing.xl)
                        
                        // Form fields
                        VStack(spacing: DS.Spacing.md) {
                            // Display Name
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Display Name")
                                    .font(DS.Typography.subheadline())
                                    .foregroundStyle(DS.Colors.textPrimary)
                                
                                TextField("Your name", text: $displayName)
                                    .textContentType(.name)
                                    .autocapitalization(.words)
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
                            
                            // Username
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Username")
                                    .font(DS.Typography.subheadline())
                                    .foregroundStyle(DS.Colors.textPrimary)
                                
                                HStack {
                                    Text("@")
                                        .foregroundStyle(DS.Colors.textSecondary)
                                        .padding(.leading, DS.Spacing.md)
                                    
                                    TextField("username", text: $username)
                                        .textContentType(.username)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .foregroundStyle(DS.Colors.textPrimary)
                                        .tint(DS.Colors.primaryAccent)
                                }
                                .padding(.vertical, DS.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .fill(DS.Colors.cardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                                )
                            }
                            
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
                                
                                SecureField("At least 8 characters", text: $password)
                                    .textContentType(.newPassword)
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
                            .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                        
                        // Create account button
                        Button(action: handleSignUp) {
                            Text(isSubmitting ? "Creating..." : "Create account")
                                .font(DS.Typography.buttonLabel)
                                .foregroundStyle(DS.Colors.textOnMint)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .fill(isSubmitting ? DS.Colors.primaryAccent.opacity(0.5) : DS.Colors.primaryAccent)
                                )
                        }
                        .disabled(isSubmitting)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.lg)
                        
                        Spacer(minLength: DS.Spacing.xxl)
                    }
                }
            }
        }
    }
    
    private func handleSignUp() {
        validationErrors = []
        authError = nil
        
        // Haptic: confirm create account button tap
        hapticsManager.mediumTap()
        
        // Validate fields
        if displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("Display name is required")
        }
        
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("Username is required")
        } else {
            // Basic username validation (alphanumeric, lowercase)
            let usernameLower = username.lowercased()
            if usernameLower != username {
                validationErrors.append("Username must be lowercase")
            }
            if !usernameLower.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) {
                validationErrors.append("Username can only contain letters, numbers, _, and -")
            }
        }
        
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("Email is required")
        } else if !email.contains("@") || !email.contains(".") {
            validationErrors.append("Please enter a valid email address")
        }
        
        if password.count < 8 {
            validationErrors.append("Password must be at least 8 characters")
        }
        
        if !validationErrors.isEmpty {
            // Haptic: validation error
            hapticsManager.playError()
            return
        }
        
        isSubmitting = true
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.lowercased().trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedPassword = password
        
        Task { @MainActor in
            do {
                try await dataManager.signUp(
                    displayName: trimmedDisplayName,
                    username: trimmedUsername,
                    email: trimmedEmail,
                    password: trimmedPassword
                )
                isSubmitting = false
                // Haptic: sign up success (AuthFlowRootView will also call success, but this is fine)
                hapticsManager.playSuccess()
                onSignUpSuccess(trimmedEmail)
            } catch {
                isSubmitting = false
                // Haptic: sign up error
                hapticsManager.playError()
                authError = formatAuthError(error)
            }
        }
    }
    
    private func formatAuthError(_ error: Error) -> String {
        // Check for user-friendly MugshotError first
        if let mugshotError = error as? MugshotError {
            return mugshotError.localizedDescription
        }
        
        if let supabaseError = error as? SupabaseError {
            switch supabaseError {
            case .server(let status, let message):
                if status == 429 {
                    // Email send rate limit - user-friendly message
                    return "Whoa there ☕️\nWe just sent you an email.\nTry again in a few seconds!"
                }
                if let message = message,
                   message.contains("over_email_send_rate_limit") || message.contains("429") {
                    return "Whoa there ☕️\nWe just sent you an email.\nTry again in a few seconds!"
                }
                return supabaseError.localizedDescription
            default:
                return supabaseError.localizedDescription
            }
        }
        
        // Generic fallback
        return "Something went wrong — please try again."
    }
}

