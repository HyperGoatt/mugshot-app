import Foundation
import Testing
@testable import testMugshot

struct PremiumPolishTests {
    @Test func emptyLocalQueuesDoNotClaimVerifiedCloudBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshot = SyncHealthSnapshot(userID: nil, draftStore: SipDraftStore(baseDirectory: root))
        #expect(snapshot.title == "No pending uploads on this device")
        #expect(snapshot.detail.contains("doesn’t verify a cloud backup"))
        #expect(!snapshot.systemImage.contains("icloud"))
    }
    @Test func passwordResetFailureNamesTheRequestedActionWithoutExposingDetails() {
        let error = NSError(domain: "private.transport", code: 99,
                            userInfo: [NSLocalizedDescriptionKey: "secret internal endpoint"])
        let message = MugshotUserFacingError.message(for: error, context: .passwordReset)
        #expect(message == "We couldn’t request a reset link. Check your connection, then try again.")
        #expect(!message.contains("secret"))
        #expect(MugshotUserFacingError.message(for: URLError(.notConnectedToInternet), context: .passwordReset).contains("offline"))
    }

    @MainActor @Test func discoveryLoadFailureKeepsUnknownValuesAbsentAndRetryRestoresEditing() async {
        var attempts = 0
        let store = DiscoveryPreferencesStore(fetch: { _ in
            attempts += 1
            if attempts == 1 { throw URLError(.notConnectedToInternet) }
            return Self.preferences
        }, save: { _, value in value })
        let owner = UUID()
        await store.load(accountID: owner)
        #expect(store.preferences == nil)
        #expect(!store.canEdit && store.needsReload)
        await store.load(accountID: owner)
        #expect(store.preferences == Self.preferences)
        #expect(store.canEdit && store.errorMessage == nil)
        #expect(attempts == 2)
    }

    @MainActor @Test func failedDiscoverySaveRequiresReloadRatherThanClaimingRollbackOnServer() async {
        var writes = 0
        var serverValue = Self.preferences
        let store = DiscoveryPreferencesStore(fetch: { _ in serverValue }, save: { _, value in
            writes += 1
            serverValue = value // Simulate server commit followed by a lost acknowledgement.
            throw URLError(.networkConnectionLost)
        })
        let owner = UUID()
        await store.load(accountID: owner)
        var proposed = Self.preferences; proposed.emailDiscoverable = true
        #expect(await store.save(proposed, accountID: owner) == false)
        #expect(store.preferences == Self.preferences)
        #expect(store.errorMessage?.contains("couldn’t confirm") == true)
        #expect(!store.canEdit)
        #expect(await store.save(proposed, accountID: owner) == nil)
        #expect(writes == 1)
        await store.load(accountID: owner)
        #expect(store.preferences == proposed && store.canEdit)
    }

    @MainActor @Test func previousAccountLoadCannotReplaceCurrentAccountPreferences() async {
        let first = UUID(), second = UUID()
        let gate = PreferenceResponseGate()
        var secondValue = Self.preferences; secondValue.suggestionsEnabled = false
        let expected = secondValue
        let store = DiscoveryPreferencesStore(fetch: { owner in
            if owner == first { return await gate.response() }
            return expected
        }, save: { _, value in value })
        let firstLoad = Task { await store.load(accountID: first) }
        await gate.waitUntilRequested()
        await store.load(accountID: second)
        gate.finish(Self.preferences)
        await firstLoad.value
        #expect(store.preferences == expected)
        #expect(store.canEdit)
        #expect(await store.save(Self.preferences, accountID: first) == nil)
    }

    @MainActor @Test func discoverySaveCannotDuplicateOrRepopulateADismissedScreen() async {
        let gate = PreferenceResponseGate()
        var writes = 0
        let store = DiscoveryPreferencesStore(fetch: { _ in Self.preferences }, save: { _, _ in
            writes += 1
            return await gate.response()
        })
        let owner = UUID(); await store.load(accountID: owner)
        var proposed = Self.preferences; proposed.suggestionsEnabled = false
        let value = proposed
        let saving = Task { await store.save(value, accountID: owner) }
        await gate.waitUntilRequested()
        #expect(await store.save(value, accountID: owner) == nil)
        store.invalidate()
        gate.finish(value)
        #expect(await saving.value == nil)
        #expect(store.preferences == nil && !store.isSaving)
        #expect(writes == 1)
    }

    @MainActor @Test func cancelledDiscoverySaveRequiresConfirmationBeforeAnotherEdit() async {
        let gate = PreferenceResponseGate()
        let store = DiscoveryPreferencesStore(fetch: { _ in Self.preferences }, save: { _, _ in await gate.response() })
        let owner = UUID(); await store.load(accountID: owner)
        var proposed = Self.preferences; proposed.emailDiscoverable = true
        let value = proposed
        let saving = Task { await store.save(value, accountID: owner) }
        await gate.waitUntilRequested()
        saving.cancel(); gate.finish(value)
        #expect(await saving.value == nil)
        #expect(store.preferences == Self.preferences)
        #expect(store.needsReload && !store.canEdit)
    }

    @MainActor @Test func signedOutDiscoveryNeverFetchesOrSaves() async {
        var requests = 0
        let store = DiscoveryPreferencesStore(fetch: { _ in requests += 1; return Self.preferences },
            save: { _, value in requests += 1; return value })
        await store.load(accountID: nil)
        #expect(store.preferences == nil && !store.canEdit)
        #expect(await store.save(Self.preferences, accountID: nil) == nil)
        #expect(requests == 0)
    }

    private static var preferences: PeopleDiscoveryPreferences {
        PeopleDiscoveryPreferences(emailDiscoverable: false, suggestionsEnabled: true,
            mutualExplanationsEnabled: true, consentVersion: nil, version: 0, hasDiscoveryEmail: false)
    }

}


@MainActor private final class PreferenceResponseGate {
    private var continuation: CheckedContinuation<PeopleDiscoveryPreferences, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    func response() async -> PeopleDiscoveryPreferences {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            waiter?.resume(); waiter = nil
        }
    }
    func waitUntilRequested() async {
        if continuation != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func finish(_ value: PeopleDiscoveryPreferences) {
        continuation?.resume(returning: value); continuation = nil
    }
}
