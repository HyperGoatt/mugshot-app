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
        case landing
        case signUp
        case signIn
        case verifyEmail(email: String)
    }
    
    var body: some View {
        Group {
            switch mode {
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
        .onChange(of: dataManager.appData.hasEmailVerified) { _, verified in
            if verified, case .verifyEmail = mode {
                handleEmailVerified()
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

