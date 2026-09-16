import XCTest

/// Uses synthetic local account data; never publishes or synchronizes to production.
final class HomeRecipesJourneyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testEveryTemplateSavesIndependentlyAndLogsWithoutRequiredFeedback() throws {
        let examples: [(String, String, String?)] = [
            ("Espresso", "coffee", "Espresso"),
            ("Pour over", "coffee", "Pour-over"),
            ("Cold brew", "coffee", "Cold brew"),
            ("Syrup", "component", nil),
            ("Latte", "drink", nil),
            ("Custom", "custom", nil)
        ]
        let run = String(UUID().uuidString.prefix(8))
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-MugshotRoadmap.homeRecipes.v1", "YES"]
        app.launch()
        for (name, template, method) in examples {
            app.buttons["mugshot.tab.journal"].tap()
            let home = app.buttons["Home"].firstMatch
            if !app.segmentedControls["Home collection"].exists {
                reveal(home, in: app)
                home.tap()
            }
            let recipes = app.buttons["Recipes"].firstMatch
            XCTAssertTrue(recipes.waitForExistence(timeout: 5))
            recipes.tap()
            app.navigationBars.buttons["New recipe"].tap()
            let templateButton = app.buttons["home.recipe.template.\(template)"]
            XCTAssertTrue(templateButton.waitForExistence(timeout: 5))
            templateButton.tap()
            let nameField = app.textFields["home.recipe.name"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5))
            nameField.tap()
            nameField.typeText("QA \(run) \(name)")
            if let method {
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Method")).firstMatch.tap()
                app.buttons[method].firstMatch.tap()
            }
            app.buttons["home.recipe.save"].tap()
            let log = app.buttons["Log a make"].firstMatch
            XCTAssertTrue(log.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Your recipe · Version 1"].exists)
            log.tap()
            XCTAssertEqual(app.textFields["home.log.name"].value as? String, "QA \(run) \(name)")
            let reflect = app.buttons["How was it?"]
            reveal(reflect, in: app)
            reflect.tap()
            app.buttons["home.log.save"].tap()
            XCTAssertTrue(app.staticTexts["Saved privately"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Unrated"].exists)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Saved \(name) without photo or rating"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
            app.launch()
        }
    }

    @MainActor
    func testGuidedPourOverAndColdBrewBatchResume() throws {
        let run = String(UUID().uuidString.prefix(8))
        let app = launchApp()
        openRecipes(in: app)

        app.navigationBars.buttons["New recipe"].tap()
        app.buttons["home.recipe.template.coffee"].tap()
        enter("QA \(run) Guided pour-over", in: app.textFields["home.recipe.name"])
        chooseMethod("Pour-over", in: app)
        reveal(app.buttons["home.recipe.save"], in: app)
        app.buttons["home.recipe.save"].tap()

        XCTAssertTrue(app.buttons["home.recipe.make"].waitForExistence(timeout: 5))
        app.buttons["home.recipe.make"].tap()
        XCTAssertTrue(app.staticTexts["Bloom"].waitForExistence(timeout: 5))
        assertCumulativeWater("60 grams", in: app)
        app.buttons["home.make.next"].tap()
        assertCumulativeWater("180 grams", in: app)
        app.buttons["home.make.next"].tap()
        assertCumulativeWater("300 grams", in: app)
        reveal(app.buttons["home.make.finish"], in: app)
        app.buttons["home.make.finish"].tap()
        completeUnratedLog(in: app)

        app.terminate()
        app.launch()
        openRecipes(in: app)
        app.navigationBars.buttons["New recipe"].tap()
        app.buttons["home.recipe.template.coffee"].tap()
        let batchName = "QA \(run) Overnight cold brew"
        enter(batchName, in: app.textFields["home.recipe.name"])
        chooseMethod("Cold brew", in: app)
        reveal(app.buttons["home.recipe.save"], in: app)
        app.buttons["home.recipe.save"].tap()
        app.buttons["home.recipe.make"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Ready around")).firstMatch.waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openHome(in: app)
        let resumable = app.buttons[batchName]
        XCTAssertTrue(resumable.waitForExistence(timeout: 5))
        resumable.tap()
        XCTAssertTrue(app.buttons["home.make.finish"].waitForExistence(timeout: 5))
        app.buttons["home.make.finish"].tap()
        completeUnratedLog(in: app)
        XCTAssertTrue(app.buttons["Log a serving from this batch"].exists)
    }

    @MainActor
    func testCompleteDrinkLinksAndPreparesAReusableComponent() throws {
        let run = String(UUID().uuidString.prefix(8))
        let componentName = "QA \(run) Brown sugar syrup"
        let drinkName = "QA \(run) Cloud latte"
        let app = launchApp()
        openRecipes(in: app)

        app.navigationBars.buttons["New recipe"].tap()
        app.buttons["home.recipe.template.component"].tap()
        enter(componentName, in: app.textFields["home.recipe.name"])
        app.buttons["Add ingredient"].tap()
        enter("Brown sugar", in: app.textFields["Ingredient"].firstMatch)
        reveal(app.buttons["home.recipe.save"], in: app)
        app.buttons["home.recipe.save"].tap()
        XCTAssertTrue(app.buttons["home.recipe.make"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openRecipes(in: app)
        app.navigationBars.buttons["New recipe"].tap()
        app.buttons["home.recipe.template.drink"].tap()
        enter(drinkName, in: app.textFields["home.recipe.name"])
        app.buttons["home.recipe.link"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        enter(componentName, in: search)
        XCTAssertTrue(app.staticTexts[componentName].waitForExistence(timeout: 5))
        app.buttons["Link version 1"].tap()
        reveal(app.buttons["home.recipe.save"], in: app)
        app.buttons["home.recipe.save"].tap()
        app.buttons["home.recipe.make"].tap()
        let prepare = app.buttons["Prepare \(componentName)"]
        reveal(prepare, in: app)
        prepare.tap()
        XCTAssertTrue(app.staticTexts["This prepares a component for your drink. It does not create a separate journal entry."].waitForExistence(timeout: 5))
        let ready = app.buttons["Ready for my drink"]
        reveal(ready, in: app)
        ready.tap()
        reveal(app.buttons["home.make.finish"], in: app)
        app.buttons["home.make.finish"].tap()
        completeUnratedLog(in: app)
        XCTAssertTrue(app.staticTexts["Saved privately"].exists)
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-MugshotRoadmap.homeRecipes.v1", "YES"]
        app.launch()
        return app
    }

    @MainActor
    private func openHome(in app: XCUIApplication) {
        app.buttons["mugshot.tab.journal"].tap()
        if !app.segmentedControls["Home collection"].exists {
            let home = app.buttons["Home"].firstMatch
            reveal(home, in: app)
            home.tap()
        }
        // SwiftUI exposes this segmented picker as its child buttons on some
        // simulator/runtime combinations, so assert the stable destination
        // control instead of relying on the container's accessibility role.
        XCTAssertTrue(app.buttons["Recipes"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    private func openRecipes(in app: XCUIApplication) {
        openHome(in: app)
        let recipes = app.buttons["Recipes"].firstMatch
        XCTAssertTrue(recipes.waitForExistence(timeout: 5))
        recipes.tap()
    }

    @MainActor
    private func chooseMethod(_ method: String, in app: XCUIApplication) {
        let picker = app.buttons["home.recipe.method"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        app.buttons[method].tap()
    }

    @MainActor
    private func enter(_ value: String, in field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(value)
    }

    @MainActor
    private func completeUnratedLog(in app: XCUIApplication) {
        let reflect = app.buttons["How was it?"]
        reveal(reflect, in: app)
        reflect.tap()
        let save = app.buttons["home.log.save"]
        reveal(save, in: app)
        save.tap()
        XCTAssertTrue(app.staticTexts["Saved privately"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Unrated"].exists)
    }

    @MainActor
    private func assertCumulativeWater(_ expected: String, in app: XCUIApplication) {
        let target = app.descendants(matching: .any)["home.make.cumulative-water"]
        XCTAssertTrue(target.waitForExistence(timeout: 3))
        XCTAssertEqual(target.value as? String, expected)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
