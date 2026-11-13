import XCTest

final class HomeLibraryBrowseUITests: XCTestCase {
    @MainActor private func openLibrary() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion"]
        app.launch()
        app.buttons["mugshot.tab.saved"].tap()
        let library = app.buttons["home.library.entry"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        library.tap()
        XCTAssertTrue(app.buttons["home.library.close"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor func testEmptyShelfOffersLocalStartersAndNameOnlyBagRetainsUnknownDate() {
        let app = openLibrary()
        XCTAssertFalse(app.textFields["home.library.recipeSearch"].exists)
        XCTAssertTrue(app.buttons["home.drafts.open"].exists, "Guest photo drafts remain available from an empty shelf.")
        XCTAssertTrue(app.buttons["home.library.addRecipe"].exists)
        let starter = app.buttons["home.library.starter"]
        reveal(starter, in: app)
        starter.tap()
        XCTAssertTrue(app.buttons["home.starter.coffee"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.starter.tea"].exists)
        XCTAssertTrue(app.buttons["home.starter.matcha"].exists)
        app.navigationBars.buttons["Cancel"].tap()

        app.buttons["home.library.beans"].tap()
        app.buttons["home.library.addBag"].tap()
        let name = app.textFields["logASipV3.home.bag.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["logASipV3.home.bag.roaster"].exists)
        name.tap()
        name.typeText("Alder Decaf")
        XCTAssertEqual(name.value as? String, "Alder Decaf")
        app.buttons["home.bag.save"].tap()

        let bag = row(app, containing: "Alder Decaf")
        XCTAssertTrue(bag.waitForExistence(timeout: 5))
        XCTAssertTrue(bag.label.contains("Roast date unknown"))
        app.buttons["home.library.close"].tap()
        app.buttons["home.library.entry"].tap()
        app.buttons["home.library.beans"].tap()
        XCTAssertTrue(bag.waitForExistence(timeout: 5))
        XCTAssertTrue(bag.label.contains("Roast date unknown"))
    }

    @MainActor func testDetailDoneReturnsToShelfAndArchivedRecipeCanBeRestoredThere() {
        let app = openLibrary()
        saveIdea("Green tea idea", in: app)
        saveIdea("Blueberry syrup idea", in: app)
        let search = app.textFields["home.library.recipeSearch"]
        reveal(search, in: app)
        search.tap()
        search.typeText("unfindable drink\n")
        reveal(app.staticTexts["No recipes match"], in: app)
        let clear = app.buttons["home.library.clearRecipeFilters"]
        reveal(clear, in: app)
        clear.tap()

        let tea = row(app, containing: "Green tea idea")
        reveal(tea, in: app)
        tea.tap()
        let archive = app.buttons["Archive recipe"]
        reveal(archive, in: app)
        archive.tap()
        app.buttons["home.library.recipeDone"].tap()

        let archiveShelf = app.buttons["home.library.archivedRecipes"]
        reveal(archiveShelf, in: app)
        archiveShelf.tap()
        XCTAssertEqual(archiveShelf.value as? String, "1, expanded")
        let restore = app.buttons["Restore Green tea idea"]
        reveal(restore, in: app)
        restore.tap()
        XCTAssertTrue(tea.waitForExistence(timeout: 5))
        XCTAssertFalse(archiveShelf.exists)
    }

    @MainActor private func saveIdea(_ value: String, in app: XCUIApplication) {
        let add = app.buttons["home.library.addRecipe"]
        reveal(add, in: app)
        add.tap()
        let name = app.textFields["home.recipe.name"]
        reveal(name, in: app)
        name.tap()
        name.typeText(value)
        app.buttons["home.recipe.keyboardDone"].tap()
        app.buttons["home.recipe.saveIdea"].tap()
        let done = app.buttons["home.library.recipeDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 6))
        done.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Recipe Book"].exists)
    }

    @MainActor private func row(_ app: XCUIApplication, containing value: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
}
