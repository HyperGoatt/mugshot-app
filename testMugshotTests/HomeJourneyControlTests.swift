import Foundation
import Testing
import UIKit
@testable import testMugshot

@MainActor
struct HomeJourneyControlTests {
    @Test func journalKeepsPrivateHomeInDateOrderAndDeduplicatesPublishedCopies() {
        var older = HomeAttemptRecord(name: "Tea", savedAt: Date(timeIntervalSince1970: 10))
        var newer = HomeAttemptRecord(name: "Latte", savedAt: Date(timeIntervalSince1970: 20))
        let publishedID = UUID()
        older.publicationDraftID = publishedID; older.publicationStatus = .failed
        newer.locationName = "Kitchen counter"
        var workspace = HomeRecipeWorkspace(); workspace.attempts = [older, newer]
        let all = HomeJournalProjection.privateEntries(in: workspace, scope: .guest, expectedScope: .guest, publishedIDs: [])
        #expect(all.map(\.name) == ["Latte", "Tea"])
        #expect(all.first?.journalLocationName == "Kitchen counter")
        let filtered = HomeJournalProjection.privateEntries(in: workspace, scope: .guest, expectedScope: .guest, publishedIDs: [publishedID])
        #expect(filtered.map(\.id) == [newer.id])
        #expect(HomeJournalProjection.privateEntries(in: workspace, scope: .guest, expectedScope: .user(UUID()), publishedIDs: []).isEmpty)
    }

    @Test func oldAttemptsDecodeWithoutInventingAHomeProfile() throws {
        let old = HomeAttemptRecord(name: "Filter coffee")
        let data = try JSONEncoder().encode(old)
        let decoded = try JSONDecoder().decode(HomeAttemptRecord.self, from: data)
        #expect(decoded.journalLocationName == "Home")
        #expect(decoded.locationName == nil)
    }

