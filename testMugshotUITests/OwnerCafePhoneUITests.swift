import XCTest

/// Opt-in hardware check of the installed build. No fixture flags or account mutations.
final class OwnerCafePhoneUITests: XCTestCase {
    @MainActor
    func testInstalledCafeDetailOpensFromMapPinAndSaved() throws {
        guard ProcessInfo.processInfo.environment["MUGSHOT_OWNER_PHONE_QA"] == "1" else {
            throw XCTSkip("Requires explicit owner-promoted physical-device execution.")
        }
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "co.mugshot.app.dev")
        app.activate()

        let map = app.buttons["mugshot.tab.map"]
        XCTAssertTrue(map.waitForExistence(timeout: 8))
        map.tap()
        let pins = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "map.pin.")
        )
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 10), "The Map needs an existing cafe pin.")
        let pin = try XCTUnwrap(pins.allElementsBoundByIndex.first(where: \.isHittable))
        let pinID = pin.identifier
        for _ in 0..<2 {
            let mapPin = pins.matching(identifier: pinID).firstMatch
            XCTAssertTrue(mapPin.waitForExistence(timeout: 5))
            mapPin.tap()
            assertCafeOpensAndReturns(to: "Map", in: app)
        }

        app.buttons["mugshot.tab.saved"].tap()
        let savedCafes = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
            "saved.cafe.card.", "saved.cafe.row."
        ))
        XCTAssertTrue(savedCafes.firstMatch.waitForExistence(timeout: 10), "Saved needs an existing cafe.")
        let saved = try XCTUnwrap(savedCafes.allElementsBoundByIndex.first(where: \.isHittable))
        saved.tap()
        assertCafeOpensAndReturns(to: "Saved", in: app)
        XCTAssertTrue(savedCafes.firstMatch.exists)
    }

    @MainActor
    private func assertCafeOpensAndReturns(to source: String, in app: XCUIApplication) {
        let name = app.staticTexts["cafe.detail.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 6), "Tapping a cafe from \(source) should show its details.")
        XCTAssertFalse(name.label.isEmpty)
        let back = app.buttons["cafe.detail.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        XCTAssertEqual(back.label, "Back to \(source)")
        back.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }
}
