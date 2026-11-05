import Foundation
import Testing
import UIKit
@testable import testMugshot

@MainActor
struct HomeWorkspaceDeletionBoundaryTests {
    @Test func onlyExactAuthenticatedMissingVisitAcknowledgesDeleteRetry() {
        let owner = UUID()
        #expect(VisitDeletionAcknowledgment.isAlreadyAbsent(code: "P0002", message: "visit not found", currentOwner: owner, expectedOwner: owner))
        #expect(!VisitDeletionAcknowledgment.isAlreadyAbsent(code: "42501", message: "visit not found", currentOwner: owner, expectedOwner: owner))
        #expect(!VisitDeletionAcknowledgment.isAlreadyAbsent(code: "P0002", message: "visit not found", currentOwner: UUID(), expectedOwner: owner))
        #expect(!VisitDeletionAcknowledgment.isAlreadyAbsent(code: "P0002", message: "other missing record", currentOwner: owner, expectedOwner: owner))
        #expect(!VisitDeletionAcknowledgment.isAlreadyAbsent(code: "P0002", message: "visit not found", currentOwner: nil, expectedOwner: owner))
    }
    @Test func selectedCoverIsFirstWithoutLosingOtherPhotos() {
        #expect(HomeJournalProjection.coverFirstIndices(count: 4, posterIndex: 2) == [2, 0, 1, 3])
        #expect(HomeJournalProjection.coverFirstIndices(count: 2, posterIndex: 8) == [1, 0])
        #expect(HomeJournalProjection.coverFirstIndices(count: 2, posterIndex: -1) == [0, 1])
        #expect(HomeJournalProjection.coverFirstIndices(count: 0, posterIndex: 1).isEmpty)
    }

