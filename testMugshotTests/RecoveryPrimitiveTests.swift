import Foundation
import Testing
import UIKit
@testable import testMugshot

struct RecoveryPrimitiveTests {
    @Test func durablePhotoStoreReturnsAfterAtomicJPEGIsReadable() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoCacheTests.\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = PhotoCache(photosDirectory: directory)
        let key = "durable-photo"
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }

        try cache.storeDurably(image, forKey: key)

        let fileURL = directory.appendingPathComponent("\(key).jpg")
        let persistedData = try Data(contentsOf: fileURL)
        #expect(!persistedData.isEmpty)
        #expect(UIImage(data: persistedData) != nil)
        #expect(cache.retrieve(forKey: key) != nil)
    }

    @Test func visitUpsertCollapsesDuplicateIDsAndRecalculatesMovedCafeStats() throws {
        let suiteName = "DataManagerVisitUpsertTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = DataManager(defaults: defaults)
        let firstCafe = Cafe(name: "First Cafe")
        let secondCafe = Cafe(name: "Second Cafe")
        let userID = UUID()
        let visitID = UUID()
        manager.addCafe(firstCafe)
        manager.addCafe(secondCafe)

        manager.addVisit(Visit(
            id: visitID,
            cafeId: firstCafe.id,
            userId: userID,
            drinkType: .coffee,
            overallScore: 2
        ))
        manager.addVisit(Visit(
            id: visitID,
            cafeId: firstCafe.id,
            userId: userID,
            drinkType: .coffee,
            overallScore: 4
        ))

        manager.upsertVisit(Visit(
            id: visitID,
            cafeId: secondCafe.id,
            userId: userID,
            drinkType: .coffee,
            overallScore: 5
        ))

        #expect(manager.appData.visits.count == 1)
        #expect(manager.appData.visits.first?.id == visitID)
        #expect(manager.appData.cafes.first { $0.id == firstCafe.id }?.visitCount == 0)
        #expect(manager.appData.cafes.first { $0.id == firstCafe.id }?.averageRating == 0)
        #expect(manager.appData.cafes.first { $0.id == secondCafe.id }?.visitCount == 1)
        #expect(manager.appData.cafes.first { $0.id == secondCafe.id }?.averageRating == 5)
    }

    @Test func visitUpsertDoesNotCountHomeMemoryAsCafeEvidence() throws {
        let suiteName = "DataManagerHomeVisitUpsertTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = DataManager(defaults: defaults)
        let homePlaceholder = Cafe(name: "Home")
        manager.addCafe(homePlaceholder)

        manager.upsertVisit(Visit(
            cafeId: homePlaceholder.id,
            userId: UUID(),
            drinkType: .coffee,
            context: .home,
            overallScore: 4.5
        ))

        #expect(manager.appData.visits.count == 1)
        #expect(manager.appData.cafes.first?.visitCount == 0)
        #expect(manager.appData.cafes.first?.averageRating == 0)
    }
}
