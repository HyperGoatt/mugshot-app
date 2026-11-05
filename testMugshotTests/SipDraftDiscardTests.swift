import Foundation
import Testing
@testable import testMugshot

struct SipDraftDiscardTests {
    @Test func confirmedDiscardSurvivesRelaunchAndRejectsLateAutosave() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SipDraftStore(baseDirectory: root, protectedSubmissionIDs: { _ in [] })
        let draft = SipDraft(context: .home, drinkName: "Oat latte")
        _ = try store.save(draft, images: [], in: .guest)
        try store.discard(draft, in: .guest)
        try store.discard(draft, in: .guest)
        let restored = SipDraftStore(baseDirectory: root, protectedSubmissionIDs: { _ in [] })
        #expect(restored.load(id: draft.id, in: .guest) == nil)
        #expect(restored.allDrafts(in: .guest).isEmpty)
        #expect(throws: (any Error).self) { try restored.save(draft, images: [], in: .guest) }
    }

    @Test func protectedForeignAndUnreadableOutboxCannotDiscardDrafts() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let owner = UUID()
        let draft = SipDraft(ownerUserID: owner, context: .home, drinkName: "Filter coffee")
        let protected = SipDraftStore(baseDirectory: root, protectedSubmissionIDs: { _ in [draft.id] })
        _ = try protected.save(draft, images: [], in: .user(owner))
        #expect(throws: (any Error).self) { try protected.discard(draft, in: .user(owner)) }
        #expect(throws: (any Error).self) { try protected.discard(draft, in: .user(UUID())) }
        let unavailable = SipDraftStore(baseDirectory: root, protectedSubmissionIDs: { _ in throw CocoaError(.fileReadCorruptFile) })
        #expect(throws: (any Error).self) { try unavailable.discard(draft, in: .user(owner)) }
        #expect(unavailable.load(id: draft.id, in: .user(owner)) != nil)
    }

    @Test func latestProtectedStateWinsOverStalePickerSnapshot() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SipDraftStore(baseDirectory: root, protectedSubmissionIDs: { _ in [] })
        let stale = SipDraft(context: .home, drinkName: "Tea")
        _ = try store.save(stale, images: [], in: .guest)
        var latest = stale; latest.uploadState = .prepared
        _ = try store.save(latest, images: [], in: .guest)
        #expect(throws: (any Error).self) { try store.discard(stale, in: .guest) }
        #expect(store.load(id: stale.id, in: .guest)?.draft.uploadState == .prepared)
    }

    @Test func corruptDiscardReceiptIsReportedWithoutRemovingUnrelatedDraftBytes() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SipDraftStore(baseDirectory: root, protectedSubmissionIDs: { _ in [] })
        let draft = SipDraft(context: .home, drinkName: "Matcha")
        _ = try store.save(draft, images: [], in: .guest)
        let metadata = root.appendingPathComponent("v2/guest/\(draft.id.uuidString.lowercased())/draft.json")
        let before = try Data(contentsOf: metadata)
        let receipt = root.appendingPathComponent("v2/guest/discarded-drafts-v1.json")
        try Data("invalid".utf8).write(to: receipt)
        #expect(!store.readReport(in: .guest).isComplete)
        #expect(throws: (any Error).self) { try store.discard(draft, in: .guest) }
        #expect(try Data(contentsOf: metadata) == before)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("SipDraftDiscardTests-\(UUID())")
    }
}
