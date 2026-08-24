import Combine
import Foundation
import Supabase

final class ActivityService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func events(
        accountID: UUID,
        limit: Int = 30,
        before event: MugshotActivityEvent? = nil
    ) async throws -> [MugshotActivityEvent] {
        try requireAccount(accountID)
        let events: [MugshotActivityEvent]
        do {
            events = try await client.rpc(
                "list_activity_events_v1",
                params: ActivityListParameters(
                    pLimit: min(max(limit, 1), 50),
                    pBeforeCreatedAt: event?.createdAt,
                    pBeforeID: event?.id
                )
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            events = try await legacyEvents(
                accountID: accountID,
                limit: limit,
                before: event
            )
        }
        try requireAccount(accountID)
        return events
    }

    func unreadCount(accountID: UUID) async throws -> Int {
        try requireAccount(accountID)
        let count: Int
        do {
            count = try await client.rpc(
                "activity_unread_count_v1"
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            count = try await legacyUnreadCount(accountID: accountID)
        }
        try requireAccount(accountID)
        return count
    }

    @discardableResult
    func markRead(eventID: UUID?, accountID: UUID) async throws -> Int {
        try requireAccount(accountID)
        let count: Int
        do {
            count = try await client.rpc(
                "mark_activity_read_v1",
                params: ActivityReadParameters(pEventID: eventID)
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            count = try await markLegacyRead(eventID: eventID, accountID: accountID)
        }
        try requireAccount(accountID)
        return count
    }

    private func legacyEvents(
        accountID: UUID,
        limit: Int,
        before event: MugshotActivityEvent?
    ) async throws -> [MugshotActivityEvent] {
        let requestedLimit = min(max(limit, 1), 50)
        let sourcePageSize = 50
        var cursorCreatedAt = event?.createdAt
        var cursorID = event?.id
        var visibleEvents: [MugshotActivityEvent] = []

        while visibleEvents.count < requestedLimit {
            let query = client
                .from("notifications_with_actor")
                .select(LegacyActivityNotification.columns)
                .eq("user_id", value: accountID.uuidString)

            if let cursorCreatedAt, let cursorID {
                _ = query.or(
                    "created_at.lt.\(cursorCreatedAt),and(created_at.eq.\(cursorCreatedAt),id.lt.\(cursorID.uuidString))"
                )
            }

            let rows: [LegacyActivityNotification] = try await query
                .order("created_at", ascending: false)
                .order("id", ascending: false)
                .limit(sourcePageSize)
                .execute()
                .value
            guard !rows.isEmpty else { break }

            let blockedActorIDs = try await legacyBlockedActorIDs(
                Set(rows.map(\.actorUserID)),
                accountID: accountID
            )
            visibleEvents.append(contentsOf: rows
                .filter { !blockedActorIDs.contains($0.actorUserID) }
                .compactMap(\.activityEvent))

            guard rows.count == sourcePageSize,
                  let lastRow = rows.last else { break }
            cursorCreatedAt = lastRow.createdAt
            cursorID = lastRow.id
        }

        return Array(visibleEvents.prefix(requestedLimit))
    }

    private func legacyUnreadCount(accountID: UUID) async throws -> Int {
        let pageSize = 500
        var offset = 0
        var visibleUnreadCount = 0

        while true {
            let rows: [LegacyUnreadActivityNotification] = try await client
                .from("notifications")
                .select("id, actor_user_id")
                .eq("user_id", value: accountID.uuidString)
                .is("read_at", value: nil)
                .order("id", ascending: true)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            let blockedActorIDs = try await legacyBlockedActorIDs(
                Set(rows.map(\.actorUserID)),
                accountID: accountID
            )
            visibleUnreadCount += rows.reduce(into: 0) { count, row in
                if !blockedActorIDs.contains(row.actorUserID) {
                    count += 1
                }
            }
            guard rows.count == pageSize else { return visibleUnreadCount }
            offset += rows.count
        }
    }

    /// The legacy notification view predates block-trigger cleanup. Recheck
    /// every actor through the caller-bound pairwise helper before showing or
    /// counting a historical event. An unresolved check throws, so blocked
    /// content never reappears merely because the compatibility path is active.
    private func legacyBlockedActorIDs(
        _ actorIDs: Set<UUID>,
        accountID: UUID
    ) async throws -> Set<UUID> {
        let actors = Array(actorIDs)
        guard !actors.isEmpty else { return [] }
        let maximumConcurrentChecks = 8
        let activityClient = client
        var nextIndex = 0
        var blockedActorIDs = Set<UUID>()

        return try await withThrowingTaskGroup(
            of: LegacyActorBlockResult.self
        ) { group in
            while nextIndex < min(maximumConcurrentChecks, actors.count) {
                let actorID = actors[nextIndex]
                nextIndex += 1
                group.addTask { [activityClient] in
                    let isBlocked: Bool = try await activityClient.rpc(
                        "is_blocked_between",
                        params: LegacyActorBlockParameters(
                            accountID: accountID,
                            actorID: actorID
                        )
                    ).execute().value
                    return LegacyActorBlockResult(
                        actorID: actorID,
                        isBlocked: isBlocked
                    )
                }
            }

            while let result = try await group.next() {
                if result.isBlocked {
                    blockedActorIDs.insert(result.actorID)
                }
                if nextIndex < actors.count {
                    let actorID = actors[nextIndex]
                    nextIndex += 1
                    group.addTask { [activityClient] in
                        let isBlocked: Bool = try await activityClient.rpc(
                            "is_blocked_between",
                            params: LegacyActorBlockParameters(
                                accountID: accountID,
                                actorID: actorID
                            )
                        ).execute().value
                        return LegacyActorBlockResult(
                            actorID: actorID,
                            isBlocked: isBlocked
                        )
                    }
                }
            }
            return blockedActorIDs
        }
    }

    private func markLegacyRead(eventID: UUID?, accountID: UUID) async throws -> Int {
        let query = try client
            .from("notifications")
            .update(LegacyActivityReadUpdate(readAt: ISO8601DateFormatter().string(from: Date())))
            .eq("user_id", value: accountID.uuidString)
        if let eventID {
            _ = query.eq("id", value: eventID.uuidString)
        }
        try await query.execute()
        return try await legacyUnreadCount(accountID: accountID)
    }

    func preferences(accountID: UUID) async throws -> ActivityNotificationPreferences {
        try requireAccount(accountID)
        let preferences: ActivityNotificationPreferences
        do {
            preferences = try await client.rpc(
                "get_notification_preferences_v1"
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            throw ActivityServiceError.notificationPreferencesUnavailable
        }
        try requireAccount(accountID)
        return preferences
    }

    func backendCapabilities(accountID: UUID) async throws -> BackendCapabilitiesV1 {
        try requireAccount(accountID)
        let capabilities: BackendCapabilitiesV1
        do {
            capabilities = try await client.rpc(
                "get_backend_capabilities_v1"
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            throw ActivityServiceError.backendCapabilitiesUnavailable
        }
        try requireAccount(accountID)
        guard capabilities.contractVersion == 1 else {
            throw ActivityServiceError.backendCapabilitiesMalformed
        }
        return capabilities
    }

    func savePreferences(
        _ preferences: ActivityNotificationPreferences,
        accountID: UUID
    ) async throws -> ActivityNotificationPreferences {
        try requireAccount(accountID)
        let saved: ActivityNotificationPreferences
        do {
            saved = try await client.rpc(
                "set_notification_preferences_v1",
                params: ActivityPreferenceParameters(preferences)
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            throw ActivityServiceError.notificationPreferencesUnavailable
        }
        try requireAccount(accountID)
        return saved
    }

    func removeTag(visitID: UUID, accountID: UUID) async throws -> Bool {
        try requireAccount(accountID)
        let removed: Bool = try await client.rpc(
            "remove_self_visit_tag_v1",
            params: ["p_visit_id": visitID]
        ).execute().value
        try requireAccount(accountID)
        return removed
    }

    func registerDevice(
        installationID: UUID,
        pushToken: String,
        environment: ActivityPushEnvironment,
        supportsBadgeSync: Bool,
        accountID: UUID
    ) async throws {
        try requireAccount(accountID)
        do {
            try await client.rpc(
                "register_user_device_v3",
                params: ActivityDeviceRegistrationParameters(
                    pDeviceID: installationID,
                    pPushToken: pushToken,
                    pEnvironment: environment.rawValue,
                    pSupportsBadgeSync: supportsBadgeSync
                )
            ).execute()
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            throw ActivityServiceError.pushRegistrationUnavailable
        }
        try requireAccount(accountID)
    }

    func claimDeviceInstallation(
        installationID: UUID,
        knownPushToken: String?,
        environment: ActivityPushEnvironment,
        accountID: UUID
    ) async throws {
        try requireAccount(accountID)
        do {
            try await client.rpc(
                "claim_user_device_installation_v2",
                params: ActivityDeviceClaimParameters(
                    pDeviceID: installationID,
                    pEnvironment: environment.rawValue,
                    pKnownPushToken: knownPushToken
                )
            ).execute()
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            throw ActivityServiceError.pushRegistrationUnavailable
        }
        try requireAccount(accountID)
    }

    func unregisterDevice(installationID: UUID, accountID: UUID) async throws {
        try requireAccount(accountID)
        do {
            try await client.rpc(
                "unregister_user_device_v2",
                params: ["p_device_id": installationID]
            ).execute()
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            throw ActivityServiceError.pushRegistrationUnavailable
        }
        try requireAccount(accountID)
    }

    private func requireAccount(_ expectedAccountID: UUID) throws {
        try Self.validateAccountScope(
            currentUserID: client.auth.currentUser?.id,
            expectedAccountID: expectedAccountID
        )
    }

    static func validateAccountScope(
        currentUserID: UUID?,
        expectedAccountID: UUID
    ) throws {
        guard currentUserID == expectedAccountID else {
            throw ActivityServiceError.accountScopeChanged
        }
    }
}

private struct ActivityDeviceClaimParameters: Encodable {
    let pDeviceID: UUID
    let pEnvironment: String
    let pKnownPushToken: String?

    enum CodingKeys: String, CodingKey {
        case pDeviceID = "p_device_id"
        case pEnvironment = "p_environment"
        case pKnownPushToken = "p_known_push_token"
    }
}

enum ActivityServiceError: LocalizedError, Equatable {
    case accountScopeChanged
    case backendCapabilitiesUnavailable
    case backendCapabilitiesMalformed
    case notificationPreferencesUnavailable
    case pushRegistrationUnavailable

    var errorDescription: String? {
        switch self {
        case .accountScopeChanged:
            "The signed-in account changed before Mugshot could finish refreshing activity."
        case .backendCapabilitiesUnavailable:
            "Mugshot’s backend capability contract is unavailable."
        case .backendCapabilitiesMalformed:
            "Mugshot’s backend capability contract could not be verified."
        case .notificationPreferencesUnavailable:
            "Push preferences aren’t available in this Mugshot backend yet."
        case .pushRegistrationUnavailable:
            "Push registration isn’t available in this Mugshot backend yet."
        }
    }
}

struct ActivityCenterClient {
    var events: (_ limit: Int, _ before: MugshotActivityEvent?) async throws -> [MugshotActivityEvent]
    var unreadCount: () async throws -> Int
    var markRead: (_ eventID: UUID?) async throws -> Int
    var removeTag: (_ visitID: UUID) async throws -> Bool

    static func live(accountID: UUID) throws -> ActivityCenterClient {
        let service = ActivityService(client: try SupabaseClientProvider.shared.client())
        return ActivityCenterClient(
            events: {
                try await service.events(
                    accountID: accountID,
                    limit: $0,
                    before: $1
                )
            },
            unreadCount: { try await service.unreadCount(accountID: accountID) },
            markRead: {
                try await service.markRead(eventID: $0, accountID: accountID)
            },
            removeTag: {
                try await service.removeTag(visitID: $0, accountID: accountID)
            }
        )
    }
}

@MainActor
final class ActivityCenterStore: ObservableObject {
    @Published private(set) var events: [MugshotActivityEvent] = []
    @Published private(set) var unreadCount = 0
    @Published private(set) var state: ActivityCenterLoadState = .idle
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published private(set) var actionError: String?

    private let pageSize: Int
    private let clientFactory: (UUID) throws -> ActivityCenterClient
    private let badgeUpdater: any ActivityBadgeUpdating
    private var accountID: UUID?
    private var requestID: UUID?

    init(
        pageSize: Int = 30,
        clientFactory: @escaping (UUID) throws -> ActivityCenterClient = ActivityCenterClient.live,
        badgeUpdater: (any ActivityBadgeUpdating)? = nil
    ) {
        self.pageSize = min(max(pageSize, 1), 50)
        self.clientFactory = clientFactory
        self.badgeUpdater = badgeUpdater ?? SystemActivityBadgeUpdater.shared
    }

    func activate(accountID: UUID?) async {
        guard self.accountID != accountID else {
            if accountID != nil, state == .idle { await refresh() }
            return
        }
        self.accountID = accountID
        requestID = nil
        events = []
        unreadCount = 0
        isLoadingMore = false
        hasMore = false
        actionError = nil
        state = accountID == nil ? .idle : .loading
        guard accountID != nil else {
            await badgeUpdater.setBadgeCount(0)
            return
        }
        await refresh()
    }

    func refresh() async {
        guard let expectedAccountID = accountID else { return }
        let currentRequest = UUID()
        requestID = currentRequest
        if events.isEmpty { state = .loading }
        actionError = nil
        do {
            let client = try clientFactory(expectedAccountID)
            async let loadedEvents = client.events(pageSize, nil)
            async let loadedUnread = client.unreadCount()
            let (resolvedEvents, resolvedUnread) = try await (loadedEvents, loadedUnread)
            guard accountID == expectedAccountID,
                  requestID == currentRequest else { return }
            events = resolvedEvents
            unreadCount = max(resolvedUnread, 0)
            hasMore = resolvedEvents.count == pageSize
            state = .loaded
            await badgeUpdater.setBadgeCount(unreadCount)
        } catch is CancellationError {
            return
        } catch {
            guard accountID == expectedAccountID,
                  requestID == currentRequest else { return }
            let message = "Mugshot couldn’t refresh activity. Your activity history is unchanged—please try again."
            if events.isEmpty { state = .failed(message) }
            actionError = events.isEmpty ? nil : message
        }
    }

    func loadMore() async {
        guard let expectedAccountID = accountID,
              hasMore,
              !isLoadingMore,
              let cursor = events.last else { return }
        let expectedRequestID = requestID
        isLoadingMore = true
        defer {
            if accountID == expectedAccountID {
                isLoadingMore = false
            }
        }
        do {
            let page = try await clientFactory(expectedAccountID).events(pageSize, cursor)
            guard accountID == expectedAccountID,
                  requestID == expectedRequestID else { return }
            let existingIDs = Set(events.map(\.id))
            events.append(contentsOf: page.filter { !existingIDs.contains($0.id) })
            hasMore = page.count == pageSize
        } catch is CancellationError {
            return
        } catch {
            guard accountID == expectedAccountID,
                  requestID == expectedRequestID else { return }
            actionError = "Mugshot couldn’t load older activity. Please try again."
        }
    }

    func markRead(_ event: MugshotActivityEvent) async {
        guard let expectedAccountID = accountID, !event.isRead else { return }
        do {
            let resolvedUnread = try await clientFactory(expectedAccountID).markRead(event.id)
            guard accountID == expectedAccountID else { return }
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].readAt = ISO8601DateFormatter().string(from: Date())
            }
            unreadCount = max(resolvedUnread, 0)
            await badgeUpdater.setBadgeCount(unreadCount)
        } catch {
            guard accountID == expectedAccountID else { return }
            actionError = "Mugshot couldn’t mark that activity as read yet."
        }
    }

    func markAllRead() async {
        guard let expectedAccountID = accountID, unreadCount > 0 else { return }
        do {
            let resolvedUnread = try await clientFactory(expectedAccountID).markRead(nil)
            guard accountID == expectedAccountID else { return }
            let timestamp = ISO8601DateFormatter().string(from: Date())
            for index in events.indices where events[index].readAt == nil {
                events[index].readAt = timestamp
            }
            unreadCount = max(resolvedUnread, 0)
            await badgeUpdater.setBadgeCount(unreadCount)
        } catch {
            guard accountID == expectedAccountID else { return }
            actionError = "Mugshot couldn’t mark all activity as read yet."
        }
    }

    func removePrivateTag(_ event: MugshotActivityEvent) async {
        guard let expectedAccountID = accountID,
              event.kind == .tag,
              event.canRemoveTag,
              let visitID = event.visitID else { return }
        do {
            let client = try clientFactory(expectedAccountID)
            guard try await client.removeTag(visitID) else {
                guard accountID == expectedAccountID else { return }
                actionError = "That tag is no longer available."
                await refresh()
                return
            }
            guard accountID == expectedAccountID else { return }
            events.removeAll { $0.id == event.id }
            do {
                let authoritativeUnread = try await client.unreadCount()
                guard accountID == expectedAccountID else { return }
                unreadCount = max(authoritativeUnread, 0)
            } catch {
                guard accountID == expectedAccountID else { return }
                actionError = "Your tag was removed, but Mugshot couldn’t refresh the unread badge yet. It will reconcile the next time Activity refreshes."
                return
            }
            actionError = nil
            await badgeUpdater.setBadgeCount(unreadCount)
        } catch {
            guard accountID == expectedAccountID else { return }
            actionError = "Mugshot couldn’t remove that tag. Your post access did not change—please try again."
        }
    }

    func clearActionError() {
        actionError = nil
    }
}

@MainActor
final class ActivityDeepLinkRouter: ObservableObject {
    static let shared = ActivityDeepLinkRouter()
    private static let storageKey = "MugshotActivity.pendingRoute.v1"

    @Published private(set) var pendingRoute: PendingActivityRoute?
    private let defaults: UserDefaults
    private var activeAccountID: UUID?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            pendingRoute = try? JSONDecoder().decode(PendingActivityRoute.self, from: data)
        }
    }

    func activate(accountID: UUID?) {
        activeAccountID = accountID
        // A nil account while session restoration is checking or temporarily
        // unavailable is not proof that the owner signed out. Keep the route
        // until the app has either restored its owner or resolved sign-out.
        guard let accountID else { return }
        guard let route = pendingRoute else { return }
        guard route.accountID == accountID else {
            clear()
            return
        }
    }

    func deactivateForSignedOutSession() {
        activeAccountID = nil
        clear()
    }

    @discardableResult
    func enqueue(
        url: URL,
        accountID: UUID,
        source: ActivityOpenSource = .deepLink
    ) -> Bool {
        guard activeAccountID == nil || activeAccountID == accountID else { return false }
        guard let destination = ActivityDeepLinkDestination.resolve(url) else { return false }
        enqueue(destination, accountID: accountID, source: source)
        return true
    }

    func enqueue(
        _ destination: ActivityDeepLinkDestination,
        accountID: UUID,
        source: ActivityOpenSource? = nil
    ) {
        guard activeAccountID == nil || activeAccountID == accountID else { return }
        let route = PendingActivityRoute(
            accountID: accountID,
            destination: destination,
            source: source
        )
        pendingRoute = route
        if let data = try? JSONEncoder().encode(route) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    func consume(_ route: PendingActivityRoute, accountID: UUID) {
        guard route.id == pendingRoute?.id,
              route.accountID == accountID,
              activeAccountID == accountID else { return }
        clear()
    }

    /// Account teardown must not erase a route owned by a different account
    /// that may already be staged in the same defaults suite.
    func clear(accountID: UUID) {
        guard pendingRoute?.accountID == accountID else { return }
        clear()
    }

    func clear() {
        pendingRoute = nil
        defaults.removeObject(forKey: Self.storageKey)
    }
}

struct LegacyActivityNotification: Decodable, Equatable {
    static let columns = """
    id, user_id, actor_user_id, type, visit_id, comment_id, created_at, read_at, actor_username, actor_display_name, actor_avatar_url
    """

    let id: UUID
    let userID: UUID
    let actorUserID: UUID
    let type: String
    let visitID: UUID?
    let commentID: UUID?
    let createdAt: String
    let readAt: String?
    let actorUsername: String
    let actorDisplayName: String?
    let actorAvatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, type
        case userID = "user_id"
        case actorUserID = "actor_user_id"
        case visitID = "visit_id"
        case commentID = "comment_id"
        case createdAt = "created_at"
        case readAt = "read_at"
        case actorUsername = "actor_username"
        case actorDisplayName = "actor_display_name"
        case actorAvatarURL = "actor_avatar_url"
    }

    var activityEvent: MugshotActivityEvent? {
        guard let kind else { return nil }
        let label = actorDisplayName.flatMap { value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
            ?? "@\(actorUsername)"
        let copy = activityCopy(kind: kind, actorLabel: label)
        let opensVisit = visitID != nil && [
            MugshotActivityKind.friendPost,
            .like,
            .comment,
            .commentMention
        ].contains(kind)
        let deepLink: String
        if opensVisit, let visitID {
            deepLink = "mugshot://activity/visit/\(visitID.uuidString)"
        } else if kind == .friendRequest || kind == .friendRequestAccepted {
            deepLink = "mugshot://activity/people/\(actorUserID.uuidString)"
        } else {
            deepLink = "mugshot://activity"
        }

        return MugshotActivityEvent(
            id: id,
            kind: kind,
            actorUserID: actorUserID,
            actorDisplayName: actorDisplayName,
            actorUsername: actorUsername,
            actorAvatarURL: actorAvatarURL,
            title: copy.title,
            body: copy.body,
            visitID: visitID,
            commentID: commentID,
            cafeListID: nil,
            friendRequestID: nil,
            deepLink: deepLink,
            canOpenVisit: opensVisit,
            canRemoveTag: false,
            createdAt: createdAt,
            readAt: readAt
        )
    }

    private var kind: MugshotActivityKind? {
        switch type.lowercased() {
        case "like": .like
        case "comment", "reply": .comment
        case "mention": .commentMention
        case "friend_request": .friendRequest
        case "friend_accept", "friend_request_accepted", "follow": .friendRequestAccepted
        case "new_visit_from_friend": .friendPost
        default: nil
        }
    }

    private func activityCopy(
        kind: MugshotActivityKind,
        actorLabel: String
    ) -> (title: String, body: String) {
        switch kind {
        case .friendPost:
            ("\(actorLabel) posted a MugShot", "A fresh friend sip is waiting in Feed.")
        case .like:
            ("\(actorLabel) liked your MugShot", "Your sip got a little love.")
        case .comment:
            ("\(actorLabel) joined the conversation", "There is a new comment on your MugShot.")
        case .commentMention:
            ("\(actorLabel) mentioned you", "You were mentioned in a MugShot conversation.")
        case .friendRequest:
            ("\(actorLabel) wants to connect", "You have a new friend request.")
        case .friendRequestAccepted:
            ("\(actorLabel) accepted your request", "You are friends on Mugshot now.")
        default:
            ("New activity", "Open Mugshot to see what changed.")
        }
    }
}

private struct LegacyUnreadActivityNotification: Decodable {
    let id: UUID
    let actorUserID: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case actorUserID = "actor_user_id"
    }
}

private struct LegacyActorBlockParameters: Encodable, Sendable {
    let accountID: UUID
    let actorID: UUID

    enum CodingKeys: String, CodingKey {
        case accountID = "p_first"
        case actorID = "p_second"
    }
}

private struct LegacyActorBlockResult: Sendable {
    let actorID: UUID
    let isBlocked: Bool
}

private struct LegacyActivityReadUpdate: Encodable {
    let readAt: String

    enum CodingKeys: String, CodingKey {
        case readAt = "read_at"
    }
}

private struct ActivityListParameters: Encodable {
    let pLimit: Int
    let pBeforeCreatedAt: String?
    let pBeforeID: UUID?

    enum CodingKeys: String, CodingKey {
        case pLimit = "p_limit"
        case pBeforeCreatedAt = "p_before_created_at"
        case pBeforeID = "p_before_id"
    }
}

private struct ActivityReadParameters: Encodable {
    let pEventID: UUID?

    enum CodingKeys: String, CodingKey {
        case pEventID = "p_event_id"
    }
}

private struct ActivityDeviceRegistrationParameters: Encodable {
    let pDeviceID: UUID
    let pPushToken: String
    let pEnvironment: String
    let pSupportsBadgeSync: Bool

    enum CodingKeys: String, CodingKey {
        case pDeviceID = "p_device_id"
        case pPushToken = "p_push_token"
        case pEnvironment = "p_environment"
        case pSupportsBadgeSync = "p_supports_badge_sync"
    }
}

private struct ActivityPreferenceParameters: Encodable {
    let pPushEnabled: Bool
    let pFriendPosts: Bool
    let pTags: Bool
    let pCollaborativeListInvitations: Bool
    let pLikes: Bool
    let pComments: Bool
    let pReactions: Bool
    let pFriendRequests: Bool

    init(_ preferences: ActivityNotificationPreferences) {
        pPushEnabled = preferences.pushEnabled
        pFriendPosts = preferences.friendPosts
        pTags = preferences.tags
        pCollaborativeListInvitations = preferences.collaborativeListInvitations
        pLikes = preferences.likes
        pComments = preferences.comments
        pReactions = preferences.reactions
        pFriendRequests = preferences.friendRequests
    }

    enum CodingKeys: String, CodingKey {
        case pPushEnabled = "p_push_enabled"
        case pFriendPosts = "p_friend_posts"
        case pTags = "p_tags"
        case pCollaborativeListInvitations = "p_collaborative_list_invitations"
        case pLikes = "p_likes"
        case pComments = "p_comments"
        case pReactions = "p_reactions"
        case pFriendRequests = "p_friend_requests"
    }
}
