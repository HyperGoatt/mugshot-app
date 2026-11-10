import Foundation
import Combine
import UIKit
import UserNotifications

/// Account-scoped, atomic local persistence. Remote synchronization never
/// replaces a newer local edit or treats a failed write as a successful save.
@MainActor
final class HomeRecipeWorkspaceStore: ObservableObject {
    static let shared: HomeRecipeWorkspaceStore = {
        #if DEBUG
        if MugshotLaunchEnvironment.isUITesting {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MugshotUITestHomeRecipes", isDirectory: true)
            if MugshotLaunchEnvironment.shouldResetUITestState { try? FileManager.default.removeItem(at: root) }
            return HomeRecipeWorkspaceStore(root: root)
        }
        #endif
        return HomeRecipeWorkspaceStore()
    }()
    @Published private(set) var workspace = HomeRecipeWorkspace()
    @Published private(set) var scope = LocalAccountScope.guest
    @Published var errorMessage: String?
    @Published private(set) var isSyncing = false
    @Published private(set) var hasRemoteConflict = false
    var canResolveRemoteConflict: Bool { remoteConflict != nil }
    private let root: URL
    private let transport: (any HomeRecipeWorkspaceTransport)?
    private var loaded = false
    private var canWrite = false
    private var remoteConflict: HomeRecipeWorkspace?
    private var syncTaskID: UUID?
    private var activationID = UUID()
    private let photoWriter: (@Sendable (Data, URL) async throws -> Void)?

    init(root: URL? = nil, transport: (any HomeRecipeWorkspaceTransport)? = nil,
         photoWriter: (@Sendable (Data, URL) async throws -> Void)? = nil) {
        self.transport = transport
        self.photoWriter = photoWriter
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MugshotHomeRecipes", isDirectory: true)
    }
    private func directory(_ scope: LocalAccountScope) -> URL { root.appendingPathComponent(scope.storageComponent, isDirectory: true) }
    private func file(_ scope: LocalAccountScope) -> URL { directory(scope).appendingPathComponent("workspace-v1.json") }

    /// Read an explicit owner's durable state without activating that account.
    func exportSnapshot(ownerID: UUID) throws -> HomeRecipeWorkspace {
        let source = file(.user(ownerID))
        guard FileManager.default.fileExists(atPath: source.path) else { return HomeRecipeWorkspace() }
        return try JSONDecoder().decode(HomeRecipeWorkspace.self, from: Data(contentsOf: source))
    }

    func exportPhoto(name: String, ownerID: UUID) throws -> Data {
        _ = try HomeRecipeMediaService.path(owner: ownerID, name: name)
        return try Data(contentsOf: directory(.user(ownerID)).appendingPathComponent(name))
    }

    func activate(_ newScope: LocalAccountScope) {
        guard !loaded || scope != newScope else { return }
        scope = newScope
        activationID = UUID()
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
            if let owner = scope.userID, !HomeDeletedPostReceipts.ids(for: owner).isEmpty {
                try applyConfirmedPostDeletions(expectedScope: scope)
            }
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
        account.retainedVersions = (account.retainedVersions ?? []) + (guest.retainedVersions ?? []).filter { item in
            !(account.retainedVersions ?? []).contains { $0.reference == item.reference }
        }
        account.preparationConflicts = (account.preparationConflicts ?? []) + (guest.preparationConflicts ?? []).filter { item in
            !(account.preparationConflicts ?? []).contains { $0.id == item.id }
        }
        account.attemptConflicts = (account.attemptConflicts ?? []) + (guest.attemptConflicts ?? []).filter { item in
            !(account.attemptConflicts ?? []).contains { $0.id == item.id }
        }
        let knownReferences = Set((account.savedReferences ?? []).map(\.id))
        account.savedReferences = (account.savedReferences ?? []) + (guest.savedReferences ?? []).filter { !knownReferences.contains($0.id) }
        account.deletions = (account.deletions ?? HomeWorkspaceDeletions()).union(guest.deletions ?? HomeWorkspaceDeletions())
        account.applyDeletions()
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
        HomeDeletedPostReceipts.erase(owner: ownerUserID)
        if scope == target { loaded = false; activate(.guest) }
    }

