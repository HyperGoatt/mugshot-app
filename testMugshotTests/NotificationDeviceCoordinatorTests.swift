import Foundation
import Testing
@testable import testMugshot

@MainActor
@Suite(.serialized)
struct NotificationDeviceCoordinatorTests {
    @Test func buildCapabilitySelectsOnlyTheSignedEnvironment() {
        #expect(NotificationDeviceCoordinator.resolvedCapability(
            isSimulator: true,
            sandboxBuild: true,
            productionBuild: true
        ) == .unavailable(
            "Remote push requires a signed iPhone build. In-app Activity works in Simulator."
        ))
        #expect(NotificationDeviceCoordinator.resolvedCapability(
            isSimulator: false,
            sandboxBuild: true,
            productionBuild: false
        ) == .configured(environment: .sandbox))
        #expect(NotificationDeviceCoordinator.resolvedCapability(
            isSimulator: false,
            sandboxBuild: false,
            productionBuild: true
        ) == .configured(environment: .production))
    }

    @Test func authorizedV3RegistrationClaimsThenRegistersBadgeCapability() async throws {
        let harness = try CoordinatorHarness(permission: .authorized)
        await harness.coordinator.activate(accountID: harness.accountID)

        #expect(harness.service.claims.count == 1)
        #expect(harness.remote.registerCount == 1)
        #expect(harness.coordinator.registrationState == .registering)

        await harness.coordinator.didRegisterForRemoteNotifications(
            deviceToken: Data([0x01, 0xab, 0xff])
        )

        let registration = try #require(harness.service.registrations.last)
        #expect(registration.token == "01abff")
        #expect(registration.environment == .production)
        #expect(registration.supportsBadgeSync)
        #expect(harness.coordinator.registrationState == .registered)
    }

    @Test func deniedPermissionNeverClaimsOrRegisters() async throws {
        let harness = try CoordinatorHarness(permission: .denied)
        await harness.coordinator.activate(accountID: harness.accountID)

        #expect(harness.service.claims.isEmpty)
        #expect(harness.service.registrations.isEmpty)
        #expect(harness.remote.registerCount == 0)
        #expect(harness.coordinator.permissionState == .denied)
    }

    @Test func provisionalPermissionRegistersWithoutAnotherPrompt() async throws {
        let harness = try CoordinatorHarness(permission: .provisional)
        await harness.coordinator.activate(accountID: harness.accountID)

        #expect(harness.authorization.requestCount == 0)
        #expect(harness.service.claims.count == 1)
        #expect(harness.remote.registerCount == 1)
        #expect(harness.coordinator.permissionState == .provisional)
    }

    @Test func nearbyReminderGrantUsesSharedPermissionAndReconcilesOnce() async throws {
        let authorization = NotificationAuthorizationFake(
            state: .notRequested,
            requestedState: .authorized
        )
        let harness = try CoordinatorHarness(authorization: authorization)
        await harness.coordinator.activate(accountID: harness.accountID)

        let allowed = await harness.coordinator.requestAuthorization(
            source: .nearbyReminder
        )

        #expect(allowed)
        #expect(authorization.requestCount == 1)
        #expect(harness.service.claims.count == 1)
        #expect(harness.remote.registerCount == 1)
    }

    @Test func missingBadgeCapabilityFailsClosedButKeepsPermissionState() async throws {
        let capabilities = BackendCapabilitiesV1.ready(pushBadgeSync: false)
        let harness = try CoordinatorHarness(
            permission: .authorized,
            capabilities: capabilities
        )
        await harness.coordinator.activate(accountID: harness.accountID)

        guard case .unavailable(let message) = harness.coordinator.backendState else {
            Issue.record("The missing v3 capability was presented as available.")
            return
        }
        #expect(message.contains("badge sync"))
        #expect(harness.coordinator.permissionState == .authorized)
        #expect(harness.service.claims.isEmpty)
        #expect(harness.remote.registerCount == 0)
    }

    @Test func malformedCapabilityResponseDisablesRemoteRegistration() async throws {
        let accountID = UUID()
        let service = ActivityDeviceServiceFake()
        service.capabilitiesError = DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "Malformed capability fixture"
        ))
        let factory = ActivityClientFactoryFake(services: [accountID: service])
        let harness = try CoordinatorHarness(
            accountID: accountID,
            permission: .authorized,
            factory: factory
        )

        await harness.coordinator.activate(accountID: accountID)

        guard case .unavailable(let message) = harness.coordinator.backendState else {
            Issue.record("A malformed capability response was accepted.")
            return
        }
        #expect(message.contains("backend push contract"))
        #expect(service.claims.isEmpty)
        #expect(harness.remote.registerCount == 0)
    }

    @Test func preferenceOffUnregistersWithoutRequestingAPNs() async throws {
        let harness = try CoordinatorHarness(
            permission: .authorized,
            preferences: .alphaDefaults.withPushEnabled(false)
        )
        await harness.coordinator.activate(accountID: harness.accountID)
        await harness.coordinator.applyPushPreference(
            enabled: false,
            accountID: harness.accountID
        )

        #expect(harness.service.claims.isEmpty)
        #expect(harness.service.unregisterCount == 1)
        #expect(harness.remote.registerCount == 0)
        #expect(harness.authorization.clearCount == 0)
        #expect(harness.badge.counts.isEmpty)
    }

    @Test func offlineSignOutClearsLocalDeliveryAndBadge() async throws {
        let harness = try CoordinatorHarness(permission: .authorized)
        harness.service.unregisterError = CoordinatorTestError.offline
        await harness.coordinator.activate(accountID: harness.accountID)

        await harness.coordinator.unregisterForSignOut()

        #expect(harness.authorization.clearCount == 1)
        #expect(harness.remote.unregisterCount > 0)
        #expect(harness.badge.counts.last == 0)
        #expect(!harness.coordinator.acceptsPush(for: harness.accountID))
    }

    @Test func accountDeletionInvalidatesDeliveryAndClearsBadge() async throws {
        let harness = try CoordinatorHarness(permission: .authorized)
        await harness.coordinator.activate(accountID: harness.accountID)

        harness.coordinator.deactivateAfterAccountDeletion(accountID: harness.accountID)
        for _ in 0..<10 where harness.badge.counts.last != 0 {
            await Task.yield()
        }

        #expect(harness.authorization.clearCount == 1)
        #expect(harness.remote.unregisterCount > 0)
        #expect(harness.badge.counts.last == 0)
        #expect(!harness.coordinator.acceptsPush(for: harness.accountID))
        #expect(harness.coordinator.backendState == .unchecked)
    }

    @Test func tokenRotationRegistersOnlyTheLatestToken() async throws {
        let harness = try CoordinatorHarness(permission: .authorized)
        await harness.coordinator.activate(accountID: harness.accountID)
        await harness.coordinator.didRegisterForRemoteNotifications(
            deviceToken: Data([0x01])
        )
        await harness.coordinator.didRegisterForRemoteNotifications(
            deviceToken: Data([0x02])
        )

        let registeredTokens = harness.service.registrations.map(\.token)
        let allRegistrationsSupportBadges = harness.service.registrations
            .allSatisfy { $0.supportsBadgeSync }
        #expect(registeredTokens == ["01", "02"])
        #expect(allRegistrationsSupportBadges)
    }

    @Test func staleCapabilityResponseCannotReplaceTheNextAccount() async throws {
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let firstService = ActivityDeviceServiceFake()
        firstService.suspendCapabilities = true
        let secondService = ActivityDeviceServiceFake(
            capabilities: .ready(schemaRelease: "second-account")
        )
        let factory = ActivityClientFactoryFake(services: [
            firstAccountID: firstService,
            secondAccountID: secondService
        ])
        let harness = try CoordinatorHarness(
            accountID: firstAccountID,
            permission: .authorized,
            factory: factory
        )

        let staleActivation = Task { @MainActor in
            await harness.coordinator.activate(accountID: firstAccountID)
        }
        while !firstService.capabilitiesStarted { await Task.yield() }
        await harness.coordinator.activate(accountID: secondAccountID)
        firstService.releaseCapabilities()
        await staleActivation.value

        #expect(harness.coordinator.backendState == .available(
            schemaRelease: "second-account"
        ))
        #expect(firstService.claims.isEmpty)
        #expect(secondService.claims.count == 1)
    }
}

