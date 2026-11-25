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

    @MainActor func testJournalReminderFlowsWithContentAndLeavesHeadersClear() {
        // Exercise the production tab shell and Journal, rather than the
        // isolated preferences preview, so a global overlay regression fails.
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-mugsy-journal-card"]
        app.launch()
        let feed = app.buttons["mugshot.tab.feed"]
        XCTAssertTrue(feed.waitForExistence(timeout: 15))
        feed.tap()
        let feedHeader = app.staticTexts["Feed"].firstMatch
        XCTAssertTrue(feedHeader.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(feedHeader.frame.height, 0)
        XCTAssertTrue(app.frame.contains(feedHeader.frame), "The Feed title must remain inside the visible screen.")
        XCTAssertTrue(app.buttons["Search feed"].isHittable, "The Feed header’s real action must remain usable.")
        let card = app.descendants(matching: .any).matching(identifier: "mugsy.journal.card").firstMatch
        XCTAssertFalse(card.exists, "Journal reminders must never cover the Feed header.")
        capture(app, "07-feed-header-clear")

        app.buttons["mugshot.tab.journal"].tap()
        let journalHeader = app.staticTexts["Journal"].firstMatch
        XCTAssertTrue(journalHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(journalHeader.frame.height, 0)
        XCTAssertTrue(app.frame.contains(journalHeader.frame), "The real Journal title must remain visible above the reminder.")
        XCTAssertLessThanOrEqual(journalHeader.frame.maxY, card.frame.minY + 2,
            "The reminder belongs below the Journal header in normal document flow.")
        XCTAssertTrue(app.buttons["mugsy.card.open"].isHittable)
        let originalCardY = card.frame.minY
        capture(app, "08-journal-reminder-inline")

        let journalScroll = app.scrollViews.firstMatch
        XCTAssertTrue(journalScroll.exists)
        journalScroll.swipeUp()
        XCTAssertTrue(!card.exists || card.frame.minY < originalCardY - 8,
            "The reminder must scroll with Journal content, rather than stay in a fixed overlay.")
        capture(app, "09-journal-reminder-scrolled")

        feed.tap()
        XCTAssertTrue(feedHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.contains(feedHeader.frame))
        XCTAssertTrue(app.buttons["Search feed"].isHittable)
        XCTAssertFalse(card.exists, "Switching away from Journal must not leave its reminder over another tab.")
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
