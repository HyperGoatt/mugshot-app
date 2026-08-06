import XCTest

final class DiscoveryMapUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testForYouCardListAndScopeSelectorKeepMapAsTheDiscoveryHome() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-seed-adaptive-map"
        ]
        app.launch()

        let mapTab = element("mugshot.tab.map", in: app)
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        let map = element("map.surface", in: app)
        let scope = element("map.discovery.scope", in: app)
        let card = element("map.forYou.card", in: app)
        let seeAll = element("map.forYou.seeAll", in: app)
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertTrue(seeAll.waitForExistence(timeout: 3))
        XCTAssertFalse(element("map.searchThisArea", in: app).exists)
        attachScreenshot(named: "Discovery - For You map")

        seeAll.tap()
        let list = element("map.forYou.list", in: app)
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["For You"].exists)
        attachScreenshot(named: "Discovery - For You picks")

        app.buttons["Done"].tap()
        XCTAssertTrue(map.waitForExistence(timeout: 3))
        XCTAssertTrue(card.waitForExistence(timeout: 3))

        scope.tap()
        let favorites = app.buttons["Favorites"]
        XCTAssertTrue(favorites.waitForExistence(timeout: 3))
        favorites.tap()
        XCTAssertTrue(app.staticTexts["Your ratings"].waitForExistence(timeout: 3))
        XCTAssertFalse(element("map.forYou.card", in: app).exists)

        element("map.discovery.scope", in: app).tap()
        let all = app.buttons["All"]
        XCTAssertTrue(all.waitForExistence(timeout: 3))
        all.tap()
        XCTAssertTrue(app.staticTexts["Your ratings"].waitForExistence(timeout: 3))
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