    @Test func privateEditPreservesSavedIdentityDateRecipeAndPublication() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        let recipeID = try store.saveRecipe(.init(content: .init(name: "Syrup latte")))
        let original = HomeAttemptRecord(name: "Latte", locationName: "Kitchen", recipe: .init(recipeID: recipeID, versionID: store.workspace.recipes[0].current!.id), rating: 3, batchID: UUID(), batchSourceAttemptID: UUID(), publicationDraftID: UUID(), publicationStatus: .draft)
        try store.saveAttempt(original)
        let saved = try #require(store.workspace.attempts.first); let recipes = store.workspace.recipes
        var edit = saved; edit.id = UUID(); edit.editingAttemptID = saved.id
        edit.savedAt = nil; edit.publicationDraftID = nil; edit.publicationStatus = nil
        edit.batchID = nil; edit.batchSourceAttemptID = UUID()
        edit.name = "Blueberry latte"; edit.privateNote = "Lovely"; edit.rating = 4
        try store.saveAttemptDraft(edit); let stale = store.workspace
        try store.saveAttempt(edit, updateRecipe: true)
        #expect(store.workspace.attempts.count == 1)
        let updated = try #require(store.workspace.attempts.first)
        #expect(updated.id == saved.id && updated.savedAt == saved.savedAt && updated.createdAt == saved.createdAt)
        #expect(updated.name == edit.name && updated.privateNote == edit.privateNote && updated.rating == 4)
        #expect(updated.locationName == saved.locationName && updated.publicationDraftID == saved.publicationDraftID)
        #expect(updated.publicationStatus == saved.publicationStatus && updated.editingAttemptID == nil)
        #expect(updated.batchID == saved.batchID && updated.batchSourceAttemptID == saved.batchSourceAttemptID)
        #expect(store.workspace.recipes == recipes && store.workspace.attemptDrafts.isEmpty)
        try store.saveAttempt(edit)
        #expect(throws: (any Error).self) { try store.saveAttemptDraft(edit) }
        #expect(stale.reconciling(local: store.workspace).attemptDrafts.isEmpty)
        #expect(store.workspace.reconciling(local: stale).attemptDrafts.isEmpty)
    }

    @Test func deletingOriginalAlsoDeletesEditDraftButDiscardingEditKeepsOriginal() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        let original = HomeAttemptRecord(name: "Tea"); try store.saveAttempt(original)
        var edit = original; edit.id = UUID(); edit.editingAttemptID = original.id
        try store.saveAttemptDraft(edit); try store.discardAttemptDraft(id: edit.id)
        #expect(store.workspace.attempts.map(\.id) == [original.id])
        edit.id = UUID(); try store.saveAttemptDraft(edit); let stale = store.workspace
        try store.deleteAttempt(id: original.id, expectedScope: .guest)
        #expect(store.workspace.attemptDrafts.isEmpty)
        #expect(stale.reconciling(local: store.workspace).attemptDrafts.isEmpty)
        var oldClient = stale; oldClient.attemptDrafts[0].editingAttemptID = nil
        #expect(oldClient.reconciling(local: store.workspace).attemptDrafts.isEmpty)
        #expect(throws: (any Error).self) { try store.saveAttempt(edit) }
    }

    @Test func aDraftDiscardDoesNotEraseAnotherDevicesSavedMake() {
        let attempt = HomeAttemptRecord(name: "Coffee", savedAt: .now, publicationDraftID: UUID(), publicationStatus: .draft)
        var saved = HomeRecipeWorkspace(); saved.attempts = [attempt]
        var discarded = HomeRecipeWorkspace(); discarded.deletions = .init(attemptDrafts: [attempt.id])
        #expect(saved.reconciling(local: discarded).attempts.map(\.id) == [attempt.id])
        var withDraft = saved; withDraft.attemptDrafts = [attempt]
        let merged = withDraft.reconciling(local: discarded)
        #expect(merged.deletions?.publicationDrafts?.isEmpty ?? true)
    }

    @Test func confirmedDeletionCoversDraftAndConflictOnlyRepresentations() {
        let publication = UUID(); let attempt = HomeAttemptRecord(name: "Coffee", publicationDraftID: publication)
        var workspace = HomeRecipeWorkspace(); workspace.attemptDrafts = [attempt]
        workspace.preparationConflicts = [HomePreparationSession(attempt: attempt)]
        workspace.removeConfirmedPublication(publication)
        #expect(workspace.attemptDrafts.isEmpty && workspace.preparationConflicts?.isEmpty == true)
        #expect(workspace.deletions?.attempts.contains(attempt.id) == true)
    }

    @Test func failedRemoteDeleteDoesNotAcknowledgeAndAccountSwitchDoesNotRetargetReceipt() async throws {
        let owner = UUID(); var active: UUID? = owner; var receiptOwners: [UUID] = []
        await #expect(throws: (any Error).self) {
            try await HomePublishedSipDeletion.perform(owner: owner, currentOwner: { active }, deleteRemote: {
                throw URLError(.notConnectedToInternet)
            }, recordConfirmed: { receiptOwners.append(owner) })
        }
        #expect(receiptOwners.isEmpty)
        try await HomePublishedSipDeletion.perform(owner: owner, currentOwner: { active }, deleteRemote: {
            active = UUID()
        }, recordConfirmed: { receiptOwners.append(owner) })
        #expect(receiptOwners == [owner])
        var called = false
        await #expect(throws: (any Error).self) {
            try await HomePublishedSipDeletion.perform(owner: owner, currentOwner: { active }, deleteRemote: { called = true }, recordConfirmed: {})
        }
        #expect(!called)
    }

    @Test func cloudPhotoDeletionWaitsForMetadataAndRetriesAfterRelaunch() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let transport = DeletionTransport(); let owner = UUID()
        let store = HomeRecipeWorkspaceStore(root: root, transport: transport); store.activate(.user(owner))
        let attempt = try photoAttempt(store); try store.saveAttempt(attempt); await store.synchronize()
        try store.deleteAttempt(id: attempt.id, expectedScope: .user(owner))
        transport.failSave = true; await store.synchronize()
        #expect(transport.deleted.isEmpty && store.workspace.pendingOperationID != nil)
        transport.failSave = false; transport.failDelete = true; await store.synchronize()
        #expect(transport.deleted.isEmpty && store.errorMessage != nil)
        transport.failDelete = false
        let relaunched = HomeRecipeWorkspaceStore(root: root, transport: transport); relaunched.activate(.user(owner))
        await relaunched.synchronize()
        #expect(transport.deleted == attempt.photoNames)
        #expect(relaunched.workspace.attempts.isEmpty && relaunched.errorMessage == nil)
        await relaunched.synchronize()
        #expect(transport.deleted == attempt.photoNames, "Successful cleanup has a durable receipt")
    }

    @Test func sharedPhotoAndAccountSwitchPreventPrematureCloudRemoval() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let transport = DeletionTransport(); let owner = UUID()
        let store = HomeRecipeWorkspaceStore(root: root, transport: transport); store.activate(.user(owner))
        let first = try photoAttempt(store); var second = first; second.id = UUID()
        try store.saveAttempt(first); try store.saveAttempt(second); await store.synchronize()
        try store.deleteAttempt(id: first.id, expectedScope: .user(owner)); await store.synchronize()
        #expect(transport.deleted.isEmpty && store.photo(first.photoNames[0]) != nil)
        try store.deleteAttempt(id: second.id, expectedScope: .user(owner))
        transport.onSave = { store.activate(.user(UUID())) }
        await store.synchronize()
        #expect(transport.deleted.isEmpty && store.workspace.attempts.isEmpty)
    }

    @Test func guestDeletionIntentSurvivesAdoptionAndRetry() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let owner = UUID(); let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        let attempt = HomeAttemptRecord(name: "Guest tea"); try store.saveAttemptDraft(attempt)
        let stale = store.workspace
        try store.discardAttemptDraft(id: attempt.id); try store.adoptGuestWorkspace(for: owner)
        store.activate(.user(owner)); try store.adoptGuestWorkspace(for: owner)
        #expect(store.workspace.deletions?.attemptDrafts.contains(attempt.id) == true)
        #expect(stale.reconciling(local: store.workspace).attemptDrafts.isEmpty)
    }

    @Test func hostilePhotoNamesCannotDeleteWorkspaceOrNeighborAccount() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let owner = UUID(); let neighbor = root.appendingPathComponent("sentinel")
        let bytes = Data("preserved".utf8); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try bytes.write(to: neighbor)
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        let attempt = HomeAttemptRecord(name: "Bad metadata", photoNames: ["workspace-v1.json", "../sentinel"])
        try store.saveAttemptDraft(attempt); try store.discardAttemptDraft(id: attempt.id)
        #expect(try Data(contentsOf: neighbor) == bytes)
        let restored = HomeRecipeWorkspaceStore(root: root); restored.activate(.guest)
        #expect(restored.errorMessage == nil && restored.workspace.attemptDrafts.isEmpty)
        let saved = HomeAttemptRecord(name: "Retained", photoNames: ["workspace-v1.json"])
        try store.saveAttempt(saved); try store.deleteAttempt(id: saved.id, expectedScope: .guest)
        store.activate(.user(owner)); store.activate(.guest)
        #expect(store.errorMessage == nil && store.workspace.attempts.isEmpty)
    }

    @Test(arguments: [false, true]) func abandonedPhotoWriteRemovesItsCapturedFile(_ switchAccount: Bool) async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let gate = PhotoWriteGate()
        let store = HomeRecipeWorkspaceStore(root: root, photoWriter: { data, url in
            await gate.wait()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        })
        store.activate(.guest); let attempt = HomeAttemptRecord(name: "Loading photo")
        try store.saveAttemptDraft(attempt)
        let task = Task { try await store.savePhotoAsync(Data("synthetic bytes".utf8), attemptID: attempt.id) }
        await gate.started()
        if switchAccount { store.activate(.user(UUID())) }
        else { try store.discardAttemptDraft(id: attempt.id) }
        await gate.release()
        await #expect(throws: (any Error).self) { try await task.value }
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        #expect(!files.contains { $0.pathExtension == "jpg" })
    }

    @Test func photoReferenceAddedDuringCleanupGetsFreshIdentityAndAnotherSync() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let owner = UUID(); let transport = DeletionTransport()
        let store = HomeRecipeWorkspaceStore(root: root, transport: transport); store.activate(.user(owner))
        let first = try photoAttempt(store); try store.saveAttempt(first); await store.synchronize()
        let oldName = first.photoNames[0]; let originalBytes = try store.exportPhoto(name: oldName, ownerID: owner)
        try store.deleteAttempt(id: first.id, expectedScope: .user(owner))
        var newID = UUID()
        transport.onDelete = {
            transport.onDelete = nil
            do {
                // Simulate a picker holding bytes while the deletion was pending.
                let oldURL = root.appendingPathComponent(LocalAccountScope.user(owner).storageComponent).appendingPathComponent(oldName)
                try originalBytes.write(to: oldURL)
                let second = HomeAttemptRecord(name: "New serving", photoNames: [oldName]); newID = second.id
                try store.saveAttempt(second)
            } catch { Issue.record("Concurrent local make failed: \(error)") }
        }
        await store.synchronize()
        // Let the queued second metadata pass finish, without a timing sleep.
        for _ in 0..<50 where store.isSyncing || store.workspace.pendingOperationID != nil { await Task.yield() }
        await store.synchronize()
        let second = try #require(store.workspace.attempts.first { $0.id == newID })
        #expect(second.photoNames[0] != oldName)
        #expect(store.photo(second.photoNames[0]) != nil)
        #expect(transport.uploads.contains(second.photoNames[0]))
        #expect(transport.deleted == [oldName] && store.workspace.pendingOperationID == nil)
    }

    private func temporaryRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("HomeDeletionBoundary-\(UUID())") }
    private func photoAttempt(_ store: HomeRecipeWorkspaceStore) throws -> HomeAttemptRecord {
        var attempt = HomeAttemptRecord(name: "Photo coffee")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.brown.setFill(); context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        attempt.photoNames = [try store.savePhoto(try #require(image.jpegData(compressionQuality: 0.8)), attemptID: attempt.id)]
        return attempt
    }
}

@MainActor
private final class DeletionTransport: HomeRecipeWorkspaceTransport {
    var remote = HomeRecipeWorkspace()
    var failSave = false; var failDelete = false
    var deleted: [String] = []; var onSave: (() -> Void)?
    var uploads: [String] = []; var onDelete: (() -> Void)?
    func fetch(ownerID: UUID) async throws -> HomeRecipeWorkspace { remote }
    func synchronize(_ workspace: HomeRecipeWorkspace, ownerID: UUID) async throws -> HomeRecipeWorkspace {
        onSave?()
        if failSave { throw URLError(.notConnectedToInternet) }
        if workspace.pendingOperationID != nil { remote = workspace; remote.pendingOperationID = nil; remote.remoteRevision += 1 }
        return remote
    }
    func uploadPhoto(_ data: Data, name: String, ownerID: UUID) async throws { uploads.append(name) }
    func downloadPhoto(name: String, ownerID: UUID) async throws -> Data { throw URLError(.fileDoesNotExist) }
    func deletePhoto(name: String, ownerID: UUID) async throws {
        onDelete?()
        if failDelete { throw URLError(.notConnectedToInternet) }; deleted.append(name)
    }
}

private actor PhotoWriteGate {
    var continuation: CheckedContinuation<Void, Never>?
    var startWaiter: CheckedContinuation<Void, Never>?
    func wait() async {
        await withCheckedContinuation { pending in
            continuation = pending; startWaiter?.resume(); startWaiter = nil
        }
    }
    func started() async {
        if continuation != nil { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func release() { continuation?.resume(); continuation = nil }
}
