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
    var canResolveRemoteConflict: Bool { remoteConflict != nil }
    private let root: URL
    private let transport: (any HomeRecipeWorkspaceTransport)?
    private var loaded = false
    private var canWrite = false
    private var remoteConflict: HomeRecipeWorkspace?
    private var syncTaskID: UUID?

    init(root: URL? = nil, transport: (any HomeRecipeWorkspaceTransport)? = nil) {
        self.transport = transport
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
        guard next != workspace else { return }
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
                guard state.recipes.contains(where: { $0.id == reference.recipeID && $0.versions.contains { $0.id == reference.versionID } }) else {
                    throw HomeRecipeWorkspaceError.unavailableReference
                }
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
        MugshotAnalytics.shared.capture(.homeRecipe(.recipeSaved, hasRecipe: true, durationSeconds: 0))
        if draft.recipeID == nil, draft.content.sourceVersionID != nil {
            MugshotAnalytics.shared.capture(.homeRecipe(.adapted, hasRecipe: true, durationSeconds: 0))
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
        if let message = attempt.preparation?.validationMessage {
            throw HomeRecipeWorkspaceError.invalid(message)
        }
        try mutate { state in
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

    func saveSession(_ session: HomePreparationSession) throws {
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

    func discardAttemptDraft(id: UUID) throws {
        let names = workspace.attemptDrafts.first(where: { $0.id == id })?.photoNames
            ?? workspace.sessions.first(where: { $0.attempt.id == id })?.attempt.photoNames ?? []
        let reminderIDs = workspace.sessions.filter { $0.attempt.id == id }.map {
            "home-preparation-\(scope.storageComponent)-\($0.id)"
        }
        try mutate { state in
            state.attemptDrafts.removeAll { $0.id == id }
            state.sessions.removeAll { $0.attempt.id == id && $0.currentPhase != .saved }
        }
        for name in names where !workspace.referencedPhotoNames.contains(name) {
            let url = directory(scope).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { try? FileManager.default.removeItem(at: url) }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIDs)
    }

    func discardRecipeDraft(id: UUID) throws {
        try mutate { $0.recipeDrafts.removeAll { $0.id == id } }
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
        let targetDirectory = directory(scope)
        let name = "\(attemptID)-\(UUID()).jpg"
        return try await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: data),
                  let jpeg = image.resizedForVisitUpload(maxDimension: 1600).jpegData(compressionQuality: 0.84) else {
                throw HomeRecipeWorkspaceError.invalid("That photo could not be opened.")
            }
            try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            try jpeg.write(to: targetDirectory.appendingPathComponent(name),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return name
        }.value
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
            let remote = try await remoteTransport.synchronize(captured, ownerID: owner)
            try Task.checkCancellation()
            guard scope == capturedScope, syncTaskID == taskID else { return }
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
        let merged = remoteConflict.reconciling(local: workspace)
        try write(merged, scope: scope)
        workspace = merged
        hasRemoteConflict = false
        self.remoteConflict = nil
        errorMessage = nil
    }
}
