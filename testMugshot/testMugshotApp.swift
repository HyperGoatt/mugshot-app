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
    @StateObject private var profileNavigator = ProfileNavigator()
    // PERF: HapticsManager singleton provided as environment object to prevent wasteful recreation in every view
    @StateObject private var hapticsManager = HapticsManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    // PERF: Debounce widget sync to max once per 5 minutes
    @State private var lastWidgetSyncTime: Date? = nil
    private let widgetSyncMinInterval: TimeInterval = 5 * 60 // 5 minutes
    
    init() {
        #if DEBUG
        print("🚀 [PERF] App init started")
        let initStart = CFAbsoluteTimeGetCurrent()
        #endif
        
        // Configure UITextField and UITextView to use light mode colors
        configureTextInputAppearance()
        // Log Supabase configuration once at launch to verify URL + anon key wiring
        SupabaseConfig.logConfigurationIfAvailable()
        SupabaseConfig.debugPrintConfig()
        
        #if DEBUG
        let initTime = (CFAbsoluteTimeGetCurrent() - initStart) * 1000
        print("🚀 [PERF] App init completed in \(String(format: "%.2f", initTime))ms")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(supabaseEnvironment)
                .environmentObject(tabCoordinator)
                .environmentObject(profileNavigator)
                .environmentObject(hapticsManager)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
                .onAppear {
                    profileNavigator.attach(tabCoordinator: tabCoordinator)
                }
        }
    }
    
    /// Handle scene phase changes to refresh widgets and data
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            #if DEBUG
            print("🚀 [PERF] App became active")
            #endif
            
            // App came to foreground - refresh widget data
            guard dataManager.appData.isAuthenticated && dataManager.appData.hasCompletedProfileSetup else {
                return
            }
            
            #if DEBUG
            print("[App] Scene became active - syncing widget data")
            #endif
            
            // Sync widget data when app becomes active
            syncWidgetData()
            
        case .inactive:
            break
            
        case .background:
            // Sync widget data when going to background to ensure fresh data
            guard dataManager.appData.isAuthenticated else { return }
            
            #if DEBUG
            print("[App] Scene going to background - final widget sync")
            #endif
            
            syncWidgetData()
            
        @unknown default:
            break
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
        // Remove artificial "Starting Up" screen and go straight to content
        // Launch Screen handles the initial brand impression
        rootContentView
            .onAppear {
                // Log routing decision after view appears
                let routingDecision = determineRoutingDecision()
                logRoutingDecision(routingDecision)
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
    
    /// Sync data to widgets (calls DataManager which includes friends visits)
    private func syncWidgetData() {
        // PERF: Debounce widget sync to prevent excessive updates
        let now = Date()
        if let lastSync = lastWidgetSyncTime,
           now.timeIntervalSince(lastSync) < widgetSyncMinInterval {
            #if DEBUG
            let timeSinceLastSync = now.timeIntervalSince(lastSync)
            print("🚀 [PERF] Widget sync skipped (last sync \(Int(timeSinceLastSync))s ago, min interval: \(Int(widgetSyncMinInterval))s)")
            #endif
            return
        }
        
        lastWidgetSyncTime = now
        
        Task { @MainActor in
            #if DEBUG
            print("🚀 [PERF] Widget sync initiated")
            #endif
            
            // IMPORTANT: Call dataManager.syncWidgetData() NOT WidgetSyncService directly
            // DataManager.syncWidgetData() fetches friends visits and passes them to the widget
            dataManager.syncWidgetData()
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
    // This handles BOTH regular notifications and SILENT push notifications
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Check if this is a silent push notification (content-available: 1)
        let aps = userInfo["aps"] as? [String: Any]
        let isContentAvailable = aps?["content-available"] as? Int == 1
        let hasAlert = aps?["alert"] != nil
        let isSilentPush = isContentAvailable && !hasAlert
        
        // Check the notification type
        let notificationType = userInfo["type"] as? String
        
        if isSilentPush && notificationType == "widget_update" {
            // SILENT PUSH: Widget update from friend's new visit
            print("[AppDelegate] 📱 Received SILENT push for widget update")
            
            Task { @MainActor in
                await PushNotificationManager.shared.handleSilentPushForWidgetUpdate(userInfo: userInfo)
                completionHandler(.newData)
            }
        } else if isSilentPush {
            // Other silent push types (future expansion)
            print("[AppDelegate] 📱 Received silent push (type: \(notificationType ?? "unknown"))")
            
            Task { @MainActor in
                // Generic silent push handling - just sync data
                DataManager.shared.syncWidgetData()
                completionHandler(.newData)
            }
        } else {
            // Regular visible notification
            print("[AppDelegate] 🔔 Received remote notification in background")
            
            Task { @MainActor in
                PushNotificationManager.shared.handleNotificationFromUserInfo(userInfo)
            }
            completionHandler(.newData)
        }
    }
}
