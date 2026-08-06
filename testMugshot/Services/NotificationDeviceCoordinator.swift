import Combine
import UIKit
@preconcurrency import UserNotifications

/// Owns the narrow boundary between iOS notification authorization and
/// Mugshot's caller-bound device RPCs. The last token is retained only as an
/// installation claim hint and is never registered unless both the current
/// account and its server preference allow push.
@MainActor
final class NotificationDeviceCoordinator: ObservableObject {
    static let shared = NotificationDeviceCoordinator()

    private static let tokenKey = "MugshotActivity.lastAPNSToken.v2"
    private static let ownershipUncertainKey = "MugshotActivity.pushOwnershipUncertain.v2"

    @Published private(set) var capability: ActivityPushCapability
    @Published private(set) var permissionState: ActivityPushPermissionState = .notRequested
    @Published private(set) var registrationState: ActivityRegistrationState = .idle

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let installationID: UUID
    private var accountID: UUID?
    private var serverPushEnabled = false
    private var token: String?
    private var ownershipUncertain = false

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard,
        capability: ActivityPushCapability? = nil
    ) {
        self.center = center
        self.defaults = defaults
        self.capability = capability ?? Self.detectCapability()

        let key = "MugshotActivity.installationID.v1"
        if let stored = defaults.string(forKey: key),
           let identifier = UUID(uuidString: stored) {
            installationID = identifier
        } else {
            let identifier = UUID()
            installationID = identifier
            defaults.set(identifier.uuidString.lowercased(), forKey: key)
        }
        token = defaults.string(forKey: Self.tokenKey)
        ownershipUncertain = defaults.bool(forKey: Self.ownershipUncertainKey)
    }

    func activate(accountID newAccountID: UUID?) async {
        guard accountID != newAccountID else {
            await refreshPermission()
            guard accountID == newAccountID else { return }
            await reconcileRegistration(expectedAccountID: newAccountID)
            return
        }

        accountID = newAccountID
        token = defaults.string(forKey: Self.tokenKey)
        serverPushEnabled = false
        registrationState = .idle
        await refreshPermission()
        guard let newAccountID,
              accountID == newAccountID else { return }

        do {
            let client = try SupabaseClientProvider.shared.client()
            guard client.auth.currentUser?.id == newAccountID else { return }
            let enabled = try await ActivityService(client: client).preferences(
                accountID: newAccountID
            ).pushEnabled
            guard accountID == newAccountID,
                  client.auth.currentUser?.id == newAccountID else { return }
            serverPushEnabled = enabled
            await reconcileRegistration(expectedAccountID: newAccountID)
        } catch ActivityServiceError.notificationPreferencesUnavailable {
            guard accountID == newAccountID else { return }
            registrationState = .failed("Push isn’t available yet. In-app Activity still works.")
        } catch {
            guard accountID == newAccountID else { return }
            // In-app activity remains available. Do not register a token when
            // the account's current push preference cannot be proven.
            registrationState = .failed("Push settings couldn’t be verified. In-app activity is still available.")
        }
    }

    func refreshPermission() async {
        guard capability.isConfigured else {
            permissionState = .unavailable
            return
        }
        let settings = await center.notificationSettings()
        permissionState = Self.permissionState(for: settings.authorizationStatus)
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard capability.isConfigured else {
            permissionState = .unavailable
            return false
        }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshPermission()
            await reconcileRegistration(expectedAccountID: accountID)
            return permissionState == .authorized || permissionState == .provisional
        } catch {
            registrationState = .failed("iOS couldn’t finish notification permission. You can try again in Settings.")
            await refreshPermission()
            return false
        }
    }

    func applyPushPreference(enabled: Bool, accountID expectedAccountID: UUID) async {
        guard accountID == expectedAccountID else { return }
        serverPushEnabled = enabled
        if enabled {
            await reconcileRegistration(expectedAccountID: expectedAccountID)
        } else {
            await unregisterCurrentInstallation(
                clearAccount: false,
                expectedAccountID: expectedAccountID
            )
        }
    }

    func unregisterForSignOut() async {
        await unregisterCurrentInstallation(clearAccount: true)
    }

    func deactivateAfterAccountDeletion(accountID deletedAccountID: UUID) {
        guard accountID == deletedAccountID else { return }
        accountID = nil
        serverPushEnabled = false
        setOwnershipUncertain(false)
        registrationState = .idle
        UIApplication.shared.unregisterForRemoteNotifications()
        clearVisibleNotifications()
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let resolvedToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        if token != resolvedToken {
            token = resolvedToken
            defaults.set(resolvedToken, forKey: Self.tokenKey)
            setOwnershipUncertain(true)
        }
        Task { await registerCurrentTokenIfAllowed() }
    }

    func didFailToRegisterForRemoteNotifications(_ error: Error) {
        guard capability.isConfigured else { return }
        registrationState = .failed("This device couldn’t register for push. In-app activity is still available.")
    }

    private func reconcileRegistration(expectedAccountID: UUID?) async {
        guard let expectedAccountID,
              accountID == expectedAccountID,
              serverPushEnabled,
              capability.isConfigured else { return }
        guard permissionState == .authorized || permissionState == .provisional else { return }
        registrationState = .registering
        do {
            guard case .configured(let environment) = capability else { return }
            let client = try SupabaseClientProvider.shared.client()
            guard client.auth.currentUser?.id == expectedAccountID else { return }
            try await ActivityService(client: client).claimDeviceInstallation(
                installationID: installationID,
                knownPushToken: token,
                environment: environment,
                accountID: expectedAccountID
            )
            guard accountID == expectedAccountID,
                  client.auth.currentUser?.id == expectedAccountID else { return }
            setOwnershipUncertain(false)
            UIApplication.shared.registerForRemoteNotifications()
            await registerCurrentTokenIfAllowed(expectedAccountID: expectedAccountID)
        } catch {
            guard accountID == expectedAccountID else { return }
            UIApplication.shared.unregisterForRemoteNotifications()
            setOwnershipUncertain(true)
            registrationState = .failed("Push ownership couldn’t be verified. In-app activity is still available.")
        }
    }

    private func registerCurrentTokenIfAllowed(expectedAccountID: UUID? = nil) async {
        guard let activeAccountID = accountID,
              expectedAccountID == nil || expectedAccountID == activeAccountID,
              serverPushEnabled,
              permissionState == .authorized || permissionState == .provisional,
              case .configured(let environment) = capability,
              let token else { return }
        do {
            let client = try SupabaseClientProvider.shared.client()
            guard client.auth.currentUser?.id == activeAccountID else { return }
            try await ActivityService(client: client).registerDevice(
                installationID: installationID,
                pushToken: token,
                environment: environment,
                accountID: activeAccountID
            )
            guard accountID == activeAccountID,
                  client.auth.currentUser?.id == activeAccountID else { return }
            setOwnershipUncertain(false)
            registrationState = .registered
        } catch {
            guard accountID == activeAccountID else { return }
            UIApplication.shared.unregisterForRemoteNotifications()
            setOwnershipUncertain(true)
            registrationState = .failed("Push registration couldn’t reach Mugshot. In-app activity is still available.")
        }
    }

    private func unregisterCurrentInstallation(
        clearAccount: Bool,
        expectedAccountID: UUID? = nil
    ) async {
        let activeAccountID = accountID
        guard expectedAccountID == nil || expectedAccountID == activeAccountID else { return }
        var unregisterConfirmed = activeAccountID == nil
        if let activeAccountID {
            do {
                let client = try SupabaseClientProvider.shared.client()
                if client.auth.currentUser?.id == activeAccountID {
                    try await ActivityService(client: client)
                        .unregisterDevice(
                            installationID: installationID,
                            accountID: activeAccountID
                        )
                    unregisterConfirmed = true
                }
            } catch {
                // Best effort: server rows also cascade on account deletion,
                // and token reassignment removes stale ownership on next login.
            }
        }
        guard accountID == activeAccountID else { return }
        UIApplication.shared.unregisterForRemoteNotifications()
        setOwnershipUncertain(!unregisterConfirmed)
        clearVisibleNotifications()
        registrationState = .idle
        if clearAccount {
            accountID = nil
            serverPushEnabled = false
        }
    }

    func acceptsPush(for recipientID: UUID) -> Bool {
        accountID == recipientID && !ownershipUncertain
    }

    private func setOwnershipUncertain(_ value: Bool) {
        ownershipUncertain = value
        defaults.set(value, forKey: Self.ownershipUncertainKey)
    }

    private func clearVisibleNotifications() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    private static func permissionState(
        for status: UNAuthorizationStatus
    ) -> ActivityPushPermissionState {
        switch status {
        case .notDetermined: .notRequested
        case .denied: .denied
        case .authorized: .authorized
        case .provisional, .ephemeral: .provisional
        @unknown default: .unsupported
        }
    }

    private static func detectCapability() -> ActivityPushCapability {
#if targetEnvironment(simulator)
        return .unavailable("Push requires a signed device build. In-app activity works in Simulator.")
#elseif MUGSHOT_PUSH_CAPABLE
        return .configured(environment: "production")
#else
        return .unavailable("This build does not include the APNs entitlement. In-app activity remains available.")
#endif
    }
}

