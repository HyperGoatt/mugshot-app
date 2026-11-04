import XCTest

final class HomeLibraryFlowUITests: XCTestCase {
    @MainActor
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out"]
        app.launch()
        return app
    }

    @MainActor
    func testSavedHasStandaloneBeansAndGear() {
        let app = launch()
        app.buttons["mugshot.tab.saved"].tap()
        let library = app.buttons["home.library.entry"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        library.tap()
        app.buttons["home.library.beans"].tap()
        app.buttons["home.library.addBag"].tap()
        let name = app.textFields["logASipV3.home.bag.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Sunrise beans")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sunrise beans")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["home.library.gear"].tap()
        app.buttons["home.library.addGear"].tap()
        let nickname = app.textFields["Nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        nickname.tap(); nickname.typeText("Kitchen kettle")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Kitchen kettle")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["home.library.close"].tap()
        XCTAssertTrue(app.buttons["mugshot.tab.saved"].exists)
        XCTAssertFalse(app.textFields["logASipV3.drinkName"].exists)
    }

    @MainActor
    func testHomeQuickPathUsesSharedRatingAndReview() {
        let app = launch()
        app.buttons["mugshot.tab.add"].tap()
        app.buttons["logASipV3.context.home"].tap()
        app.buttons["logASipV4.home.starter.espresso"].tap()
        app.buttons["logASipV3.primaryAction"].tap()
        let name = app.textFields["logASipV3.drinkName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        app.buttons["logASipV3.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Sip reflection"].waitForExistence(timeout: 5))
        app.buttons["logASipV3.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Review your sip"].waitForExistence(timeout: 5))
    }
}
