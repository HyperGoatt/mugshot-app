//
//  testMugshotApp.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

@main
struct testMugshotApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var supabaseEnvironment = SupabaseEnvironment()
    @StateObject private var tabCoordinator = TabCoordinator()
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
                .environmentObject(tabCoordinator)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    /// Handle deep links from widgets and other sources
    private func handleDeepLink(_ url: URL) {
        print("[App] Received deep link: \(url.absoluteString)")
        
        // Only handle widget deep links when the main app is visible
        guard dataManager.appData.isAuthenticated && dataManager.appData.hasCompletedProfileSetup else {
            print("[App] Cannot handle deep link - user not fully authenticated")
            return
        }
        
        Task { @MainActor in
            let handled = WidgetDeepLinkHandler.shared.handleDeepLink(
                url: url,
                tabCoordinator: tabCoordinator,
                dataManager: dataManager
            )
            
            if !handled {
                print("[App] Deep link was not handled: \(url.absoluteString)")
            }
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
        // FLOW LOGIC:
        // 1. If not authenticated -> show Auth (Login/Sign Up)
        // 2. If authenticated but email not verified -> show Verify Email
        // 3. If new signup AND hasn't seen marketing onboarding -> show Marketing Onboarding
        // 4. If hasn't completed profile setup -> show Profile Setup
        // 5. Otherwise -> show Main App
        //
        // Key distinction: Only NEW SIGNUPS see marketing onboarding, NOT returning logins
        
        if !dataManager.appData.isAuthenticated {
            // Step 1: Not authenticated - show Login/Sign Up screen
            AuthFlowRootView()
                .environmentObject(dataManager)
                .environmentObject(HapticsManager.shared)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.light)
        } else if !dataManager.appData.hasEmailVerified {
            // Step 2: Authenticated but email not verified
            if let email = dataManager.appData.currentUserEmail {
                VerifyEmailView(
                    email: email,
                    onEmailVerified: {
                        print("✅ Email verified - proceeding to next step")
                    },
                    onResendEmail: {
                        print("📧 Resend email requested")
                    },
                    onBack: {
                        print("⬅️ Back button tapped - returning to auth flow")
                        dataManager.appData.isUserAuthenticated = false
                        dataManager.appData.hasEmailVerified = false
                        dataManager.appData.isNewAccountSignup = false
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
        } else if dataManager.appData.isNewAccountSignup && !dataManager.appData.hasSeenMarketingOnboarding {
            // Step 3: NEW signups only - show marketing onboarding
            // Returning users who login skip this entirely
            MugshotOnboardingView(dataManager: dataManager)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.light)
        } else if !dataManager.appData.hasCompletedProfileSetup {
            // Step 4: Profile setup needed (only for new signups - returning users have profiles)
            ProfileSetupOnboardingView()
                .environmentObject(dataManager)
                .environmentObject(HapticsManager.shared)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.light)
        } else {
            // Step 5: Fully authenticated and setup - show main app
            MainTabView(dataManager: dataManager, tabCoordinator: tabCoordinator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.light)
                .onAppear {
                    // Sync widget data when main app becomes visible
                    syncWidgetData()
                }
        }
    }
    
    /// Sync data to widgets
    private func syncWidgetData() {
        Task { @MainActor in
            WidgetSyncService.shared.syncWidgetData(dataManager: dataManager)
        }
    }
    
    private struct RoutingDecision {
        let isUserAuthenticated: Bool
        let hasEmailVerified: Bool
        let isNewAccountSignup: Bool
        let hasSeenMarketingOnboarding: Bool
        let hasCompletedProfileSetup: Bool
        let destination: String
    }
    
    private func determineRoutingDecision() -> RoutingDecision {
        let appData = dataManager.appData
        let isAuthenticated = appData.isUserAuthenticated
        let emailVerified = appData.hasEmailVerified
        let isNewSignup = appData.isNewAccountSignup
        let hasSeenMarketing = appData.hasSeenMarketingOnboarding
        let profileSetup = appData.hasCompletedProfileSetup
        
        // New routing order:
        // 1. Not authenticated -> AuthFlow
        // 2. Not email verified -> VerifyEmail
        // 3. New signup AND hasn't seen marketing -> MarketingOnboarding
        // 4. Not profile setup -> ProfileSetup
        // 5. Otherwise -> MainTabs
        let destination: String
        if !isAuthenticated {
            destination = "AuthFlow"
        } else if !emailVerified {
            destination = "VerifyEmail"
        } else if isNewSignup && !hasSeenMarketing {
            destination = "MarketingOnboarding"
        } else if !profileSetup {
            destination = "ProfileSetup"
        } else {
            destination = "MainTabs"
        }
        
        return RoutingDecision(
            isUserAuthenticated: isAuthenticated,
            hasEmailVerified: emailVerified,
            isNewAccountSignup: isNewSignup,
            hasSeenMarketingOnboarding: hasSeenMarketing,
            hasCompletedProfileSetup: profileSetup,
            destination: destination
        )
    }
    
    private func logRoutingDecision(_ decision: RoutingDecision) {
        print("[RootRouter] Launch state:")
        print("  - isUserAuthenticated: \(decision.isUserAuthenticated)")
        print("  - hasEmailVerified: \(decision.hasEmailVerified)")
        print("  - isNewAccountSignup: \(decision.isNewAccountSignup)")
        print("  - hasSeenMarketingOnboarding: \(decision.hasSeenMarketingOnboarding)")
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
