import XCTest

final class AdaptiveMapClusteringUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAdaptiveMapMovesFromClustersToPinsAndNamedPlaces() throws {
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

        let mediumCluster = element("map.cluster", in: app)
        XCTAssertTrue(
            mediumCluster.waitForExistence(timeout: 5),
            "The city-scale fixture should consolidate overlapping cafes."
        )
        attachScreenshot(named: "06 After - Map aggregate")

        let northBeachPin = element(
            "map.pin.00000000-0000-4000-8001-000000000001",
            in: app
        )
        XCTAssertTrue(northBeachPin.waitForExistence(timeout: 3))
        northBeachPin.tap()
        XCTAssertTrue(
            element("map.cafeDetail.sheet", in: app).waitForExistence(timeout: 5),
            "An individual cafe pin should keep the existing cafe navigation."
        )
        app.buttons["Close cafe card"].tap()
        XCTAssertTrue(map.waitForExistence(timeout: 3))

        mediumCluster.tap()
        let cafePin = element(
            "map.pin.00000000-0000-4000-8001-000000000005",
            in: app
        )
        XCTAssertTrue(
            cafePin.waitForExistence(timeout: 5),
            "Tapping a cluster should reveal the existing cafe pins."
        )
        attachScreenshot(named: "06b After - Map individual cafes")

        gestureSurface.pinch(withScale: 0.25, velocity: -2)
        gestureSurface.pinch(withScale: 0.25, velocity: -2)
        gestureSurface.pinch(withScale: 0.25, velocity: -2)
        let place = element("map.place", in: app)
        XCTAssertTrue(
            place.waitForExistence(timeout: 6),
            "A far camera should replace pin-level detail with named place aggregates."
        )
        XCTAssertTrue(
            ["San Francisco", "Oakland", "Berkeley", "Sacramento"].contains {
                place.label.contains($0)
            },
            "Far aggregates should communicate a real place name."
        )
        XCTAssertTrue(place.label.contains("cafe"))
        let regionalCluster = app.descendants(matching: .button).matching(
            NSPredicate(
                format: "identifier == %@ AND label BEGINSWITH %@",
                "map.cluster",
                "Across "
            )
        ).firstMatch
        XCTAssertTrue(regionalCluster.waitForExistence(timeout: 3))
        attachScreenshot(named: "06c After - Map named places")

        regionalCluster.tap()
        let revealedCluster = element("map.cluster", in: app)
        let revealedPin = app.descendants(matching: .button).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "map.pin.")
        ).firstMatch
        XCTAssertTrue(
            revealedCluster.waitForExistence(timeout: 6) || revealedPin.waitForExistence(timeout: 1),
            "Tapping a place should zoom back toward its cafes."
        )
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
