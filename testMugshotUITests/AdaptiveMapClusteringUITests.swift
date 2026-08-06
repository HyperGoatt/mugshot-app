import XCTest

final class AdaptiveMapClusteringUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAdaptiveMapMovesFromPinsToClustersAndNamedPlaces() throws {
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
            "The close city-scale fixture should preserve individual cafe scores."
        )
        attachScreenshot(named: "06 After - Map individual scores")

        northBeachPin.tap()
        XCTAssertTrue(
            element("map.cafeDetail.sheet", in: app).waitForExistence(timeout: 5),
            "An individual cafe pin should keep the existing cafe navigation."
        )
        app.buttons["Close cafe card"].tap()
        XCTAssertTrue(map.waitForExistence(timeout: 3))

        gestureSurface.pinch(withScale: 0.2, velocity: -2)
        let namedPlace = app.descendants(matching: .button).matching(
            NSPredicate(
                format: "identifier == %@ AND (label BEGINSWITH %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@)",
                "map.place",
                "San Francisco",
                "Oakland",
                "Berkeley",
                "Sacramento"
            )
        ).firstMatch
        XCTAssertTrue(
            namedPlace.waitForExistence(timeout: 6),
            "Zooming out should replace pin-level detail with named place aggregates."
        )
        let regionalCluster = app.descendants(matching: .button).matching(
            NSPredicate(
                format: "identifier == %@ AND label BEGINSWITH %@",
                "map.cluster",
                "Across "
            )
        ).firstMatch
        XCTAssertTrue(regionalCluster.waitForExistence(timeout: 3))
        attachScreenshot(named: "06b After - Map named places")

        regionalCluster.tap()
        XCTAssertTrue(namedPlace.waitForNonExistence(timeout: 6))
        let cafeCluster = app.descendants(matching: .button).matching(
            NSPredicate(
                format: "identifier == %@ AND NOT label BEGINSWITH %@",
                "map.cluster",
                "Across "
            )
        ).firstMatch
        XCTAssertTrue(
            cafeCluster.waitForExistence(timeout: 6),
            "Tapping the regional cluster should reveal cafe-level clusters."
        )
        attachScreenshot(named: "06c After - Map cafe clusters")

        cafeCluster.tap()
        let revealedPin = app.descendants(matching: .button).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "map.pin.")
        ).firstMatch
        XCTAssertTrue(
            revealedPin.waitForExistence(timeout: 6),
            "Tapping a cafe cluster should reveal individual cafe scores."
        )
        attachScreenshot(named: "06d After - Map revealed cafes")
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
