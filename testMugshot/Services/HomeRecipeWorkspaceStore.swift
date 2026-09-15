import Foundation
import Combine
import UIKit
import UserNotifications

/// Account-scoped, atomic local persistence. Remote synchronization never
/// replaces a newer local edit or treats a failed write as a successful save.
@MainActor
final class HomeRecipeWorkspaceStore: ObservableObject {
    static let shared = HomeRecipeWorkspaceStore()
    @Published private(set) var workspace = HomeRecipeWorkspace()
    @Published private(set) var scope = LocalAccountScope.guest
    @Published var errorMessage: String?
    @Published private(set) var isSyncing = false
    @Published private(set) var hasRemoteConflict = false
    private let root: URL
    private var loaded = false
    private var canWrite = false
    private var remoteConflict: HomeRecipeWorkspace?
    private var syncTaskID: UUID?

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MugshotHomeRecipes", isDirectory: true)
    }
    private func directory(_ scope: LocalAccountScope) -> URL { root.appendingPathComponent(scope.storageComponent, isDirectory: true) }
    private func file(_ scope: LocalAccountScope) -> URL { directory(scope).appendingPathComponent("workspace-v1.json") }

    func activate(_ newScope: LocalAccountScope) {
        guard !loaded || scope != newScope else { return }
        scope = newScope
        workspace = HomeRecipeWorkspace()
        errorMessage = nil
        hasRemoteConflict = false
        remoteConflict = nil
        syncTaskID = nil
        isSyncing = false
        loaded = true
        canWrite = false
        do {
            if FileManager.default.fileExists(atPath: file(scope).path) {
                workspace = try JSONDecoder().decode(HomeRecipeWorkspace.self, from: Data(contentsOf: file(scope)))
            }
            canWrite = true
        } catch {
            errorMessage = HomeRecipeWorkspaceError.corruptData.localizedDescription
        }
    }

    private func write(_ value: HomeRecipeWorkspace, scope: LocalAccountScope) throws {
        try FileManager.default.createDirectory(at: directory(scope), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: file(scope), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Copy and verify before removing guest data. Existing account records win
    /// on ID collisions; adoption can safely be retried after interruption.
    func adoptGuestWorkspace(for userID: UUID) throws {
        guard FileManager.default.fileExists(atPath: file(.guest).path) else { return }
        let guest = try JSONDecoder().decode(HomeRecipeWorkspace.self, from: Data(contentsOf: file(.guest)))
        let target = LocalAccountScope.user(userID)
        var account = FileManager.default.fileExists(atPath: file(target).path)
            ? try JSONDecoder().decode(HomeRecipeWorkspace.self, from: Data(contentsOf: file(target))) : HomeRecipeWorkspace()
        account.recipes += guest.recipes.filter { item in !account.recipes.contains { $0.id == item.id } }
        account.attempts += guest.attempts.filter { item in !account.attempts.contains { $0.id == item.id } }
        account.sessions += guest.sessions.filter { item in !account.sessions.contains { $0.id == item.id } }
        account.recipeDrafts += guest.recipeDrafts.filter { item in !account.recipeDrafts.contains { $0.id == item.id } }
        account.attemptDrafts += guest.attemptDrafts.filter { item in !account.attemptDrafts.contains { $0.id == item.id } }
        let knownReferences = Set((account.savedReferences ?? []).map(\.id))
        account.savedReferences = (account.savedReferences ?? []) + (guest.savedReferences ?? []).filter { !knownReferences.contains($0.id) }
        try FileManager.default.createDirectory(at: directory(target), withIntermediateDirectories: true)
        for source in try FileManager.default.contentsOfDirectory(at: directory(.guest), includingPropertiesForKeys: nil)
            where source.pathExtension == "jpg" {
            let destination = directory(target).appendingPathComponent(source.lastPathComponent)
            if !FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.copyItem(at: source, to: destination) }
            guard try Data(contentsOf: source) == Data(contentsOf: destination) else { throw HomeRecipeWorkspaceError.corruptData }
        }
        account.pendingOperationID = UUID()
        try write(account, scope: target)
        guard try JSONDecoder().decode(HomeRecipeWorkspace.self, from: Data(contentsOf: file(target))) == account else {
            throw HomeRecipeWorkspaceError.corruptData
        }
        try FileManager.default.removeItem(at: directory(.guest))
        if scope == target || scope == .guest { loaded = false; activate(target) }
    }

    func removeAll(ownerUserID: UUID) throws {
        let target = LocalAccountScope.user(ownerUserID)
        if FileManager.default.fileExists(atPath: directory(target).path) { try FileManager.default.removeItem(at: directory(target)) }
        if scope == target { loaded = false; activate(.guest) }
    }

    func mutate(_ change: (inout HomeRecipeWorkspace) throws -> Void) throws {
        guard canWrite else { throw HomeRecipeWorkspaceError.corruptData }
        // A remote edit conflict pauses synchronization, not private journaling.
        // Reconciliation reads the latest local workspace, including these saves.
        var next = workspace
        try change(&next)
        next.pendingOperationID = UUID()
        try write(next, scope: scope)
        workspace = next
    }

    func saveRecipe(_ draft: HomeRecipeEditorDraft) throws -> UUID {
        if let message = draft.content.validationMessage { throw HomeRecipeWorkspaceError.invalid(message) }
        let id = draft.recipeID ?? draft.id
        try mutate { state in
            guard !state.wouldCreateCycle(recipeID: id, content: draft.content) else {
                throw HomeRecipeWorkspaceError.invalid("A recipe cannot link back to itself.")
            }
            for reference in draft.content.ingredients.compactMap(\.recipe) {
                guard state.version(reference) != nil else { throw HomeRecipeWorkspaceError.unavailableReference }
            }
            if let index = state.recipes.firstIndex(where: { $0.id == id }) {
                guard state.recipes[index].current?.id == draft.baseVersionID else { throw HomeRecipeWorkspaceError.conflict }
                try Self.validateAttribution(draft.content, previous: state.recipes[index].current?.content)
                if state.recipes[index].current?.content != draft.content {
                    state.recipes[index].versions.append(HomeRecipeVersion(number: (state.recipes[index].current?.number ?? 0) + 1, content: draft.content))
                }
            } else {
                state.recipes.append(HomeRecipeRecord(id: id, versions: [HomeRecipeVersion(content: draft.content)]))
            }
            state.recipeDrafts.removeAll { $0.id == draft.id }
        }
        return id
    }

    func saveDraft(_ draft: HomeRecipeEditorDraft) throws {
        try mutate { state in
            state.recipeDrafts.removeAll { $0.id == draft.id }
            state.recipeDrafts.append(draft)
        }
    }

    func saveAttemptDraft(_ attempt: HomeAttemptRecord) throws {
        try mutate { state in
            state.attemptDrafts.removeAll { $0.id == attempt.id }
            state.attemptDrafts.append(attempt)
        }
    }

    func saveAttempt(_ attempt: HomeAttemptRecord, updateRecipe: Bool = false) throws {
        guard !attempt.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HomeRecipeWorkspaceError.invalid("Name what you made before saving.")
        }
        let values = [attempt.actuals.dose, attempt.actuals.output, attempt.actuals.seconds,
                      attempt.actuals.batchMilliliters, attempt.actuals.servingMilliliters]
        guard values.compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 > 0 }),
              attempt.rating.map({ $0.isFinite && (0.5...5).contains($0) }) ?? true else {
            throw HomeRecipeWorkspaceError.invalid("Check your measurements and rating.")
        }
        try mutate { state in
            // An interrupted save can safely be retried with the same ID.
            guard !state.attempts.contains(where: { $0.id == attempt.id }) else { return }
            var saved = attempt
            saved.savedAt = .now
            if let reference = attempt.recipe, let index = state.recipes.firstIndex(where: { $0.id == reference.recipeID }) {
                if updateRecipe, let preparation = attempt.preparation, preparation != attempt.targets {
                    guard state.recipes[index].current?.id == reference.versionID else { throw HomeRecipeWorkspaceError.conflict }
                    if let message = preparation.validationMessage { throw HomeRecipeWorkspaceError.invalid(message) }
                    try Self.validateAttribution(preparation, previous: state.recipes[index].current?.content)
                    guard !state.wouldCreateCycle(recipeID: reference.recipeID, content: preparation) else {
                        throw HomeRecipeWorkspaceError.invalid("A recipe cannot link back to itself.")
                    }
                    for linked in preparation.ingredients.compactMap(\.recipe) {
                        guard state.version(linked) != nil else { throw HomeRecipeWorkspaceError.unavailableReference }
                    }
                    state.recipes[index].versions.append(HomeRecipeVersion(number: (state.recipes[index].current?.number ?? 0) + 1, content: preparation))
                }
                state.recipes[index].lastUsedAt = saved.createdAt
                if !attempt.nextTimeNote.isEmpty { state.recipes[index].nextTimeNote = attempt.nextTimeNote }
            }
            state.attempts.append(saved)
            state.attemptDrafts.removeAll { $0.id == attempt.id }
            for index in state.sessions.indices where state.sessions[index].attempt.id == attempt.id {
                state.sessions[index].finishedAt = .now
                state.sessions[index].reminderEnabled = false
            }
        }
        let identifiers = workspace.sessions.filter { $0.attempt.id == attempt.id }.map {
            "home-preparation-\(scope.storageComponent)-\($0.id)"
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func saveSession(_ session: HomePreparationSession) throws {
        try mutate { state in
            state.sessions.removeAll { $0.id == session.id }
            state.sessions.append(session)
        }
    }

    func setReminder(for session: HomePreparationSession, enabled: Bool) async throws {
        let capturedScope = scope
        let center = UNUserNotificationCenter.current()
        let identifier = "home-preparation-\(capturedScope.storageComponent)-\(session.id)"
        if enabled {
            guard let readyAt = session.readyAt, readyAt > .now else { throw HomeRecipeWorkspaceError.invalid("This batch is already ready to finish.") }
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                throw HomeRecipeWorkspaceError.invalid("Reminders are disabled in Settings. Your batch is still saved.")
            }
            guard scope == capturedScope else { return }
            let content = UNMutableNotificationContent()
            content.title = "Your home batch is ready"
            content.body = "Open Mugshot to finish your batch."
            content.sound = .default
            try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, readyAt.timeIntervalSinceNow), repeats: false)))
        } else { center.removePendingNotificationRequests(withIdentifiers: [identifier]) }
        guard scope == capturedScope else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }
        // Authorization can suspend while the user advances or finishes a batch.
        // Never replace that newer progress with the pre-authorization snapshot.
        guard var updated = workspace.sessions.first(where: { $0.id == session.id }),
              updated.finishedAt == nil else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }
        updated.reminderEnabled = enabled
        try saveSession(updated)
    }

    func savePhoto(_ data: Data, attemptID: UUID) throws -> String {
        guard let image = UIImage(data: data), let jpeg = image.resizedForVisitUpload(maxDimension: 1600).jpegData(compressionQuality: 0.84) else {
            throw HomeRecipeWorkspaceError.invalid("That photo could not be opened.")
        }
        let name = "\(attemptID)-\(UUID()).jpg"
        try FileManager.default.createDirectory(at: directory(scope), withIntermediateDirectories: true)
        try jpeg.write(to: directory(scope).appendingPathComponent(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return name
    }

    private static func validateAttribution(_ content: HomeRecipeContent, previous: HomeRecipeContent?) throws {
        if let source = previous?.sourceVersionID, content.sourceVersionID != source {
            throw HomeRecipeWorkspaceError.invalid("Keep the original recipe attribution when saving a new version.")
        }
        if previous?.sourceURL.isEmpty == false, content.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw HomeRecipeWorkspaceError.invalid("Keep the inspiration link when saving a new version.")
        }
    }
    func photo(_ name: String) -> UIImage? {
        guard name == URL(fileURLWithPath: name).lastPathComponent else { return nil }
        return UIImage(contentsOfFile: directory(scope).appendingPathComponent(name).path)
    }

    func synchronize() async {
        guard !MugshotLaunchEnvironment.isUITesting,
              !isSyncing, canWrite, !hasRemoteConflict, let owner = scope.userID,
              let client = try? SupabaseClientProvider.shared.client() else { return }
        isSyncing = true
        let taskID = UUID()
        syncTaskID = taskID
        let capturedScope = scope
        let captured = workspace
        var needsAnotherPass = false
        defer {
            if syncTaskID == taskID {
                isSyncing = false
                if needsAnotherPass { Task { await self.synchronize() } }
            }
        }
        do {
            let remote = try await HomeRecipeWorkspaceService(client: client).synchronize(captured, ownerID: owner)
            guard scope == capturedScope else { return }
            if workspace.pendingOperationID != captured.pendingOperationID {
                if captured.pendingOperationID == nil, remote.remoteRevision != captured.remoteRevision {
                    remoteConflict = remote
                    hasRemoteConflict = true
                    errorMessage = HomeRecipeWorkspaceError.conflict.localizedDescription
                    return
                }
                var latest = workspace
                latest.remoteRevision = remote.remoteRevision
                try write(latest, scope: capturedScope)
                workspace = latest
                needsAnotherPass = true
            } else {
                try write(remote, scope: capturedScope)
                workspace = remote
            }
            errorMessage = nil
        } catch {
            guard scope == capturedScope else { return }
            errorMessage = "Saved on this device. Sync needs attention: \(error.localizedDescription)"
            if String(describing: error).contains("HOME_WORKSPACE_CONFLICT") {
                hasRemoteConflict = true
                let latest = try? await HomeRecipeWorkspaceService(client: client).fetch(ownerID: owner)
                guard scope == capturedScope, syncTaskID == taskID else { return }
                remoteConflict = latest
            }
        }
    }

    /// Preserve a recoverable local copy before adopting a newer remote library.
    func useRemoteAfterConflict() throws {
        guard let remoteConflict else { throw HomeRecipeWorkspaceError.conflict }
        let backup = directory(scope).appendingPathComponent("conflict-\(UUID()).json")
        try JSONEncoder().encode(workspace).write(to: backup, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var merged = remoteConflict
        for recipe in workspace.recipes where recipe.current != remoteConflict.recipes.first(where: { $0.id == recipe.id })?.current {
            if let content = recipe.current?.content {
                merged.recipeDrafts.append(HomeRecipeEditorDraft(recipeID: recipe.id,
                    baseVersionID: remoteConflict.recipes.first(where: { $0.id == recipe.id })?.current?.id, content: content))
            }
        }
        let known = Set(merged.attempts.map(\.id))
        merged.attempts += workspace.attempts.filter { !known.contains($0.id) }
        merged.recipeDrafts += workspace.recipeDrafts.filter { draft in !merged.recipeDrafts.contains { $0.id == draft.id } }
        merged.attemptDrafts += workspace.attemptDrafts.filter { draft in !merged.attemptDrafts.contains { $0.id == draft.id } }
        merged.sessions += workspace.sessions.filter { session in !merged.sessions.contains { $0.id == session.id } }
        let knownReferences = Set((merged.savedReferences ?? []).map(\.id))
        merged.savedReferences = (merged.savedReferences ?? []) + (workspace.savedReferences ?? []).filter { !knownReferences.contains($0.id) }
        merged.pendingOperationID = UUID()
        try write(merged, scope: scope)
        workspace = merged
        hasRemoteConflict = false
        self.remoteConflict = nil
        errorMessage = nil
    }
}
