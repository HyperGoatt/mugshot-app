import Foundation
import Testing
@testable import testMugshot

struct AutomaticSipRecoveryCoordinatorTests {
    @MainActor
    @Test func reconnectDrainsFIFOAndReconcilesBeforeRetry() async throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let accountID = UUID()
        var first = try prepare(
            fixture.store,
            accountID: accountID,
            caption: "First"
        )
        let second = try prepare(
            fixture.store,
            accountID: accountID,
            caption: "Second"
        )
        first.finalizationRequestedAt = Date(timeIntervalSince1970: 100)
        try fixture.store.save(first)
        first = try #require(fixture.store.load(visitId: first.id, userId: accountID))

        var events: [String] = []
        let dependencies = AutomaticSipRecoveryDependencies(
            loadRecords: { try fixture.store.loadAll(userId: $0) },
            reconcile: { record in
                events.append("reconcile:\(record.id)")
                var reconciled = record
                reconciled.remoteFinalizedAt = Date(timeIntervalSince1970: 101)
                try fixture.store.save(reconciled)
                return try #require(
                    fixture.store.load(visitId: record.id, userId: accountID)
                )
            },
            recover: { candidate in
                events.append(
                    "recover:\(candidate.record.id):\(candidate.reconciledRemoteState)"
                )
                let latest = try #require(
                    fixture.store.load(
                        visitId: candidate.record.id,
                        userId: accountID
                    )
                )
                fixture.store.remove(latest)
                return candidate.record.id
            }
        )
        let coordinator = AutomaticSipRecoveryCoordinator(
            dependencies: dependencies,
            observesNetwork: false
        )

        coordinator.activate(accountID: accountID)
        coordinator.setAppActive(true)
        #expect(coordinator.state == .waitingForNetwork(2))
        #expect(events.isEmpty)

        coordinator.setNetworkAvailable(true)
        let completed = await waitUntil { coordinator.state == .idle }

        #expect(completed)
        #expect(events == [
            "reconcile:\(first.id)",
            "recover:\(first.id):true",
            "reconcile:\(second.id)",
            "recover:\(second.id):true"
        ])
        #expect(coordinator.completionRevision == 2)
    }

    @MainActor
    @Test func legacyOutboxRecordReconcilesAlreadyPublishedVisitBeforeRetry() async throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let accountID = UUID()
        let published = try prepare(
            fixture.store,
            accountID: accountID,
            caption: "Published before the local receipt was saved"
        )
        var recoveredRemoteFinalization = false

        let dependencies = AutomaticSipRecoveryDependencies(
            loadRecords: { try fixture.store.loadAll(userId: $0) },
            reconcile: { record in
                // Model the owner-bound server probe returning `complete` for
                // an older outbox record with no finalization marker.
                #expect(record.finalizationRequestedAt == nil)
                var reconciled = record
                reconciled.remoteFinalizedAt = Date(timeIntervalSince1970: 101)
                try fixture.store.save(reconciled)
                return try #require(
                    fixture.store.load(visitId: record.id, userId: accountID)
                )
            },
            recover: { candidate in
                recoveredRemoteFinalization = candidate.reconciledRemoteState
                    && candidate.record.isRemoteFinalized
                let latest = try #require(
                    fixture.store.load(
                        visitId: candidate.record.id,
                        userId: accountID
                    )
                )
                fixture.store.remove(latest)
                return candidate.record.id
            }
        )
        let coordinator = AutomaticSipRecoveryCoordinator(
            dependencies: dependencies,
            observesNetwork: false
        )

        coordinator.activate(accountID: accountID)
        coordinator.setNetworkAvailable(true)
        coordinator.setAppActive(true)
        let completed = await waitUntil { coordinator.state == .idle }

        #expect(completed)
        #expect(recoveredRemoteFinalization)
        #expect(coordinator.completionRevision == 1)
        #expect(try fixture.store.loadAll(userId: accountID).isEmpty)
        #expect(published.remoteFinalizedAt == nil)
    }

    @Test func publishedDraftCleanupRemovesOnlyTheMatchingOwnerDraft() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let draftDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PublishedSipDraftCleanerTests.\(UUID().uuidString)",
                isDirectory: true
            )
        defer { try? FileManager.default.removeItem(at: draftDirectory) }
        let draftStore = SipDraftStore(baseDirectory: draftDirectory)
        let accountID = UUID()
        let otherAccountID = UUID()
        let matchingDraft = SipDraft(
            ownerUserID: accountID,
            context: .home,
            drinkName: "Already posted",
            visibility: .friends
        )
        let otherDraft = SipDraft(
            ownerUserID: otherAccountID,
            context: .home,
            drinkName: "Still drafting",
            visibility: .private
        )
        _ = try draftStore.save(
            matchingDraft,
            images: [],
            in: .user(accountID)
        )
        _ = try draftStore.save(
            otherDraft,
            images: [],
            in: .user(otherAccountID)
        )
        var published = try fixture.store.prepare(
            visitId: matchingDraft.id,
            userId: accountID,
            cafe: nil,
            entryContext: .home,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Coffee",
            caption: "Already posted",
            notes: nil,
            visibility: .friends,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            images: [],
            posterPhotoIndex: 0
        )
        published.remoteFinalizedAt = Date(timeIntervalSince1970: 101)
        try fixture.store.save(published)
        let cleaner = PublishedSipDraftCleaner(draftStore: draftStore)

        #expect(cleaner.removeDraft(matching: published))
        #expect(draftStore.load(id: matchingDraft.id, in: .user(accountID)) == nil)
        #expect(draftStore.load(id: otherDraft.id, in: .user(otherAccountID)) != nil)
    }

    @MainActor
    @Test func publishedRecoveryFailureDoesNotClaimDeviceIsOffline() async throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let accountID = UUID()
        _ = try prepare(
            fixture.store,
            accountID: accountID,
            caption: "Already visible"
        )
        let dependencies = AutomaticSipRecoveryDependencies(
            loadRecords: { try fixture.store.loadAll(userId: $0) },
            reconcile: { record in
                var reconciled = record
                reconciled.remoteFinalizedAt = Date(timeIntervalSince1970: 101)
                try fixture.store.save(reconciled)
                return reconciled
            },
            recover: { _ in
                throw InjectedRecoveryFailure.transport
            }
        )
        let coordinator = AutomaticSipRecoveryCoordinator(
            dependencies: dependencies,
            observesNetwork: false
        )

        coordinator.activate(accountID: accountID)
        coordinator.setNetworkAvailable(true)
        coordinator.setAppActive(true)
        let failed = await waitUntil {
            if case .failed = coordinator.state { return true }
            return false
        }

        #expect(failed)
        guard case .failed(let count, let published, let message) = coordinator.state else {
            Issue.record("Expected the published recovery state to remain actionable.")
            return
        }
        #expect(count == 1)
        #expect(published)
        #expect(message.contains("already published"))
        #expect(!message.localizedCaseInsensitiveContains("online"))
    }

    @MainActor
    @Test func repeatedLifecycleTriggersRemainSingleFlight() async throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let accountID = UUID()
        let first = try prepare(fixture.store, accountID: accountID, caption: "First")
        let second = try prepare(fixture.store, accountID: accountID, caption: "Second")
        var activeRecoveries = 0
        var maximumConcurrentRecoveries = 0
        var recoveredIDs: [UUID] = []

        let dependencies = AutomaticSipRecoveryDependencies(
            loadRecords: { try fixture.store.loadAll(userId: $0) },
            reconcile: { $0 },
            recover: { candidate in
                activeRecoveries += 1
                maximumConcurrentRecoveries = max(
                    maximumConcurrentRecoveries,
                    activeRecoveries
                )
                recoveredIDs.append(candidate.record.id)
                try await Task.sleep(for: .milliseconds(35))
                let latest = try #require(
                    fixture.store.load(
                        visitId: candidate.record.id,
                        userId: accountID
                    )
                )
                fixture.store.remove(latest)
                activeRecoveries -= 1
                return candidate.record.id
            }
        )
        let coordinator = AutomaticSipRecoveryCoordinator(
            dependencies: dependencies,
            observesNetwork: false
        )

        coordinator.activate(accountID: accountID)
        coordinator.setNetworkAvailable(true)
        coordinator.setAppActive(true)
        coordinator.retryNow()
        coordinator.setAppActive(true)
        coordinator.setNetworkAvailable(true)
        coordinator.retryNow()

        let completed = await waitUntil { coordinator.state == .idle }

        #expect(completed)
        #expect(maximumConcurrentRecoveries == 1)
        #expect(recoveredIDs == [first.id, second.id])
        #expect(Set(recoveredIDs).count == 2)
    }

    @MainActor
    @Test func activeAccountNeverDrainsAnotherAccountsOutbox() async throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let first = try prepare(
            fixture.store,
            accountID: firstAccountID,
            caption: "First account"
        )
        let second = try prepare(
            fixture.store,
            accountID: secondAccountID,
            caption: "Second account"
        )
        var recoveredIDs: [UUID] = []
        let dependencies = AutomaticSipRecoveryDependencies(
            loadRecords: { try fixture.store.loadAll(userId: $0) },
            reconcile: { $0 },
            recover: { candidate in
                recoveredIDs.append(candidate.record.id)
                let latest = try #require(
                    fixture.store.load(
                        visitId: candidate.record.id,
                        userId: candidate.record.userId
                    )
                )
                fixture.store.remove(latest)
                return candidate.record.id
            }
        )
        let coordinator = AutomaticSipRecoveryCoordinator(
            dependencies: dependencies,
            observesNetwork: false
        )

        coordinator.activate(accountID: firstAccountID)
        coordinator.setNetworkAvailable(true)
        coordinator.setAppActive(true)
        let completed = await waitUntil { coordinator.state == .idle }

        #expect(completed)
        #expect(recoveredIDs == [first.id])
        #expect(try fixture.store.loadAll(userId: firstAccountID).isEmpty)
        #expect(try fixture.store.loadAll(userId: secondAccountID).map(\.id) == [second.id])
    }

    @MainActor
    @Test func accountSwitchReleasesOldRunWhenCancelledDependencyThrowsAnotherError() async throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let first = try prepare(
            fixture.store,
            accountID: firstAccountID,
            caption: "First account"
        )
        let second = try prepare(
            fixture.store,
            accountID: secondAccountID,
            caption: "Second account"
        )
        var firstRecoveryStarted = false
        var recoveredIDs: [UUID] = []
        let dependencies = AutomaticSipRecoveryDependencies(
            loadRecords: { try fixture.store.loadAll(userId: $0) },
            reconcile: { $0 },
            recover: { candidate in
                if candidate.record.userId == firstAccountID {
                    firstRecoveryStarted = true
                    // Model an SDK call that observes cancellation but maps it
                    // to a transport error before returning to the coordinator.
                    try? await Task.sleep(for: .seconds(1))
                    throw InjectedRecoveryFailure.transport
                }
                recoveredIDs.append(candidate.record.id)
                let latest = try #require(
                    fixture.store.load(
                        visitId: candidate.record.id,
                        userId: candidate.record.userId
                    )
                )
                fixture.store.remove(latest)
                return candidate.record.id
            }
        )
        let coordinator = AutomaticSipRecoveryCoordinator(
            dependencies: dependencies,
            observesNetwork: false
        )

        coordinator.activate(accountID: firstAccountID)
        coordinator.setNetworkAvailable(true)
        coordinator.setAppActive(true)
        let started = await waitUntil { firstRecoveryStarted }
        #expect(started)

        coordinator.activate(accountID: secondAccountID)
        let completed = await waitUntil { coordinator.state == .idle }

        #expect(completed)
        #expect(recoveredIDs == [second.id])
        #expect(try fixture.store.loadAll(userId: firstAccountID).map(\.id) == [first.id])
        #expect(try fixture.store.loadAll(userId: secondAccountID).isEmpty)
    }

    @MainActor
    @Test func unreadableLocalQueueIsExplicitAndNeverStartsRecovery() {
        let accountID = UUID()
        var loadAttempts = 0
        var recoverCalled = false
        let dependencies = AutomaticSipRecoveryDependencies(
            loadRecords: { _ in
                loadAttempts += 1
                throw InjectedRecoveryFailure.localRead
            },
            reconcile: { $0 },
            recover: { candidate in
                recoverCalled = true
                return candidate.record.id
            }
        )
        let coordinator = AutomaticSipRecoveryCoordinator(
            dependencies: dependencies,
            observesNetwork: false
        )

        coordinator.activate(accountID: accountID)
        coordinator.setNetworkAvailable(true)
        coordinator.setAppActive(true)

        guard case .localDataUnavailable(let message) = coordinator.state else {
            Issue.record("An unreadable queue was presented as a normal recovery state.")
            return
        }
        #expect(message.contains("left unchanged"))
        #expect(loadAttempts > 0)
        #expect(!recoverCalled)
    }

    @MainActor
    private func waitUntil(
        _ predicate: @escaping () -> Bool
    ) async -> Bool {
        for _ in 0..<150 {
            if predicate() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return predicate()
    }

    private func prepare(
        _ store: PendingVisitSubmissionStore,
        accountID: UUID,
        caption: String
    ) throws -> PendingVisitSubmissionRecord {
        try store.prepare(
            userId: accountID,
            cafe: nil,
            entryContext: .home,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Coffee",
            caption: caption,
            notes: nil,
            visibility: .friends,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            images: [],
            posterPhotoIndex: 0
        )
    }

    private func makeStore() throws -> (
        store: PendingVisitSubmissionStore,
        cleanup: () -> Void
    ) {
        let suiteName = "AutomaticSipRecoveryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "AutomaticSipRecoveryTests.\(UUID().uuidString)",
            isDirectory: true
        )
        return (
            PendingVisitSubmissionStore(
                defaults: defaults,
                baseDirectory: directory
            ),
            {
                defaults.removePersistentDomain(forName: suiteName)
                try? FileManager.default.removeItem(at: directory)
            }
        )
    }

    private enum InjectedRecoveryFailure: Error {
        case transport
        case localRead
    }
}
