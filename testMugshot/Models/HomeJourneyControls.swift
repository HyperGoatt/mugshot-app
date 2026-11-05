import Foundation

/// Owner-only deletion intent travels with the existing private workspace.
/// Unioning these markers before conflict recovery prevents a removed item
/// becoming a new recovered draft with a different identity.
struct HomeWorkspaceDeletions: Codable, Equatable, Sendable {
    var attempts: Set<UUID> = []
    var attemptDrafts: Set<UUID> = []
    var recipeDrafts: Set<UUID> = []
    var publications: Set<UUID> = []
    /// Ordinary sharing drafts attached to deleted private makes, not confirmed posts.
    var publicationDrafts: Set<UUID>?
    var photoNames: Set<String>?

    func union(_ other: Self) -> Self {
        let combinedDrafts: Set<UUID>? = publicationDrafts == nil && other.publicationDrafts == nil
            ? nil : (publicationDrafts ?? []).union(other.publicationDrafts ?? [])
        let combinedPhotos: Set<String>? = photoNames == nil && other.photoNames == nil
            ? nil : (photoNames ?? []).union(other.photoNames ?? [])
        return Self(attempts: attempts.union(other.attempts), attemptDrafts: attemptDrafts.union(other.attemptDrafts),
             recipeDrafts: recipeDrafts.union(other.recipeDrafts), publications: publications.union(other.publications),
             publicationDrafts: combinedDrafts, photoNames: combinedPhotos)
    }
}

extension HomeRecipeWorkspace {
    mutating func replacePhotoReference(_ old: String, with new: String) {
        func replace(_ value: inout HomeAttemptRecord) {
            value.photoNames = value.photoNames.map { $0 == old ? new : $0 }
        }
        for index in attempts.indices { replace(&attempts[index]) }
        for index in attemptDrafts.indices { replace(&attemptDrafts[index]) }
        for index in sessions.indices { replace(&sessions[index].attempt) }
        if let values = attemptConflicts { for index in values.indices { replace(&attemptConflicts![index]) } }
        if let values = preparationConflicts { for index in values.indices { replace(&preparationConflicts![index].attempt) } }
    }

    mutating func applyDeletions() {
        guard var removed = deletions else { return }
        var allRecords = attempts
        allRecords.append(contentsOf: attemptDrafts)
        allRecords.append(contentsOf: attemptConflicts ?? [])
        allRecords.append(contentsOf: sessions.map(\.attempt))
        allRecords.append(contentsOf: (preparationConflicts ?? []).map(\.attempt))
        for item in allRecords where removed.publications.contains(item.id) || item.publicationDraftID.map(removed.publications.contains) == true {
            removed.attempts.insert(item.id)
        }
        for item in allRecords where item.editingAttemptID.map(removed.attempts.contains) == true {
            removed.attemptDrafts.insert(item.id)
        }
        let makeIDs = removed.attempts.union(removed.attemptDrafts)
        func isRemoved(_ item: HomeAttemptRecord, saved: Bool = false) -> Bool {
            (saved ? removed.attempts : makeIDs).contains(item.id)
                || item.editingAttemptID.map(removed.attempts.contains) == true
                || item.publicationDraftID.map(removed.publications.contains) == true
        }
        var deletedPhotos = removed.photoNames ?? []
        var deletedDrafts = removed.publicationDrafts ?? []
        let retainedAttempts = attempts.filter { !isRemoved($0, saved: true) }
        let retainedPublications = Set(retainedAttempts.map(\.id) + retainedAttempts.compactMap(\.publicationDraftID))
        for item in attempts where isRemoved(item, saved: true) {
            deletedPhotos.formUnion(item.photoNames.filter(HomeRecipeMediaService.isValidName))
            if let id = item.publicationDraftID, !retainedPublications.contains(id) { deletedDrafts.insert(id) }
        }
        for item in allRecords where !attempts.contains(where: { $0.id == item.id && $0 == item }) && isRemoved(item) {
            deletedPhotos.formUnion(item.photoNames.filter(HomeRecipeMediaService.isValidName))
            if let id = item.publicationDraftID, !retainedPublications.contains(id) { deletedDrafts.insert(id) }
        }
        attempts.removeAll { removed.attempts.contains($0.id) }
        attemptDrafts.removeAll { isRemoved($0) }
        recipeDrafts.removeAll { removed.recipeDrafts.contains($0.id) }
        sessions.removeAll { isRemoved($0.attempt) }
        attemptConflicts?.removeAll { isRemoved($0) }
        preparationConflicts?.removeAll { isRemoved($0.attempt) }
        if !deletedPhotos.isEmpty { removed.photoNames = deletedPhotos }
        if !deletedDrafts.isEmpty { removed.publicationDrafts = deletedDrafts }
        deletions = removed
    }

    mutating func removeConfirmedPublication(_ id: UUID) {
        var removed = deletions ?? HomeWorkspaceDeletions()
        removed.publications.insert(id); deletions = removed; applyDeletions()
    }
}

extension HomeAttemptRecord {
    var journalLocationName: String { locationName?.remoteTrimmedNonEmpty ?? "Home" }
    var journalDate: Date { savedAt ?? createdAt }
}