private enum CoordinatorTestError: Error {
    case offline
}

@MainActor
private final class NotificationAuthorizationFake: NotificationAuthorizationProviding {
    var state: ActivityPushPermissionState
    var requestedState: ActivityPushPermissionState
    var requestCount = 0
    var clearCount = 0

    init(
        state: ActivityPushPermissionState,
        requestedState: ActivityPushPermissionState? = nil
    ) {
        self.state = state
        self.requestedState = requestedState ?? state
    }

    func currentPermissionState() async -> ActivityPushPermissionState { state }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        state = requestedState
        return state == .authorized || state == .provisional
    }

    func clearVisibleNotifications() { clearCount += 1 }
}

@MainActor
private final class RemoteNotificationRegistrarFake: RemoteNotificationRegistering {
    var registerCount = 0
    var unregisterCount = 0

    func registerForRemoteNotifications() { registerCount += 1 }
    func unregisterForRemoteNotifications() { unregisterCount += 1 }
}

@MainActor
final class ActivityBadgeUpdaterFake: ActivityBadgeUpdating {
    private(set) var counts: [Int] = []

    func setBadgeCount(_ count: Int) async { counts.append(count) }
}

@MainActor
private final class ActivityClientFactoryFake: ActivityNotificationClientCreating {
    var services: [UUID: ActivityDeviceServiceFake]

    init(services: [UUID: ActivityDeviceServiceFake]) {
        self.services = services
    }

