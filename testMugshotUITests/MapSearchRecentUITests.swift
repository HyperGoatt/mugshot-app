import XCTest

final class MapSearchRecentUITests: XCTestCase {
    private enum Identifier {
        static let addTab = "mugshot.tab.add"
        static let mapTab = "mugshot.tab.map"
        static let drinkName = "logASipV3.drinkName"
        static let cafeSelector = "logASipV3.cafe.selector"
        static let cafeSearchSheet = "logASipV3.cafeSearch.sheet"
        static let cafeSearchRecent =
            "logASipV3.cafeSearch.recent.Mugshot Test Cafe|1 Test Street, Charleston, SC"
        static let seededPhoto = "logASipV3.photos.thumbnail.0"
        static let mapSearchQuery = "map.search.query"
        static let mapSearchCancel = "map.search.cancel"
        static let mapSearchResults = "map.search.results"
        static let mapSearchRecent =
            "map.search.recent.Mugshot Test Cafe|1 Test Street, Charleston, SC"
        static let mapCafeCard = "map.cafeDetail.sheet"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLogASipRecentSelectsCafeInOneTapWithoutLosingSetup() throws {
        let app = launch(seedPhoto: true)

        element(Identifier.addTab, in: app).tap()
        type("Iced latte", into: Identifier.drinkName, in: app)

        let cafeSelector = element(Identifier.cafeSelector, in: app)
        reveal(cafeSelector, in: app)
        cafeSelector.tap()

        let searchSheet = element(Identifier.cafeSearchSheet, in: app)
        XCTAssertTrue(searchSheet.waitForExistence(timeout: 3))
        let recent = element(Identifier.cafeSearchRecent, in: app)
        XCTAssertTrue(recent.waitForExistence(timeout: 3))

        recent.tap()

        XCTAssertTrue(cafeSelector.waitForExistence(timeout: 3))
        XCTAssertEqual(cafeSelector.value as? String, "Mugshot Test Cafe")
        XCTAssertTrue(waitForAbsence(of: searchSheet), "One recent tap should dismiss Choose a cafe.")
        XCTAssertEqual(
            (element(Identifier.drinkName, in: app).value as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            "Iced latte"
        )
        XCTAssertTrue(element(Identifier.seededPhoto, in: app).exists)
    }

    @MainActor
    func testMapRecentOpensCafeCardInOneTapAndRestoresMapBackground() throws {
        let app = launch(seedPhoto: false)

        element(Identifier.mapTab, in: app).tap()
        let searchField = element(Identifier.mapSearchQuery, in: app)
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()

        let searchResults = element(Identifier.mapSearchResults, in: app)
        XCTAssertTrue(searchResults.waitForExistence(timeout: 3))
        let recent = element(Identifier.mapSearchRecent, in: app)
        XCTAssertTrue(recent.waitForExistence(timeout: 3))

        recent.tap()

        let cafeCard = element(Identifier.mapCafeCard, in: app)
        XCTAssertTrue(cafeCard.waitForExistence(timeout: 3), "One recent tap should open the cafe card.")
        XCTAssertTrue(app.staticTexts["Mugshot Test Cafe"].exists)
        XCTAssertTrue(
            waitForAbsence(of: searchResults),
            "The search results should leave the background when the cafe card opens."
        )
        XCTAssertTrue(
            waitForAbsence(of: element(Identifier.mapSearchCancel, in: app)),
            "Cancel should leave with the active search interface."
        )
        XCTAssertTrue(
            waitForAbsence(of: searchField),
            "The search field should leave so the cafe card sits over only the map."
        )
        XCTAssertFalse(app.staticTexts["Recent"].exists)

        let closeCafeCard = app.buttons["Close cafe card"]
        XCTAssertTrue(closeCafeCard.waitForExistence(timeout: 3))
        closeCafeCard.tap()
        XCTAssertTrue(
            element(Identifier.mapSearchQuery, in: app).waitForExistence(timeout: 3),
            "Closing the cafe card should restore Map discovery controls."
        )
    }

    @MainActor
    private func launch(seedPhoto: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-seed-map-search-recent"
        ] + (seedPhoto ? ["--ui-testing-seed-photo"] : [])
        app.launch()
        XCTAssertTrue(element(Identifier.addTab, in: app).waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func type(_ value: String, into identifier: String, in app: XCUIApplication) {
        let field = element(identifier, in: app)
        reveal(field, in: app)
        field.tap()
        field.typeText(value)
    }

    @MainActor
    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 10
    ) {
        var swipes = 0
        while swipes < maximumSwipes, !element.isHittable {
            app.scrollViews.firstMatch.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(
            element.waitForExistence(timeout: 3) && element.isHittable,
            "Expected \(element) to become visible and tappable."
        )
    }

    @MainActor
    private func waitForAbsence(of element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
