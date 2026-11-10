import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import testMugshot

@MainActor
struct PocketSipCaptureTests {
    @Test func privateDraftAndOrderedPhotosSurviveAReopenedStoreAndReplayPreservesEdits() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let owner = PocketSipOwner(userID: UUID())
        let scope = LocalAccountScope.forUserID(owner.userID)
        let store = SipDraftStore(baseDirectory: root, protectedSubmissionIDs: { _ in [] })
        let photos = [try photo(.red), try photo(.blue)]
        let capture = PocketSipCapture(id: UUID(), date: .now, owner: owner, photos: photos)
        let imported = try store.importPocketSip(capture, in: scope)
        let draft = try #require(imported)
        #expect(draft.launchContext.source == .pocketSip && draft.visibility == .private)
        #expect(draft.drinkName.isEmpty && draft.cafe == nil && draft.overallScore == 0)
        let reopened = SipDraftStore(baseDirectory: root, protectedSubmissionIDs: { _ in [] })
        let read = try #require(reopened.load(id: draft.id, in: scope))
        #expect(read.images.count == 2)
        #expect(reopened.load(id: draft.id, in: .guest) == nil)
        #expect(reopened.load(id: draft.id, in: .user(UUID())) == nil)
        let folder = root.appendingPathComponent("v2/\(scope.storageComponent)/\(draft.id.uuidString.lowercased())")
        for (name, expected) in zip(draft.localPhotoNames, photos) {
            #expect(try Data(contentsOf: folder.appendingPathComponent(name)) == expected)
        }

        var edited = read.draft
        edited.drinkName = "Today's cup"
        _ = try reopened.save(edited, images: read.images, in: scope)
        #expect(try reopened.importPocketSip(capture, in: scope)?.drinkName == "Today's cup")
        #expect(reopened.allDrafts(in: scope).count == 1)
        reopened.remove(edited, in: scope)
        #expect(try reopened.importPocketSip(capture, in: scope) == nil)
        #expect(reopened.allDrafts(in: scope).isEmpty)
    }

    @Test func failedCommitKeepsOriginalHandoffAndRetryCommitsExactlyOnce() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let owner = PocketSipOwner(userID: UUID())
        let inbox = PocketSipInbox(directory: root.appendingPathComponent("inbox"))
        let store = SipDraftStore(baseDirectory: root.appendingPathComponent("app"))
        let scope = LocalAccountScope.forUserID(owner.userID)
        try inbox.activate(owner)
        let session = try #require(inbox.activeSession())
        let photos = [try photo(.red), try photo(.blue)]
        let capture = PocketSipCapture(id: UUID(), date: .now, owner: owner, photos: photos)
        try inbox.enqueue(capture, for: session)
        try inbox.enqueue(capture, for: session)
        #expect(try inbox.pendingIDs(for: owner) == [capture.id])
        #expect(throws: (any Error).self) {
            try inbox.consume(id: capture.id, for: owner) { _ in throw CocoaError(.fileWriteOutOfSpace) }
        }
        #expect(try inbox.pendingIDs(for: owner) == [capture.id])
        let relaunched = PocketSipInbox(directory: inbox.directory)
        try relaunched.consume(id: capture.id, for: owner) { packet in
            #expect(packet.photos == photos)
            _ = try store.importPocketSip(packet, in: scope)
        }
        #expect(try relaunched.pendingIDs(for: owner).isEmpty)
        #expect(store.allDrafts(in: scope).map(\.id) == [capture.id])
        #expect(store.load(id: capture.id, in: scope)?.images.count == 2)
    }

    @Test func staleShareAndForeignAccountCannotEnqueueOrConsumeAndPurgeIsScoped() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let inbox = PocketSipInbox(directory: root)
        let a = PocketSipOwner(userID: UUID())
        let b = PocketSipOwner(userID: UUID())
        let photos = [try photo(.red)]
        let first = PocketSipCapture(id: UUID(), date: .now, owner: a, photos: photos)
        let second = PocketSipCapture(id: UUID(), date: .now, owner: b, photos: photos)
        try inbox.activate(a)
        let sessionA = try #require(inbox.activeSession())
        try inbox.enqueue(first, for: sessionA)

        try inbox.activate(b)
        let sessionB = try #require(inbox.activeSession())
        try inbox.enqueue(second, for: sessionB)
        #expect(try inbox.pendingIDs(for: a).isEmpty)
        #expect(throws: PocketSipCaptureError.accountChanged) {
            try inbox.consume(id: first.id, for: a) { _ in Issue.record("Foreign bytes reached the consumer") }
        }
        try inbox.activate(a)
        #expect(throws: PocketSipCaptureError.accountChanged) { try inbox.enqueue(first, for: sessionA) }
        try inbox.purge(a)
        #expect(inbox.activeSession() == nil)
        try inbox.activate(a)
        #expect(try inbox.pendingIDs(for: a).isEmpty)
        try inbox.activate(b)
        #expect(try inbox.pendingIDs(for: b) == [second.id])
    }

    @Test func badSelectionsWriteNoDraftOrHandoff() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let owner = PocketSipOwner(userID: nil)
        let inbox = PocketSipInbox(directory: root.appendingPathComponent("inbox"))
        let store = SipDraftStore(baseDirectory: root.appendingPathComponent("app"))
        try inbox.activate(owner)
        let session = try #require(inbox.activeSession())
        let jpeg = try photo(.red)
        #expect(PocketSipPhoto.maximumCount == VisitPhotoUploadPlan.maxPhotoCount)
        for photos in [[], [jpeg, Data("broken".utf8)], Array(repeating: jpeg, count: PocketSipPhoto.maximumCount + 1)] {
            let capture = PocketSipCapture(id: UUID(), date: .now, owner: owner, photos: photos)
            #expect(throws: (any Error).self) { try inbox.enqueue(capture, for: session) }
            #expect(throws: (any Error).self) { try store.importPocketSip(capture, in: .guest) }
        }
        #expect(try inbox.pendingIDs(for: owner).isEmpty)
        #expect(store.allDrafts(in: .guest).isEmpty)
    }

    @Test func downsamplePreservesOrientationAndRemovesLocationMetadata() throws {
        let source = temporaryRoot().appendingPathExtension("jpg")
        defer { try? FileManager.default.removeItem(at: source) }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2_500, height: 100)).image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2_500, height: 100))
        }
        let cgImage = try #require(image.cgImage)
        let destination = try #require(CGImageDestinationCreateWithURL(
            source as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, cgImage, [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 37.0,
                kCGImagePropertyGPSLatitudeRef: "N"
            ]
        ] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))

        let normalized = try PocketSipPhoto.draftJPEG(at: source)
        try PocketSipPhoto.validate([normalized])
        let restored = try #require(UIImage(data: normalized))
        #expect(restored.size.height == 1_800)
        #expect(restored.size.width < restored.size.height)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func photo(_ color: UIColor) throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        return try #require(image.jpegData(compressionQuality: 0.8))
    }
}
