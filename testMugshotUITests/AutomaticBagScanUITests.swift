import XCTest

final class AutomaticBagScanUITests: XCTestCase {
    @MainActor
    private func launch(failure: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-coffee-assistance", "--ui-testing-auto-bag-scan"]
        if failure { app.launchArguments.append("--ui-testing-coffee-assistance-failure") }
        app.launch()
        app.buttons["home.bag.fixture.open"].tap()
        let enable = app.buttons["coffeeAssistance.enable"]
        for _ in 0..<4 where !enable.isHittable { app.swipeUp() }
        XCTAssertTrue(enable.waitForExistence(timeout: 5))
        enable.tap()
        return app
    }

    @MainActor
    func testLunaFillsTheActualBagEditorWithoutAnImproveOrReviewStep() {
        let app = launch()
        let message = app.staticTexts["home.bag.scan.status"]
        let filled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Luna read"), object: message)
        XCTAssertEqual(XCTWaiter.wait(for: [filled], timeout: 8), .completed)
        XCTAssertFalse(app.buttons["Improve this scan"].exists)
        XCTAssertFalse(app.buttons["coffeeAssistance.accept"].exists)
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["home.bag.fixture.savedOrigin"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["home.bag.fixture.savedOrigin"].label, "Colombia")
    }

    @MainActor
    func testFailedLunaReadFallsBackToTheOnDeviceScanner() {
        let app = launch(failure: true)
        let message = app.staticTexts["home.bag.scan.status"]
        let fallback = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Read on your iPhone"), object: message)
        XCTAssertEqual(XCTWaiter.wait(for: [fallback], timeout: 8), .completed)
        XCTAssertTrue(app.navigationBars.buttons["Save"].isEnabled)
    }
}
