import XCTest

final class CafeNextSipUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSavedRepeatOpensAnEditableDraftAndResumesAfterRelaunch() throws {
        let app = XCUIApplication()
        launch(app, reset: true)
        openSavedCafe("Harborlight Coffee Roasters", in: app)
        let repeatAction = app.buttons["cafe.nextSip.repeat"]
        XCTAssertTrue(repeatAction.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cafe.nextSip.original"].label.contains("Oat milk, half sweet"))
        repeatAction.tap()

        let drink = app.textFields["logASipV3.drinkName"]
        XCTAssertTrue(drink.waitForExistence(timeout: 5))
        XCTAssertEqual(drink.value as? String, "Honey oat cortado")
        XCTAssertTrue(app.staticTexts["Harborlight Coffee Roasters"].exists)
        XCTAssertFalse(element("logASipV3.photos.thumbnail.0", in: app).exists)
        let orderDetails = app.textFields["logASipV3.orderNotes"]
        XCTAssertEqual(orderDetails.value as? String, "Oat milk, half sweet")
        orderDetails.tap()
        orderDetails.typeText(", warm")
        XCTAssertEqual(orderDetails.value as? String, "Oat milk, half sweet, warm")

        app.terminate()
        launch(app, reset: false)
        app.buttons["mugshot.tab.add"].tap()
        let resume = app.buttons["logASipV3.resumeDraft"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        let draft = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "home.drafts.resume."
        )).firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 4))
        XCTAssertTrue(draft.label.contains("Honey oat cortado"))
        draft.tap()
        XCTAssertTrue(drink.waitForExistence(timeout: 5))
        XCTAssertEqual(drink.value as? String, "Honey oat cortado")
        XCTAssertEqual(orderDetails.value as? String, "Oat milk, half sweet, warm")
    }

    @MainActor
    func testFirstVisitAndDeclinedOrderOfferAFreshSip() throws {
        let app = XCUIApplication()
        launch(app, reset: true)

        openSavedCafe("Juniper & Stone", in: app)
        XCTAssertTrue(app.staticTexts["A fresh sip"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["cafe.nextSip.repeat"].exists)
        app.buttons["cafe.detail.back"].tap()

        openSavedCafe("Paper Moon Espresso", in: app)
        XCTAssertTrue(app.buttons["cafe.nextSip.original"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["You’d try a different order"].exists)
        XCTAssertFalse(app.buttons["cafe.nextSip.repeat"].exists)
    }

    @MainActor
    func testPocketSipCancelReturnsToAddWithoutADraft() {
        let app = XCUIApplication()
        launch(app, reset: true)
        app.buttons["mugshot.tab.add"].tap()
        let pocket = app.buttons["pocketSip.entry"]
        XCTAssertTrue(pocket.waitForExistence(timeout: 5))
        pocket.tap()
        XCTAssertTrue(app.buttons["pocketSip.choose"].waitForExistence(timeout: 5))
        app.buttons["pocketSip.close"].tap()
        XCTAssertTrue(pocket.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["logASipV3.resumeDraft"].exists)
    }

    @MainActor
    private func launch(_ app: XCUIApplication, reset: Bool) {
        app.launchArguments = ["--ui-testing", "--saved-audit-scenario=populated"]
        if reset { app.launchArguments.append("--ui-testing-reset") }
        app.launch()
    }

    @MainActor
    private func openSavedCafe(_ name: String, in app: XCUIApplication) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(element("cafe.detail.name", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
