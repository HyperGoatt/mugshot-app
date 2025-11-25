//
//  testMugshotApp.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import UIKit
import UserNotifications

@main
struct testMugshotApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var supabaseEnvironment = SupabaseEnvironment()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
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
        } else {
            rootContentView
                .onAppear {
                    // Log routing decision after bootstrap completes
                    let routingDecision = determineRoutingDecision()
                    logRoutingDecision(routingDecision)
                }
        }
    }
    
    @ViewBuilder
    private var rootContentView: some View {
        if !dataManager.appData.hasSeenMarketingOnboarding {
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
    
    private struct RoutingDecision {
        let hasSeenMarketingOnboarding: Bool
        let isUserAuthenticated: Bool
        let hasEmailVerified: Bool
        let hasCompletedProfileSetup: Bool
        let destination: String
    }
    
    private func determineRoutingDecision() -> RoutingDecision {
        let appData = dataManager.appData
        let hasSeenMarketing = appData.hasSeenMarketingOnboarding
        let isAuthenticated = appData.isUserAuthenticated
        let emailVerified = appData.hasEmailVerified
        let profileSetup = appData.hasCompletedProfileSetup
        
        let destination: String
        if !hasSeenMarketing {
            destination = "MarketingOnboarding"
        } else if !isAuthenticated {
            destination = "AuthFlow"
        } else if !emailVerified {
            destination = "VerifyEmail"
        } else if !profileSetup {
            destination = "ProfileSetup"
        } else {
            destination = "MainTabs"
        }
        
        return RoutingDecision(
            hasSeenMarketingOnboarding: hasSeenMarketing,
            isUserAuthenticated: isAuthenticated,
            hasEmailVerified: emailVerified,
            hasCompletedProfileSetup: profileSetup,
            destination: destination
        )
    }
    
    private func logRoutingDecision(_ decision: RoutingDecision) {
        print("[RootRouter] Launch state:")
        print("  - hasSeenMarketingOnboarding: \(decision.hasSeenMarketingOnboarding)")
        print("  - isUserAuthenticated: \(decision.isUserAuthenticated)")
        print("  - hasEmailVerified: \(decision.hasEmailVerified)")
        print("  - hasCompletedProfileSetup: \(decision.hasCompletedProfileSetup)")
        print("[RootRouter] Showing: \(decision.destination)")
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

// MARK: - AppDelegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[AppDelegate] Application did finish launching")
        
        // Handle notification that launched the app
        if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            print("[AppDelegate] App launched from notification")
            // Delay handling slightly to ensure app is fully initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task { @MainActor in
                    PushNotificationManager.shared.handleNotificationFromUserInfo(notification)
                }
            }
        }
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("[AppDelegate] Registered for remote notifications")
        Task { @MainActor in
            PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
    
    // Handle notification received while app is in background
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("[AppDelegate] Received remote notification in background")
        Task { @MainActor in
            PushNotificationManager.shared.handleNotificationFromUserInfo(userInfo)
        }
        completionHandler(.newData)
    }
}
