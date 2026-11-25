import XCTest

final class WeeklyPourUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testCompleteStoryCaptionArchiveAndPrivateSharePreview() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["weeklyPour.next"].waitForExistence(timeout: 15))
        capture(app, "01-cover")
        app.buttons["weeklyPour.next"].tap()
        capture(app, "02-moments")
        app.buttons["weeklyPour.next"].tap()
        let memory = app.buttons["weeklyPour.turnMemory"]
        XCTAssertTrue(memory.waitForExistence(timeout: 3))
        capture(app, "03-standout")
        memory.tap()
        XCTAssertTrue(memory.label.contains("Found my new favorite corner"))
        capture(app, "04-caption")
        memory.tap()
        app.buttons["weeklyPour.next"].tap()
        capture(app, "05-places")
        app.buttons["weeklyPour.next"].tap()
        capture(app, "06-repeat")
        app.buttons["weeklyPour.next"].tap()
        let share = app.buttons["weeklyPour.sharePreview"]
        if !share.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(share.isHittable)
        capture(app, "07-keepsake")
        share.tap()
        XCTAssertTrue(app.buttons["weeklyPour.shareImage"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["3"].exists)
        let toggle = app.switches["weeklyPour.includePrivate"]
        if !toggle.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(toggle.exists)
        capture(app, "08-share-default")
        toggle.tap()
        app.scrollViews.firstMatch.swipeDown()
        XCTAssertTrue(app.staticTexts["5"].exists)
        capture(app, "09-share-opt-in")
        app.buttons["Done"].tap()
        app.buttons["weeklyPour.archive"].tap()
        XCTAssertTrue(app.navigationBars["Your Weekly Pours"].waitForExistence(timeout: 3))
        capture(app, "10-archive")
    }

    @MainActor func testQuietWeekHasImmediateExitAndJournalInvitation() throws {
        let app = launch(state: "quiet")
        XCTAssertTrue(app.buttons["weeklyPour.next"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["weeklyPour.previous"].exists)
        XCTAssertFalse(app.buttons["weeklyPour.sharePreview"].exists)
        capture(app, "11-quiet")
        app.buttons["weeklyPour.next"].tap()
        XCTAssertTrue(app.buttons["weeklyPour.invitation"].waitForExistence(timeout: 3))
        capture(app, "12-journal-invitation")
        app.buttons["weeklyPour.invitation"].tap()
        XCTAssertTrue(app.buttons["weeklyPour.close"].exists)
    }

    @MainActor func testOneSipHasAShorterStory() throws {
        let app = launch(state: "single")
        XCTAssertTrue(app.buttons["weeklyPour.next"].waitForExistence(timeout: 15))
        capture(app, "13-single")
        app.buttons["weeklyPour.next"].tap()
        XCTAssertTrue(app.buttons["weeklyPour.turnMemory"].exists)
        app.buttons["weeklyPour.next"].tap()
        XCTAssertTrue(app.buttons["weeklyPour.sharePreview"].exists)
    }

    @MainActor func testPhotoFreeAndUnratedWeeksRemainHonest() throws {
        let app = launch(state: "no-photo")
        XCTAssertTrue(app.buttons["weeklyPour.next"].waitForExistence(timeout: 15))
        capture(app, "14-no-photo")
        app.buttons["weeklyPour.next"].tap()
        app.buttons["weeklyPour.next"].tap()
        capture(app, "15-no-photo-standout")
        app.terminate()
        let unrated = launch(state: "unrated")
        XCTAssertTrue(unrated.buttons["weeklyPour.next"].waitForExistence(timeout: 15))
        unrated.buttons["weeklyPour.next"].tap()
        unrated.buttons["weeklyPour.next"].tap()
        XCTAssertFalse(unrated.staticTexts["YOUR HIGHEST-RATED SIP"].exists)
        capture(unrated, "16-unrated")
    }

    @MainActor func testAllPrivateShareStartsEmptyUntilExplicitInclusion() throws {
        let app = launch(state: "private")
        XCTAssertTrue(app.buttons["weeklyPour.next"].waitForExistence(timeout: 15))
        for _ in 0..<5 { app.buttons["weeklyPour.next"].tap() }
        let share = app.buttons["weeklyPour.sharePreview"]
        if !share.isHittable { app.scrollViews.firstMatch.swipeUp() }
        share.tap()
        let export = app.buttons["weeklyPour.shareImage"]
        XCTAssertTrue(export.waitForExistence(timeout: 3))
        XCTAssertFalse(export.isEnabled)
        let toggle = app.switches["weeklyPour.includePrivate"]
        if !toggle.isHittable { app.scrollViews.firstMatch.swipeUp() }
        toggle.tap()
        XCTAssertTrue(export.isEnabled)
        capture(app, "17-private-opt-in")
    }

    @MainActor func testLargestTextReduceMotionKeepsNavigationReachable() throws {
        let app = launch(extra: ["--ui-testing-accessibility-xxxl", "--ui-testing-reduce-motion"])
        XCTAssertTrue(app.buttons["weeklyPour.next"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["weeklyPour.next"].isHittable)
        capture(app, "18-largest-text")
        app.buttons["weeklyPour.next"].tap()
        XCTAssertTrue(app.buttons["weeklyPour.previous"].isHittable)
        app.buttons["weeklyPour.next"].tap()
        XCTAssertTrue(app.buttons["weeklyPour.next"].isHittable)
        capture(app, "19-largest-highlight")
    }

    @MainActor private func launch(state: String = "full", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-weekly-pour", "--weekly-pour-state=\(state)"] + extra
        app.launch()
        return app
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "WeeklyPour-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
