import Foundation
import Testing
@testable import testMugshot

@MainActor
struct EnforcementNoticeStoreTests {
    @Test func accountSwitchLoadsOnlyThatAccountsCachedNotice() throws {
        let suiteName = "EnforcementNoticeStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstAccount = UUID()
        let secondAccount = UUID()
        let first = action(kind: .accountSuspended, reason: "first_account")
        let second = action(kind: .warning, reason: "second_account")
        let prefix = "MugshotEnforcementSummary.v1."
        defaults.set(
            try JSONEncoder().encode([first]),
            forKey: prefix + LocalAccountScope.user(firstAccount).defaultsComponent
        )
        defaults.set(
            try JSONEncoder().encode([second]),
            forKey: prefix + LocalAccountScope.user(secondAccount).defaultsComponent
        )

        let store = EnforcementNoticeStore(defaults: defaults)
        store.prepare(accountID: firstAccount)
        #expect(store.primaryAction == first)
        #expect(store.activeCount == 1)

        store.prepare(accountID: secondAccount)
        #expect(store.primaryAction == second)
        #expect(store.primaryAction?.reasonCode != first.reasonCode)

        store.prepare(accountID: nil)
        #expect(store.primaryAction == nil)
        #expect(store.activeCount == 0)

        store.removeAll(accountID: firstAccount)
        #expect(
            defaults.data(
                forKey: prefix + LocalAccountScope.user(firstAccount).defaultsComponent
            ) == nil
        )
        #expect(
            defaults.data(
                forKey: prefix + LocalAccountScope.user(secondAccount).defaultsComponent
            ) != nil
        )
    }

    @Test func staleRefreshCannotCacheOrDisplayAnotherAccountsNotice() async throws {
        let suiteName = "EnforcementNoticeRefreshSwitch.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstAccount = UUID()
        let secondAccount = UUID()
        let delayedAction = action(
            kind: .accountSuspended,
            reason: "delayed_first_account"
        )
        let currentAction = action(
            kind: .warning,
            reason: "current_second_account"
        )
        let backend = EnforcementRefreshSwitchBackend(
            delayedAccountID: firstAccount,
            delayedActions: [delayedAction],
            currentActions: [currentAction]
        )
        let store = EnforcementNoticeStore(
            defaults: defaults,
            loadActions: { accountID in
                await backend.actions(accountID: accountID)
            }
        )

        let delayedActivation = Task { @MainActor in
            await store.activate(accountID: firstAccount)
        }
        await backend.waitUntilDelayedRefreshStarts()

        await store.activate(accountID: secondAccount)
        #expect(store.primaryAction == currentAction)
        #expect(store.activeCount == 1)

        await backend.releaseDelayedRefresh()
        await delayedActivation.value

        #expect(store.primaryAction == currentAction)
        #expect(store.activeCount == 1)
        let prefix = "MugshotEnforcementSummary.v1."
        #expect(defaults.data(
            forKey: prefix + LocalAccountScope.user(firstAccount).defaultsComponent
        ) == nil)
        let secondData = try #require(defaults.data(
            forKey: prefix + LocalAccountScope.user(secondAccount).defaultsComponent
        ))
        #expect(
            try JSONDecoder().decode(
                [ModerationEnforcementAction].self,
                from: secondData
            ) == [currentAction]
        )
    }

    private func action(
        kind: ModerationActionKind,
        reason: String
    ) -> ModerationEnforcementAction {
        ModerationEnforcementAction(
            actionID: UUID(),
            actionKind: kind,
            subjectKind: "user",
            subjectID: UUID(),
            reasonCode: reason,
            startsAt: "2024-07-21T12:00:00Z",
            endsAt: nil,
            revokedAt: nil,
            isActive: true,
            appealEligible: true,
            appealID: nil,
            appealStatus: nil,
            appealSubmittedAt: nil,
            appealReviewedAt: nil,
            appealResolutionSummary: nil
        )
    }
}

private actor EnforcementRefreshSwitchBackend {
    private let delayedAccountID: UUID
    private let delayedActions: [ModerationEnforcementAction]
    private let currentActions: [ModerationEnforcementAction]
    private var delayedRefreshStarted = false
    private var delayedRefreshReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        delayedAccountID: UUID,
        delayedActions: [ModerationEnforcementAction],
        currentActions: [ModerationEnforcementAction]
    ) {
        self.delayedAccountID = delayedAccountID
        self.delayedActions = delayedActions
        self.currentActions = currentActions
    }

    func actions(accountID: UUID) async -> [ModerationEnforcementAction] {
        guard accountID == delayedAccountID else { return currentActions }
        delayedRefreshStarted = true
        let pendingStartWaiters = startWaiters
        startWaiters = []
        pendingStartWaiters.forEach { $0.resume() }
        if !delayedRefreshReleased {
            await withCheckedContinuation { continuation in
                releaseWaiters.append(continuation)
            }
        }
        return delayedActions
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
