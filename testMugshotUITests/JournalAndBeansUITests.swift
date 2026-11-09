import XCTest

final class JournalAndBeansUITests: XCTestCase {
    @MainActor
    private func launch(signedOut: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset"]
        if signedOut { app.launchArguments.append("--ui-testing-signed-out") }
        app.launch()
        return app
    }

    @MainActor
    func testJournalOpensAndReturnsWithoutTerminating() {
        let app = launch()
        let journal = app.buttons["mugshot.tab.journal"]
        XCTAssertTrue(journal.waitForExistence(timeout: 10))
        journal.tap()
        XCTAssertTrue(app.staticTexts["Keep exploring"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Archive"].exists)
        app.buttons["mugshot.tab.feed"].tap()
        journal.tap()
        XCTAssertTrue(app.staticTexts["Keep exploring"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCurrentHomeSetupOffersManualAndScannedBeans() {
        let app = launch(signedOut: true)
        app.buttons["mugshot.tab.add"].tap()
        app.buttons["logASipV3.context.home"].tap()
        app.buttons["logASipV4.home.starter.espresso"].tap()
        let adjust = app.buttons["home.setup.changeForThisBrew"]
        for _ in 0..<5 where !adjust.isHittable { app.swipeUp() }
        XCTAssertTrue(adjust.waitForExistence(timeout: 5))
        adjust.tap()
        let manual = app.buttons["home.today.beans.addManually"]
        for _ in 0..<4 where !manual.isHittable { app.swipeUp() }
        XCTAssertTrue(manual.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.today.beans.scan"].exists)
        XCTAssertTrue(manual.isEnabled)
        manual.tap()
        XCTAssertTrue(app.navigationBars["Add coffee"].waitForExistence(timeout: 5))
        app.buttons["More bag details"].tap()
        let roaster = app.textFields["logASipV3.home.bag.roaster"]
        roaster.tap()
        roaster.typeText("QA Roaster")
        let name = app.textFields["logASipV3.home.bag.name"]
        name.tap()
        name.typeText("Morning Beans")
        app.navigationBars.buttons["Save"].tap()
        let selected = app.buttons["home.today.beans.select"]
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.label.contains("QA Roaster · Morning Beans"))
        app.buttons["home.today.beans.scan"].tap()
        XCTAssertTrue(app.navigationBars["Add coffee"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.label.contains("QA Roaster · Morning Beans"))
        selected.tap()
        app.buttons["None"].tap()
        XCTAssertEqual(selected.label, "Choose beans")
        selected.tap()
        let savedBag = app.buttons["Morning Beans"].firstMatch
        XCTAssertTrue(savedBag.waitForExistence(timeout: 5))
        savedBag.tap()
        XCTAssertTrue(selected.label.contains("QA Roaster · Morning Beans"))
    }
}
