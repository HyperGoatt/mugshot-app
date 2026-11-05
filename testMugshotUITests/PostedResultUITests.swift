import XCTest

final class PostedResultUITests: XCTestCase {
    @MainActor private func launch(_ extra: [String] = [], reducedMotion: Bool = true) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out",
                               "--ui-testing-post-result"] + (reducedMotion ? ["--ui-testing-reduce-motion"] : []) + extra
        app.launch()
        return app
    }

    @MainActor func testHomePostHasFullScreenCelebrationThenCleanSharingAndSeePost() {
        let app = launch(reducedMotion: false)
        let result = app.descendants(matching: .any)["mugshot.posted.fullScreen"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["mugshot.posted.share"].isHittable)
        XCTAssertTrue(app.buttons["mugshot.posted.seePost"].isHittable)
        XCTAssertTrue(app.tabBars.allElementsBoundByIndex.isEmpty)
        XCTAssertGreaterThan(app.buttons["mugshot.posted.seePost"].frame.maxY, app.windows.firstMatch.frame.height * 0.85)
        capture(app, "01-full-screen-post")
        app.buttons["mugshot.posted.share"].tap()
        XCTAssertTrue(app.staticTexts["Share your sip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["mugshot.share.preview"].exists || app.images["mugshot.share.preview"].exists)
        XCTAssertFalse(app.staticTexts["Your export"].exists)
        capture(app, "02-clean-share")
        app.buttons["mugshot.share.back"].tap()
        app.buttons["mugshot.posted.seePost"].tap()
        XCTAssertTrue(app.staticTexts["mugshot.fixture.post"].waitForExistence(timeout: 5))
    }

    @MainActor func testCafeAndElsewhereUseTheSamePostedActions() {
        for context in ["--ui-testing-result-cafe", "--ui-testing-result-elsewhere"] {
            let app = launch([context])
            XCTAssertTrue(app.buttons["mugshot.posted.seePost"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.buttons["mugshot.posted.share"].isHittable)
            app.buttons["mugshot.posted.done"].tap()
            XCTAssertFalse(app.buttons["mugshot.posted.share"].exists)
            app.terminate()
        }
    }

    @MainActor func testLargestTextKeepsTheCelebrationActionsReachable() {
        let app = launch(["--ui-testing-accessibility-xxxl"])
        XCTAssertTrue(app.descendants(matching: .any)["mugshot.posted.layout.accessibility"].firstMatch.waitForExistence(timeout: 8))
        let share = app.buttons["mugshot.posted.share"]
        XCTAssertTrue(share.waitForExistence(timeout: 8))
        for _ in 0..<4 where !share.isHittable { app.swipeUp() }
        XCTAssertTrue(share.isHittable)
        capture(app, "03-largest-post-result")
        share.tap()
        XCTAssertTrue(app.staticTexts["Share your sip"].waitForExistence(timeout: 5))
    }

    @MainActor func testPrivateSaveNeverShowsPostedCelebrationOrSeePost() {
        let app = launch(["--ui-testing-private-result"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Saved privately'")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["mugshot.posted.seePost"].exists)
        XCTAssertFalse(app.buttons["mugshot.posted.share"].exists)
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