enum HomeJournalProjection {
    static func coverFirstIndices(count: Int, posterIndex: Int) -> [Int] {
        guard count > 0 else { return [] }
        let cover = min(max(posterIndex, 0), count - 1)
        return [cover] + (0..<count).filter { $0 != cover }
    }
    static func privateEntries(in workspace: HomeRecipeWorkspace, scope: LocalAccountScope,
                               expectedScope: LocalAccountScope, publishedIDs: Set<UUID>, removedPublicationIDs: Set<UUID> = []) -> [HomeAttemptRecord] {
        guard scope == expectedScope else { return [] }
        return workspace.attempts.filter {
            $0.publicationStatus != .published
                && ($0.publicationStatus != nil || $0.publicationDraftID == nil)
                && !($0.publicationDraftID.map(publishedIDs.contains) ?? false)
                && !publishedIDs.contains($0.id) && !removedPublicationIDs.contains($0.id)
                && !($0.publicationDraftID.map(removedPublicationIDs.contains) ?? false)
                && !(workspace.deletions?.attempts.contains($0.id) ?? false)
        }.sorted { $0.journalDate > $1.journalDate }
    }
}

@MainActor
enum HomePublishedSipDeletion {
    static func perform(owner: UUID, currentOwner: () -> UUID?,
                        deleteRemote: () async throws -> Void, recordConfirmed: () -> Void) async throws {
        guard currentOwner() == owner else {
            throw HomeRecipeWorkspaceError.invalid("Your account changed. Nothing was deleted.")
        }
        try await deleteRemote()
        // The caller records the original owner's identifier-only receipt. If
        // that owner is no longer active, workspace cleanup waits for activation.
        recordConfirmed()
    }
}

enum HomeJourneyControlPolicy {
    static func canDiscard(_ draft: SipDraft, in scope: LocalAccountScope, hasProtectedSubmission: Bool) -> Bool {
        draft.ownerUserID == scope.userID && !hasProtectedSubmission
            && [.local, .failed].contains(draft.uploadState)
    }
}

enum HomeSharingDraftResolver {
    static func resolve(attemptID: UUID, previousID: UUID?, scope: LocalAccountScope,
                        store: SipDraftStore = .shared) throws -> (id: UUID, existing: StoredSipDraft?) {
        guard store.readReport(in: scope).isComplete else {
            throw HomeRecipeWorkspaceError.invalid("Your saved drafts could not be checked. Your private sip is safe; please try again.")
        }
        guard let previousID, try !store.isDiscarded(id: previousID, in: scope) else { return (UUID(), nil) }
        guard let existing = store.load(id: previousID, in: scope) else { return (previousID, nil) }
        guard existing.draft.context == .home, existing.draft.launchContext.homeAttemptID == attemptID else {
            return (UUID(), nil)
        }
        return (previousID, existing)
    }
}

struct HomeDraftItem: Identifiable {
    enum Kind { case recipe, attempt, session }
    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let attemptID: UUID?
    let sessionID: UUID?
    let recipeDraftID: UUID?
    let date: Date
}

enum HomeDraftIndex {
    static func items(in original: HomeRecipeWorkspace) -> [HomeDraftItem] {
        var workspace = original; workspace.applyDeletions()
        let saved = Set(workspace.attempts.map(\.id))
        var items: [HomeDraftItem] = []
        let sessions = workspace.sessions.filter { [.ready, .preparing, .awaitingReflection].contains($0.currentPhase) && !saved.contains($0.attempt.id) }
        for attempt in workspace.attemptDrafts where attempt.hasMeaningfulDraftContent && !saved.contains(attempt.id) {
            let session = sessions.first { $0.attempt.id == attempt.id }
            if session?.currentPhase == .preparing { continue }
            items.append(HomeDraftItem(id: "make-\(attempt.id)", kind: .attempt,
                title: attempt.name.remoteTrimmedNonEmpty ?? "Untitled Home sip", detail: "Ready for your reflection",
                attemptID: attempt.id, sessionID: nil, recipeDraftID: nil, date: attempt.createdAt))
        }
        let indexed = Set(items.compactMap(\.attemptID))
        for session in sessions where !indexed.contains(session.attempt.id) {
            guard !items.contains(where: { $0.attemptID == session.attempt.id }) else { continue }
            items.append(HomeDraftItem(id: "make-\(session.attempt.id)", kind: .session,
                title: session.attempt.name.remoteTrimmedNonEmpty ?? "In-progress Home sip",
                detail: session.currentPhase == .awaitingReflection ? "Preparation finished · add your reflection" : "Making · step \(session.stepIndex + 1)",
                attemptID: session.attempt.id, sessionID: session.id, recipeDraftID: nil, date: session.startedAt))
        }
        for recipe in workspace.recipeDrafts {
            items.append(HomeDraftItem(id: "recipe-\(recipe.id)", kind: .recipe,
                title: recipe.content.name.remoteTrimmedNonEmpty ?? "Recipe idea", detail: "Recipe draft",
                attemptID: nil, sessionID: nil, recipeDraftID: recipe.id, date: .distantPast))
        }
        return items.sorted { $0.date > $1.date }
    }
}

/// Contains identifiers only. A confirmed cloud delete can finish after an
/// account switch; its receipt is applied only when that owner's store is active.
enum HomeDeletedPostReceipts {
    private static func key(_ owner: UUID) -> String { "MugshotHomeDeletedPosts.v1.\(owner.uuidString.lowercased())" }
    static func ids(for owner: UUID, defaults: UserDefaults = .standard) -> Set<UUID> {
        Set((defaults.stringArray(forKey: key(owner)) ?? []).compactMap(UUID.init(uuidString:)))
    }
    static func record(_ visitID: UUID, owner: UUID, defaults: UserDefaults = .standard) {
        defaults.set(ids(for: owner, defaults: defaults).union([visitID]).map(\.uuidString).sorted(), forKey: key(owner))
    }
    static func erase(owner: UUID, defaults: UserDefaults = .standard) { defaults.removeObject(forKey: key(owner)) }
}
