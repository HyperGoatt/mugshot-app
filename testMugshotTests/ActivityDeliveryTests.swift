import Foundation
import Testing
@testable import testMugshot

struct ActivityDeliveryTests {
    @Test func activityDeepLinksAcceptOnlyMugshotActivityRoutes() throws {
        let visitID = UUID()
        let profileID = UUID()

        #expect(ActivityDeepLinkDestination.resolve(
            try #require(URL(string: "mugshot://activity"))
        ) == .center)
        #expect(ActivityDeepLinkDestination.resolve(
            try #require(URL(string: "mugshot://activity/visit/\(visitID.uuidString)"))
        ) == .visit(visitID))
        #expect(ActivityDeepLinkDestination.resolve(
            try #require(URL(string: "mugshot://activity/people/\(profileID.uuidString)"))
        ) == .profile(profileID))
        #expect(ActivityDeepLinkDestination.resolve(
            try #require(URL(string: "mugshot://activity/shared"))
        ) == nil)
        #expect(ActivityDeepLinkDestination.resolve(
            try #require(URL(string: "mugshot://activity/lists"))
        ) == .collaborativeLists)

        #expect(ActivityDeepLinkDestination.resolve(
            try #require(URL(string: "https://activity/visit/\(visitID.uuidString)"))
        ) == nil)
        #expect(ActivityDeepLinkDestination.resolve(
            try #require(URL(string: "mugshot://activity/visit/not-a-uuid"))
        ) == nil)
        #expect(ActivityDeepLinkDestination.resolve(
            try #require(URL(string: "mugshot://activity/shared/\(visitID.uuidString)"))
        ) == nil)
        #expect(ActivityDeepLinkDestination.resolve(
            try #require(URL(string: "mugshot://auth/callback"))
        ) == nil)
    }

    @Test func alphaPushDefaultsIncludeFriendPosts() {
        let defaults = ActivityNotificationPreferences.alphaDefaults
        #expect(defaults.pushEnabled)
        #expect(defaults.friendPosts)
        #expect(defaults.tags)
        #expect(defaults.collaborativeListInvitations)
    }

    @Test func legacyPWANameForAcceptedFriendRequestRemainsReadable() throws {
        let actorID = UUID()
        let notification = LegacyActivityNotification(
            id: UUID(),
            userID: UUID(),
            actorUserID: actorID,
            type: "friend_accept",
            visitID: nil,
            commentID: nil,
            createdAt: "2026-08-09T00:00:00Z",
            readAt: nil,
            actorUsername: "friend",
            actorDisplayName: "Alpha Friend",
            actorAvatarURL: nil
        )

        let event = try #require(notification.activityEvent)
        #expect(event.kind == .friendRequestAccepted)
        #expect(event.actorUserID == actorID)
    }

    @Test func activityAccountScopeRequiresTheExactActiveSession() {
        let accountID = UUID()
        do {
            try ActivityService.validateAccountScope(
                currentUserID: accountID,
                expectedAccountID: accountID
            )
        } catch {
            Issue.record("The matching activity account scope was rejected: \(error)")
        }
        #expect(throws: ActivityServiceError.accountScopeChanged) {
            try ActivityService.validateAccountScope(
                currentUserID: UUID(),
                expectedAccountID: accountID
            )
        }
        #expect(throws: ActivityServiceError.accountScopeChanged) {
            try ActivityService.validateAccountScope(
                currentUserID: nil,
                expectedAccountID: accountID
            )
        }
    }

    @MainActor
    @Test func persistedActivityRouteCannotCrossAccounts() throws {
        let suiteName = "ActivityRouteAccountIsolation.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let visitID = UUID()

        let firstRouter = ActivityDeepLinkRouter(defaults: defaults)
        firstRouter.activate(accountID: firstAccountID)
        firstRouter.enqueue(.visit(visitID), accountID: firstAccountID)
        #expect(firstRouter.pendingRoute?.accountID == firstAccountID)

        let reloadedForSecondAccount = ActivityDeepLinkRouter(defaults: defaults)
        reloadedForSecondAccount.activate(accountID: secondAccountID)
        #expect(reloadedForSecondAccount.pendingRoute == nil)
        #expect(defaults.data(forKey: "MugshotActivity.pendingRoute.v1") == nil)
    }

    @MainActor
    @Test func coldLaunchPushPersistsOnlyForItsBoundRecipient() throws {
        let suiteName = "ActivityRoutePushBinding.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let recipientID = UUID()
        let visitID = UUID()
        let envelope = try #require(ActivityPushRouteEnvelope.resolve(userInfo: [
            "mugshot": [
                "recipient_id": recipientID.uuidString,
                "deep_link": "mugshot://activity/visit/\(visitID.uuidString)"
            ]
        ]))

        let router = ActivityDeepLinkRouter(defaults: defaults)
        router.enqueue(envelope.destination, accountID: envelope.accountID)
        #expect(router.pendingRoute?.accountID == recipientID)
        #expect(router.pendingRoute?.destination == .visit(visitID))

        let restored = ActivityDeepLinkRouter(defaults: defaults)
        restored.activate(accountID: recipientID)
        #expect(restored.pendingRoute?.destination == .visit(visitID))

        #expect(ActivityPushRouteEnvelope.resolve(userInfo: [
            "mugshot": ["deep_link": "mugshot://activity"]
        ]) == nil)
    }

    @MainActor
    @Test func temporarySessionUnavailabilityPreservesThePendingOwnersRoute() throws {
        let suiteName = "ActivityRouteSessionRecovery.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let accountID = UUID()
        let visitID = UUID()

        let router = ActivityDeepLinkRouter(defaults: defaults)
        router.activate(accountID: accountID)
        router.enqueue(.visit(visitID), accountID: accountID)

        router.activate(accountID: nil)
        #expect(router.pendingRoute?.accountID == accountID)
        #expect(defaults.data(forKey: "MugshotActivity.pendingRoute.v1") != nil)

        router.activate(accountID: accountID)
        #expect(router.pendingRoute?.destination == .visit(visitID))
    }

    @MainActor
    @Test func resolvedSignOutClearsThePendingActivityRoute() throws {
        let suiteName = "ActivityRouteSignedOut.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let accountID = UUID()
        let router = ActivityDeepLinkRouter(defaults: defaults)

        router.activate(accountID: accountID)
        router.enqueue(.collaborativeLists, accountID: accountID)
        router.deactivateForSignedOutSession()

        #expect(router.pendingRoute == nil)
        #expect(defaults.data(forKey: "MugshotActivity.pendingRoute.v1") == nil)
    }

    @MainActor
    @Test func targetedAccountCleanupPreservesAnotherAccountsRoute() throws {
        let suiteName = "ActivityRouteTargetedCleanup.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let deletedAccountID = UUID()
        let remainingAccountID = UUID()
        let router = ActivityDeepLinkRouter(defaults: defaults)

        router.activate(accountID: remainingAccountID)
        router.enqueue(.collaborativeLists, accountID: remainingAccountID)
        router.clear(accountID: deletedAccountID)

        #expect(router.pendingRoute?.accountID == remainingAccountID)
        #expect(router.pendingRoute?.destination == .collaborativeLists)

        router.clear(accountID: remainingAccountID)
        #expect(router.pendingRoute == nil)
    }

    @Test func inaccessibleTagProjectionHasRemovalWithoutForbiddenRoute() throws {
        let actorID = UUID()
        let visitID = UUID()
        let eventID = UUID()
        let json = """
        {
          "event_id": "\(eventID.uuidString)",
          "kind": "tag",
          "actor_user_id": "\(actorID.uuidString)",
          "actor_display_name": "Amanda",
          "actor_username": "amanda",
          "actor_avatar_url": null,
          "title": "You were tagged",
          "body": "Amanda tagged you in a MugShot you can't view.",
          "visit_id": "\(visitID.uuidString)",
          "comment_id": null,
          "shared_memory_id": null,
          "cafe_list_id": null,
          "friend_request_id": null,
          "deep_link": "mugshot://activity",
          "can_open_visit": false,
          "can_remove_tag": true,
          "created_at": "2026-07-21T20:00:00Z",
          "read_at": null
        }
        """
        let event = try JSONDecoder().decode(
            MugshotActivityEvent.self,
            from: Data(json.utf8)
        )

        #expect(event.destination == .center)
        #expect(!event.canOpenVisit)
        #expect(event.canRemoveTag)
        #expect(!event.body.lowercased().contains("cafe"))
    }

    @MainActor
    @Test func staleReadResponseCannotMutateTheNextAccountsActivity() async {
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let firstEvent = Self.event(title: "First account")
        let secondEvent = Self.event(title: "Second account")
        let backend = ActivityAccountSwitchBackend(
            eventResponses: [[firstEvent], [secondEvent]],
            unreadResponses: [1, 1]
        )
        let store = ActivityCenterStore { _ in
            ActivityCenterClient(
                events: { _, _ in await backend.nextEvents() },
                unreadCount: { await backend.nextUnreadCount() },
                markRead: { _ in await backend.suspendedMarkRead() },
                removeTag: { _ in true }
            )
        }

        await store.activate(accountID: firstAccountID)
        #expect(store.events == [firstEvent])

        let staleRead = Task { @MainActor in
            await store.markRead(firstEvent)
        }
        await backend.waitUntilMarkReadStarts()

        await store.activate(accountID: secondAccountID)
        #expect(store.events == [secondEvent])
        #expect(store.unreadCount == 1)

        await backend.releaseMarkRead()
        await staleRead.value

        #expect(store.events == [secondEvent])
        #expect(store.events.first?.readAt == nil)
        #expect(store.unreadCount == 1)
        #expect(store.actionError == nil)
    }

    @MainActor
    @Test func staleRefreshResponseCannotReplaceTheNextAccountsActivity() async {
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let firstEvent = Self.event(title: "Delayed first account")
        let secondEvent = Self.event(title: "Current second account")
        let backend = ActivityRefreshSwitchBackend(
            delayedAccountID: firstAccountID,
            delayedEvents: [firstEvent],
            currentEvents: [secondEvent]
        )
        let store = ActivityCenterStore { accountID in
            ActivityCenterClient(
                events: { _, _ in
                    await backend.events(accountID: accountID)
                },
                unreadCount: {
                    await backend.unreadCount(accountID: accountID)
                },
                markRead: { _ in 0 },
                removeTag: { _ in true }
            )
        }

        let delayedActivation = Task { @MainActor in
            await store.activate(accountID: firstAccountID)
        }
        await backend.waitUntilDelayedRefreshStarts()

        await store.activate(accountID: secondAccountID)
        #expect(store.events == [secondEvent])
        #expect(store.unreadCount == 1)

        await backend.releaseDelayedRefresh()
        await delayedActivation.value

        #expect(store.events == [secondEvent])
        #expect(store.unreadCount == 1)
        #expect(store.actionError == nil)
    }

    private static func event(title: String) -> MugshotActivityEvent {
        MugshotActivityEvent(
            id: UUID(),
            kind: .friendPost,
            actorUserID: UUID(),
            actorDisplayName: "Mugshot tester",
            actorUsername: "tester",
            actorAvatarURL: nil,
            title: title,
            body: "Published a MugShot",
            visitID: UUID(),
            commentID: nil,
            cafeListID: nil,
            friendRequestID: nil,
            deepLink: "mugshot://activity",
            canOpenVisit: true,
            canRemoveTag: false,
            createdAt: "2026-07-21T20:00:00Z",
            readAt: nil
        )
    }
}

