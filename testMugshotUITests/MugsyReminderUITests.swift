import XCTest

final class MugsyReminderUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testConsentPaceSaveAndPauseStayExplicit() {
        let app = launch()
        let consent = app.switches["mugsy.settings.consent"]
        XCTAssertTrue(consent.waitForExistence(timeout: 15))
        XCTAssertEqual(consent.value as? String, "0")
        capture(app, "01-mugsy-preferences")
        consent.tap()
        let pace = app.descendants(matching: .any).matching(identifier: "mugsy.settings.pace").firstMatch
        XCTAssertTrue(pace.exists)
        pace.tap()
        app.buttons["Light"].tap()
        app.buttons["mugsy.settings.save"].tap()
        let confirmation = app.staticTexts["Your reminder preferences are saved."]
        scrollTo(confirmation, in: app)
        XCTAssertTrue(confirmation.waitForExistence(timeout: 4))
        capture(app, "02-mugsy-light-saved")
        let pause = app.buttons["mugsy.settings.pause7"]
        scrollTo(pause, in: app)
        pause.tap()
        // Choosing a pause changes a draft; the explicit Save commits it.
        app.buttons["mugsy.settings.save"].tap()
        let resume = app.buttons["mugsy.settings.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 4))
        capture(app, "03-mugsy-paused")
        resume.tap()
        app.buttons["mugsy.settings.save"].tap()
        XCTAssertFalse(app.staticTexts["Paused until you choose to resume"].exists)
    }

    @MainActor func testUnavailableBackendHasTruthfulPreviewAndDisabledSave() {
        let app = launch(state: "unavailable")
        let consent = app.switches["mugsy.settings.consent"]
        XCTAssertTrue(consent.waitForExistence(timeout: 15))
        XCTAssertFalse(consent.isEnabled)
        XCTAssertFalse(app.buttons["mugsy.settings.save"].isEnabled)
        let message = app.staticTexts["Mugsy’s push reminders aren’t available yet. Your journal and in-app reminders still work."]
        scrollTo(message, in: app)
        XCTAssertTrue(message.exists)
        XCTAssertFalse(app.staticTexts["Your reminder preferences are saved."].exists)
        capture(app, "04-mugsy-unavailable")
    }

    @MainActor func testFailedSavePreservesChoicesAndOffersRetry() {
        let app = launch(state: "save-failure")
        let consent = app.switches["mugsy.settings.consent"]
        XCTAssertTrue(consent.waitForExistence(timeout: 15))
        consent.tap()
        app.buttons["mugsy.settings.save"].tap()
        let message = app.staticTexts["Mugshot couldn’t confirm that change. Your last saved preferences still apply. Try again when connected."]
        scrollTo(message, in: app)
        XCTAssertTrue(message.exists)
        XCTAssertFalse(app.staticTexts["Your reminder preferences are saved."].exists)
        capture(app, "05-mugsy-save-retry")
        app.buttons["mugsy.settings.save"].tap()
        XCTAssertTrue(app.staticTexts["Your reminder preferences are saved."].waitForExistence(timeout: 4))
    }

    @MainActor func testLargeTextAndReduceMotionKeepSettingsReachable() {
        let app = launch(extra: ["--ui-testing-accessibility-xxxl", "--ui-testing-reduce-motion"])
        XCTAssertTrue(app.buttons["mugsy.settings.save"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["mugsy.settings.save"].isHittable)
        capture(app, "06-mugsy-large-text")
        let consent = app.switches["mugsy.settings.consent"]
        scrollTo(consent, in: app)
        XCTAssertTrue(consent.isHittable)
        let pause = app.buttons["mugsy.settings.pauseIndefinitely"]
        scrollTo(pause, in: app)
        XCTAssertTrue(pause.isHittable)
    }

    @MainActor private func launch(state: String = "settings", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-mugsy-reminders", "--mugsy-reminders-state=\(state)"] + extra
        app.launch()
        return app
    }

    @MainActor private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<9 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
