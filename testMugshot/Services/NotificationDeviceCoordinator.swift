import Combine
import UIKit
@preconcurrency import UserNotifications

/// Owns the narrow boundary between shared iOS notification authorization and
/// Mugshot's caller-bound device RPCs. The APNs token is retained only as an
/// installation claim hint and is never sent unless the current account,
/// backend capabilities, preference, permission, and APNs environment agree.
@MainActor
final class NotificationDeviceCoordinator: ObservableObject {
    static let shared = NotificationDeviceCoordinator()

    private static let tokenKey = "MugshotActivity.lastAPNSToken.v2"
    private static let ownershipUncertainKey = "MugshotActivity.pushOwnershipUncertain.v2"
    private static let installationKey = "MugshotActivity.installationID.v1"

    @Published private(set) var capability: ActivityPushCapability
    @Published private(set) var backendState: ActivityPushBackendState = .unchecked
    @Published private(set) var permissionState: ActivityPushPermissionState = .notRequested
    @Published private(set) var registrationState: ActivityRegistrationState = .idle

    private let authorizationProvider: any NotificationAuthorizationProviding
    private let remoteRegistrar: any RemoteNotificationRegistering
    private let badgeUpdater: any ActivityBadgeUpdating
    private let clientFactory: any ActivityNotificationClientCreating
    private let defaults: UserDefaults
    private let installationID: UUID
    private let captureAnalytics: (MugshotAnalyticsEvent) -> Void

    private var accountID: UUID?
    private var activationID = UUID()
    private var deviceService: (any ActivityDeviceServicing)?
    private var serverPushEnabled = false
    private var token: String?
    private var ownershipUncertain = false

    init(
        authorizationProvider: (any NotificationAuthorizationProviding)? = nil,
        remoteRegistrar: (any RemoteNotificationRegistering)? = nil,
        badgeUpdater: (any ActivityBadgeUpdating)? = nil,
        clientFactory: (any ActivityNotificationClientCreating)? = nil,
        defaults: UserDefaults = .standard,
        capability: ActivityPushCapability? = nil,
        installationID: UUID? = nil,
        captureAnalytics: @escaping (MugshotAnalyticsEvent) -> Void = {
            MugshotAnalytics.shared.capture($0)
        }
    ) {
        self.authorizationProvider = authorizationProvider
            ?? SystemNotificationAuthorizationProvider()
        self.remoteRegistrar = remoteRegistrar ?? SystemRemoteNotificationRegistrar()
        self.badgeUpdater = badgeUpdater ?? SystemActivityBadgeUpdater.shared
        self.clientFactory = clientFactory ?? LiveActivityNotificationClientFactory()
        self.defaults = defaults
        self.capability = capability ?? Self.detectCapability()
        self.captureAnalytics = captureAnalytics

        if let installationID {
            self.installationID = installationID
        } else if let stored = defaults.string(forKey: Self.installationKey),
                  let identifier = UUID(uuidString: stored) {
            self.installationID = identifier
        } else {
            let identifier = UUID()
            self.installationID = identifier
            defaults.set(identifier.uuidString.lowercased(), forKey: Self.installationKey)
        }
        token = defaults.string(forKey: Self.tokenKey)
        ownershipUncertain = defaults.bool(forKey: Self.ownershipUncertainKey)
    }