private actor ActivityRefreshSwitchBackend {
    private let delayedAccountID: UUID
    private let delayedEvents: [MugshotActivityEvent]
    private let currentEvents: [MugshotActivityEvent]
    private var delayedRefreshStarted = false
    private var delayedRefreshReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        delayedAccountID: UUID,
        delayedEvents: [MugshotActivityEvent],
        currentEvents: [MugshotActivityEvent]
    ) {
        self.delayedAccountID = delayedAccountID
        self.delayedEvents = delayedEvents
        self.currentEvents = currentEvents
    }

    func events(accountID: UUID) async -> [MugshotActivityEvent] {
        guard accountID == delayedAccountID else { return currentEvents }
        delayedRefreshStarted = true
        let pendingStartWaiters = startWaiters
        startWaiters = []
        pendingStartWaiters.forEach { $0.resume() }
        if !delayedRefreshReleased {
            await withCheckedContinuation { continuation in
                releaseWaiters.append(continuation)
            }
        }
        return delayedEvents
    }

    func unreadCount(accountID: UUID) -> Int {
        accountID == delayedAccountID ? delayedEvents.count : currentEvents.count
    }

    func waitUntilDelayedRefreshStarts() async {
        guard !delayedRefreshStarted else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releaseDelayedRefresh() {
        delayedRefreshReleased = true
        let pendingReleaseWaiters = releaseWaiters
        releaseWaiters = []
        pendingReleaseWaiters.forEach { $0.resume() }
    }
}

private actor ActivityAccountSwitchBackend {
    private var eventResponses: [[MugshotActivityEvent]]
    private var unreadResponses: [Int]
    private var markReadStarted = false
    private var markReadReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        eventResponses: [[MugshotActivityEvent]],
        unreadResponses: [Int]
    ) {
        self.eventResponses = eventResponses
        self.unreadResponses = unreadResponses
    }

    func nextEvents() -> [MugshotActivityEvent] {
        eventResponses.removeFirst()
    }

    func nextUnreadCount() -> Int {
        unreadResponses.removeFirst()
    }

    func suspendedMarkRead() async -> Int {
        markReadStarted = true
        let waiters = startWaiters
        startWaiters = []
        waiters.forEach { $0.resume() }
        guard !markReadReleased else { return 1 }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
        return 1
    }

    func waitUntilMarkReadStarts() async {
        guard !markReadStarted else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releaseMarkRead() {
        markReadReleased = true
        let waiters = releaseWaiters
        releaseWaiters = []
        waiters.forEach { $0.resume() }
    }
}
