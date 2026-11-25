import Combine
import Foundation

/// Owns notification consent and the minimum local facts needed to avoid
/// nudging someone who has just saved privately or while offline.
@MainActor
final class MugsyReminderCoordinator: ObservableObject {
    static let shared = MugsyReminderCoordinator()
    @Published private(set) var accountID: UUID?
    @Published private(set) var preferences = MugsyReminderPreferences()
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var backendAvailable = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var confirmationMessage: String?
    @Published private(set) var showsInvitation = false
    @Published private(set) var showsMemoryCard = false
    @Published private(set) var pendingIntent: MugsyNotificationIntent?

    private let defaults: UserDefaults
    private let now: () -> Date
    private let makeService: @MainActor (UUID) throws -> any MugsyReminderServicing
    private let loadHistory: @MainActor (UUID) throws -> [MugsyCompletedMemorySignal]
    private var service: (any MugsyReminderServicing)?
    private var generation = UUID()
    private var loadID = UUID()
    private var flushTask: Task<Void, Never>?
    private var flushingID: UUID?
    private var cardShownThisSession = false
    private var isActive = false
    private var lastHeartbeat: Date?
    private var localHistoryReadable = true
    private static let pendingIntentKey = "MugshotMugsy.pendingIntent.v1"

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init,
         makeService: @escaping @MainActor (UUID) throws -> any MugsyReminderServicing = { owner in
             MugsyReminderService(client: try SupabaseClientProvider.shared.client(), accountID: owner)
         }, loadHistory: @escaping @MainActor (UUID) throws -> [MugsyCompletedMemorySignal] = { owner in
             try HomeRecipeWorkspaceStore.shared.exportSnapshot(ownerID: owner).attempts.compactMap { attempt in
                 guard let saved = attempt.savedAt else { return nil }
                 return MugsyCompletedMemorySignal(accountID: owner, memoryID: attempt.id, origin: .home,
                    completedAt: saved, linkedVisitID: attempt.publicationStatus == .published ? attempt.publicationDraftID : nil)
             }
         }) {
        self.defaults = defaults; self.now = now; self.makeService = makeService
        self.loadHistory = loadHistory
        if let data = defaults.data(forKey: Self.pendingIntentKey),
           let intent = try? JSONDecoder().decode(MugsyNotificationIntent.self, from: data),
           intent.expiresAt > now() { pendingIntent = intent }
    }

    func activate(accountID owner: UUID?) async {
        if accountID != owner {
            generation = UUID(); flushTask?.cancel(); service = nil
            preferences = .init(); backendAvailable = false
            showsInvitation = false; showsMemoryCard = false; cardShownThisSession = false
            errorMessage = nil; confirmationMessage = nil
            lastHeartbeat = nil
            isSaving = false
            flushingID = nil
        }
        accountID = owner
        if let owner, let intent = pendingIntent, intent.accountID != owner { clearIntent() }
        guard let owner else { isLoading = false; return }
        do {
            let history = try loadHistory(owner)
            let initialHistory = readFacts(owner).isEmpty
            adoptCompletedHistory(accountID: owner, signals: history, suppressInvitation: initialHistory)
            localHistoryReadable = true
        } catch { localHistoryReadable = false }
        let expected = generation
        let expectedLoad = UUID(); loadID = expectedLoad
        isLoading = true
        defer { if generation == expected, loadID == expectedLoad { isLoading = false } }
        do {
            let candidate = try makeService(owner)
            // Registering the current timezone may advance the server's
            // preference revision. Read only after that operational update.
            try? await candidate.capability(deviceID: NotificationDeviceCoordinator.shared.currentInstallationID)
            guard accountID == owner, generation == expected, loadID == expectedLoad else { return }
            let loaded = try await candidate.fetch()
            guard accountID == owner, generation == expected, loadID == expectedLoad else { return }
            service = candidate
            if loaded.revision >= preferences.revision { preferences = loaded }
            backendAvailable = true; errorMessage = nil
            await flushPendingSignals()
        } catch {
            guard accountID == owner, generation == expected, loadID == expectedLoad else { return }
            backendAvailable = false
            errorMessage = "Mugsy’s push reminders aren’t available yet. Your journal and in-app reminders still work."
        }
        refreshLocalCard()
    }

    @discardableResult
    func save(_ proposed: MugsyReminderPreferences, requestID: UUID = UUID()) async -> Bool {
        guard let owner = accountID, let service, backendAvailable, !isSaving else { return false }
        guard proposed.timingIsValid else {
            errorMessage = "Choose a reminder time inside your daytime window."
            return false
        }
        let expected = generation
        isSaving = true; confirmationMessage = nil
        defer { if generation == expected { isSaving = false } }
        do {
            var value = proposed; value.timezoneName = TimeZone.current.identifier
            let saved = try await service.save(value, requestID: requestID)
            guard accountID == owner, generation == expected else { return false }
            preferences = saved; errorMessage = nil
            confirmationMessage = "Your reminder preferences are saved."
            MugshotAnalytics.shared.capture(.mugsyReminder(action: .preferencesSaved, pace: saved.pace.rawValue))
            return true
        } catch {
            guard accountID == owner, generation == expected else { return false }
            errorMessage = "Mugshot couldn’t confirm that change. Your last saved preferences still apply. Try again when connected."
            return false
        }
    }

    func pause(days: Int?) async {
        var next = preferences
        next.pausedIndefinitely = days == nil
        next.pausedUntil = days.map { now().addingTimeInterval(Double($0) * 86400) }
        if await save(next) {
            showsMemoryCard = false
            MugshotAnalytics.shared.capture(.mugsyReminder(action: .paused, pace: next.pace.rawValue))
        }
    }

    func useLightPace() async {
        var next = preferences; next.pace = .light
        _ = await save(next)
    }

    func recordCompletedMemory(accountID owner: UUID, memoryID: UUID, origin: MugsyMemoryOrigin,
                               completedAt: Date, linkedVisitID: UUID? = nil) {
        let signal = MugsyCompletedMemorySignal(accountID: owner, memoryID: memoryID,
            origin: origin, completedAt: completedAt, linkedVisitID: linkedVisitID)
        if signalsAreReadable(owner) {
            var pending = readSignals(owner)
            if !pending.contains(where: { $0.id == signal.id }) { pending.append(signal) }
            persist(pending, key: signalKey(owner))
        }
        var facts = readFacts(owner)
        let isNewMemory = facts[memoryID.uuidString] == nil
            && linkedVisitID.map { facts[$0.uuidString] == nil } != false
        if let linkedVisitID { facts.removeValue(forKey: linkedVisitID.uuidString) }
        facts[memoryID.uuidString] = min(facts[memoryID.uuidString] ?? completedAt, completedAt)
        persist(facts, key: factKey(owner))
        rememberCompletedDraft(signal)
        if isNewMemory, accountID == owner {
            MugshotAnalytics.shared.capture(
                .memoryCompleted(origin: origin == .home ? .home : .canonical), expectedUserID: owner
            )
        }
        guard accountID == owner else { return }
        showsMemoryCard = false
        refreshLocalCard()
        flushTask?.cancel()
        flushTask = Task { await flushPendingSignals() }
    }

    /// A durable Home deletion withdraws its scheduling fact too. Keep this
    /// separate from upserts so a failed request cannot resurrect a memory.
    func recordRemovedMemory(accountID owner: UUID, memoryID: UUID) {
        if withdrawalsAreReadable(owner) {
            var removals = readWithdrawals(owner)
            if !removals.contains(memoryID) { removals.append(memoryID) }
            persist(removals, key: withdrawalKey(owner))
        }
        if signalsAreReadable(owner) {
            persist(readSignals(owner).filter { $0.memoryID != memoryID }, key: signalKey(owner))
        }
        var facts = readFacts(owner); facts.removeValue(forKey: memoryID.uuidString)
        persist(facts, key: factKey(owner))
        guard accountID == owner else { return }
        showsMemoryCard = false; showsInvitation = false; refreshLocalCard()
        flushTask?.cancel()
        flushTask = Task { await flushPendingSignals() }
    }

    func dismissInvitation() {
        guard let owner = accountID else { return }
        defaults.set(true, forKey: invitationKey(owner)); showsInvitation = false
        MugshotAnalytics.shared.capture(.mugsyReminder(action: .invitationDismissed))
    }

    func markInvitationViewed() {
        if let owner = accountID { defaults.set(true, forKey: invitationKey(owner)) }
        MugshotAnalytics.shared.capture(.mugsyReminder(action: .invitationViewed))
    }

    func dismissCard() {
        cardShownThisSession = true; showsMemoryCard = false
        MugshotAnalytics.shared.capture(.mugsyReminder(action: .cardDismissed, family: "return_memory"))
    }

    func markCardViewed() {
        MugshotAnalytics.shared.capture(.mugsyReminder(action: .cardViewed, family: "return_memory"))
    }

    func setActivity(active: Bool, composing: Bool) async {
        if active && !isActive { cardShownThisSession = false; refreshLocalCard() }
        isActive = active
        guard let owner = accountID, let service else { return }
        let expected = generation
        // Frequent view updates never generate a network heartbeat storm.
        if !composing, active, let lastHeartbeat, now().timeIntervalSince(lastHeartbeat) < 60 { return }
        lastHeartbeat = now()
        try? await service.activity(deviceID: NotificationDeviceCoordinator.shared.currentInstallationID,
                                    active: active, composing: composing)
        guard accountID == owner, generation == expected else { return }
        if active { await flushPendingSignals() }
    }

    func recordWeekViewed(_ end: Date) async {
        guard let service else { return }
        try? await service.viewed(weekEnd: end)
    }

    func recordNotificationOpened(_ intent: MugsyNotificationIntent) async {
        guard intent.accountID == accountID, let service else { return }
        try? await service.opened(occurrenceID: intent.occurrenceID)
    }

    func requestNearbyPermit() async -> MugsyNearbyPermit? {
        guard let owner = accountID, let service, backendAvailable else { return nil }
        let expected = generation
        do {
            let permit = try await service.nearbyPermit(
                deviceID: NotificationDeviceCoordinator.shared.currentInstallationID, requestID: UUID())
            guard generation == expected, accountID == owner, permit.allowed,
                  permit.permitID != nil, permit.expiresAt.map({ $0 > now() }) == true else { return nil }
            return permit
        } catch { return nil }
    }

    func enqueue(_ intent: MugsyNotificationIntent) {
        guard intent.expiresAt > now(), accountID == nil || accountID == intent.accountID else { return }
        pendingIntent = intent
        persist(intent, key: Self.pendingIntentKey)
    }

    func authorizePendingIntent() async -> MugsyNotificationIntent? {
        guard let intent = pendingIntent, intent.accountID == accountID, let service else { return nil }
        let expected = generation
        do {
            let allowed = try await service.authorize(intent)
            guard generation == expected, accountID == intent.accountID else { return nil }
            guard allowed, intent.expiresAt > now() else {
                clearIntent(); errorMessage = "This reminder is no longer available. Your journal is ready when you are."
                return nil
            }
            return intent
        } catch {
            guard generation == expected else { return nil }
            errorMessage = "Reconnect to open this reminder. Your journal is still here."
            return nil
        }
    }

    func clearIntent() { pendingIntent = nil; defaults.removeObject(forKey: Self.pendingIntentKey) }

    /// Restores existing history without treating sync/import as a new save.
    func adoptCompletedHistory(accountID owner: UUID, signals: [MugsyCompletedMemorySignal], suppressInvitation: Bool = true) {
        var facts = readFacts(owner)
        guard signalsAreReadable(owner) else {
            localHistoryReadable = false
            return
        }
        var pending = readSignals(owner)
        for signal in signals where signal.accountID == owner {
            if let linked = signal.linkedVisitID { facts.removeValue(forKey: linked.uuidString) }
            if facts[signal.memoryID.uuidString] == nil,
               !pending.contains(where: { $0.id == signal.id }) { pending.append(signal) }
            facts[signal.memoryID.uuidString] = min(facts[signal.memoryID.uuidString] ?? signal.completedAt, signal.completedAt)
            rememberCompletedDraft(signal)
        }
        persist(facts, key: factKey(owner)); persist(pending, key: signalKey(owner))
        if suppressInvitation, !signals.isEmpty { defaults.set(true, forKey: invitationKey(owner)) }
    }

    func removeAll(accountID owner: UUID) {
        for key in [signalKey(owner), withdrawalKey(owner), factKey(owner), invitationKey(owner), completedDraftKey(owner)] { defaults.removeObject(forKey: key) }
        if accountID == owner { signOut() }
    }

    func signOut() {
        generation = UUID(); accountID = nil; service = nil; backendAvailable = false
        preferences = .init(); showsInvitation = false; showsMemoryCard = false
        isLoading = false; isSaving = false; clearIntent(); flushTask?.cancel()
    }

    func flushPendingSignals() async {
        guard flushingID == nil, let owner = accountID, let service else { return }
        let expected = generation
        let operation = UUID(); flushingID = operation
        defer { if flushingID == operation { flushingID = nil } }
        do { try await service.baseline(ready: false) } catch { return }
        guard generation == expected, accountID == owner else { return }
        guard withdrawalsAreReadable(owner) else { return }
        for memoryID in readWithdrawals(owner) {
            guard !Task.isCancelled, generation == expected, accountID == owner else { return }
            do {
                try await service.withdraw(memoryID: memoryID)
                guard generation == expected, accountID == owner else { return }
                persist(readWithdrawals(owner).filter { $0 != memoryID }, key: withdrawalKey(owner))
            } catch {
                MugshotAnalytics.shared.capture(.mugsyReminder(action: .synchronizationFailed, outcome: "unavailable"))
                return
            }
        }
        guard signalsAreReadable(owner) else { return }
        for signal in readSignals(owner) {
            guard !Task.isCancelled, generation == expected, accountID == owner else { return }
            do {
                try await service.record(signal)
                guard generation == expected, accountID == owner else { return }
                let remaining = readSignals(owner).filter { $0.id != signal.id }
                persist(remaining, key: signalKey(owner))
            } catch {
                MugshotAnalytics.shared.capture(.mugsyReminder(action: .synchronizationFailed, outcome: "unavailable"))
                return
            }
        }
        guard !Task.isCancelled, generation == expected, accountID == owner, localHistoryReadable,
              readSignals(owner).isEmpty, readWithdrawals(owner).isEmpty else { return }
        try? await service.baseline(ready: true)
    }

    func pendingSignals(accountID owner: UUID) -> [MugsyCompletedMemorySignal] { readSignals(owner) }
    func pendingWithdrawals(accountID owner: UUID) -> [UUID] { readWithdrawals(owner) }

    func isCompletedDraft(_ id: UUID, accountID owner: UUID) -> Bool {
        completedDraftIDs(owner).contains(id)
    }

    private func refreshLocalCard() {
        guard let owner = accountID else { return }
        let facts = readFacts(owner)
        showsInvitation = facts.count == 1 && !preferences.mugsyEnabled && !defaults.bool(forKey: invitationKey(owner))
        let latest = facts.values.max()
        showsMemoryCard = !showsInvitation && !cardShownThisSession
            && preferences.pace != .off
            && !preferences.isPaused(at: now())
            && (latest.map { now().timeIntervalSince($0) >= 5 * 86400 } ?? false)
    }

    private func signalKey(_ owner: UUID) -> String { "MugshotMugsy.pendingSignals.v1.\(owner)" }
    private func withdrawalKey(_ owner: UUID) -> String { "MugshotMugsy.withdrawals.v1.\(owner)" }
    private func factKey(_ owner: UUID) -> String { "MugshotMugsy.memoryFacts.v1.\(owner)" }
    private func invitationKey(_ owner: UUID) -> String { "MugshotMugsy.invitationDismissed.v1.\(owner)" }
    private func completedDraftKey(_ owner: UUID) -> String { "MugshotMugsy.completedDraftIDs.v1.\(owner)" }
    private func completedDraftIDs(_ owner: UUID) -> Set<UUID> {
        defaults.data(forKey: completedDraftKey(owner)).flatMap { try? JSONDecoder().decode(Set<UUID>.self, from: $0) } ?? []
    }
    private func rememberCompletedDraft(_ signal: MugsyCompletedMemorySignal) {
        guard let id = signal.linkedVisitID ?? (signal.origin == .canonical ? signal.memoryID : nil) else { return }
        var values = completedDraftIDs(signal.accountID); values.insert(id)
        persist(values, key: completedDraftKey(signal.accountID))
    }
    private func readSignals(_ owner: UUID) -> [MugsyCompletedMemorySignal] {
        defaults.data(forKey: signalKey(owner)).flatMap { try? JSONDecoder().decode([MugsyCompletedMemorySignal].self, from: $0) } ?? []
    }
    private func signalsAreReadable(_ owner: UUID) -> Bool {
        guard let data = defaults.data(forKey: signalKey(owner)) else { return true }
        return (try? JSONDecoder().decode([MugsyCompletedMemorySignal].self, from: data)) != nil
    }
    private func readWithdrawals(_ owner: UUID) -> [UUID] {
        defaults.data(forKey: withdrawalKey(owner)).flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? []
    }
    private func withdrawalsAreReadable(_ owner: UUID) -> Bool {
        guard let data = defaults.data(forKey: withdrawalKey(owner)) else { return true }
        return (try? JSONDecoder().decode([UUID].self, from: data)) != nil
    }
    private func readFacts(_ owner: UUID) -> [String: Date] {
        defaults.data(forKey: factKey(owner)).flatMap { try? JSONDecoder().decode([String: Date].self, from: $0) } ?? [:]
    }
    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
