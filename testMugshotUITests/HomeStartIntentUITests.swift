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

    @MainActor func testNamedHomeSipRatesAndSavesPrivatelyFromOneRatingScreen() {
        let app = launchHome()
        let drink = app.textFields["home.entry.name"]
        XCTAssertTrue(drink.waitForExistence(timeout: 5), "Home should start with the drink name or recipe.")
        drink.tap()
        drink.typeText("Cinnamon oat latte")
        let done = app.buttons["home.entry.keyboardDone"]
        if done.isHittable { done.tap() }
        let rate = app.buttons["home.entry.rate"]
        XCTAssertTrue(rate.isHittable)
        rate.tap()
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 5))
        let stars = app.descendants(matching: .any).matching(identifier: "logASipV3.sipScore").firstMatch
        XCTAssertTrue(stars.isHittable)
        stars.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        XCTAssertEqual(stars.value as? String, "4.0 out of 5")
        app.buttons["home.sip.savePrivate"].tap()
        XCTAssertTrue(app.staticTexts["Saved privately"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Cinnamon oat latte"].firstMatch.exists)
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
