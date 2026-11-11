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
        capture("01-home-entry", in: app)
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
        capture("02-home-rating", in: app)
        app.buttons["home.sip.savePrivate"].tap()
        XCTAssertTrue(app.staticTexts["Saved privately"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Saved to Journal"].exists)
        XCTAssertTrue(app.staticTexts["Cinnamon oat latte"].firstMatch.exists)
        capture("03-private-journal-receipt", in: app)
        app.buttons["home.sip.share"].tap()
        XCTAssertTrue(app.staticTexts["Share your sip"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Audience"].exists)
        capture("04-optional-sharing", in: app)
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

    @MainActor func testSaveAndMakeFromHomeOpensFirstImportedInstruction() {
        let app = launchHome()
        app.buttons["home.entry.saveRecipe"].tap()
        app.buttons["home.recipe.caption"].tap()
        let caption = app.descendants(matching: .any)["home.recipe.sourceText"].firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 5)); caption.tap()
        caption.typeText("Ingredients:\n2 g tea\n100 ml water\nSteps:\nSteep for three minutes.")
        app.buttons["home.recipe.keyboardDone"].tap()
        let name = app.textFields["home.recipe.name"]
        let form = app.scrollViews["home.recipe.captureScroll"]
        for _ in 0..<5 where !name.isHittable { form.swipeDown(velocity: .slow) }
        for _ in 0..<5 where !name.isHittable { form.swipeUp(velocity: .slow) }
        XCTAssertTrue(name.isHittable)
        name.tap(); name.typeText("Jasmine tea")
        app.buttons["home.recipe.keyboardDone"].tap()
        let make = app.buttons["home.recipe.saveAndMake"]
        XCTAssertTrue(make.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.recipe.editSource"].exists)
        capture("05-captured-recipe-save-and-make", in: app)
        make.tap()
        let instruction = app.staticTexts["home.guidance.currentInstruction"]
        XCTAssertTrue(instruction.waitForExistence(timeout: 8))
        XCTAssertEqual(instruction.label, "Steep for three minutes.")
        capture("06-saved-recipe-first-instruction", in: app)
        app.buttons["logASipV3.primaryAction"].tap()
        XCTAssertTrue(app.buttons["home.sip.savePrivate"].waitForExistence(timeout: 6))
        app.buttons["home.sip.savePrivate"].tap()
        XCTAssertTrue(app.staticTexts["Saved to Journal"].waitForExistence(timeout: 8))
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