    func mutate(_ change: (inout HomeRecipeWorkspace) throws -> Void) throws {
        guard canWrite else { throw HomeRecipeWorkspaceError.corruptData }
        // A remote edit conflict pauses synchronization, not private journaling.
        // Reconciliation reads the latest local workspace, including these saves.
        var next = workspace
        try change(&next)
        if let owner = scope.userID {
            for id in HomeDeletedPostReceipts.ids(for: owner) { next.removeConfirmedPublication(id) }
        }
        next.applyDeletions()
        // A retired cloud object may not gain a new reference under the same
        // name. Preserve available bytes with a fresh identity instead.
        let copiedNames = try rekeyRetiredPhotos(in: &next, priorReferences: workspace.referencedPhotoNames)
        guard next != workspace else { return }
        next.pendingOperationID = UUID()
        do { try write(next, scope: scope) }
        catch {
            for name in copiedNames { try? FileManager.default.removeItem(at: directory(scope).appendingPathComponent(name)) }
            throw error
        }
        workspace = next
        do { try cleanupUnreferencedLocalPhotos() }
        catch { errorMessage = "Your change is saved. Some photo cleanup needs another try." }
    }

    private func rekeyRetiredPhotos(in value: inout HomeRecipeWorkspace, priorReferences: Set<String>) throws -> [String] {
        let retiredReferences = value.referencedPhotoNames.subtracting(priorReferences).intersection(value.deletions?.photoNames ?? [])
        var copied: [String] = []
        do {
            for name in retiredReferences {
                guard HomeRecipeMediaService.isValidName(name) else { throw HomeRecipeWorkspaceError.corruptData }
                let replacement = "\(UUID())-\(UUID()).jpg"
                let bytes = try Data(contentsOf: directory(scope).appendingPathComponent(name))
                try bytes.write(to: directory(scope).appendingPathComponent(replacement),
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                copied.append(replacement)
                value.replacePhotoReference(name, with: replacement)
            }
            return copied
        } catch {
            for name in copied { try? FileManager.default.removeItem(at: directory(scope).appendingPathComponent(name)) }
            throw error
        }
    }

    private func cleanupUnreferencedLocalPhotos() throws {
        for name in workspace.deletions?.photoNames ?? [] where !workspace.referencedPhotoNames.contains(name) {
            try removeUnreferencedPhoto(name, in: scope)
        }
    }

    func removeUnreferencedPhoto(_ name: String, in capturedScope: LocalAccountScope) throws {
        guard HomeRecipeMediaService.isValidName(name) else { return }
        let snapshot: HomeRecipeWorkspace
        if capturedScope == scope { snapshot = workspace }
        else if FileManager.default.fileExists(atPath: file(capturedScope).path) {
            snapshot = try JSONDecoder().decode(HomeRecipeWorkspace.self, from: Data(contentsOf: file(capturedScope)))
        } else { snapshot = HomeRecipeWorkspace() }
        guard !snapshot.referencedPhotoNames.contains(name) else { return }
        let location = directory(capturedScope).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: location.path) { try FileManager.default.removeItem(at: location) }
    }

    func saveRecipe(_ draft: HomeRecipeEditorDraft, asCopy: Bool = false) throws -> UUID {
        var content = draft.content
        if asCopy {
            guard let originalID = draft.recipeID, originalID != draft.id,
                  let original = workspace.recipes.first(where: { $0.id == originalID }),
                  let source = original.versions.first(where: { $0.id == draft.baseVersionID }) else {
                throw HomeRecipeWorkspaceError.unavailableReference
            }
            try Self.validateAttribution(content, previous: source.content)
            if content.name.remoteTrimmedNonEmpty == source.content.name.remoteTrimmedNonEmpty,
               let name = content.name.remoteTrimmedNonEmpty {
                content.name = String(name.prefix(115)) + " copy"
            }
        }
        if let message = content.validationMessage { throw HomeRecipeWorkspaceError.invalid(message) }
        let id = asCopy ? draft.id : (draft.recipeID ?? draft.id)
        try mutate { state in
            guard !state.wouldCreateCycle(recipeID: id, content: content) else {
                throw HomeRecipeWorkspaceError.invalid("A recipe cannot link back to itself.")
            }
            for reference in content.ingredients.compactMap(\.recipe) {
                guard state.recipes.contains(where: { $0.id == reference.recipeID && $0.versions.contains { $0.id == reference.versionID } }) else {
                    throw HomeRecipeWorkspaceError.unavailableReference
                }
            }
            if let index = state.recipes.firstIndex(where: { $0.id == id }) {
                if asCopy, state.recipes[index].versions.first?.content == content { return }
                guard state.recipes[index].current?.id == draft.baseVersionID else { throw HomeRecipeWorkspaceError.conflict }
                try Self.validateAttribution(content, previous: state.recipes[index].current?.content)
                if state.recipes[index].current?.content != content {
                    state.recipes[index].versions.append(HomeRecipeVersion(number: (state.recipes[index].current?.number ?? 0) + 1, content: content))
                }
            } else {
                state.recipes.append(HomeRecipeRecord(id: id, versions: [HomeRecipeVersion(content: content)]))
            }
            state.recipeDrafts.removeAll { $0.id == draft.id }
        }
        MugshotAnalytics.shared.capture(.homeRecipe(.recipeSaved, hasRecipe: true, durationSeconds: 0))
        if draft.recipeID == nil, draft.content.sourceVersionID != nil {
            MugshotAnalytics.shared.capture(.homeRecipe(.adapted, hasRecipe: true, durationSeconds: 0))
        }
        return id
    }