    func makeDeviceService(accountID: UUID) throws -> any ActivityDeviceServicing {
        try #require(services[accountID])
    }
}

@MainActor
private final class ActivityDeviceServiceFake: ActivityDeviceServicing {
    struct Claim: Equatable {
        let installationID: UUID
        let token: String?
        let environment: ActivityPushEnvironment
    }

    struct Registration: Equatable {
        let installationID: UUID
        let token: String
        let environment: ActivityPushEnvironment
        let supportsBadgeSync: Bool
    }

    var capabilities: BackendCapabilitiesV1
    var preferencesValue: ActivityNotificationPreferences
    var claims: [Claim] = []
    var registrations: [Registration] = []
    var unregisterCount = 0
    var capabilitiesError: Error?
    var unregisterError: Error?
    var suspendCapabilities = false
    var capabilitiesStarted = false
    private var capabilityContinuation: CheckedContinuation<Void, Never>?

    init(
        capabilities: BackendCapabilitiesV1 = .ready(),
        preferences: ActivityNotificationPreferences = .alphaDefaults
    ) {
        self.capabilities = capabilities
        preferencesValue = preferences
    }

    func backendCapabilities() async throws -> BackendCapabilitiesV1 {
        capabilitiesStarted = true
        if let capabilitiesError { throw capabilitiesError }
        if suspendCapabilities {
            await withCheckedContinuation { continuation in
                capabilityContinuation = continuation
            }
        }
        return capabilities
    }

    func releaseCapabilities() {
        suspendCapabilities = false
        capabilityContinuation?.resume()
        capabilityContinuation = nil
    }

    func preferences() async throws -> ActivityNotificationPreferences {
        preferencesValue
    }

    func claimDeviceInstallation(
        installationID: UUID,
        knownPushToken: String?,
        environment: ActivityPushEnvironment
    ) async throws {
        claims.append(Claim(
            installationID: installationID,
            token: knownPushToken,
            environment: environment
        ))
    }

    func registerDevice(
        installationID: UUID,
        pushToken: String,
        environment: ActivityPushEnvironment,
        supportsBadgeSync: Bool
    ) async throws {
        registrations.append(Registration(
            installationID: installationID,
            token: pushToken,
            environment: environment,
            supportsBadgeSync: supportsBadgeSync
        ))
    }

    func unregisterDevice(installationID: UUID) async throws {
        unregisterCount += 1
        if let unregisterError { throw unregisterError }
    }
}

@MainActor
private struct CoordinatorHarness {
    let accountID: UUID
    let authorization: NotificationAuthorizationFake
    let remote: RemoteNotificationRegistrarFake
    let badge: ActivityBadgeUpdaterFake
    let service: ActivityDeviceServiceFake
    let coordinator: NotificationDeviceCoordinator

    init(
        accountID: UUID = UUID(),
        permission: ActivityPushPermissionState = .notRequested,
        authorization: NotificationAuthorizationFake? = nil,
        capabilities: BackendCapabilitiesV1 = .ready(),
        preferences: ActivityNotificationPreferences = .alphaDefaults,
        factory suppliedFactory: ActivityClientFactoryFake? = nil
    ) throws {
        let suiteName = "NotificationDeviceCoordinatorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let resolvedAuthorization = authorization
            ?? NotificationAuthorizationFake(state: permission)
        let service = suppliedFactory?.services[accountID]
            ?? ActivityDeviceServiceFake(
                capabilities: capabilities,
                preferences: preferences
            )
        let factory = suppliedFactory
            ?? ActivityClientFactoryFake(services: [accountID: service])
        let remote = RemoteNotificationRegistrarFake()
        let badge = ActivityBadgeUpdaterFake()

        self.accountID = accountID
        self.authorization = resolvedAuthorization
        self.remote = remote
        self.badge = badge
        self.service = service
        coordinator = NotificationDeviceCoordinator(
            authorizationProvider: resolvedAuthorization,
            remoteRegistrar: remote,
            badgeUpdater: badge,
            clientFactory: factory,
            defaults: defaults,
            capability: .configured(environment: .production),
            installationID: UUID(),
            captureAnalytics: { _ in }
        )
    }
}

private extension BackendCapabilitiesV1 {
    static func ready(
        schemaRelease: String = "2026-08-24-activity-push-badge-v3",
        pushBadgeSync: Bool = true
    ) -> BackendCapabilitiesV1 {
        BackendCapabilitiesV1(
            contractVersion: 1,
            schemaRelease: schemaRelease,
            capabilities: Capabilities(
                activityCenter: true,
                notificationPreferences: true,
                pushRegistration: true,
                pushBadgeSync: pushBadgeSync
            )
        )
    }
}

private extension ActivityNotificationPreferences {
    func withPushEnabled(_ value: Bool) -> ActivityNotificationPreferences {
        var copy = self
        copy.pushEnabled = value
        return copy
    }
}
