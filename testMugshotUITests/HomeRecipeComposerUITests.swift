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
        XCTAssertTrue(app.staticTexts["Save a recipe."].waitForExistence(timeout: 5))
        for id in ["link", "screenshot", "video", "caption", "typeItIn"] {
            XCTAssertTrue(app.buttons["home.recipe.\(id)"].exists)
        }
        reveal(app.buttons["home.recipe.buildDrink"], app)
        capture("01-capture-empty", app)
    }

    @MainActor
    func testManualTeaCanStayAnIdeaOrBecomeMakeableWithoutAnImport() {
        let app = book()
        app.buttons["home.library.addRecipe"].tap()
        let manual = app.buttons["home.recipe.typeItIn"]
        reveal(manual, app); manual.tap()
        let name = app.textFields["home.recipe.name"]
        reveal(name, app); name.tap(); name.typeText("Jasmine tea")
        app.buttons["home.recipe.keyboardDone"].tap()
        let ingredient = app.textFields["home.recipe.capture.ingredient.0.name"]
        reveal(ingredient, app); ingredient.tap(); ingredient.typeText("Jasmine tea leaves")
        app.buttons["home.recipe.keyboardDone"].tap()
        let save = app.buttons["home.recipe.saveIdea"]
        XCTAssertEqual(save.label, "Save for later")
        let instruction = app.textFields["home.recipe.capture.step.0.instruction"]
        reveal(instruction, app); instruction.tap(); instruction.typeText("Steep for three minutes.")
        app.buttons["home.recipe.keyboardDone"].tap()
        XCTAssertEqual(save.label, "Save recipe")
        clearBanner(); save.tap()
        XCTAssertTrue(app.buttons["home.recipe.make"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testSyrupCanBeSavedThenCombinedAndPreviewedWithoutLosingTheLatte() {
        let app = book(); app.buttons["home.library.addRecipe"].tap()
        let captionChoice = app.buttons["home.recipe.caption"]
        reveal(captionChoice, app); captionChoice.tap()
        let caption = app.descendants(matching: .any)["home.recipe.sourceText"].firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 4)); reveal(caption, app); caption.tap()
        app.typeText("Ingredients:\n1 cup berries\n1 cup water\nSteps:\nSimmer gently.")
        app.buttons["home.recipe.keyboardDone"].tap()
        let name = app.textFields["home.recipe.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); reveal(name, app); name.tap(); name.typeText("Berry syrup")
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
        XCTAssertTrue(drinkName.waitForExistence(timeout: 5))
        drinkName.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        drinkName.typeText("Berry latte")
        XCTAssertEqual(drinkName.value as? String, "Berry latte")
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
        XCTAssertTrue(make.waitForExistence(timeout: 6))
        app.buttons["home.library.recipeDone"].tap()
        let addIns = app.buttons["home.library.use.component"]
        reveal(addIns, app); addIns.tap()
        let source = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Berry syrup")).firstMatch
        reveal(source, app); source.tap()
        let usedIn = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.recipe.usedIn.")).firstMatch
        reveal(usedIn, app)
        XCTAssertTrue(usedIn.label.contains("Berry latte") && usedIn.label.contains("v1"))
        capture("03b-add-in-used-in", app)
        let archive = app.buttons["home.recipe.archiveAddIn"]
        reveal(archive, app); archive.tap()
        app.buttons.matching(NSPredicate(format: "label == %@", "Archive add-in")).allElementsBoundByIndex.last?.tap()
        app.buttons["home.library.recipeDone"].tap()
        let wholeDrinks = app.buttons["home.library.use.drink"]
        reveal(wholeDrinks, app); wholeDrinks.tap()
        let savedDrink = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Berry latte")).firstMatch
        reveal(savedDrink, app); savedDrink.tap()
        XCTAssertTrue(make.waitForExistence(timeout: 5)); make.tap()
        XCTAssertTrue(app.staticTexts["Make"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.guidance.currentInstruction"].exists)
        for _ in 0..<8 where !app.staticTexts["How was the sip?"].exists { app.buttons["logASipV3.primaryAction"].tap() }
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 4))
        app.buttons["home.sip.savePrivate"].tap()
        XCTAssertTrue(app.staticTexts["Saved to Journal"].waitForExistence(timeout: 8))
        capture("04-composed-drink-private-receipt", app)
    }

    @MainActor
    func testBuildAMatchaDrinkWithoutSettingUpInventoryOrUsingAI() {
        let app = book(); openEmptyBuilder(app)
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
        XCTAssertTrue(app.staticTexts["Make"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["home.guidance.method"].label, "Traditional matcha")
        XCTAssertTrue(app.staticTexts["home.guidance.currentInstruction"].exists)
        XCTAssertTrue(app.staticTexts["STEP 1 OF 2"].exists, "Assembly instructions must not be duplicated as both base and drink steps.")
    }

    @MainActor
    func testIngredientAmountTypingRetainsAllDigits() {
        let app = book(); openEmptyBuilder(app)
        let amount = app.textFields["Amount of Milk"]
        reveal(amount, app); amount.tap(); amount.typeText("150.5")
        app.buttons["home.drink.keyboardDone"].tap()
        XCTAssertEqual(amount.value as? String, "150.5")
        amount.tap()
        app.buttons["Remove Milk from this drink"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 4), "Removing an ingredient while editing must safely end its input.")
    }

    @MainActor func testWholeDrinkEditSeparatesVersionAndCopy() {
        let app = book(); openEmptyBuilder(app)
        let name = app.textFields["home.drink.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Maple latte")
        app.buttons["home.drink.keyboardDone"].tap()
        app.buttons["home.drink.save"].tap()
        let edit = app.buttons["Edit recipe"]
        XCTAssertTrue(app.buttons["home.recipe.make"].waitForExistence(timeout: 6)); reveal(edit, app); edit.tap()
        let remove = app.buttons["Remove Milk from this drink"]
        reveal(remove, app); remove.tap()
        let copy = app.buttons["home.drink.saveCopy"]
        let version = app.buttons["home.drink.save"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        let actionsReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in copy.isHittable && version.isHittable }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [actionsReady], timeout: 5), .completed)
        XCTAssertEqual(version.label, "Save changes to recipe")
        capture("07-copy-and-version-actions", app)
        copy.tap()
        XCTAssertTrue(app.staticTexts["Maple latte copy"].firstMatch.waitForExistence(timeout: 6))
        app.buttons["home.library.recipeDone"].tap()
        let wholeDrinks = app.buttons["home.library.use.drink"]
        reveal(wholeDrinks, app); wholeDrinks.tap()
        let original = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND NOT label CONTAINS %@", "Maple latte", "copy")).firstMatch
        reveal(original, app); original.tap()
        reveal(edit, app); edit.tap()
        reveal(remove, app); remove.tap()
        version.tap()
        let versions = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Version 2")).firstMatch
        reveal(versions, app)
        capture("08-version-history", app)
    }

    @MainActor
    func testLargestTextCanSaveAnIdeaAndBuildADrink() {
        let app = book(extraArguments: ["--ui-testing-accessibility-xxxl"])
        let add = app.buttons["home.library.addRecipe"]; reveal(add, app); add.tap()
        let name = app.textFields["home.recipe.name"]; reveal(name, app); name.tap(); name.typeText("Large tea idea")
        let save = app.buttons["home.recipe.saveIdea"]
        XCTAssertTrue(save.isHittable)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.exists)
        XCTAssertLessThanOrEqual(save.frame.maxY, keyboard.frame.minY + 2)
        capture("05a-largest-text-capture-keyboard", app)
        app.buttons["home.recipe.keyboardDone"].tap()
        for kind in ["base", "component", "drink"] {
            let role = app.buttons["home.recipe.use.\(kind)"]
            reveal(role, app)
            XCTAssertLessThanOrEqual(role.frame.maxY, save.frame.minY)
            capture("05b-largest-text-\(kind)", app)
        }
        clearBanner(); save.tap()
        let use = app.buttons["home.recipe.useInDrink"]; reveal(use, app); use.tap()
        let drinkName = app.textFields["home.drink.name"]
        reveal(drinkName, app); drinkName.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        drinkName.typeText("Large drink")
        XCTAssertEqual(drinkName.value as? String, "Large drink")
        app.buttons["home.drink.keyboardDone"].tap()
        let quantityContext = app.staticTexts["In this drink"]
        reveal(quantityContext, app)
        XCTAssertTrue(quantityContext.exists, "The builder must retain the accessibility-size layout across recipe navigation and sheets.")
        let amount = app.textFields["Amount of Milk"]; reveal(amount, app); amount.tap(); amount.typeText("125")
        app.buttons["home.drink.keyboardDone"].tap()
        XCTAssertEqual(amount.value as? String, "125")
        capture("06-largest-text-builder", app)
        clearBanner()
        XCTAssertTrue(app.buttons["home.drink.save"].isEnabled)
        app.buttons["home.drink.save"].tap()
        XCTAssertTrue(app.buttons["home.drink.save"].waitForNonExistence(timeout: 6))
        reveal(app.buttons["home.recipe.make"], app)
    }

    @MainActor private func openEmptyBuilder(_ app: XCUIApplication) {
        app.buttons["home.library.use.drink"].tap()
        let builder = app.buttons["home.library.buildDrink"]
        reveal(builder, app); builder.tap()
    }

    @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<14 {
            let visibleScrolls = app.scrollViews.allElementsBoundByIndex.filter { $0.frame.height > 180 }
            let scroll = visibleScrolls.last ?? app.collectionViews.allElementsBoundByIndex.last ?? app.scrollViews.firstMatch
            let isCapture = scroll.identifier == "home.recipe.captureScroll"
            let top = isCapture ? scroll.frame.minY
                : (app.navigationBars.allElementsBoundByIndex.last.map { $0.frame.maxY + 2 } ?? app.frame.minY + 80)
            let save = app.buttons["home.drink.save"].firstMatch
            let bottom = isCapture ? scroll.frame.maxY : (save.isHittable ? save.frame.minY : app.frame.maxY - 38)
            guard element.exists else {
                if scroll.exists { scroll.swipeUp() } else { app.swipeUp() }
                continue
            }
            let frame = element.frame
            if element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
            let area = scroll.exists ? scroll : app
            let upper = area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.33))
            let lower = area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
            if frame.minY < top && frame != .zero { upper.press(forDuration: 0.01, thenDragTo: lower, withVelocity: .slow, thenHoldForDuration: 0) }
            else { lower.press(forDuration: 0.01, thenDragTo: upper, withVelocity: .slow, thenHoldForDuration: 0) }
        }
        XCTFail("\(element.identifier) must scroll into the visible area above the action bar.")
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
