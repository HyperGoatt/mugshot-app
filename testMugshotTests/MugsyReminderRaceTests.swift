import Foundation
import Testing
@testable import testMugshot

/// Deliberate suspension points exercise the production coordinator's ownership,
/// revision and durable-outbox boundaries. No backend or owner files are read.
@MainActor
@Suite(.serialized)
struct MugsyReminderRaceTests {
    @Test func lateFetchForPreviousAccountCannotReplaceCurrentPreferences() async throws {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let first = UUID(), second = UUID()
        let oldService = MugsyRaceService()
        let newService = MugsyRaceService()
        newService.preferences.pace = .light
        newService.preferences.revision = 4
        var resumeOld: ((MugsyReminderPreferences) -> Void)?
        oldService.fetchHandler = {
            await withCheckedContinuation { continuation in
                resumeOld = { continuation.resume(returning: $0) }
            }
        }
        let coordinator = MugsyReminderCoordinator(defaults: fixture.defaults,
            makeService: { $0 == first ? oldService : newService }, loadHistory: { _ in [] })
        let oldActivation = Task { await coordinator.activate(accountID: first) }
        #expect(await waitFor { resumeOld != nil })
        await coordinator.activate(accountID: second)
        var stale = MugsyReminderPreferences()
        stale.mugsyEnabled = true; stale.revision = 90
        let finishOldFetch = try #require(resumeOld)
        finishOldFetch(stale)
        await oldActivation.value
        #expect(coordinator.accountID == second)
        #expect(coordinator.preferences.pace == .light)
        #expect(coordinator.preferences.revision == 4)
        #expect(!coordinator.preferences.mugsyEnabled)
        #expect(coordinator.backendAvailable)
        #expect(!coordinator.isLoading)
        coordinator.signOut()
    }

    @Test func accountSwitchClearsBusySaveAndRejectsItsLateResult() async throws {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let first = UUID(), second = UUID()
        let oldService = MugsyRaceService(), newService = MugsyRaceService()
        var resumeSave: ((MugsyReminderPreferences) -> Void)?
        oldService.saveHandler = { _ in
            await withCheckedContinuation { continuation in
                resumeSave = { continuation.resume(returning: $0) }
            }
        }
        let coordinator = MugsyReminderCoordinator(defaults: fixture.defaults,
            makeService: { $0 == first ? oldService : newService }, loadHistory: { _ in [] })
        await coordinator.activate(accountID: first)
        var proposed = coordinator.preferences; proposed.mugsyEnabled = true
        let oldSave = Task { await coordinator.save(proposed) }
        #expect(await waitFor { resumeSave != nil })
        #expect(coordinator.isSaving)
        await coordinator.activate(accountID: second)
        #expect(!coordinator.isSaving)
        var lateResult = proposed; lateResult.revision = 99
        let finishOldSave = try #require(resumeSave)
        finishOldSave(lateResult)
        #expect(await oldSave.value == false)
        #expect(coordinator.accountID == second)
        #expect(coordinator.preferences.revision == 0)
        #expect(!coordinator.preferences.mugsyEnabled)
        #expect(await coordinator.save(coordinator.preferences))
        #expect(coordinator.preferences.revision == 1)
        coordinator.signOut()
    }

    @Test func fetchStartedBeforeSuccessfulSaveCannotRollBackItsRevision() async throws {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let owner = UUID(), service = MugsyRaceService()
        let coordinator = MugsyReminderCoordinator(defaults: fixture.defaults,
            makeService: { _ in service }, loadHistory: { _ in [] })
        await coordinator.activate(accountID: owner)
        let original = coordinator.preferences
        var resumeFetch: ((MugsyReminderPreferences) -> Void)?
        service.fetchHandler = {
            await withCheckedContinuation { continuation in
                resumeFetch = { continuation.resume(returning: $0) }
            }
        }
        let reload = Task { await coordinator.activate(accountID: owner) }
        #expect(await waitFor { resumeFetch != nil })
        var proposed = original; proposed.mugsyEnabled = true; proposed.pace = .light
        #expect(await coordinator.save(proposed))
        #expect(coordinator.preferences.revision == 1)
        let finishReload = try #require(resumeFetch)
        finishReload(original)
        await reload.value
        #expect(coordinator.preferences.revision == 1)
        #expect(coordinator.preferences.mugsyEnabled)
        #expect(coordinator.preferences.pace == .light)
        coordinator.signOut()
    }

