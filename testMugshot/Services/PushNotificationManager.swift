//
//  PushNotificationManager.swift
//  testMugshot
//
//  Manages push notification registration, token handling, and routing
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    
    @Published var isRegistered = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let dataManager: DataManager
    private let deviceService: SupabaseUserDeviceService
    private var currentDeviceToken: String?
    
    private init(
        dataManager: DataManager? = nil,
        deviceService: SupabaseUserDeviceService? = nil
    ) {
        // Access MainActor-isolated properties inside the init body
        self.dataManager = dataManager ?? DataManager.shared
        self.deviceService = deviceService ?? SupabaseUserDeviceService.shared
        super.init()
        
        // Set up as UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Check current authorization status
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization & Registration
    
    /// Request notification permissions and register for remote notifications
    /// Should be called after user signs in or completes profile setup
    func requestAuthorizationAndRegister() async {
        print("[Push] Requesting notification authorization...")
        
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                print("✅ [Push] Notification authorization granted")
                await checkAuthorizationStatus()
                
                // Register for remote notifications
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ [Push] Notification authorization denied")
                await checkAuthorizationStatus()
            }
        } catch {
            print("❌ [Push] Error requesting authorization: \(error.localizedDescription)")
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isRegistered = settings.authorizationStatus == .authorized
        print("[Push] Authorization status: \(isRegistered ? "authorized" : "not authorized")")
    }
    
    // MARK: - Token Management
    
    /// Called by AppDelegate when device token is received from APNs
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Push] Received device token: \(tokenString.prefix(20))...")
        
        currentDeviceToken = tokenString
        
        // Only register token if user is authenticated
        guard dataManager.appData.isUserAuthenticated,
              let userId = dataManager.appData.supabaseUserId else {
            print("⚠️ [Push] User not authenticated, storing token for later registration")
            return
        }
        
        Task {
            await registerTokenWithSupabase(token: tokenString, userId: userId)
        }
    }
    
    /// Called by AppDelegate when token registration fails
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("❌ [Push] Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    /// Register or update device token in Supabase
    private func registerTokenWithSupabase(token: String, userId: String) async {
        print("[Push] Registering device token for userId=\(userId.prefix(8))...")
        
        do {
            // Ensure we have a valid session
            guard let session = SupabaseAuthService.shared.restoreSession() else {
                print("⚠️ [Push] No session found, cannot register token")
                return
            }
            
            // Set access token on client
            SupabaseClientProvider.shared.accessToken = session.accessToken
            
            try await deviceService.upsertDeviceToken(userId: userId, token: token, platform: "ios")
            print("✅ [Push] Device token registered successfully in Supabase")
        } catch {
            print("❌ [Push] Error registering device token: \(error.localizedDescription)")
        }
    }
    
    /// Re-register token if we have a stored token but user wasn't authenticated when it was received
    func reRegisterTokenIfNeeded() async {
        guard let token = currentDeviceToken,
              dataManager.appData.isUserAuthenticated,
              let userId = dataManager.appData.supabaseUserId else {
            return
        }
        
        await registerTokenWithSupabase(token: token, userId: userId)
    }
    
    // MARK: - Notification Handling
    
    /// Handle notification when app is in foreground
    func handleNotificationInForeground(_ notification: UNNotification) {
        print("[Push] Notification received in foreground")
        
        guard let payload = PushNotificationPayload(from: notification) else {
            print("⚠️ [Push] Could not parse notification payload")
            return
        }
        
        // For v1, just log and update badge
        // In future, we can show an in-app banner here
        print("[Push] Notification type: \(payload.type.rawValue), tapAction: \(payload.tapAction.rawValue)")
        
        // Refresh notifications to update badge
        Task {
            await dataManager.refreshNotifications()
        }
    }
    
    /// Handle notification tap (app was in background or closed)
    func handleNotificationTap(_ notification: UNNotification) {
        print("[Push] Notification tapped - routing to destination")
        
        guard let payload = PushNotificationPayload(from: notification) else {
            print("⚠️ [Push] Could not parse notification payload, opening default screen")
            // Fallback: open Feed tab
            openDefaultScreen()
            return
        }
        
        routeToDestination(payload: payload)
    }
    
    /// Handle notification from userInfo (for background/launch scenarios)
    func handleNotificationFromUserInfo(_ userInfo: [AnyHashable: Any]) {
        print("[Push] Handling notification from userInfo")
        
        guard let payload = PushNotificationPayload(from: userInfo) else {
            print("⚠️ [Push] Could not parse notification payload from userInfo")
            openDefaultScreen()
            return
        }
        
        routeToDestination(payload: payload)
    }
    
    // MARK: - Routing
    
    private func routeToDestination(payload: PushNotificationPayload) {
        // Get TabCoordinator from the app
        // We'll need to access it through the environment or a shared instance
        // For now, we'll use a notification-based approach or direct access
        
        switch payload.tapAction {
        case .visitDetail:
            if let visitId = payload.visitId {
                routeToVisitDetail(visitId: visitId)
            } else {
                print("⚠️ [Push] visitDetail action but no visitId provided")
                openDefaultScreen()
            }
            
        case .friendProfile:
            if let friendUserId = payload.friendUserId {
                routeToFriendProfile(userId: friendUserId)
            } else {
                print("⚠️ [Push] friendProfile action but no friendUserId provided")
                openDefaultScreen()
            }
            
        case .friendsFeed:
            routeToFriendsFeed()
            
        case .notifications:
            routeToNotifications()
            
        case .friendRequests:
            routeToFriendRequests()
        }
    }
    
    private func routeToVisitDetail(visitId: UUID) {
        print("[Push] Routing to visit detail: \(visitId)")
        
        // Post notification that TabCoordinator can listen to
        NotificationCenter.default.post(
            name: .pushNotificationNavigateToVisit,
            object: nil,
            userInfo: ["visitId": visitId]
        )
    }
    
    private func routeToFriendProfile(userId: String) {
        print("[Push] Routing to friend profile: \(userId.prefix(8))...")
        
        NotificationCenter.default.post(
            name: .pushNotificationNavigateToProfile,
            object: nil,
            userInfo: ["userId": userId]
        )
    }
    
    private func routeToFriendsFeed() {
        print("[Push] Routing to friends feed")
        
        NotificationCenter.default.post(
            name: .pushNotificationNavigateToFeed,
            object: nil
        )
    }
    
    private func routeToNotifications() {
        print("[Push] Routing to notifications")
        
        NotificationCenter.default.post(
            name: .pushNotificationNavigateToNotifications,
            object: nil
        )
    }
    
    private func routeToFriendRequests() {
        print("[Push] Routing to friend requests")
        
        NotificationCenter.default.post(
            name: .pushNotificationNavigateToFriendRequests,
            object: nil
        )
    }
    
    private func openDefaultScreen() {
        print("[Push] Opening default screen (Feed)")
        routeToFriendsFeed()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// Called when notification is received while app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            handleNotificationInForeground(notification)
        }
        
        // For v1, don't show banner in foreground (just update badge)
        // In future, we can show a custom in-app banner
        completionHandler([.badge, .sound])
    }
    
    /// Called when user taps a notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            handleNotificationTap(response.notification)
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let pushNotificationNavigateToVisit = Notification.Name("pushNotificationNavigateToVisit")
    static let pushNotificationNavigateToProfile = Notification.Name("pushNotificationNavigateToProfile")
    static let pushNotificationNavigateToFeed = Notification.Name("pushNotificationNavigateToFeed")
    static let pushNotificationNavigateToNotifications = Notification.Name("pushNotificationNavigateToNotifications")
    static let pushNotificationNavigateToFriendRequests = Notification.Name("pushNotificationNavigateToFriendRequests")
}

