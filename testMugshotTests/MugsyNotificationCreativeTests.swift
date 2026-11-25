import Foundation
import XCTest
@testable import testMugshot

final class MugsyNotificationCreativeTests: XCTestCase {
    func testBundledRegistryHasReviewedCopyAndValidNativePoses() throws {
        let catalog = try XCTUnwrap(MugsyNotificationCopyCatalog.load())
        XCTAssertEqual(catalog.templates.count, 32)
        XCTAssertEqual(catalog.version, 1)
        XCTAssertEqual(catalog.locale, "en")
        for template in catalog.templates {
            let pose = try XCTUnwrap(MugsyCatalogPose(rawValue: template.pose))
            XCTAssertEqual(pose.assetName, template.asset)
            XCTAssertTrue(MugsyNotificationAttachmentPolicy.allowedAssets.contains(template.asset))
        }
        XCTAssertTrue(catalog.templates.contains(MugsyNotificationCopyCatalog.previewSecondMemory))
    }

    func testExtensionContainsOnlyApprovedArtworkResources() throws {
        let plugins = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
        let bundle = try XCTUnwrap(Bundle(url: plugins.appendingPathComponent("MugshotNotificationService.appex")))
        let extensionInfo = try XCTUnwrap(bundle.infoDictionary?["NSExtension"] as? [String: Any])
        XCTAssertEqual(extensionInfo["NSExtensionPointIdentifier"] as? String, "com.apple.usernotifications.service")
        for asset in MugsyNotificationAttachmentPolicy.allowedAssets {
            let file = try XCTUnwrap(bundle.url(forResource: asset, withExtension: "png"))
            XCTAssertEqual(Array(try Data(contentsOf: file).prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        }
    }

    func testCopyRequiresTruthAndStopsWhenRecentVariantsAreExhausted() throws {
        let catalog = try XCTUnwrap(MugsyNotificationCopyCatalog.load())
        let now = Date(timeIntervalSince1970: 1_795_608_000)
        let recent = catalog.templates.filter { $0.family == .repeatMemory }.map {
            MugsyNotificationCopyUse(templateID: $0.id, usedAt: now.addingTimeInterval(-86400))
        }
        XCTAssertNil(catalog.select(family: .repeatMemory, facts: [], recentUses: [], now: now, rotationKey: "fixture"))
        XCTAssertNil(catalog.select(family: .repeatMemory, facts: ["repeat_available"], recentUses: recent, now: now, rotationKey: "fixture"))
        XCTAssertNotNil(catalog.select(family: .repeatMemory, facts: ["repeat_available"], recentUses: [], now: now, rotationKey: "fixture"))
    }

    func testExpiryAndProcessingCallCompletionOnce() {
        var values: [String] = []
        let completion = MugsyNotificationCompletionGate(fallback: "original") { values.append($0) }
        XCTAssertTrue(completion.finish())
        XCTAssertFalse(completion.finish("artwork"))
        XCTAssertEqual(values, ["original"])
    }
}
