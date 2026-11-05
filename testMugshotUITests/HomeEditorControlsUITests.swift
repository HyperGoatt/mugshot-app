import XCTest

final class HomeEditorControlsUITests: XCTestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out",
            "--ui-testing-reduce-motion", "--ui-testing-home-editor"] + extra
        app.launch()
        return app
    }

    @MainActor func testRecipeCanvasRetainsIngredientReorderRemoveAndSave() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 8))
        let amount = app.textFields["Amount"].firstMatch
        // UI1 reported this field hittable while the fixed Save bar covered it.
        // Scroll it above the real action bar before the same normal tap/type.
        reveal(amount, app); amount.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        amount.typeText("125")
        app.buttons["home.editor.keyboardDone"].tap()
        XCTAssertEqual(amount.value as? String, "125")
        let firstMenu = app.buttons["home.recipe.ingredient.0.actions"]
        reveal(firstMenu, app); firstMenu.tap()
        app.buttons["Move later"].tap()
        XCTAssertEqual(app.textFields["home.recipe.ingredient.0.name"].value as? String, "Sugar")
        reveal(app.buttons["home.recipe.ingredient.0.actions"], app)
        app.buttons["home.recipe.ingredient.0.actions"].tap()
        app.buttons["Remove ingredient"].tap()
        XCTAssertEqual(app.textFields["home.recipe.ingredient.0.name"].value as? String, "Milk")
        XCTAssertFalse(app.textFields["home.recipe.ingredient.1.name"].exists)
        let lastTiming = app.textFields["Wait (seconds)"].lastMatch
        reveal(lastTiming, app)
        XCTAssertLessThan(lastTiming.frame.maxY, app.buttons["home.recipe.save"].frame.minY,
            "The final editor input must scroll fully above the fixed Save action.")
        capture(app, "01-recipe-editor-canvas")
        app.buttons["home.recipe.save"].tap()
        XCTAssertTrue(app.staticTexts["Recipe saved"].waitForExistence(timeout: 5))
    }

    @MainActor func testInstructionActionsRemainAvailableAtLargestText() {
        let app = launch(["--ui-testing-accessibility-xxxl"])
        XCTAssertTrue(app.descendants(matching: .any)["home.editor.layout.accessibility"].firstMatch.waitForExistence(timeout: 8))
        let firstStep = app.buttons["home.recipe.step.0.actions"]
        reveal(firstStep, app); firstStep.tap()
        app.buttons["Move later"].tap()
        XCTAssertEqual(app.textFields["home.recipe.step.0.instruction"].value as? String, "Pour into a jar.")
        reveal(app.buttons["home.recipe.step.0.actions"], app)
        app.buttons["home.recipe.step.0.actions"].tap()
        app.buttons["Remove step"].tap()
        XCTAssertEqual(app.textFields["home.recipe.step.0.instruction"].value as? String, "Stir gently.")
        XCTAssertTrue(app.buttons["home.recipe.save"].isHittable)
        capture(app, "02-recipe-editor-largest-text")
    }

    @MainActor func testGearCanvasKeepsRoleIdentityAndSaveControls() {
        let app = launch(["--ui-testing-home-gear"])
        XCTAssertTrue(app.staticTexts["Meet your gear."].waitForExistence(timeout: 8))
        let nickname = app.textFields["home.gear.nickname"]
        reveal(nickname, app); nickname.tap(); nickname.typeText("My kettle")
        app.buttons["home.editor.keyboardDone"].tap()
        XCTAssertTrue(app.buttons["home.gear.save"].isEnabled)
        capture(app, "03-gear-editor-canvas")
        app.buttons["home.gear.save"].tap()
        XCTAssertTrue(app.staticTexts["Gear saved"].waitForExistence(timeout: 5))
    }

    @MainActor func testLegacyMakeUsesTheCanvasAndKeepsThePrivateSavePath() {
        let app = launch(["--ui-testing-home-legacy-log"])
        XCTAssertTrue(app.staticTexts["A sip worth keeping."].waitForExistence(timeout: 8))
        app.buttons["home.log.reflect"].tap()
        XCTAssertTrue(app.staticTexts["Keep this moment."].waitForExistence(timeout: 5))
        capture(app, "04-private-home-reflection-canvas")
        app.buttons["home.log.save"].tap()
        XCTAssertTrue(app.staticTexts["Sip saved"].waitForExistence(timeout: 5))
    }

    @MainActor func testLegacyShareUsesTheCanvasWithExplicitAudience() {
        let app = launch(["--ui-testing-home-legacy-share"])
        XCTAssertTrue(app.staticTexts["Ready to share?"].waitForExistence(timeout: 8))
        capture(app, "05-home-share-canvas")
        XCTAssertTrue(app.buttons["home.legacyShare.post"].isEnabled)
        app.buttons["home.legacyShare.post"].tap()
        XCTAssertTrue(app.staticTexts["Post preview ready"].waitForExistence(timeout: 5))
    }

    @MainActor func testPrivateHomeEditUpdatesOneExistingSipAndKeepsItsRecipe() {
        let app = launch(["--ui-testing-home-private-edit"])
        openPrivateEdit(app)
        let note = app.textFields["Private note"]
        reveal(note, app); replaceText(note, with: "More cinnamon next time.")
        app.buttons["home.editor.keyboardDone"].tap()
        reveal(app.sliders["Rating"], app); app.sliders["Rating"].adjust(toNormalizedSliderPosition: 1)
        app.buttons["Edit sip details"].tap()
        let name = app.textFields["home.log.name"]
        reveal(name, app); replaceText(name, with: "Iced cinnamon latte")
        app.buttons["home.editor.keyboardDone"].tap()
        app.buttons["home.log.reflect"].tap()
        capture(app, "06-private-home-edit")
        XCTAssertEqual(app.buttons["home.log.save"].label, "Save changes")
        app.buttons["home.log.save"].tap()
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5)); app.buttons["More"].tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        XCTAssertTrue(app.staticTexts["1 saved sip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name: Iced cinnamon latte"].exists)
        XCTAssertTrue(app.staticTexts["Score: 5"].exists)
        XCTAssertTrue(app.staticTexts["Private note: More cinnamon next time."].exists)
        XCTAssertTrue(app.staticTexts["Original journal identity kept"].exists)
        XCTAssertTrue(app.staticTexts["Recipe unchanged"].exists)
        XCTAssertTrue(app.staticTexts["Pending edit drafts: 0"].exists)
    }

    @MainActor func testPrivateEditCanBeKeptResumedAndDiscardedWithoutChangingSavedSip() {
        let app = launch(["--ui-testing-home-private-edit"])
        openPrivateEdit(app)
        app.buttons["Edit sip details"].tap()
        let name = app.textFields["home.log.name"]
        reveal(name, app); replaceText(name, with: "Unfinished variation")
        app.buttons["home.editor.keyboardDone"].tap()
        app.buttons["Cancel"].firstMatch.tap()
        let keep = app.buttons["Keep draft"].firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5)); keep.tap()
        openPrivateEdit(app, expectsReflection: false)
        XCTAssertEqual(app.textFields["home.log.name"].value as? String, "Unfinished variation")
        app.buttons["Cancel"].firstMatch.tap()
        let discard = app.buttons["Discard draft"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5)); discard.tap()
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5)); app.buttons["More"].tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        XCTAssertTrue(app.staticTexts["1 saved sip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name: Cinnamon latte"].exists)
        XCTAssertTrue(app.staticTexts["Original journal identity kept"].exists)
        XCTAssertTrue(app.staticTexts["Recipe unchanged"].exists)
        XCTAssertTrue(app.staticTexts["Pending edit drafts: 0"].exists)
    }

    @MainActor func testLargestTextDeleteConfirmationKeepsBothActionsReachableAndCanBeCancelled() {
        let app = launch(["--ui-testing-home-private-edit", "--ui-testing-accessibility-xxxl"])
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 8)); more.tap()
        app.buttons["home.sip.delete"].firstMatch.tap()
        let cancel = app.buttons["sip.delete.cancel"]
        let confirm = app.buttons["sip.delete.confirm"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(cancel.isHittable)
        XCTAssertTrue(confirm.isHittable)
        XCTAssertGreaterThanOrEqual(cancel.frame.height, 44)
        XCTAssertGreaterThanOrEqual(confirm.frame.height, 44)
        capture(app, "07-delete-confirmation-largest-text")
        cancel.tap()
        XCTAssertTrue(more.waitForExistence(timeout: 5)); more.tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        XCTAssertTrue(app.staticTexts["1 saved sip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name: Cinnamon latte"].exists)
        XCTAssertTrue(app.staticTexts["Original journal identity kept"].exists)
    }

    @MainActor private func openPrivateEdit(_ app: XCUIApplication, expectsReflection: Bool = true) {
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 8)); reveal(more, app); more.tap()
        // iOS 27 exposes one SwiftUI menu control as nested AX button matches.
        let edit = app.buttons["home.sip.edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); edit.tap()
        XCTAssertTrue(app.buttons[expectsReflection ? "home.log.save" : "home.log.reflect"].waitForExistence(timeout: 5))
    }

    @MainActor private func replaceText(_ field: XCUIElement, with replacement: String) {
        let current = field.value as? String ?? ""
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + replacement)
    }

    @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<12 {
            let frame = element.frame
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY + 8 : app.frame.minY + 100
            let stickyActions = ["home.recipe.save", "home.log.save", "home.log.reflect"]
                .map { app.buttons[$0].firstMatch }.filter { $0.exists && $0.isHittable }
            if element.isHittable && stickyActions.isEmpty { return }
            let bottom = stickyActions.map { $0.frame.minY - 12 }.min() ?? app.frame.maxY - 70
            if element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
            if element.exists && frame.minY < top && frame != .zero {
                scroll.swipeDown()
            } else { scroll.swipeUp() }
        }
        XCTFail("The control must scroll into the visible editor area above the fixed actions.")
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
