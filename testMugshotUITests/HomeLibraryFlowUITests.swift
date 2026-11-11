import XCTest

final class HomeLibraryFlowUITests: XCTestCase {
    @MainActor
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion"]
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
        XCTAssertEqual(name.value as? String, "Sunrise beans")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sunrise beans")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["home.library.gear"].tap()
        app.buttons["home.library.addGear"].tap()
        let nickname = app.textFields["Nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        nickname.tap(); nickname.typeText("Kitchen kettle")
        XCTAssertEqual(nickname.value as? String, "Kitchen kettle", "Gear identity must retain the complete typed nickname.")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Kitchen kettle")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["home.library.close"].tap()
        XCTAssertTrue(app.buttons["mugshot.tab.saved"].exists)
        XCTAssertFalse(app.textFields["logASipV3.drinkName"].exists)
    }

    @MainActor
    func testRecipeLogAMakeOpensPrefilledRatingAndPrivateSave() {
        let app = launch()
        app.buttons["mugshot.tab.saved"].tap(); app.buttons["home.library.entry"].tap()
        app.buttons["home.library.addRecipe"].tap()
        let name = app.textFields["home.recipe.name"]
        for _ in 0..<4 where !name.isHittable { app.swipeUp(velocity: .slow) }
        name.tap(); name.typeText("Morning espresso")
        app.buttons["home.recipe.keyboardDone"].tap()
        app.buttons["home.recipe.saveIdea"].tap()
        let log = app.buttons["home.recipe.log"]
        XCTAssertTrue(log.waitForExistence(timeout: 6)); log.tap()
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["home.sip.name"].value as? String, "Morning espresso")
        app.buttons["home.sip.savePrivate"].tap()
        XCTAssertTrue(app.staticTexts["Saved to Journal"].waitForExistence(timeout: 6))
        app.buttons["home.sip.share"].tap()
        XCTAssertTrue(app.staticTexts["Share your sip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recipe attachment"].firstMatch.exists)
        capture("Recipe attachment and audience", in: app)
    }

    @MainActor
    func testRecipeDiscoveryCanSaveAnIdeaWithoutStartingASip() {
        let app = launch()
        app.buttons["mugshot.tab.saved"].tap()
        app.buttons["home.library.entry"].tap()
        app.buttons["Find your next recipe"].tap()
        let discoveryAction = app.buttons["home.discovery.saveRecipe"]
        discoveryAction.tap()
        XCTAssertTrue(discoveryAction.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Save a recipe"].waitForExistence(timeout: 5))
        let link = app.buttons["home.recipe.link"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        let source = app.textFields["home.recipe.sourceURL"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.tap(); source.typeText("https://example.invalid/tea")
        app.buttons["home.recipe.keyboardDone"].tap()
        let name = app.textFields["home.recipe.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Evening matcha idea")
        app.buttons["home.recipe.keyboardDone"].tap()
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
        app.buttons["home.recipe.caption"].tap()
        let caption = app.descendants(matching: .any)["home.recipe.sourceText"].firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 4))
        caption.tap(); app.typeText("Ingredients:\n2 g tea\n100 ml water\nSteps:\nStir with water.")
        app.buttons["home.recipe.keyboardDone"].tap()
        let name = app.textFields["home.recipe.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        for _ in 0..<3 where !name.isHittable { app.swipeUp() }
        name.tap(); name.typeText("Guided tea")
        app.buttons["home.recipe.keyboardDone"].tap()
        let extracted = app.staticTexts["home.recipe.extractedCount"]
        XCTAssertTrue(extracted.waitForExistence(timeout: 5), "Pasting recipe instructions must fill the draft without a separate copy prompt.")
        XCTAssertFalse(app.switches["home.recipe.allowInstructions"].exists)
        clearNotificationBanner()
        app.buttons["home.recipe.saveIdea"].tap()
        XCTAssertTrue(app.buttons["home.recipe.saveIdea"].waitForNonExistence(timeout: 6))
        let make = app.buttons["home.recipe.make"]
        XCTAssertTrue(make.waitForExistence(timeout: 5)); make.tap()
        XCTAssertTrue(app.staticTexts["Make"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Today’s target"].exists, "Instructions without planned measurements must not show an empty target card.")
        capture("Guidance", in: app)
        for _ in 0..<8 where !app.staticTexts["How was the sip?"].exists {
            app.buttons["logASipV3.primaryAction"].tap()
        }
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 4))
        let score = app.descendants(matching: .any).matching(identifier: "logASipV3.sipScore").firstMatch
        for _ in 0..<3 where !score.isHittable { app.swipeUp() }
        XCTAssertTrue(score.waitForExistence(timeout: 4))
        score.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        XCTAssertEqual(score.value as? String, "4.0 out of 5")
        capture("Rating", in: app)
        app.buttons["home.sip.savePrivate"].tap()
        XCTAssertTrue(app.staticTexts["Saved to Journal"].waitForExistence(timeout: 6))
        capture("Private Journal receipt", in: app)
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