    func activate(accountID newAccountID: UUID?) async {
        let currentActivationID = UUID()
        activationID = currentActivationID
        accountID = newAccountID
        deviceService = nil
        token = defaults.string(forKey: Self.tokenKey)
        serverPushEnabled = false
        backendState = newAccountID == nil ? .unchecked : .checking
        registrationState = .idle
        await refreshPermission(reconcileRegistration: false)
        guard activationID == currentActivationID else { return }

        guard let newAccountID else {
            remoteRegistrar.unregisterForRemoteNotifications()
            await badgeUpdater.setBadgeCount(0)
            return
        }

        do {
            let service = try clientFactory.makeDeviceService(accountID: newAccountID)
            let capabilities = try await service.backendCapabilities()
            guard activationID == currentActivationID,
                  accountID == newAccountID else { return }
            guard let unavailableReason = Self.unavailableBackendReason(capabilities) else {
                backendState = .unavailable(
                    "Mugshot’s push capability response was incomplete. In-app Activity still works."
                )
                registrationState = .failed(
                    "Push capability couldn’t be verified. In-app Activity is still available."
                )
                remoteRegistrar.unregisterForRemoteNotifications()
                captureRegistration(.capabilityUnavailable)
                return
            }
            if !unavailableReason.isEmpty {
                backendState = .unavailable(unavailableReason)
                registrationState = .failed(unavailableReason)
                remoteRegistrar.unregisterForRemoteNotifications()
                captureRegistration(.capabilityUnavailable)
                return
            }

            let preferences = try await service.preferences()
            guard activationID == currentActivationID,
                  accountID == newAccountID else { return }
            deviceService = service
            backendState = .available(schemaRelease: capabilities.schemaRelease)
            serverPushEnabled = preferences.pushEnabled
            await reconcileRegistration(
                expectedAccountID: newAccountID,
                expectedActivationID: currentActivationID
            )
        } catch ActivityServiceError.backendCapabilitiesUnavailable {
            handleCapabilityFailure(
                "This Mugshot backend does not advertise push capabilities. In-app Activity still works.",
                activationID: currentActivationID,
                accountID: newAccountID
            )
        } catch ActivityServiceError.backendCapabilitiesMalformed, DecodingError.dataCorrupted,
                DecodingError.keyNotFound, DecodingError.typeMismatch, DecodingError.valueNotFound {
            handleCapabilityFailure(
                "Mugshot couldn’t verify the backend push contract. In-app Activity still works.",
                activationID: currentActivationID,
                accountID: newAccountID
            )
        } catch ActivityServiceError.notificationPreferencesUnavailable {
            handleCapabilityFailure(
                "Push preferences are unavailable in this backend. In-app Activity still works.",
                activationID: currentActivationID,
                accountID: newAccountID
            )
        } catch {
            handleCapabilityFailure(
                "Mugshot couldn’t reach the push capability service. In-app Activity still works.",
                activationID: currentActivationID,
                accountID: newAccountID
            )
        }
    }

    func refreshPermission(reconcileRegistration shouldReconcile: Bool = true) async {
        let previousState = permissionState
        permissionState = await authorizationProvider.currentPermissionState()
        guard shouldReconcile,
              previousState != permissionState else { return }
        await reconcileRegistration(
            expectedAccountID: accountID,
            expectedActivationID: activationID
        )
    }

    @discardableResult
    func requestAuthorization(source: ActivityNotificationEducationSource) async -> Bool {
        captureAnalytics(.notificationEducationViewed(source: source))
        if source.requiresRemotePush, !capability.isConfigured {
            captureAnalytics(.notificationPermissionResult(.unavailable, source: source))
            return false
        }

        do {
            _ = try await authorizationProvider.requestAuthorization()
            await refreshPermission(reconcileRegistration: false)
            captureAnalytics(.notificationPermissionResult(permissionState, source: source))
            await reconcileRegistration(
                expectedAccountID: accountID,
                expectedActivationID: activationID
            )
            return permissionState == .authorized || permissionState == .provisional
        } catch {
            registrationState = .failed(
                "iOS couldn’t finish notification permission. You can try again in Settings."
            )
            await refreshPermission(reconcileRegistration: false)
            captureAnalytics(.notificationPermissionResult(.unsupported, source: source))
            return false
        }
    }

