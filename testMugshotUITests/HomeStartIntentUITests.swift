import XCTest

final class HomeStartIntentUITests: XCTestCase {
    @MainActor private func launchHome() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion"]
        app.launch()
        app.buttons["mugshot.tab.add"].tap()
        app.buttons["logASipV3.context.home"].tap()
        return app
    }

    @MainActor func testAlreadyMadeOpensNameAndPhotosWithoutSelectingAPlan() {
        let app = launchHome()
        XCTAssertTrue(app.buttons["home.start.guidance"].waitForExistence(timeout: 5))
        let quick = app.buttons["logASipV3.primaryAction"]
        XCTAssertTrue(quick.label.contains("I already made it"))
        quick.tap()
        XCTAssertTrue(app.staticTexts["Quick log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["logASipV3.drinkName"].exists)
        XCTAssertTrue(app.staticTexts["Photos"].exists)
        XCTAssertFalse(app.buttons["home.makeWithGuidance"].exists)
    }

    @MainActor func testHelpMeMakeItOffersATeaStarterWithoutAShelf() {
        let app = launchHome()
        let help = app.buttons["home.start.guidance"]
        XCTAssertTrue(help.waitForExistence(timeout: 5)); help.tap()
        let tea = app.buttons["home.starter.tea"]
        XCTAssertTrue(tea.waitForExistence(timeout: 5)); tea.tap()
        let guide = app.buttons["home.makeWithGuidance"]
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        XCTAssertTrue(guide.isEnabled)
        guide.tap()
        let instruction = app.staticTexts["home.guidance.currentInstruction"]
        XCTAssertTrue(instruction.waitForExistence(timeout: 5))
        XCTAssertEqual(instruction.label, "Put a tea bag in your mug.")
    }
}