final class MugshotNotificationAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            if let cafeID = NearbyCafeNotificationRoute.resolve(userInfo: userInfo) {
                Task { @MainActor in
                    NearbyCafeReminderRouter.shared.enqueue(cafeID: cafeID)
                }
            } else if let route = ActivityPushRouteEnvelope.resolve(userInfo: userInfo) {
                Task { @MainActor in
                    ActivityDeepLinkRouter.shared.enqueue(
                        route.destination,
                        accountID: route.accountID
                    )
                }
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationDeviceCoordinator.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            NotificationDeviceCoordinator.shared.didFailToRegisterForRemoteNotifications(error)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if NearbyCafeNotificationRoute.resolve(
            userInfo: notification.request.content.userInfo
        ) != nil {
            return [.banner, .list, .sound]
        }
        guard let route = ActivityPushRouteEnvelope.resolve(
            userInfo: notification.request.content.userInfo
        ), await MainActor.run(body: {
            NotificationDeviceCoordinator.shared.acceptsPush(for: route.accountID)
        }) else { return [] }
        return [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let cafeID = NearbyCafeNotificationRoute.resolve(userInfo: userInfo) {
            await MainActor.run {
                NearbyCafeReminderRouter.shared.enqueue(cafeID: cafeID)
            }
            return
        }
        guard let route = ActivityPushRouteEnvelope.resolve(userInfo: userInfo) else { return }
        guard await MainActor.run(body: {
            NotificationDeviceCoordinator.shared.acceptsPush(for: route.accountID)
        }) else { return }
        await MainActor.run {
            ActivityDeepLinkRouter.shared.enqueue(
                route.destination,
                accountID: route.accountID
            )
        }
    }
}
