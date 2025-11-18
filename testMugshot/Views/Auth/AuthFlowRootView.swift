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
    
    enum AuthMode {
        case landing
        case signUp
        case signIn
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
                    onAuthSuccess: handleAuthSuccess,
                    onBack: { mode = .landing }
                )
            case .signIn:
                SignInView(
                    onAuthSuccess: handleAuthSuccess,
                    onBack: { mode = .landing }
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: mode)
    }
    
    private func handleAuthSuccess(user: AuthUserSummary) {
        hapticsManager.playSuccess()
        dataManager.appData.isUserAuthenticated = true
        dataManager.appData.currentUserDisplayName = user.displayName
        dataManager.appData.currentUserUsername = user.username
        dataManager.appData.currentUserEmail = user.email
        // Do NOT set hasCompletedProfileSetup here - user will go through profile setup next
        dataManager.save()
    }
}