    @Test func savedHomeDeletionIsIdempotentAndPreservesRecipeAndOtherServings() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        let recipeID = try store.saveRecipe(HomeRecipeEditorDraft(content: .init(name: "Cold brew")))
        var batch = HomeAttemptRecord(name: "Batch"); batch.batchID = UUID()
        try store.saveAttempt(batch)
        var serving = HomeAttemptRecord(name: "A glass"); serving.batchSourceAttemptID = batch.id
        try store.saveAttempt(serving)
        let recipes = store.workspace.recipes
        try store.deleteAttempt(id: batch.id, expectedScope: .guest)
        try store.deleteAttempt(id: batch.id, expectedScope: .guest)
        #expect(store.workspace.attempts.map(\.id) == [serving.id])
        #expect(store.workspace.recipes == recipes)
        #expect(store.workspace.recipes.first?.id == recipeID)
        let restored = HomeRecipeWorkspaceStore(root: root); restored.activate(.guest)
        #expect(restored.workspace.attempts.map(\.id) == [serving.id])
    }

    @Test func wrongAccountAndUnconfirmedPublishedDeletionAreRejected() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        var attempt = HomeAttemptRecord(name: "Latte")
        attempt.publicationDraftID = UUID(); attempt.publicationStatus = .published
        try store.saveAttempt(attempt)
        #expect(throws: (any Error).self) { try store.deleteAttempt(id: attempt.id, expectedScope: .user(UUID())) }
        #expect(throws: (any Error).self) { try store.deleteAttempt(id: attempt.id, expectedScope: .guest) }
        #expect(store.workspace.attempts.count == 1)
    }

    @Test func deletingDraftRemovesLinkedSessionAndCannotReturnFromConflictOrLateAutosave() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        let attempt = HomeAttemptRecord(name: "Oat latte")
        try store.saveAttemptDraft(attempt)
        try store.saveSession(HomePreparationSession(attempt: attempt))
        let stale = store.workspace
        try store.discardAttemptDraft(id: attempt.id, expectedScope: .guest)
        #expect(store.workspace.attemptDrafts.isEmpty && store.workspace.sessions.isEmpty)
        #expect(throws: (any Error).self) { try store.saveAttemptDraft(attempt) }
        #expect(stale.reconciling(local: store.workspace).attemptDrafts.isEmpty)
        #expect(stale.reconciling(local: store.workspace).sessions.isEmpty)
        #expect(store.workspace.reconciling(local: stale).attemptDrafts.isEmpty)
    }

    @Test func recipeDraftDeletionNeverRemovesSavedVersionsAndSurvivesConflict() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        let draft = HomeRecipeEditorDraft(content: .init(name: "Syrup"))
        _ = try store.saveRecipe(draft)
        let edit = HomeRecipeEditorDraft(recipeID: draft.id, baseVersionID: store.workspace.recipes.first?.current?.id, content: .init(name: "Syrup edit"))
        try store.saveDraft(edit); let stale = store.workspace
        try store.discardRecipeDraft(id: edit.id, expectedScope: .guest)
        #expect(store.workspace.recipes.count == 1)
        #expect(store.workspace.recipeDrafts.isEmpty)
        #expect(stale.reconciling(local: store.workspace).recipeDrafts.isEmpty)
        #expect(throws: (any Error).self) { try store.saveDraft(edit) }
    }

    @Test func deletionDoesNotRemoveAPhotoReferencedByAnotherSavedSip() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { _ in UIColor.brown.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 12, height: 12)) }
        let photo = try store.savePhoto(image.jpegData(compressionQuality: 0.8)!, attemptID: UUID())
        let first = HomeAttemptRecord(name: "One", photoNames: [photo])
        let second = HomeAttemptRecord(name: "Two", photoNames: [photo])
        try store.saveAttempt(first); try store.saveAttempt(second)
        try store.deleteAttempt(id: first.id, expectedScope: .guest)
        #expect(store.photo(photo) != nil)
        try store.deleteAttempt(id: second.id, expectedScope: .guest)
        #expect(store.photo(photo) == nil)
    }

    @Test func protectedOrForeignSipDraftCannotBeDiscardedAsOrdinaryWork() {
        let owner = UUID(); let draft = SipDraft(ownerUserID: owner, context: .home, drinkName: "Latte")
        #expect(HomeJourneyControlPolicy.canDiscard(draft, in: .user(owner), hasProtectedSubmission: false))
        #expect(!HomeJourneyControlPolicy.canDiscard(draft, in: .user(UUID()), hasProtectedSubmission: false))
        #expect(!HomeJourneyControlPolicy.canDiscard(draft, in: .user(owner), hasProtectedSubmission: true))
    }

    @Test func draftIndexCountsAMakeOnlyOnceAndOmitsFinishedSessions() {
        let attempt = HomeAttemptRecord(name: "Tea")
        var workspace = HomeRecipeWorkspace(); workspace.attemptDrafts = [attempt]
        workspace.sessions = [HomePreparationSession(attempt: attempt), HomePreparationSession(attempt: .init(name: "Finished"), phase: .saved)]
        let items = HomeDraftIndex.items(in: workspace)
        #expect(items.count == 1)
        #expect(items.first?.attemptID == attempt.id)
    }

    @Test func confirmedPostDeletionRemovesItsPrivateCounterpartAcrossConflicts() throws {
        var workspace = HomeRecipeWorkspace()
        let visitID = UUID()
        let attempt = HomeAttemptRecord(name: "Published", publicationDraftID: visitID, publicationStatus: .published)
        workspace.attempts = [attempt]
        let stale = workspace
        workspace.removeConfirmedPublication(visitID)
        #expect(workspace.attempts.isEmpty)
        #expect(stale.reconciling(local: workspace).attempts.isEmpty)
        #expect(workspace.reconciling(local: stale).attempts.isEmpty)
    }

    @Test func namedHomeProfilesPersistPerAccountAndOnlyUseOwnedGear() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root); let owner = UUID()
        let owned = EquipmentProfile(ownerUserID: owner, nickname: "Kettle")
        let foreign = EquipmentProfile(ownerUserID: UUID(), nickname: "Other gear")
        _ = try shelf.upsert(owned, in: .user(owner))
        var profile = HomePlaceProfile(name: "  Kitchen counter  ", equipmentIDs: [owned.id, foreign.id])
        let saved = try shelf.upsertHomeProfile(profile, in: .user(owner))
        profile = try #require(saved.preferences?.homeProfiles?.first)
        #expect(profile.name == "Kitchen counter" && profile.ownerUserID == owner)
        var preferences = saved.preferences ?? HomeLibraryPreferences()
        preferences.defaultHomeProfileID = profile.id
        _ = try shelf.savePreferences(preferences, in: .user(owner))
        let reloaded = HomeLibraryStore(baseDirectory: root).load(in: .user(owner))
        #expect(reloaded.selectedHomeProfile(for: owner)?.name == "Kitchen counter")
        #expect(reloaded.defaults(for: owner).equipment.map(\.id) == [owned.id])
        #expect(shelf.load(in: .user(UUID())).preferences?.homeProfiles == nil)
        #expect(throws: (any Error).self) { try shelf.upsertHomeProfile(profile, in: .user(UUID())) }
    }

    @Test func removingAProfileLeavesHistoricalSipIdentityAndOldPreferencesReadable() throws {
        let old = try JSONDecoder().decode(HomeLibraryPreferences.self, from: Data("{\"defaultEquipmentIDs\":[]}".utf8))
        #expect(old.homeProfiles == nil && old.defaultHomeProfileID == nil)
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let shelf = HomeLibraryStore(baseDirectory: root)
        let profile = HomePlaceProfile(name: "My kitchen")
        _ = try shelf.upsertHomeProfile(profile, in: .guest)
        let sip = HomeAttemptRecord(name: "Latte", locationName: profile.name)
        _ = try shelf.removeHomeProfile(id: profile.id, in: .guest)
        #expect(shelf.load(in: .guest).preferences?.homeProfiles?.isEmpty == true)
        #expect(sip.journalLocationName == "My kitchen")
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("HomeJourneyControlTests-\(UUID())")
    }
}
