import XCTest

/// Explicit owner-promoted hardware QA. Normal CI/Simulator runs never open an owner's account.
final class OwnerHomePhoneUITests: XCTestCase {
    @MainActor
    func testExistingOwnerRecipeOpensWithoutStartingASip() throws {
        guard ProcessInfo.processInfo.environment["MUGSHOT_OWNER_PHONE_QA"] == "1" else {
            throw XCTSkip("Requires explicit owner-promoted physical-device execution.")
        }
        continueAfterFailure = false
        let recipeName = try XCTUnwrap(ProcessInfo.processInfo.environment["MUGSHOT_QA_EXISTING_RECIPE"])
        let app = XCUIApplication(bundleIdentifier: "co.mugshot.app.dev")
        app.activate()
        let close = app.buttons["home.library.close"]
        if close.exists { close.tap() }
        app.buttons["mugshot.tab.saved"].tap()
        app.buttons["home.library.entry"].tap()
        // Select one existing actionable recipe; never create a synthetic owner recipe.
        let recipe = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", recipeName)).firstMatch
        XCTAssertTrue(recipe.waitForExistence(timeout: 8)); recipe.tap()
        let make = app.buttons["home.recipe.make"]
        XCTAssertTrue(make.waitForExistence(timeout: 8), "A saved recipe must offer guidance before a sip is started.")
        XCTAssertFalse(app.textFields["logASipV3.drinkName"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Owner recipe details"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
