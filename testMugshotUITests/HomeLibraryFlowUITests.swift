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
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 5))
        app.buttons["logASipV3.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Review your sip"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRecipeDiscoveryCanSaveAnIdeaWithoutStartingASip() {
        let app = launch()
        app.buttons["mugshot.tab.saved"].tap()
        app.buttons["home.library.entry"].tap()
        app.buttons["Find your next recipe"].tap()
        app.buttons["Save a recipe you found"].tap()
        let name = app.textFields["home.recipe.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Evening matcha idea")
        let source = app.textFields["Paste a website or social link"]
        source.tap(); source.typeText("https://example.org/tea")
        app.buttons["home.recipe.saveIdea"].tap()
        XCTAssertTrue(app.buttons["Add preparation details"].waitForExistence(timeout: 6))
        XCTAssertFalse(app.textFields["logASipV3.drinkName"].exists)
    }

    @MainActor
    func testSavedRecipeOpensDetailsBeforeStartingASip() {
        let app = launch()
        app.buttons["mugshot.tab.saved"].tap()
        app.buttons["home.library.entry"].tap()
        app.buttons["home.library.addRecipe"].tap()
        let name = app.textFields["home.recipe.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Evening tea idea")
        app.buttons["home.recipe.saveIdea"].tap()
        XCTAssertTrue(app.buttons["Add preparation details"].waitForExistence(timeout: 6))
        XCTAssertFalse(app.textFields["logASipV3.drinkName"].exists)
    }

    @MainActor
    func testCaptionRecipeCanGoFromLibraryThroughGuidanceToSharedReviewWithoutAI() {
        let app = launch()
        app.buttons["mugshot.tab.saved"].tap(); app.buttons["home.library.entry"].tap()
        app.buttons["home.library.addRecipe"].tap()
        let name = app.textFields["home.recipe.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Guided tea")
        app.buttons["home.recipe.caption"].tap()
        let caption = app.textViews["home.recipe.sourceText"].exists ? app.textViews["home.recipe.sourceText"] : app.textFields["home.recipe.sourceText"]
        caption.tap(); caption.typeText("Ingredients:\n2 g tea\n100 ml water\nSteps:\nStir with water.")
        app.buttons["home.recipe.keyboardDone"].tap()
        let extracted = app.staticTexts["home.recipe.extractedCount"]
        for _ in 0..<3 where !extracted.isHittable { app.swipeUp() }
        XCTAssertTrue(extracted.waitForExistence(timeout: 5), "Pasting recipe instructions must fill the draft without a separate copy prompt.")
        XCTAssertFalse(app.switches["home.recipe.allowInstructions"].exists)
        clearNotificationBanner()
        app.buttons["home.recipe.saveIdea"].tap()
        XCTAssertTrue(app.buttons["home.recipe.saveIdea"].waitForNonExistence(timeout: 6))
        let make = app.buttons["home.recipe.make"]
        XCTAssertTrue(make.waitForExistence(timeout: 5)); make.tap()
        let guidance = app.buttons["home.makeWithGuidance"]
        if guidance.waitForExistence(timeout: 5) { guidance.tap() }
        XCTAssertTrue(app.staticTexts["Make"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Today’s target"].exists, "Instructions without planned measurements must not show an empty target card.")
        capture("Guidance", in: app)
        for _ in 0..<8 where !app.staticTexts["How did it go?"].exists {
            app.buttons["logASipV3.primaryAction"].tap()
        }
        XCTAssertTrue(app.staticTexts["How did it go?"].waitForExistence(timeout: 4))
        app.buttons["logASipV3.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Capture your sip"].waitForExistence(timeout: 4))
        app.buttons["logASipV3.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 4))
        let score = app.descendants(matching: .any).matching(identifier: "logASipV3.sipScore").firstMatch
        for _ in 0..<3 where !score.isHittable { app.swipeUp() }
        XCTAssertTrue(score.waitForExistence(timeout: 4))
        score.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        XCTAssertEqual(score.value as? String, "4.0 out of 5")
        capture("Rating", in: app)
        app.buttons["logASipV3.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Review your sip"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Save to journal"].exists)
        capture("Review", in: app)
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        clearNotificationBanner()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Home recipe \(name)"; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    private func clearNotificationBanner() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.descendants(matching: .any).matching(identifier: "NotificationShortLookView").firstMatch
        if banner.exists { banner.swipeUp() }
        XCTAssertTrue(banner.waitForNonExistence(timeout: 12), "A system notification must clear before a toolbar tap or screenshot.")
    }
}