    func saveDraft(_ draft: HomeRecipeEditorDraft) throws {
        guard workspace.deletions?.recipeDrafts.contains(draft.id) != true else {
            throw HomeRecipeWorkspaceError.invalid("That recipe draft was deleted. Start a new draft to keep editing.")
        }
        try mutate { state in
            state.recipeDrafts.removeAll { $0.id == draft.id }
            state.recipeDrafts.append(draft)
        }
    }

    func saveAttemptDraft(_ attempt: HomeAttemptRecord) throws {
        try requireLiveMake(attempt.id)
        if let originalID = attempt.editingAttemptID { try requireLiveMake(originalID) }
        try mutate { state in
            state.attemptDrafts.removeAll { $0.id == attempt.id }
            state.attemptDrafts.append(attempt)
        }
    }

    func saveAttempt(_ attempt: HomeAttemptRecord, updateRecipe: Bool = false) throws {
        if let originalID = attempt.editingAttemptID,
           workspace.attempts.first(where: { $0.id == originalID })?.lastEditedDraftID == attempt.id { return }
        try requireLiveMake(attempt.id)
        if let originalID = attempt.editingAttemptID { try requireLiveMake(originalID) }
        guard !attempt.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HomeRecipeWorkspaceError.invalid("Name what you made before saving.")
        }
        let values = [attempt.actuals.dose, attempt.actuals.output, attempt.actuals.seconds,
                      attempt.actuals.batchMilliliters, attempt.actuals.servingMilliliters]
        guard values.compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 > 0 }),
              attempt.actuals.ingredients.allSatisfy({ $0.amount.isFinite && $0.amount > 0 && !$0.unit.isEmpty }),
              Set(attempt.actuals.ingredients.map(\.ingredientID)).count == attempt.actuals.ingredients.count,
              attempt.actuals.temperature.map({ $0.isFinite && $0 > -273.15 }) ?? true,
              attempt.rating.map({ $0.isFinite && (0.5...5).contains($0) }) ?? true,
              attempt.actuals.customFields.allSatisfy({ field in
                  guard !field.value.isEmpty else { return true }
                  switch field.kind {
                  case .text: return true
                  case .choice: return field.choices.contains(field.value)
                  case .number, .duration:
                      guard let value = Double(field.value), value.isFinite else { return false }
                      return field.kind != .duration || value >= 0
                  }
              }) else {
            throw HomeRecipeWorkspaceError.invalid("Check your measurements and rating.")
        }
        if attempt.editingAttemptID == nil, let message = attempt.preparation?.validationMessage {
            throw HomeRecipeWorkspaceError.invalid(message)
        }
        try mutate { state in
            if let originalID = attempt.editingAttemptID {
                guard originalID != attempt.id,
                      let index = state.attempts.firstIndex(where: { $0.id == originalID }),
                      state.attempts[index].publicationStatus != .posting else {
                    throw HomeRecipeWorkspaceError.invalid("This saved sip is unavailable for editing. Your draft is still safe.")
                }
                let original = state.attempts[index]
                var updated = attempt
                updated.id = original.id
                updated.createdAt = original.createdAt
                updated.savedAt = original.savedAt
                updated.editingAttemptID = nil
                updated.lastEditedDraftID = attempt.id
                updated.resumeAtReflection = nil
                updated.publicationDraftID = original.publicationDraftID
                updated.publicationStatus = original.publicationStatus
                // Editing a journal copy never rewrites a source recipe or a post.
                updated.recipe = original.recipe
                updated.targets = original.targets
                updated.preparation = original.preparation
                updated.batchID = original.batchID
                updated.batchSourceAttemptID = original.batchSourceAttemptID
                updated.pendingKeptIngredientIDs = original.pendingKeptIngredientIDs
                updated.keptRecipeVersionID = original.keptRecipeVersionID
                let removedPhotos = Set(original.photoNames).subtracting(updated.photoNames).filter(HomeRecipeMediaService.isValidName)
                if !removedPhotos.isEmpty {
                    var removed = state.deletions ?? HomeWorkspaceDeletions()
                    removed.photoNames = (removed.photoNames ?? []).union(removedPhotos)
                    state.deletions = removed
                }
                state.attempts[index] = updated
                var completed = state.deletions ?? HomeWorkspaceDeletions()
                completed.attemptDrafts.insert(attempt.id)
                state.deletions = completed
                state.attemptDrafts.removeAll { $0.id == attempt.id }
                state.sessions.removeAll { $0.attempt.id == attempt.id }
                return
            }
            // An interrupted save can safely be retried with the same ID.
            if state.attempts.contains(where: { $0.id == attempt.id }) {
                state.attemptDrafts.removeAll { $0.id == attempt.id }
                for index in state.sessions.indices where state.sessions[index].attempt.id == attempt.id {
                    state.sessions[index].phase = .saved
                    state.sessions[index].finishedAt = state.sessions[index].finishedAt ?? .now
                    state.sessions[index].reminderEnabled = false
                }
                return
            }
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
                        guard state.recipes.contains(where: { $0.id == linked.recipeID && $0.versions.contains { $0.id == linked.versionID } }) else {
                            throw HomeRecipeWorkspaceError.unavailableReference
                        }
                    }
                    state.recipes[index].versions.append(HomeRecipeVersion(number: (state.recipes[index].current?.number ?? 0) + 1, content: preparation))
                }
                state.recipes[index].lastUsedAt = saved.createdAt
                if !attempt.nextTimeNote.isEmpty { state.recipes[index].nextTimeNote = attempt.nextTimeNote }
            }
            state.attempts.append(saved)
            state.attemptDrafts.removeAll { $0.id == attempt.id }
            for index in state.sessions.indices where state.sessions[index].attempt.id == attempt.id {
                state.sessions[index].phase = .saved
                state.sessions[index].finishedAt = .now
                state.sessions[index].reminderEnabled = false
            }
        }
        let identifiers = workspace.sessions.filter { $0.attempt.id == attempt.id }.map {
            "home-preparation-\(scope.storageComponent)-\($0.id)"
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Apply only explicitly selected ingredient changes after the attempt is durable.
    /// The source attempt ID makes an interrupted retry unable to append a second version.
    @discardableResult
    func applyKeptIngredientChanges(attemptID: UUID) throws -> UUID? {
        var resultingVersionID: UUID?
        try mutate { state in
            guard let attemptIndex = state.attempts.firstIndex(where: { $0.id == attemptID }) else {
                throw HomeRecipeWorkspaceError.invalid("Save this sip before updating its recipe.")
            }
            let attempt = state.attempts[attemptIndex]
            guard !attempt.pendingKeptIngredientIDs.isEmpty,
                  let reference = attempt.recipe,
                  let recipeIndex = state.recipes.firstIndex(where: { $0.id == reference.recipeID }) else {
                resultingVersionID = attempt.keptRecipeVersionID
                return
            }
            if let existing = state.recipes[recipeIndex].versions.first(where: { $0.sourceAttemptID == attemptID }) {
                state.attempts[attemptIndex].keptRecipeVersionID = existing.id
                state.attempts[attemptIndex].pendingKeptIngredientIDs = []
                resultingVersionID = existing.id
                return
            }
            guard state.recipes[recipeIndex].current?.id == reference.versionID else {
                throw HomeRecipeWorkspaceError.conflict
            }
            guard var content = state.recipes[recipeIndex].current?.content else {
                throw HomeRecipeWorkspaceError.unavailableReference
            }
            guard content.template == .drink else {
                throw HomeRecipeWorkspaceError.invalid("Only a complete drink can keep ingredient changes for next time.")
            }
            var changed = false
            for index in content.ingredients.indices {
                let ingredient = content.ingredients[index]
                guard attempt.pendingKeptIngredientIDs.contains(ingredient.id),
                      let actual = attempt.actuals.ingredients.first(where: { $0.ingredientID == ingredient.id }),
                      actual.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        == ingredient.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                      ingredient.amount != actual.amount else { continue }
                content.ingredients[index].amount = actual.amount
                changed = true
            }
            state.attempts[attemptIndex].pendingKeptIngredientIDs = []
            guard changed else { return }
            let version = HomeRecipeVersion(
                number: (state.recipes[recipeIndex].current?.number ?? 0) + 1,
                content: content,
                sourceAttemptID: attemptID
            )
            state.recipes[recipeIndex].versions.append(version)
            state.attempts[attemptIndex].keptRecipeVersionID = version.id
            resultingVersionID = version.id
        }
        return resultingVersionID
    }

    func beginPreparation(_ attempt: HomeAttemptRecord, replacing sessionID: UUID? = nil) throws -> HomePreparationSession {
        try requireLiveMake(attempt.id)
        if let originalID = attempt.editingAttemptID { try requireLiveMake(originalID) }
        let previous = workspace.sessions.first { $0.id == sessionID && $0.attempt.id == attempt.id }
        if let previous,
           previous.phase == .preparing, previous.attempt.preparation == attempt.preparation,
           previous.attempt.recipe == attempt.recipe, previous.attempt.locationName == attempt.locationName {
            return previous
        }
        var session = HomePreparationSession(attempt: attempt, phase: .preparing)
        if [.coldBrew, .coldBrewTea].contains(attempt.preparation?.method ?? .other) {
            session.timerStartedAt = session.startedAt
        }
        try mutate { state in
            state.attemptDrafts.removeAll { $0.id == attempt.id }
            state.attemptDrafts.append(attempt)
            state.sessions.removeAll { $0.id == sessionID && $0.attempt.id == attempt.id }
            state.sessions.append(session)
        }
        if let previous {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
                "home-preparation-\(scope.storageComponent)-\(previous.id)"
            ])
        }
        return session
    }

    func saveSession(_ session: HomePreparationSession) throws {
        try requireLiveMake(session.attempt.id)
        if let originalID = session.attempt.editingAttemptID { try requireLiveMake(originalID) }
        try mutate { state in
            state.sessions.removeAll { $0.id == session.id }
            state.sessions.append(session)
        }
    }

    func finishPreparation(sessionID: UUID, measuredTimer: Bool, content: HomeRecipeContent? = nil) throws -> HomeAttemptRecord {
        guard var session = workspace.sessions.first(where: { $0.id == sessionID }) else {
            throw HomeRecipeWorkspaceError.invalid("That preparation session is no longer available.")
        }
        let completedAt = Date.now
        var attempt = session.attempt
        if attempt.preparation == nil { attempt.preparation = content }
        if measuredTimer, let start = session.timerStartedAt {
            attempt.actuals.seconds = max(0, completedAt.timeIntervalSince(start))
        }
        if (attempt.preparation ?? content)?.method == .coldBrew { attempt.batchID = session.id }
        session.attempt = attempt
        session.phase = .awaitingReflection
        session.preparationCompletedAt = completedAt
        session.reminderEnabled = false
        try mutate { state in
            state.sessions.removeAll { $0.id == session.id }
            state.sessions.append(session)
            state.attemptDrafts.removeAll { $0.id == attempt.id }
            state.attemptDrafts.append(attempt)
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["home-preparation-\(scope.storageComponent)-\(session.id)"]
        )
        return attempt
    }

    func discardAttemptDraft(id: UUID, expectedScope: LocalAccountScope? = nil) throws {
        try requireScope(expectedScope)
        guard !workspace.attempts.contains(where: { $0.id == id }) else {
            throw HomeRecipeWorkspaceError.invalid("This sip is already saved. Open it in Journal to delete it.")
        }
        try requireUnsubmittedMake(id)
        let names = workspace.attemptDrafts.first(where: { $0.id == id })?.photoNames
            ?? workspace.sessions.first(where: { $0.attempt.id == id })?.attempt.photoNames ?? []
        let reminderIDs = workspace.sessions.filter { $0.attempt.id == id }.map {
            "home-preparation-\(scope.storageComponent)-\($0.id)"
        }
        try mutate { state in
            var removed = state.deletions ?? HomeWorkspaceDeletions()
            removed.attemptDrafts.insert(id); state.deletions = removed
        }
        for name in names where HomeRecipeMediaService.isValidName(name) && !workspace.referencedPhotoNames.contains(name) {
            let url = directory(scope).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { try? FileManager.default.removeItem(at: url) }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIDs)
    }

    func discardRecipeDraft(id: UUID, expectedScope: LocalAccountScope? = nil) throws {
        try requireScope(expectedScope)
        try mutate {
            var removed = $0.deletions ?? HomeWorkspaceDeletions()
            removed.recipeDrafts.insert(id); $0.deletions = removed
            $0.recipeDrafts.removeAll { $0.id == id }
        }
    }

    func deleteAttempt(id: UUID, expectedScope: LocalAccountScope) throws {
        try requireScope(expectedScope)
        guard let attempt = workspace.attempts.first(where: { $0.id == id }) else { return }
        guard attempt.publicationStatus != .posting, attempt.publicationStatus != .published else {
            throw HomeRecipeWorkspaceError.invalid("Open the posted sip or its interrupted post to delete it safely.")
        }
        try requireUnsubmittedMake(id)
        let names = Set(attempt.photoNames + workspace.attemptDrafts.filter { $0.id == id }.flatMap(\.photoNames)
            + workspace.sessions.filter { $0.attempt.id == id }.flatMap { $0.attempt.photoNames })
        let reminders = workspace.sessions.filter { $0.attempt.id == id }.map { "home-preparation-\(scope.storageComponent)-\($0.id)" }
        try mutate {
            var removed = $0.deletions ?? HomeWorkspaceDeletions()
            removed.attempts.insert(id); $0.deletions = removed
        }
        for name in names where !workspace.referencedPhotoNames.contains(name) {
            guard HomeRecipeMediaService.isValidName(name) else { continue }
            try? FileManager.default.removeItem(at: directory(scope).appendingPathComponent(name))
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminders)
    }

    func applyConfirmedPostDeletions(expectedScope: LocalAccountScope) throws {
        try requireScope(expectedScope)
        guard let owner = scope.userID else { return }
        let ids = HomeDeletedPostReceipts.ids(for: owner)
        guard !ids.isEmpty else { return }
        let names = workspace.referencedPhotoNames
        try mutate { value in for id in ids { value.removeConfirmedPublication(id) } }
        for name in names.subtracting(workspace.referencedPhotoNames) where HomeRecipeMediaService.isValidName(name) {
            try? FileManager.default.removeItem(at: directory(scope).appendingPathComponent(name))
        }
    }

    private func requireScope(_ expected: LocalAccountScope?) throws {
        guard expected == nil || expected == scope else {
            throw HomeRecipeWorkspaceError.invalid("Your account changed. Nothing was deleted.")
        }
    }

    private func requireLiveMake(_ id: UUID) throws {
        guard workspace.deletions?.attempts.contains(id) != true,
              workspace.deletions?.attemptDrafts.contains(id) != true else {
            throw HomeRecipeWorkspaceError.invalid("That Home sip was deleted. Start a new sip to keep editing.")
        }
    }

    private func requireUnsubmittedMake(_ id: UUID) throws {
        guard let owner = scope.userID else { return }
        // A failed read is not an empty outbox. Protected work keeps its existing
        // remote-aware discard/retry path instead of becoming an ordinary draft.
        var records = workspace.attempts + workspace.attemptDrafts
        records.append(contentsOf: workspace.sessions.map(\.attempt))
        records.append(contentsOf: workspace.attemptConflicts ?? [])
        records.append(contentsOf: (workspace.preparationConflicts ?? []).map(\.attempt))
        var linkedIDs: Set<UUID> = [id]
        let matches = records.filter { $0.id == id || $0.editingAttemptID == id }
        linkedIDs.formUnion(matches.map(\.id))
        linkedIDs.formUnion(matches.compactMap(\.publicationDraftID))
        let pending = try PendingVisitSubmissionStore.shared.loadAll(userId: owner)
        guard !pending.contains(where: { linkedIDs.contains($0.id) || $0.homeAttemptID.map(linkedIDs.contains) == true }) else {
            throw HomeRecipeWorkspaceError.invalid("This sip has an interrupted post. Resume it to finish or discard it safely.")
        }
        let report = SipDraftStore.shared.readReport(in: scope)
        guard report.isComplete else {
            throw HomeRecipeWorkspaceError.invalid("Your saved drafts could not be checked. Nothing was deleted; please try again.")
        }
        guard !report.drafts.contains(where: {
            ($0.context == .home && ($0.launchContext.homeAttemptID.map(linkedIDs.contains) == true || linkedIDs.contains($0.id)))
                && !HomeJourneyControlPolicy.canDiscard($0, in: scope, hasProtectedSubmission: false)
        }) else {
            throw HomeRecipeWorkspaceError.invalid("This sip is preparing a post. Resume it to finish or discard it safely.")
        }
    }

    func setPublicationDraft(_ draftID: UUID, for attemptID: UUID) throws {
        try mutate { state in
            guard let index = state.attempts.firstIndex(where: { $0.id == attemptID }) else {
                throw HomeRecipeWorkspaceError.invalid("Save this make before sharing it.")
            }
            state.attempts[index].publicationDraftID = draftID
            state.attempts[index].publicationStatus = .draft
        }
    }

    func setPublicationStatus(_ status: HomePublicationStatus, for attemptID: UUID) throws {
        try mutate { state in
            guard let index = state.attempts.firstIndex(where: { $0.id == attemptID }) else { return }
            state.attempts[index].publicationStatus = status
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

    func savePhotoAsync(_ data: Data, attemptID: UUID) async throws -> String {
        try requireLiveMake(attemptID)
        let capturedScope = scope
        let capturedActivation = activationID
        let targetDirectory = directory(capturedScope)
        let name = "\(attemptID)-\(UUID()).jpg"
        let destination = targetDirectory.appendingPathComponent(name)
        do {
            if let photoWriter { try await photoWriter(data, destination) }
            else {
                try await Task.detached(priority: .userInitiated) {
                    guard let image = UIImage(data: data),
                          let jpeg = image.resizedForVisitUpload(maxDimension: 1600).jpegData(compressionQuality: 0.84) else {
                        throw HomeRecipeWorkspaceError.invalid("That photo could not be opened.")
                    }
                    try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
                    try jpeg.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                }.value
            }
            try Task.checkCancellation()
            guard scope == capturedScope, activationID == capturedActivation,
                  !workspace.attempts.contains(where: { $0.id == attemptID }) else {
                throw HomeRecipeWorkspaceError.invalid("This sip changed while its photo was loading. Please select the photo again.")
            }
            try requireLiveMake(attemptID)
            return name
        } catch {
            // This unique filename has not yet been returned to a caller, so it
            // cannot be a committed reference in any workspace.
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
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
        guard !Task.isCancelled,
              !isSyncing,
              canWrite,
              !hasRemoteConflict,
              let owner = scope.userID else { return }
        let remoteTransport: any HomeRecipeWorkspaceTransport
        if let transport { remoteTransport = transport }
        else {
            guard !MugshotLaunchEnvironment.isUITesting,
                  let client = try? SupabaseClientProvider.shared.client() else { return }
            remoteTransport = HomeRecipeWorkspaceService(client: client)
        }
        isSyncing = true
        let taskID = UUID()
        syncTaskID = taskID
        let capturedScope = scope
        let captured = workspace
        var needsAnotherPass = false
        var diagnosticOutcome = BatteryDiagnostics.WorkOutcome.interrupted
        var diagnostics = BatteryDiagnostics.HomeSyncSession(
            referencedPhotoCount: captured.referencedPhotoNames.count,
            hasPendingOperation: captured.pendingOperationID != nil
        )
        defer {
            diagnostics.finish(diagnosticOutcome)
            if syncTaskID == taskID {
                isSyncing = false
                if needsAnotherPass, !Task.isCancelled {
                    Task { await self.synchronize() }
                }
            }
        }
        do {
            try Task.checkCancellation()
            let receiptURL = directory(capturedScope).appendingPathComponent("uploaded-photos-v1.json")
            var uploaded = (try? JSONDecoder().decode(Set<String>.self, from: Data(contentsOf: receiptURL))) ?? []
            for name in captured.referencedPhotoNames.subtracting(uploaded) {
                _ = try HomeRecipeMediaService.path(owner: owner, name: name)
                let source = directory(capturedScope).appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: source.path) else {
                    throw HomeRecipeWorkspaceError.invalid("A photo for this journal entry is missing on this device. The entry is safe; reconnect the original device or remove the missing photo before syncing.")
                }
                guard scope == capturedScope, syncTaskID == taskID else { return }
                let bytes = try Data(contentsOf: source)
                try await remoteTransport.uploadPhoto(bytes, name: name, ownerID: owner)
                try Task.checkCancellation()
                guard scope == capturedScope, syncTaskID == taskID else { return }
                diagnostics.recordedUpload(byteCount: bytes.count)
                uploaded.insert(name)
                try JSONEncoder().encode(uploaded).write(to: receiptURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
            var remote = try await remoteTransport.synchronize(captured, ownerID: owner)
            try Task.checkCancellation()
            guard scope == capturedScope, syncTaskID == taskID else { return }
            // Preserve local intent even if an older server/client omits markers.
            // Cleanup waits for metadata acknowledgment rather than deleting media
            // while another workspace still refers to it.
            let acknowledged = remote
            if captured.deletions != nil || remote.deletions != nil {
                remote.deletions = (remote.deletions ?? HomeWorkspaceDeletions()).union(captured.deletions ?? HomeWorkspaceDeletions())
                remote.applyDeletions()
            }
            let requiresDeletionAcknowledgment = remote != acknowledged
            if workspace.pendingOperationID != captured.pendingOperationID {
                if captured.pendingOperationID == nil, remote.remoteRevision != captured.remoteRevision {
                    remoteConflict = remote
                    hasRemoteConflict = true
                    errorMessage = HomeRecipeWorkspaceError.conflict.localizedDescription
                    diagnosticOutcome = .failed
                    return
                }
                var latest = workspace
                latest.remoteRevision = remote.remoteRevision
                try write(latest, scope: capturedScope)
                workspace = latest
                needsAnotherPass = true
            } else {
                if requiresDeletionAcknowledgment { remote.pendingOperationID = UUID() }
                try write(remote, scope: capturedScope)
                workspace = remote
            }
            for name in workspace.referencedPhotoNames {
                _ = try HomeRecipeMediaService.path(owner: owner, name: name)
                let destination = directory(capturedScope).appendingPathComponent(name)
                guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
                guard scope == capturedScope, syncTaskID == taskID else { return }
                let bytes = try await remoteTransport.downloadPhoto(name: name, ownerID: owner)
                try Task.checkCancellation()
                guard scope == capturedScope, syncTaskID == taskID else { return }
                guard bytes.count <= 10_485_760, UIImage(data: bytes) != nil else {
                    throw HomeRecipeWorkspaceError.invalid("A synced photo could not be opened. Your journal entry is saved.")
                }
                try bytes.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                diagnostics.recordedDownload(byteCount: bytes.count)
                uploaded.insert(name)
                try JSONEncoder().encode(uploaded).write(to: receiptURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                objectWillChange.send()
            }
            if !needsAnotherPass, !requiresDeletionAcknowledgment,
               workspace.pendingOperationID == nil {
                let deletedReceiptURL = directory(capturedScope).appendingPathComponent("deleted-photos-v1.json")
                var deleted: Set<String> = []
                if FileManager.default.fileExists(atPath: deletedReceiptURL.path) {
                    deleted = try JSONDecoder().decode(Set<String>.self, from: Data(contentsOf: deletedReceiptURL))
                }
                let candidates = workspace.deletions?.photoNames ?? []
                for name in candidates.sorted() where !workspace.referencedPhotoNames.contains(name) {
                    _ = try HomeRecipeMediaService.path(owner: owner, name: name)
                    try Task.checkCancellation()
                    guard scope == capturedScope, syncTaskID == taskID,
                          workspace.pendingOperationID == nil,
                          !workspace.referencedPhotoNames.contains(name) else { break }
                    if !deleted.contains(name) {
                        try await remoteTransport.deletePhoto(name: name, ownerID: owner)
                        try Task.checkCancellation()
                        guard scope == capturedScope, syncTaskID == taskID else { return }
                        uploaded.remove(name)
                        try JSONEncoder().encode(uploaded).write(to: receiptURL,
                            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                        deleted.insert(name)
                        try JSONEncoder().encode(deleted).write(to: deletedReceiptURL,
                            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                        if workspace.pendingOperationID != nil { needsAnotherPass = true }
                    }
                    if !workspace.referencedPhotoNames.contains(name) {
                        let localPhoto = directory(capturedScope).appendingPathComponent(name)
                        if FileManager.default.fileExists(atPath: localPhoto.path) { try FileManager.default.removeItem(at: localPhoto) }
                    }
                }
            }
            if requiresDeletionAcknowledgment {
                errorMessage = "Saved on this device. Your deletions are waiting to finish syncing."
                diagnosticOutcome = .interrupted
                return
            }
            errorMessage = nil
            diagnosticOutcome = .completed
        } catch is CancellationError {
            diagnosticOutcome = .cancelled
            return
        } catch {
            guard !Task.isCancelled else {
                diagnosticOutcome = .cancelled
                return
            }
            diagnosticOutcome = .failed
            guard scope == capturedScope, syncTaskID == taskID else { return }
            errorMessage = "Saved on this device. Sync needs attention: \(error.localizedDescription)"
            MugshotAnalytics.shared.capture(.homeRecipe(.syncFailed, hasRecipe: !captured.recipes.isEmpty, durationSeconds: 0))
            if String(describing: error).contains("HOME_WORKSPACE_CONFLICT") {
                hasRemoteConflict = true
                let latest = try? await remoteTransport.fetch(ownerID: owner)
                guard scope == capturedScope, syncTaskID == taskID else { return }
                remoteConflict = latest
            }
        }
    }

    func refreshRemoteConflict() async {
        guard hasRemoteConflict, remoteConflict == nil, let owner = scope.userID else { return }
        let capturedScope = scope
        do {
            let remoteTransport: any HomeRecipeWorkspaceTransport
            if let transport { remoteTransport = transport }
            else { remoteTransport = HomeRecipeWorkspaceService(client: try SupabaseClientProvider.shared.client()) }
            let latest = try await remoteTransport.fetch(ownerID: owner)
            guard scope == capturedScope, !Task.isCancelled else { return }
            remoteConflict = latest
            errorMessage = HomeRecipeWorkspaceError.conflict.localizedDescription
        } catch {
            guard scope == capturedScope, !Task.isCancelled else { return }
            errorMessage = "Your local edits are safe. The latest library could not be loaded yet: \(error.localizedDescription)"
        }
    }

    /// Preserve a recoverable local copy before adopting a newer remote library.
    func useRemoteAfterConflict() throws {
        guard let remoteConflict else { throw HomeRecipeWorkspaceError.conflict }
        let backup = directory(scope).appendingPathComponent("conflict-\(UUID()).json")
        try JSONEncoder().encode(workspace).write(to: backup, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var merged = remoteConflict.reconciling(local: workspace)
        let copied = try rekeyRetiredPhotos(in: &merged, priorReferences: remoteConflict.referencedPhotoNames)
        do { try write(merged, scope: scope) }
        catch {
            for name in copied { try? FileManager.default.removeItem(at: directory(scope).appendingPathComponent(name)) }
            throw error
        }
        workspace = merged
        try cleanupUnreferencedLocalPhotos()
        hasRemoteConflict = false
        self.remoteConflict = nil
        errorMessage = nil
    }
}
