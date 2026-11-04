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
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Evening matcha idea")).firstMatch.waitForExistence(timeout: 5))
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
        name.tap(); name.typeText("Curious matcha")
        app.buttons["home.recipe.saveIdea"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Curious matcha")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); saved.tap()
        XCTAssertTrue(app.buttons["Add preparation details"].waitForExistence(timeout: 6))
        XCTAssertFalse(app.textFields["logASipV3.drinkName"].exists)
    }
}
