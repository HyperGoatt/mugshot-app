import Combine
import Foundation

/// Keeps unverified privacy preferences distinct from confirmed server values.
/// Every operation belongs to one account and one presentation generation.
@MainActor
final class DiscoveryPreferencesStore: ObservableObject {
    typealias Fetch = @MainActor (UUID) async throws -> PeopleDiscoveryPreferences
    typealias Save = @MainActor (UUID, PeopleDiscoveryPreferences) async throws -> PeopleDiscoveryPreferences

    @Published private(set) var preferences: PeopleDiscoveryPreferences?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var needsReload = false
    @Published private(set) var errorMessage: String?
    private var ownerID: UUID?
    private var generation = UUID()
    private let fetch: Fetch
    private let persist: Save

    var canEdit: Bool { preferences != nil && !isLoading && !isSaving && !needsReload }

    init(fetch: @escaping Fetch = { owner in
        let client = try SupabaseClientProvider.shared.client()
        guard client.auth.currentUser?.id == owner else { throw CancellationError() }
        let value = try await PeopleDiscoveryService(client: client).preferences()
        guard client.auth.currentUser?.id == owner else { throw CancellationError() }
        return value
    }, save: @escaping Save = { owner, value in
        let client = try SupabaseClientProvider.shared.client()
        guard client.auth.currentUser?.id == owner else { throw CancellationError() }
        let saved = try await PeopleDiscoveryService(client: client).savePreferences(value)
        guard client.auth.currentUser?.id == owner else { throw CancellationError() }
        return saved
    }) {
        self.fetch = fetch
        persist = save
    }

    func load(accountID: UUID?) async {
        guard !Task.isCancelled else { return }
        if ownerID != accountID { invalidate(); ownerID = accountID }
        guard !isLoading && !isSaving else { return }
        guard let accountID else {
            errorMessage = "Sign in to manage discovery settings."
            return
        }
        let token = generation
        isLoading = true
        errorMessage = nil
        defer { if generation == token { isLoading = false } }
        do {
            let value = try await fetch(accountID)
            guard generation == token, !Task.isCancelled else { return }
            preferences = value
            needsReload = false
        } catch {
            guard generation == token, !Task.isCancelled else { return }
            needsReload = true
            errorMessage = "Mugshot couldn’t check your discovery settings. Reload to try again."
        }
    }

    /// nil means no request was accepted or this presentation no longer owns it.
    func save(_ value: PeopleDiscoveryPreferences, accountID: UUID?) async -> Bool? {
        guard !Task.isCancelled, let accountID, ownerID == accountID, canEdit, let confirmed = preferences else { return nil }
        let token = generation
        isSaving = true
        preferences = value
        errorMessage = nil
        defer {
            if generation == token {
                isSaving = false
                if Task.isCancelled {
                    preferences = confirmed
                    needsReload = true
                    errorMessage = "Mugshot couldn’t confirm this change. Reload to check what saved."
                }
            }
        }
        do {
            let saved = try await persist(accountID, value)
            guard generation == token, !Task.isCancelled else { return nil }
            preferences = saved
            return true
        } catch {
            guard generation == token, !Task.isCancelled else { return nil }
            preferences = confirmed
            needsReload = true
            errorMessage = "Mugshot couldn’t confirm this change. Last confirmed values are shown. Reload to check what saved."
            return false
        }
    }

    func invalidate() {
        generation = UUID()
        ownerID = nil
        preferences = nil
        isLoading = false
        isSaving = false
        needsReload = false
        errorMessage = nil
    }
}