    @Test func overlappingSameAccountLoadsAdoptOnlyTheLatestLoad() async throws {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let owner = UUID()
        let first = MugsyRaceService(), second = MugsyRaceService()
        second.preferences.revision = 2; second.preferences.pace = .light
        var resumeFirst: ((MugsyReminderPreferences) -> Void)?
        first.fetchHandler = {
            await withCheckedContinuation { continuation in
                resumeFirst = { continuation.resume(returning: $0) }
            }
        }
        var count = 0
        let coordinator = MugsyReminderCoordinator(defaults: fixture.defaults,
            makeService: { _ in count += 1; return count == 1 ? first : second }, loadHistory: { _ in [] })
        let oldLoad = Task { await coordinator.activate(accountID: owner) }
        #expect(await waitFor { resumeFirst != nil })
        await coordinator.activate(accountID: owner)
        var oldResult = MugsyReminderPreferences(); oldResult.revision = 99
        let finishFirstLoad = try #require(resumeFirst)
        finishFirstLoad(oldResult)
        await oldLoad.value
        #expect(coordinator.preferences.revision == 2)
        #expect(coordinator.preferences.pace == .light)
        #expect(!coordinator.isLoading)
        coordinator.signOut()
    }

    @Test func unreadableOutboxKeepsBaselineUnreadyAndPreservesItsBytes() async throws {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let owner = UUID(), memory = UUID()
        let signalKey = "MugshotMugsy.pendingSignals.v1.\(owner)"
        let unreadable = Data("preserved interrupted local state".utf8)
        fixture.defaults.set(unreadable, forKey: signalKey)
        let saved = Date(timeIntervalSince1970: 1_795_608_000)
        fixture.defaults.set(try JSONEncoder().encode([memory.uuidString: saved]),
            forKey: "MugshotMugsy.memoryFacts.v1.\(owner)")
        let service = MugsyRaceService()
        let coordinator = MugsyReminderCoordinator(defaults: fixture.defaults,
            makeService: { _ in service }, loadHistory: { _ in [
                MugsyCompletedMemorySignal(accountID: owner, memoryID: memory, origin: .home,
                    completedAt: saved, linkedVisitID: nil)
            ] })
        await coordinator.activate(accountID: owner)
        #expect(service.baselines == [false])
        #expect(service.recordAttempts.isEmpty)
        #expect(fixture.defaults.data(forKey: signalKey) == unreadable)
        coordinator.signOut()
    }

    @Test func offlineCompletionIsRetainedAndAcknowledgedOnlyAfterSuccessfulRetry() async throws {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let owner = UUID(), memory = UUID()
        let service = MugsyRaceService()
        let coordinator = MugsyReminderCoordinator(defaults: fixture.defaults,
            makeService: { _ in service }, loadHistory: { _ in [] })
        await coordinator.activate(accountID: owner)
        service.failRecords = true
        coordinator.recordCompletedMemory(accountID: owner, memoryID: memory, origin: .home, completedAt: .now)
        #expect(await waitFor { !service.recordAttempts.isEmpty })
        #expect(coordinator.pendingSignals(accountID: owner).map(\.memoryID) == [memory])
        #expect(service.baselines.last == false)
        service.failRecords = false
        for _ in 0..<20 where !coordinator.pendingSignals(accountID: owner).isEmpty {
            await Task.yield()
            await coordinator.flushPendingSignals()
        }
        #expect(coordinator.pendingSignals(accountID: owner).isEmpty)
        #expect(service.acknowledged.map(\.memoryID) == [memory])
        #expect(service.baselines.last == true)
        coordinator.signOut()
    }

