import XCTest

final class HomeDraftControlUITests: XCTestCase {
    @MainActor private func launch(profiles: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion",
                               profiles ? "--ui-testing-home-profiles" : "--ui-testing-home-drafts"]
        app.launch()
        return app
    }

    @MainActor func testDraftManagerDeduplicatesAndConfirmsDiscardWithoutTouchingOtherWork() {
        let app = launch()
        let sip = app.buttons["home.drafts.resume.sip-00000000-0000-4000-8000-000000000501"]
        XCTAssertTrue(sip.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Resume Iced latte")).count, 1)
        let trash = app.buttons["home.drafts.delete.sip-00000000-0000-4000-8000-000000000501"]
        trash.tap()
        app.buttons["Keep draft"].tap()
        XCTAssertTrue(sip.exists)
        capture(app, "01-draft-manager")
        trash.tap()
        app.buttons["Delete draft"].tap()
        XCTAssertFalse(sip.exists)
        XCTAssertTrue(app.buttons["home.drafts.resume.make-00000000-0000-4000-8000-000000000502"].exists)
        XCTAssertTrue(app.buttons["home.drafts.resume.recipe-00000000-0000-4000-8000-000000000503"].exists)
    }

    @MainActor func testNamedHomeSetupCanBeAddedAndRemovalCanBeCancelled() {
        let app = launch(profiles: true)
        let add = app.buttons["home.profile.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let name = app.textFields["home.profile.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Office nook")
        XCTAssertEqual(name.value as? String, "Office nook")
        if app.buttons["home.editor.keyboardDone"].exists { app.buttons["home.editor.keyboardDone"].tap() }
        XCTAssertEqual(name.value as? String, "Office nook", "Closing the keyboard must keep the final character.")
        let save = app.buttons["home.profile.save"]
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        let edit = app.buttons["Edit Office nook Home setup"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        capture(app, "02-home-profiles")
        app.buttons["Actions for Office nook"].tap()
        app.buttons["Remove setup"].tap()
        app.buttons["Keep setup"].tap()
        XCTAssertTrue(edit.exists)
    }

    @MainActor func testSelectedSipResumesThroughTheProvidedRoute() {
        let app = launch()
        let sip = app.buttons["home.drafts.resume.sip-00000000-0000-4000-8000-000000000501"]
        XCTAssertTrue(sip.waitForExistence(timeout: 10)); sip.tap()
        XCTAssertTrue(app.staticTexts["Resumed Iced latte"].waitForExistence(timeout: 5))
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
}
