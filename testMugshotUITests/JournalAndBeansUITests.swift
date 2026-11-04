import XCTest

final class JournalAndBeansUITests: XCTestCase {
    @MainActor
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset"]
        app.launch()
        return app
    }

    @MainActor
    func testJournalOpensAndRecipeBookReturnsWithoutTerminating() {
        let app = launch()
        let journal = app.buttons["mugshot.tab.journal"]
        XCTAssertTrue(journal.waitForExistence(timeout: 10))
        journal.tap()
        let book = app.buttons["Recipe Book"].firstMatch
        for _ in 0..<6 where !book.isHittable { app.swipeUp() }
        XCTAssertTrue(book.waitForExistence(timeout: 5))
        book.tap()
        XCTAssertTrue(app.navigationBars["Recipe Book"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Journal"].firstMatch.tap()
        XCTAssertTrue(app.buttons["mugshot.tab.feed"].exists)
        app.buttons["mugshot.tab.feed"].tap()
        journal.tap()
        XCTAssertTrue(app.staticTexts["Keep exploring"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCurrentHomeSetupOffersManualAndScannedBeans() {
        let app = launch()
        app.buttons["mugshot.tab.add"].tap()
        app.buttons["logASipV3.context.home"].tap()
        app.buttons["Espresso"].firstMatch.tap()
        let adjust = app.buttons["Adjust today’s setup"]
        for _ in 0..<5 where !adjust.isHittable { app.swipeUp() }
        XCTAssertTrue(adjust.waitForExistence(timeout: 5))
        adjust.tap()
        let beans = app.buttons["Beans, gear, and more"].firstMatch
        for _ in 0..<5 where !beans.isHittable { app.swipeUp() }
        beans.tap()
        let manual = app.buttons["home.today.beans.addManually"]
        for _ in 0..<4 where !manual.isHittable { app.swipeUp() }
        XCTAssertTrue(manual.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.today.beans.scan"].exists)
    }
}
