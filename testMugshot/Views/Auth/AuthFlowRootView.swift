//
//  AuthFlowRootView.swift
//  testMugshot
//
//  Root view for authentication flow (landing, sign up, sign in)
//

import SwiftUI

struct AuthFlowRootView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var hapticsManager: HapticsManager
    
    @State private var mode: AuthMode = .landing
    @State private var pendingEmail: String?
    
    enum AuthMode: Equatable {
        case loading
        case landing
        case signUp
        case signIn
        case verifyEmail(email: String)
    }
    
    var body: some View {
        Group {
            switch mode {
            case .loading:
                ZStack {
                    Color(DS.Colors.screenBackground)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(DS.Colors.primaryAccent)
                }
            case .landing:
                AuthLandingView(
                    onCreateAccount: { mode = .signUp },
                    onSignIn: { mode = .signIn }
                )
            case .signUp:
                SignUpView(
                    onSignUpSuccess: { email in
                        pendingEmail = email
                        mode = .verifyEmail(email: email)
                    },
                    onBack: { mode = .landing }
                )
            case .signIn:
                SignInView(
                    onAuthSuccess: handleAuthSuccess,
                    onBack: { mode = .landing }
                )
            case .verifyEmail(let email):
                VerifyEmailView(
                    email: email,
                    onEmailVerified: handleEmailVerified,
                    onResendEmail: { pendingEmail = email },
                    onBack: {
                        mode = .signUp
                        pendingEmail = nil
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: mode)
        .onChange(of: dataManager.isBootstrapping) { _, isBootstrapping in
            updateAuthMode()
        }
        .onChange(of: dataManager.appData.isUserAuthenticated) { _, _ in
            updateAuthMode()
        }
        .onChange(of: dataManager.appData.hasEmailVerified) { _, _ in
            updateAuthMode()
        }
        .onAppear {
            updateAuthMode()
        }
    }
    
    private func updateAuthMode() {
        if dataManager.isBootstrapping {
            mode = .loading
            return
        }
        
        if dataManager.appData.isUserAuthenticated {
            if !dataManager.appData.hasEmailVerified {
                let email = dataManager.appData.currentUserEmail ?? ""
                mode = .verifyEmail(email: email)
            } else {
                // Main app handles the "authenticated + verified" state by switching root view
                // But if we are here, we might be transitioning.
                // Usually AuthFlowRootView is only shown if !authenticated || !verified || !profileSetup
            }
        } else {
            // Not authenticated -> Landing (unless user manually navigated to sign in/up, but we reset to landing on launch)
            if mode == .loading {
                mode = .landing
            }
        }
    }
    
    private func handleAuthSuccess() {
        hapticsManager.playSuccess()
    }
    
    private func handleEmailVerified() {
        hapticsManager.playSuccess()
        // Email is verified, proceed to profile setup
        // The app will check hasEmailVerified and show ProfileSetupOnboardingView
    }
}

