import Foundation
import UIKit
@preconcurrency import UserNotifications

@MainActor
protocol NotificationAuthorizationProviding: AnyObject {
    func currentPermissionState() async -> ActivityPushPermissionState
    func requestAuthorization() async throws -> Bool
    func clearVisibleNotifications()
}

@MainActor
final class SystemNotificationAuthorizationProvider: NotificationAuthorizationProviding {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func currentPermissionState() async -> ActivityPushPermissionState {
        let settings = await center.notificationSettings()
        return ActivityPushPermissionState(settings.authorizationStatus)
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func clearVisibleNotifications() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }
}

@MainActor
protocol RemoteNotificationRegistering: AnyObject {
    func registerForRemoteNotifications()
    func unregisterForRemoteNotifications()
}

@MainActor
final class SystemRemoteNotificationRegistrar: RemoteNotificationRegistering {
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func unregisterForRemoteNotifications() {
        UIApplication.shared.unregisterForRemoteNotifications()
    }
}

@MainActor
protocol ActivityBadgeUpdating: AnyObject {
    func setBadgeCount(_ count: Int) async
}

@MainActor
final class SystemActivityBadgeUpdater: ActivityBadgeUpdating {
    static let shared = SystemActivityBadgeUpdater()

    private let center: UNUserNotificationCenter
    private var revision = 0
    private var desiredCount = 0

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func setBadgeCount(_ count: Int) async {
        desiredCount = max(count, 0)
        revision += 1
        let requestedRevision = revision
        await apply(desiredCount)
        guard revision != requestedRevision else { return }
        await apply(desiredCount)
    }

    private func apply(_ count: Int) async {
        await withCheckedContinuation { continuation in
            center.setBadgeCount(count) { _ in
                continuation.resume()
            }
        }
    }
}

@MainActor
protocol ActivityDeviceServicing: AnyObject {
    func backendCapabilities() async throws -> BackendCapabilitiesV1
    func preferences() async throws -> ActivityNotificationPreferences
    func claimDeviceInstallation(
        installationID: UUID,
        knownPushToken: String?,
        environment: ActivityPushEnvironment
    ) async throws
    func registerDevice(
        installationID: UUID,
        pushToken: String,
        environment: ActivityPushEnvironment,
        supportsBadgeSync: Bool
    ) async throws
    func unregisterDevice(installationID: UUID) async throws
}

@MainActor
protocol ActivityNotificationClientCreating: AnyObject {
    func makeDeviceService(accountID: UUID) throws -> any ActivityDeviceServicing
}

@MainActor
final class LiveActivityNotificationClientFactory: ActivityNotificationClientCreating {
    func makeDeviceService(accountID: UUID) throws -> any ActivityDeviceServicing {
        SupabaseActivityDeviceService(
            service: ActivityService(client: try SupabaseClientProvider.shared.client()),
            accountID: accountID
        )
    }
}

@MainActor
private final class SupabaseActivityDeviceService: ActivityDeviceServicing {
    private let service: ActivityService
    private let accountID: UUID

    init(service: ActivityService, accountID: UUID) {
        self.service = service
        self.accountID = accountID
    }

    func backendCapabilities() async throws -> BackendCapabilitiesV1 {
        try await service.backendCapabilities(accountID: accountID)
    }

    func preferences() async throws -> ActivityNotificationPreferences {
        try await service.preferences(accountID: accountID)
    }

    func claimDeviceInstallation(
        installationID: UUID,
        knownPushToken: String?,
        environment: ActivityPushEnvironment
    ) async throws {
        try await service.claimDeviceInstallation(
            installationID: installationID,
            knownPushToken: knownPushToken,
            environment: environment,
            accountID: accountID
        )
    }

    func registerDevice(
        installationID: UUID,
        pushToken: String,
        environment: ActivityPushEnvironment,
        supportsBadgeSync: Bool
    ) async throws {
        try await service.registerDevice(
            installationID: installationID,
            pushToken: pushToken,
            environment: environment,
            supportsBadgeSync: supportsBadgeSync,
            accountID: accountID
        )
    }

    func unregisterDevice(installationID: UUID) async throws {
        try await service.unregisterDevice(
            installationID: installationID,
            accountID: accountID
        )
    }
}

/// Bridges UIKit notification callbacks to the account-scoped Activity store
/// without giving the app delegate ownership of session or navigation state.
@MainActor
final class AccountBoundActivityUpdateSignal {
    static let shared = AccountBoundActivityUpdateSignal()

    private var activeAccountID: UUID?
    private var pendingAccountID: UUID?
    private var refreshHandler: (() async -> Void)?

    func activate(
        accountID: UUID?,
        activationAlreadyRefreshed: Bool = false,
        refresh: (() async -> Void)?
    ) {
        activeAccountID = accountID
        refreshHandler = refresh
        guard let accountID else {
            pendingAccountID = nil
            return
        }
        guard pendingAccountID == accountID else {
            if pendingAccountID != nil { pendingAccountID = nil }
            return
        }
        pendingAccountID = nil
        guard !activationAlreadyRefreshed else { return }
        Task { await refresh?() }
    }

    @discardableResult
    func refresh(accountID: UUID) async -> Bool {
        guard let activeAccountID else {
            pendingAccountID = accountID
            return true
        }
        guard activeAccountID == accountID,
              let refreshHandler else { return false }
        await refreshHandler()
        return self.activeAccountID == accountID
    }
}
