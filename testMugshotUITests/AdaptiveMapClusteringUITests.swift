import XCTest

final class AdaptiveMapClusteringUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAdaptiveMapKeepsPinsVisibleAndRevealsRatingsWhenClose() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-seed-adaptive-map"
        ]
        app.launch()

        let mapTab = app.buttons["mugshot.tab.map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        let map = app.otherElements["map.surface"]
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        let gestureSurface = app.otherElements["map.gestureSurface"]
        XCTAssertTrue(gestureSurface.waitForExistence(timeout: 3))

        let northBeachPin = element(
            "map.pin.00000000-0000-4000-8001-000000000001",
            in: app
        )
        XCTAssertTrue(
            northBeachPin.waitForExistence(timeout: 5),
            "The close fixture should show an individual cafe pin."
        )
        XCTAssertEqual(northBeachPin.value as? String, "Rating visible at this zoom")
        attachScreenshot(named: "06 After - Neighborhood rating pins")

        northBeachPin.tap()
        XCTAssertTrue(
            element("map.cafeDetail.sheet", in: app).waitForExistence(timeout: 5),
            "An individual cafe pin should keep the existing cafe navigation."
        )
        app.buttons["Close cafe card"].tap()
        XCTAssertTrue(map.waitForExistence(timeout: 3))

        gestureSurface.pinch(withScale: 0.18, velocity: -2)
        let cityPin = element(
            "map.pin.00000000-0000-4000-8001-000000000001",
            in: app
        )
        XCTAssertTrue(cityPin.waitForExistence(timeout: 6))
        let ratingHidden = NSPredicate(
            format: "value == %@",
            "Rating hidden at this zoom"
        )
        expectation(for: ratingHidden, evaluatedWith: cityPin)
        waitForExpectations(timeout: 6)
        attachScreenshot(named: "06b After - City travel pins")

        for _ in 0..<2 {
            gestureSurface.pinch(withScale: 0.18, velocity: -2)
        }
        let distantPin = element(
            "map.pin.00000000-0000-4000-8001-000000000001",
            in: app
        )
        XCTAssertTrue(
            distantPin.waitForExistence(timeout: 6),
            "The same cafe pin should remain represented after zooming far out."
        )
        expectation(for: ratingHidden, evaluatedWith: distantPin)
        waitForExpectations(timeout: 6)
        XCTAssertFalse(app.descendants(matching: .any)["map.place"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["map.cluster"].exists)
        attachScreenshot(named: "06c After - Persistent world pins")
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
