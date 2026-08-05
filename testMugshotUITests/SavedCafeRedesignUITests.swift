import XCTest

final class SavedCafeRedesignUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSavedDetailAndMapHandoff() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--saved-audit-scenario=populated"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Harborlight Coffee Roasters"].waitForExistence(timeout: 4))
        attachScreenshot(named: "implementation-saved-favorites")

        let harborlightCard = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Harborlight Coffee Roasters")
        ).firstMatch
        XCTAssertTrue(harborlightCard.waitForExistence(timeout: 3))
        harborlightCard.tap()

        let detail = element("cafe.detail.sheet", in: app)
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Log a Sip"].waitForExistence(timeout: 3))
        attachScreenshot(named: "implementation-detail-medium")

        detail.swipeUp()
        XCTAssertTrue(app.staticTexts["Your Mugshot"].waitForExistence(timeout: 3))
        attachScreenshot(named: "implementation-detail-expanded")

        let close = app.buttons["Close cafe card"]
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        close.tap()

        let moreActions = app.buttons["More actions for Harborlight Coffee Roasters"]
        XCTAssertTrue(moreActions.waitForExistence(timeout: 3))
        moreActions.tap()
        let showOnMap = app.buttons["Show on Map"]
        XCTAssertTrue(showOnMap.waitForExistence(timeout: 3))
        showOnMap.tap()

        XCTAssertTrue(element("map.surface", in: app).waitForExistence(timeout: 6))
        XCTAssertTrue(element("map.cafeDetail.sheet", in: app).waitForExistence(timeout: 5))
        attachScreenshot(named: "implementation-map-compact-detail")
    }

    @MainActor
    func testSavedSearchCategoriesAndUndo() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--saved-audit-scenario=populated"
        ]
        app.launch()

        let wantToTry = element("saved.category.Want to Try", in: app)
        XCTAssertTrue(wantToTry.waitForExistence(timeout: 6))
        wantToTry.tap()
        XCTAssertTrue(app.staticTexts["Juniper & Stone"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Paper Moon Espresso"].exists)

        let search = app.textFields["saved.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("Cedar")
        XCTAssertTrue(app.staticTexts["Cedar Room"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Juniper & Stone"].exists)
        app.buttons["Clear search"].tap()

        let favorites = element("saved.category.Favorites", in: app)
        favorites.tap()
        let firstFavorited = app.buttons["Favorited"].firstMatch
        XCTAssertTrue(firstFavorited.waitForExistence(timeout: 3))
        firstFavorited.tap()
        XCTAssertTrue(app.staticTexts["Removed from Favorites"].waitForExistence(timeout: 3))
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        XCTAssertTrue(app.buttons["Favorited"].firstMatch.waitForExistence(timeout: 3))

        app.terminate()
        app.launchArguments = [
            "--ui-testing",
            "--saved-audit-scenario=populated"
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Harborlight Coffee Roasters"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Favorited"].firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testAccessibilityXXXLReflowsSavedAndDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--saved-audit-scenario=populated",
            "--ui-testing-accessibility-xxxl"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Log a Sip"].firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Favorited"].firstMatch.waitForExistence(timeout: 3))
        attachScreenshot(named: "implementation-saved-accessibility-xxxl")

        let harborlightCard = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Harborlight Coffee Roasters")
        ).firstMatch
        XCTAssertTrue(harborlightCard.waitForExistence(timeout: 3))
        harborlightCard.tap()
        XCTAssertTrue(element("cafe.detail.sheet", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Favorite"].exists || app.buttons["Favorited"].exists)
        attachScreenshot(named: "implementation-detail-accessibility-xxxl")
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
