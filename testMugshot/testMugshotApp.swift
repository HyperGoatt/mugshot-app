//
//  testMugshotApp.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import UIKit

@main
struct testMugshotApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var supabaseEnvironment = SupabaseEnvironment()
    
    init() {
        // Configure UITextField and UITextView to use light mode colors
        configureTextInputAppearance()
        // Log Supabase configuration once at launch to verify URL + anon key wiring
        SupabaseConfig.logConfigurationIfAvailable()
        SupabaseConfig.debugPrintConfig()
    }
    
    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(supabaseEnvironment)
        }
    }
    
    @ViewBuilder
    private var rootView: some View {
        if dataManager.isBootstrapping {
            ZStack {
                Color(DS.Colors.screenBackground)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(DS.Colors.primaryAccent)
                VStack {
                    Spacer()
                        Text("Starting up...")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                            .padding(.bottom, 50)
                }
            }
        } else if !dataManager.appData.hasSeenMarketingOnboarding {
            MugshotOnboardingView(dataManager: dataManager)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.light) // Lock to light mode
        } else if !dataManager.appData.isAuthenticated {
            AuthFlowRootView()
                .environmentObject(dataManager)
                .environmentObject(HapticsManager.shared)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.light) // Lock to light mode
        } else if !dataManager.appData.hasEmailVerified {
            // Show verify email screen if authenticated but email not verified
            if let email = dataManager.appData.currentUserEmail {
                VerifyEmailView(
                    email: email,
                    onEmailVerified: {
                        // When verified, the root view will automatically transition
                        // since hasEmailVerified becomes true and triggers a re-render
                        print("✅ Email verified - proceeding to profile setup")
                    },
                    onResendEmail: {
                        // Resend is handled internally by VerifyEmailView
                        print("📧 Resend email requested")
                    },
                    onBack: {
                        // If user goes back, reset auth state to return to sign-in
                        print("⬅️ Back button tapped - returning to auth flow")
                        dataManager.appData.isUserAuthenticated = false
                        dataManager.appData.hasEmailVerified = false
                        dataManager.save()
                    }
                )
                .environmentObject(dataManager)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.light)
            } else {
                AuthFlowRootView()
                    .environmentObject(dataManager)
                    .environmentObject(HapticsManager.shared)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .preferredColorScheme(.light)
            }
        } else if !dataManager.appData.hasCompletedProfileSetup {
            ProfileSetupOnboardingView()
                .environmentObject(dataManager)
                .environmentObject(HapticsManager.shared)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.light) // Lock to light mode
        } else {
            MainTabView(dataManager: dataManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.light) // Lock to light mode
        }
    }
    
    private func configureTextInputAppearance() {
        // Configure UITextField appearance for light mode
        let textFieldAppearance = UITextField.appearance()
        textFieldAppearance.textColor = UIColor(Color.espressoBrown)
        textFieldAppearance.backgroundColor = UIColor(Color.creamWhite)
        
        // Configure UITextView appearance for light mode
        let textViewAppearance = UITextView.appearance()
        textViewAppearance.textColor = UIColor(Color.espressoBrown)
        textViewAppearance.backgroundColor = UIColor(Color.creamWhite)
    }
}
