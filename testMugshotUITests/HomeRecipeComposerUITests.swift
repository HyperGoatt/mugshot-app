import XCTest

final class HomeRecipeComposerUITests: XCTestCase {
    @MainActor
    private func book(extraArguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion"] + extraArguments
        app.launch()
        app.buttons["mugshot.tab.saved"].tap(); app.buttons["home.library.entry"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Berry syrup")).count, 0,
                       "Reset must isolate each fixture journey from earlier saved test recipes.")
        return app
    }

    @MainActor
    func testCaptureHasASourceFirstCanvasAndAVisibleDrinkBuilder() {
        let app = book()
        app.buttons["home.library.addRecipe"].tap()
        XCTAssertTrue(app.staticTexts["Save an idea."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.recipe.buildDrink"].isHittable)
        XCTAssertTrue(app.buttons["home.recipe.screenshot"].exists)
        capture("01-capture-empty", app)
    }

    @MainActor
    func testSyrupCanBeSavedThenCombinedAndPreviewedWithoutLosingTheLatte() {
        let app = book(); app.buttons["home.library.addRecipe"].tap()
        let name = app.textFields["home.recipe.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Berry syrup")
        app.buttons["home.recipe.caption"].tap()
        let caption = app.textFields["home.recipe.sourceText"]
        XCTAssertTrue(caption.waitForExistence(timeout: 4)); caption.tap()
        caption.typeText("Ingredients:\n1 cup berries\n1 cup water\nSteps:\nSimmer gently.")
        app.buttons["home.recipe.keyboardDone"].tap()
        let component = app.buttons["home.recipe.use.component"]
        reveal(component, app); component.tap()
        XCTAssertTrue(app.staticTexts["home.recipe.extractedCount"].waitForExistence(timeout: 5))
        capture("02-component-preview", app)
        clearBanner(); app.buttons["home.recipe.saveIdea"].tap()
        XCTAssertTrue(app.buttons["home.recipe.saveIdea"].waitForNonExistence(timeout: 6))
        let use = app.buttons["home.recipe.useInDrink"]
        XCTAssertTrue(use.waitForExistence(timeout: 5)); use.tap()
        let drinkName = app.textFields["home.drink.name"]
        XCTAssertTrue(drinkName.waitForExistence(timeout: 5)); drinkName.tap(); drinkName.typeText("Berry latte")
        app.buttons["home.drink.keyboardDone"].tap()
        let amount = app.textFields["Amount of Berry syrup"]
        reveal(amount, app); amount.tap()
        amount.typeText("15")
        XCTAssertEqual(amount.value as? String, "15", "Typing must retain both digits before dismissing the keyboard.")
        app.buttons["home.drink.keyboardDone"].tap()
        XCTAssertEqual(amount.value as? String, "15", "Typing must retain the complete per-drink amount.")
        capture("03-drink-mix", app)
        let preview = app.buttons["Open Berry syrup recipe"]
        reveal(preview, app); preview.tap()
        XCTAssertTrue(app.staticTexts["1. Simmer gently."].waitForExistence(timeout: 5))
        app.buttons["home.recipe.linked.done"].tap()
        XCTAssertEqual(drinkName.value as? String, "Berry latte")
        XCTAssertEqual(amount.value as? String, "15")
        let savedPart = app.buttons["home.drink.addRecipe"]
        reveal(savedPart, app); savedPart.tap()
        app.buttons["Add Berry syrup"].tap()
        XCTAssertTrue(app.buttons["Add Berry syrup"].waitForNonExistence(timeout: 5), "Choosing a saved part must return to the drink.")
        XCTAssertEqual(app.textFields.matching(identifier: "Amount of Berry syrup").count, 1, "Selecting an already linked part must not duplicate it.")
        XCTAssertEqual(drinkName.value as? String, "Berry latte")
        XCTAssertEqual(amount.value as? String, "15")
        clearBanner(); app.buttons["home.drink.save"].tap()
        let make = app.buttons["home.recipe.make"]
        XCTAssertTrue(make.waitForExistence(timeout: 6)); make.tap()
        let guidance = app.buttons["home.makeWithGuidance"]
        if guidance.waitForExistence(timeout: 4) { guidance.tap() }
        XCTAssertTrue(app.staticTexts["Make"].waitForExistence(timeout: 5))
        for _ in 0..<8 where !app.staticTexts["How did it go?"].exists { app.buttons["logASipV3.primaryAction"].tap() }
        XCTAssertTrue(app.staticTexts["How did it go?"].waitForExistence(timeout: 4))
        app.buttons["logASipV3.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Capture your sip"].waitForExistence(timeout: 4))
        app.buttons["logASipV3.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 4))
        app.buttons["logASipV3.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Review your sip"].waitForExistence(timeout: 4))
        capture("04-composed-drink-review", app)
    }

    @MainActor
    func testBuildAMatchaDrinkWithoutSettingUpInventoryOrUsingAI() {
        let app = book(); app.buttons["home.library.buildDrink"].tap()
        let name = app.textFields["home.drink.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 4)); name.tap(); name.typeText("Morning matcha")
        app.buttons["home.drink.keyboardDone"].tap()
        app.buttons["home.drink.chooseBase"].tap()
        app.buttons["home.drink.preset.traditional_matcha"].tap()
        XCTAssertTrue(app.staticTexts["Traditional matcha"].waitForExistence(timeout: 4))
        let settings = app.buttons["Brew settings"]; reveal(settings, app); settings.tap()
        XCTAssertTrue(app.staticTexts["Matcha (g)"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["Coffee dose (g)"].exists)
        clearBanner(); app.buttons["home.drink.save"].tap()
        XCTAssertTrue(app.buttons["home.recipe.make"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Morning matcha"].firstMatch.exists)
        XCTAssertFalse(app.textFields["logASipV3.drinkName"].exists)
        app.buttons["home.recipe.make"].tap()
        let guidance = app.buttons["home.makeWithGuidance"]
        if guidance.waitForExistence(timeout: 4) { guidance.tap() }
        XCTAssertTrue(app.staticTexts["Make"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["home.guidance.method"].label, "Traditional matcha")
        XCTAssertTrue(app.staticTexts["home.guidance.methodTip"].exists)
        XCTAssertTrue(app.staticTexts["STEP 1 OF 2"].exists, "Assembly instructions must not be duplicated as both base and drink steps.")
    }

    @MainActor
    func testIngredientAmountTypingRetainsAllDigits() {
        let app = book(); app.buttons["home.library.buildDrink"].tap()
        let amount = app.textFields["Amount of Milk"]
        reveal(amount, app); amount.tap(); amount.typeText("150.5")
        app.buttons["home.drink.keyboardDone"].tap()
        XCTAssertEqual(amount.value as? String, "150.5")
        amount.tap()
        app.buttons["Remove Milk"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 4), "Removing an ingredient while editing must safely end its input.")
    }

    @MainActor
    func testLargestTextCanSaveAnIdeaAndBuildADrink() {
        let app = book(extraArguments: ["--ui-testing-accessibility-xxxl"])
        let add = app.buttons["home.library.addRecipe"]; reveal(add, app); add.tap()
        let name = app.textFields["home.recipe.name"]; reveal(name, app); name.tap(); name.typeText("Large tea idea")
        app.buttons["home.recipe.keyboardDone"].tap()
        let role = app.buttons["home.recipe.use.base"]; reveal(role, app)
        capture("05-largest-text-capture", app)
        clearBanner(); app.buttons["home.recipe.saveIdea"].tap()
        let use = app.buttons["home.recipe.useInDrink"]; reveal(use, app); use.tap()
        let drinkName = app.textFields["home.drink.name"]; reveal(drinkName, app); drinkName.tap(); drinkName.typeText("Large drink")
        app.buttons["home.drink.keyboardDone"].tap()
        let quantityContext = app.staticTexts["In this drink"]
        reveal(quantityContext, app)
        XCTAssertTrue(quantityContext.exists, "The builder must retain the accessibility-size layout across recipe navigation and sheets.")
        let amount = app.textFields["Amount of Milk"]; reveal(amount, app); amount.tap(); amount.typeText("125")
        app.buttons["home.drink.keyboardDone"].tap()
        XCTAssertEqual(amount.value as? String, "125")
        capture("06-largest-text-builder", app)
        clearBanner(); app.buttons["home.drink.save"].tap()
        XCTAssertTrue(app.buttons["home.recipe.make"].waitForExistence(timeout: 6))
    }

    @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.exists)
    }
    @MainActor private func clearBanner() {
        let banner = XCUIApplication(bundleIdentifier: "com.apple.springboard").descendants(matching: .any)
            .matching(identifier: "NotificationShortLookView").firstMatch
        if banner.exists { banner.swipeUp() }
        XCTAssertTrue(banner.waitForNonExistence(timeout: 12))
    }
    @MainActor private func capture(_ label: String, _ app: XCUIApplication) {
        clearBanner()
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = label
        image.lifetime = .keepAlways; add(image)
    }
}
