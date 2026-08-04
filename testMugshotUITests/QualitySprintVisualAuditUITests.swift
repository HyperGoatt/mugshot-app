import XCTest

final class QualitySprintVisualAuditUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFullPostedMugshotEditorEvidence() throws {
        let app = launch("--ui-testing-edit-sip-design-qa")
        XCTAssertTrue(app.staticTexts["Edit Sip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Photos"].exists)
        XCTAssertTrue(app.staticTexts["Caption"].exists)
        XCTAssertTrue(app.buttons["Save sip"].exists)
        attachScreenshot(named: "01 After - Full posted Mugshot editor")

        let scroll = app.scrollViews.firstMatch
        for _ in 0..<5 where !app.staticTexts["Tagged people"].isHittable {
            scroll.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Tagged people"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Amanda"].exists)
        XCTAssertTrue(app.staticTexts["Paul"].exists)
        attachScreenshot(named: "02 After - Editor audiences and tags")
    }

    @MainActor
    func testPrivatePeopleRecapEvidence() throws {
        let app = launch("--ui-testing-people-recap-design-qa")
        XCTAssertTrue(app.staticTexts["Monthly reflection"].waitForExistence(timeout: 5))
        let firstPerson = app.staticTexts["16 sips with Amanda"]
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<6 where !firstPerson.isHittable {
            scroll.swipeUp()
        }
        XCTAssertTrue(firstPerson.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["12 sips with Paul"].exists)
        XCTAssertTrue(app.staticTexts["8 sips with Jake"].exists)
        attachScreenshot(named: "05 After - Private people recap")
    }

    @MainActor
    private func launch(_ route: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", route]
        app.launch()
        return app
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