    @Test func homePublicationAddsLinkageWithoutInventingAnotherLocalMemory() throws {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let owner = UUID(), memory = UUID(), visit = UUID()
        let saved = Date(timeIntervalSince1970: 1_795_608_000)
        let coordinator = MugsyReminderCoordinator(defaults: fixture.defaults,
            makeService: { _ in MugsyRaceService() }, loadHistory: { _ in [] })
        // Keep the coordinator inactive so this assertion inspects the durable
        // pre-network state, including a later publication's linkage receipt.
        coordinator.recordCompletedMemory(accountID: owner, memoryID: memory, origin: .home, completedAt: saved)
        coordinator.recordCompletedMemory(accountID: owner, memoryID: memory, origin: .home,
            completedAt: saved.addingTimeInterval(3600), linkedVisitID: visit)
        coordinator.recordCompletedMemory(accountID: owner, memoryID: memory, origin: .home,
            completedAt: saved.addingTimeInterval(3600), linkedVisitID: visit)
        let data = try #require(fixture.defaults.data(forKey: "MugshotMugsy.memoryFacts.v1.\(owner)"))
        let facts = try JSONDecoder().decode([String: Date].self, from: data)
        #expect(facts == [memory.uuidString: saved])
        #expect(coordinator.pendingSignals(accountID: owner).count == 2)
        #expect(coordinator.pendingSignals(accountID: owner).filter { $0.linkedVisitID == visit }.count == 1)
        #expect(coordinator.isCompletedDraft(visit, accountID: owner))
        #expect(!coordinator.isCompletedDraft(visit, accountID: UUID()))
    }

    @Test func withdrawalSurvivesOfflineFailureAndBlocksReadyUntilAcknowledged() async throws {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let owner = UUID(), memory = UUID()
        let service = MugsyRaceService()
        service.failWithdrawals = true
        let coordinator = MugsyReminderCoordinator(defaults: fixture.defaults,
            makeService: { _ in service }, loadHistory: { _ in [] })
        coordinator.recordCompletedMemory(accountID: owner, memoryID: memory, origin: .home, completedAt: .now)
        #expect(coordinator.pendingSignals(accountID: owner).count == 1)
        coordinator.recordRemovedMemory(accountID: owner, memoryID: memory)
        #expect(coordinator.pendingSignals(accountID: owner).isEmpty)
        #expect(coordinator.pendingWithdrawals(accountID: owner) == [memory])
        let factsData = try #require(fixture.defaults.data(forKey: "MugshotMugsy.memoryFacts.v1.\(owner)"))
        #expect(try JSONDecoder().decode([String: Date].self, from: factsData).isEmpty)

        await coordinator.activate(accountID: owner)
        #expect(service.withdrawalAttempts == [memory])
        #expect(service.acknowledgedWithdrawals.isEmpty)
        #expect(service.recordAttempts.isEmpty)
        #expect(service.baselines == [false])
        #expect(coordinator.pendingWithdrawals(accountID: owner) == [memory])

        service.failWithdrawals = false
        await coordinator.flushPendingSignals()
        #expect(coordinator.pendingWithdrawals(accountID: owner).isEmpty)
        #expect(service.acknowledgedWithdrawals == [memory])
        #expect(service.baselines == [false, false, true])
        #expect(service.recordAttempts.isEmpty)

        let otherOwner = UUID(), otherMemory = UUID()
        coordinator.recordRemovedMemory(accountID: otherOwner, memoryID: otherMemory)
        coordinator.recordRemovedMemory(accountID: owner, memoryID: memory)
        coordinator.removeAll(accountID: owner)
        #expect(coordinator.accountID == nil)
        #expect(fixture.defaults.data(forKey: "MugshotMugsy.withdrawals.v1.\(owner)") == nil)
        #expect(coordinator.pendingWithdrawals(accountID: owner).isEmpty)
        #expect(coordinator.pendingWithdrawals(accountID: otherOwner) == [otherMemory])
    }