    func applyPushPreference(enabled: Bool, accountID expectedAccountID: UUID) async {
        guard accountID == expectedAccountID else { return }
        serverPushEnabled = enabled
        if enabled {
            await reconcileRegistration(
                expectedAccountID: expectedAccountID,
                expectedActivationID: activationID
            )
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
        activationID = UUID()
        accountID = nil
        deviceService = nil
        serverPushEnabled = false
        backendState = .unchecked
        setOwnershipUncertain(false)
        registrationState = .idle
        remoteRegistrar.unregisterForRemoteNotifications()
        authorizationProvider.clearVisibleNotifications()
        Task { await badgeUpdater.setBadgeCount(0) }
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) async {
        let resolvedToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        let hadToken = token != nil
        let rotated = token != resolvedToken
        if rotated {
            token = resolvedToken
            defaults.set(resolvedToken, forKey: Self.tokenKey)
            setOwnershipUncertain(true)
        }
        await registerCurrentTokenIfAllowed()
        if rotated, hadToken {
            captureRegistration(
                registrationState == .registered ? .tokenRotated : .backendFailed
            )
        }
    }

    func didFailToRegisterForRemoteNotifications(_ error: Error) {
        guard capability.isConfigured else { return }
        registrationState = .failed(
            "This iPhone couldn’t register with APNs. In-app Activity is still available."
        )
        captureRegistration(.apnsFailed)
    }

    func acceptsPush(for recipientID: UUID) -> Bool {
        accountID == recipientID && !ownershipUncertain
    }

    private func reconcileRegistration(
        expectedAccountID: UUID?,
        expectedActivationID: UUID
    ) async {
        guard let expectedAccountID,
              activationID == expectedActivationID,
              accountID == expectedAccountID,
              serverPushEnabled,
              case .available = backendState,
              capability.isConfigured,
              let deviceService else { return }
        guard permissionState == .authorized || permissionState == .provisional else {
            remoteRegistrar.unregisterForRemoteNotifications()
            return
        }
        registrationState = .registering
        do {
            guard case .configured(let environment) = capability else { return }
            try await deviceService.claimDeviceInstallation(
                installationID: installationID,
                knownPushToken: token,
                environment: environment
            )
            guard activationID == expectedActivationID,
                  accountID == expectedAccountID else { return }
            setOwnershipUncertain(false)
            remoteRegistrar.registerForRemoteNotifications()
            await registerCurrentTokenIfAllowed(
                expectedAccountID: expectedAccountID,
                expectedActivationID: expectedActivationID
            )
        } catch {
            guard activationID == expectedActivationID,
                  accountID == expectedAccountID else { return }
            remoteRegistrar.unregisterForRemoteNotifications()
            setOwnershipUncertain(true)
            registrationState = .failed(
                "Push ownership couldn’t be verified with Mugshot. In-app Activity is still available."
            )
            captureRegistration(.ownershipFailed)
        }
    }

    private func registerCurrentTokenIfAllowed(
        expectedAccountID: UUID? = nil,
        expectedActivationID: UUID? = nil
    ) async {
        let activeActivationID = activationID
        guard expectedActivationID == nil || expectedActivationID == activeActivationID,
              let activeAccountID = accountID,
              expectedAccountID == nil || expectedAccountID == activeAccountID,
              serverPushEnabled,
              permissionState == .authorized || permissionState == .provisional,
              case .available = backendState,
              case .configured(let environment) = capability,
              let token,
              let deviceService else { return }
        do {
            try await deviceService.registerDevice(
                installationID: installationID,
                pushToken: token,
                environment: environment,
                supportsBadgeSync: true
            )
            guard activationID == activeActivationID,
                  accountID == activeAccountID else { return }
            setOwnershipUncertain(false)
            registrationState = .registered
            captureRegistration(.registered)
        } catch {
            guard activationID == activeActivationID,
                  accountID == activeAccountID else { return }
            remoteRegistrar.unregisterForRemoteNotifications()
            setOwnershipUncertain(true)
            registrationState = .failed(
                "Push registration couldn’t reach Mugshot. In-app Activity is still available."
            )
            captureRegistration(.backendFailed)
        }
    }

    private func unregisterCurrentInstallation(
        clearAccount: Bool,
        expectedAccountID: UUID? = nil
    ) async {
        let activeAccountID = accountID
        let activeActivationID = activationID
        guard expectedAccountID == nil || expectedAccountID == activeAccountID else { return }
        var unregisterConfirmed = activeAccountID == nil
        if activeAccountID != nil, let deviceService {
            do {
                try await deviceService.unregisterDevice(installationID: installationID)
                unregisterConfirmed = true
            } catch {
                // Best effort: account deletion cascades device rows, while a
                // later login reclaims a matching token before registration.
            }
        }
        guard activationID == activeActivationID,
              accountID == activeAccountID else { return }
        remoteRegistrar.unregisterForRemoteNotifications()
        setOwnershipUncertain(!unregisterConfirmed)
        if clearAccount {
            authorizationProvider.clearVisibleNotifications()
            await badgeUpdater.setBadgeCount(0)
        }
        registrationState = .idle
        captureRegistration(unregisterConfirmed ? .unregistered : .offlineUnregister)
        if clearAccount {
            activationID = UUID()
            accountID = nil
            deviceService = nil
            serverPushEnabled = false
            backendState = .unchecked
        }
    }

    private func handleCapabilityFailure(
        _ message: String,
        activationID expectedActivationID: UUID,
        accountID expectedAccountID: UUID
    ) {
        guard activationID == expectedActivationID,
              accountID == expectedAccountID else { return }
        deviceService = nil
        backendState = .unavailable(message)
        registrationState = .failed(message)
        remoteRegistrar.unregisterForRemoteNotifications()
        captureRegistration(.capabilityUnavailable)
    }

    private func captureRegistration(_ result: ActivityNotificationRegistrationResult) {
        let environment: ActivityPushEnvironment?
        if case .configured(let configuredEnvironment) = capability {
            environment = configuredEnvironment
        } else {
            environment = nil
        }
        captureAnalytics(.notificationRegistrationResult(result, environment: environment))
    }

    private func setOwnershipUncertain(_ value: Bool) {
        ownershipUncertain = value
        defaults.set(value, forKey: Self.ownershipUncertainKey)
    }

    /// Returns nil only when the response itself is structurally inconsistent.
    /// A non-empty string names the first unavailable backend layer.
    private static func unavailableBackendReason(_ response: BackendCapabilitiesV1) -> String? {
        guard response.contractVersion == 1,
              !response.schemaRelease.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard response.capabilities.activityCenter else {
            return "The backend Activity contract is unavailable. In-app Activity will keep using its existing data path."
        }
        guard response.capabilities.notificationPreferences else {
            return "Push preferences are unavailable in this backend. In-app Activity still works."
        }
        guard response.capabilities.pushRegistration else {
            return "Device registration is unavailable in this backend. In-app Activity still works."
        }
        guard response.capabilities.pushBadgeSync else {
            return "This backend does not support authoritative badge sync, so this build will not register for push. In-app Activity still works."
        }
        return ""
    }

    static func resolvedCapability(
        isSimulator: Bool,
        sandboxBuild: Bool,
        productionBuild: Bool
    ) -> ActivityPushCapability {
        if isSimulator {
            return .unavailable(
                "Remote push requires a signed iPhone build. In-app Activity works in Simulator."
            )
        }
        if sandboxBuild { return .configured(environment: .sandbox) }
        if productionBuild { return .configured(environment: .production) }
        return .unavailable(
            "This build does not include an APNs entitlement. In-app Activity remains available."
        )
    }

    private static func detectCapability() -> ActivityPushCapability {
#if targetEnvironment(simulator)
        return resolvedCapability(
            isSimulator: true,
            sandboxBuild: false,
            productionBuild: false
        )
#elseif MUGSHOT_PUSH_SANDBOX
        return resolvedCapability(
            isSimulator: false,
            sandboxBuild: true,
            productionBuild: false
        )
#elseif MUGSHOT_PUSH_CAPABLE
        return resolvedCapability(
            isSimulator: false,
            sandboxBuild: false,
            productionBuild: true
        )
#else
        return resolvedCapability(
            isSimulator: false,
            sandboxBuild: false,
            productionBuild: false
        )
#endif
    }
}

final class MugshotNotificationAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        guard let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] else {
            return true
        }
        if let cafeID = NearbyCafeNotificationRoute.resolve(userInfo: userInfo) {
            Task { @MainActor in
                NearbyCafeReminderRouter.shared.enqueue(cafeID: cafeID)
            }
        } else if let route = ActivityPushRouteEnvelope.resolve(userInfo: userInfo) {
            Task { @MainActor in
                _ = await AccountBoundActivityUpdateSignal.shared.refresh(
                    accountID: route.accountID
                )
                ActivityDeepLinkRouter.shared.enqueue(
                    route.destination,
                    accountID: route.accountID,
                    source: .coldLaunchPush
                )
                MugshotAnalytics.shared.capture(.activityOpened(source: .coldLaunchPush))
            }
        } else if userInfo["mugshot"] != nil {
            Task { @MainActor in
                MugshotAnalytics.shared.capture(
                    .activityRouteResult(.malformed, source: .coldLaunchPush)
                )
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await NotificationDeviceCoordinator.shared.didRegisterForRemoteNotifications(
                deviceToken: deviceToken
            )
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
        _ = await AccountBoundActivityUpdateSignal.shared.refresh(accountID: route.accountID)
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
        guard let route = ActivityPushRouteEnvelope.resolve(userInfo: userInfo) else {
            if userInfo["mugshot"] != nil {
                await MainActor.run {
                    MugshotAnalytics.shared.capture(
                        .activityRouteResult(.malformed, source: .pushTap)
                    )
                }
            }
            return
        }
        guard await MainActor.run(body: {
            NotificationDeviceCoordinator.shared.acceptsPush(for: route.accountID)
        }) else {
            await MainActor.run {
                MugshotAnalytics.shared.capture(
                    .activityRouteResult(.accountRejected, source: .pushTap)
                )
            }
            return
        }
        guard await AccountBoundActivityUpdateSignal.shared.refresh(
            accountID: route.accountID
        ) else {
            await MainActor.run {
                MugshotAnalytics.shared.capture(
                    .activityRouteResult(.accountRejected, source: .pushTap)
                )
            }
            return
        }
        await MainActor.run {
            ActivityDeepLinkRouter.shared.enqueue(
                route.destination,
                accountID: route.accountID,
                source: .pushTap
            )
            MugshotAnalytics.shared.capture(.activityOpened(source: .pushTap))
        }
    }
}
