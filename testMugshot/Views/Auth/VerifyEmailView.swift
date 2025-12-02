//
//  VerifyEmailView.swift
//  testMugshot
//
//  Email verification screen shown after signup
//

import SwiftUI

struct VerifyEmailView: View {
    let email: String
    let onEmailVerified: () -> Void
    let onResendEmail: () -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var dataManager: DataManager
    @State private var resendError: String?
    @State private var isResending = false
    @State private var resendSuccess = false
    @State private var isPollingVerification = false
    
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
                    
                    Text("Verify email")
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
                    VStack(spacing: DS.Spacing.xl) {
                        // Icon
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 64))
                            .foregroundStyle(DS.Colors.primaryAccent)
                            .padding(.top, DS.Spacing.xxl)
                        
                        // Title
                        Text("Check your email")
                            .font(DS.Typography.screenTitle)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        // Description
                        VStack(spacing: DS.Spacing.sm) {
                            Text("We've sent a verification link to")
                                .font(DS.Typography.bodyText)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                            
                            Text(email)
                                .font(DS.Typography.bodyText)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                            
                            Text("Click the link in the email to verify your account.")
                                .font(DS.Typography.bodyText)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, DS.Spacing.xs)
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        
                        // Error message
                        if let resendError = resendError {
                            Text(resendError)
                                .font(DS.Typography.caption1())
                                .foregroundStyle(DS.Colors.negativeChange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                        
                        // Success message
                        if resendSuccess {
                            Text("Verification email sent!")
                                .font(DS.Typography.caption1())
                                .foregroundStyle(DS.Colors.positiveChange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                        
                        // Resend button
                        Button(action: handleResendEmail) {
                            HStack(spacing: DS.Spacing.sm) {
                                if isResending {
                                    ProgressView()
                                        .tint(DS.Colors.textPrimary)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(isResending ? "Sending..." : "Resend verification email")
                            }
                            .font(DS.Typography.buttonLabel)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
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
                        .disabled(isResending)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.lg)
                        
                        // Error message from auth flow
                        if let errorMessage = dataManager.authErrorMessage {
                            Text(errorMessage)
                                .font(DS.Typography.caption1())
                                .foregroundStyle(DS.Colors.negativeChange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                        
                        // Continue button (check verification status)
                        Button(action: handleCheckVerification) {
                            HStack(spacing: DS.Spacing.sm) {
                                if dataManager.isCheckingEmailVerification {
                                    ProgressView()
                                        .tint(DS.Colors.textOnMint)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                }
                                Text(dataManager.isCheckingEmailVerification ? "Checking..." : "I've verified my email")
                            }
                            .font(DS.Typography.buttonLabel)
                            .foregroundStyle(DS.Colors.textOnMint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .fill(dataManager.isCheckingEmailVerification ? DS.Colors.primaryAccent.opacity(0.5) : DS.Colors.primaryAccent)
                            )
                        }
                        .disabled(dataManager.isCheckingEmailVerification)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        
                        Spacer(minLength: DS.Spacing.xxl)
                    }
                }
            }
        }
        .task {
            guard !isPollingVerification, !dataManager.appData.hasEmailVerified else { return }
            isPollingVerification = true
            await checkVerificationPeriodically()
            isPollingVerification = false
        }
        .onChange(of: dataManager.appData.hasEmailVerified) { _, verified in
            // When email is verified, call the callback to trigger navigation
            if verified {
                print("✅ Email verification detected via onChange")
                onEmailVerified()
            }
        }
    }
    
    private func handleResendEmail() {
        print("🔄 handleResendEmail called")
        resendError = nil
        resendSuccess = false
        isResending = true
        
        Task { @MainActor in
            do {
                print("📧 Sending resend verification email request...")
                try await dataManager.resendVerificationEmail()
                print("✅ Resend verification email successful")
                resendSuccess = true
                isResending = false
                onResendEmail() // Call callback to notify parent
                // Clear success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    resendSuccess = false
                }
            } catch {
                print("❌ Resend verification email failed: \(error.localizedDescription)")
                isResending = false
                resendError = formatResendError(error)
            }
        }
    }
    
    private func handleCheckVerification() {
        print("[VerifyEmail] handleCheckVerification: Button tapped")
        Task { @MainActor in
            await dataManager.confirmEmailAndAdvanceFlow()
            // The method will update hasEmailVerified if successful
            // Use a small delay to ensure state has propagated
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            if dataManager.appData.hasEmailVerified {
                print("[VerifyEmail] handleCheckVerification: Email verified - calling callback")
                onEmailVerified()
            } else {
                print("[VerifyEmail] handleCheckVerification: Email not yet verified")
            }
        }
    }
    
    private func checkVerificationPeriodically() async {
        // Check every 2 seconds for verification
        print("[VerifyEmail] checkVerificationPeriodically: Starting")
        var checkCount = 0
        let maxChecks = 150 // Stop after 5 minutes (150 * 2 seconds)
        
        while !dataManager.appData.hasEmailVerified && checkCount < maxChecks && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            checkCount += 1
            print("[VerifyEmail] checkVerificationPeriodically: Check #\(checkCount)")
            
            // Use refreshAuthStatusFromSupabase to check verification status
            await dataManager.refreshAuthStatusFromSupabase()
            
            // Check if verification status changed
            if dataManager.appData.hasEmailVerified {
                print("[VerifyEmail] checkVerificationPeriodically: Email verified - calling callback")
                await MainActor.run {
                    onEmailVerified()
                }
                break
            }
        }
        
        if checkCount >= maxChecks {
            print("[VerifyEmail] checkVerificationPeriodically: Stopped after max checks")
        } else {
            print("[VerifyEmail] checkVerificationPeriodically: Stopping - email verified")
        }
    }
    
    private func formatResendError(_ error: Error) -> String {
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