    @Test func capabilityTimezoneRevisionIsFetchedBeforeTheFirstPreferenceSave() async throws {
        let fixture = makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let owner = UUID(), service = MugsyRaceService()
        service.capabilityHandler = { [weak service] in
            guard let service else { return }
            if service.preferences.timezoneName == nil {
                service.preferences.timezoneName = TimeZone.current.identifier
                service.preferences.revision += 1
            }
        }
        var savedRevision: Int?
        service.saveHandler = { proposed in
            savedRevision = proposed.revision
            guard proposed.revision == 1 else { throw URLError(.cannotParseResponse) }
            var saved = proposed; saved.revision = 2
            return saved
        }
        let coordinator = MugsyReminderCoordinator(defaults: fixture.defaults,
            makeService: { _ in service }, loadHistory: { _ in [] })
        await coordinator.activate(accountID: owner)
        #expect(coordinator.preferences.revision == 1)
        #expect(coordinator.preferences.timezoneName == TimeZone.current.identifier)
        var proposed = coordinator.preferences; proposed.mugsyEnabled = true
        #expect(await coordinator.save(proposed))
        #expect(savedRevision == 1)
        #expect(coordinator.preferences.revision == 2)
        coordinator.signOut()
    }

    private func makeDefaults() -> (defaults: UserDefaults, suite: String) {
        let suite = "MugsyReminderRaceTests.\(UUID())"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    private func waitFor(_ condition: @MainActor () -> Bool) async -> Bool {
        for _ in 0..<200 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }
}

@MainActor
private final class MugsyRaceService: MugsyReminderServicing {
    var preferences = MugsyReminderPreferences()
    var fetchHandler: (() async throws -> MugsyReminderPreferences)?
    var saveHandler: ((MugsyReminderPreferences) async throws -> MugsyReminderPreferences)?
    var capabilityHandler: (() async throws -> Void)?
    var failRecords = false
    var failWithdrawals = false
    var recordAttempts: [MugsyCompletedMemorySignal] = []
    var acknowledged: [MugsyCompletedMemorySignal] = []
    var withdrawalAttempts: [UUID] = []
    var acknowledgedWithdrawals: [UUID] = []
    var baselines: [Bool] = []

    func fetch() async throws -> MugsyReminderPreferences {
        if let fetchHandler { return try await fetchHandler() }
        return preferences
    }
    func save(_ value: MugsyReminderPreferences, requestID: UUID) async throws -> MugsyReminderPreferences {
        if let saveHandler { return try await saveHandler(value) }
        var updated = value; updated.revision += 1; preferences = updated
        return updated
    }
    func record(_ signal: MugsyCompletedMemorySignal) async throws {
        recordAttempts.append(signal)
        if failRecords { throw URLError(.notConnectedToInternet) }
        acknowledged.append(signal)
    }
    func withdraw(memoryID: UUID) async throws {
        withdrawalAttempts.append(memoryID)
        if failWithdrawals { throw URLError(.notConnectedToInternet) }
        acknowledgedWithdrawals.append(memoryID)
    }
    func capability(deviceID: UUID) async throws {
        try await capabilityHandler?()
    }
    func activity(deviceID: UUID, active: Bool, composing: Bool) async throws {}
    func viewed(weekEnd: Date) async throws {}
    func nearbyPermit(deviceID: UUID, requestID: UUID) async throws -> MugsyNearbyPermit {
        MugsyNearbyPermit(allowed: false, reason: "fixture", permitID: nil, expiresAt: nil)
    }
    func authorize(_ intent: MugsyNotificationIntent) async throws -> Bool { true }
    func opened(occurrenceID: UUID) async throws {}
    func baseline(ready: Bool) async throws { baselines.append(ready) }
}
