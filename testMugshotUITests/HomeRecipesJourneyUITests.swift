import XCTest

/// Uses synthetic local account data; never publishes or synchronizes to production.
final class HomeRecipesJourneyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testEveryTemplateSavesIndependentlyAndLogsWithoutRequiredFeedback() throws {
        let examples: [(String, String, String?)] = [
            ("Espresso", "Coffee preparation", "Espresso"),
            ("Pour over", "Coffee preparation", "Pour-over"),
            ("Cold brew", "Coffee preparation", "Cold brew"),
            ("Syrup", "Ingredient or component", nil),
            ("Latte", "Complete drink", nil),
            ("Custom", "Start blank", nil)
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
            let nameField = app.textFields["home.recipe.name"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5))
            nameField.tap()
            nameField.typeText("QA \(run) \(name)")
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Starting template")).firstMatch.tap()
            app.buttons[template].firstMatch.tap()
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
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
