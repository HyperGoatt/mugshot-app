import XCTest

final class MugshotOnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureEverySipOnboardingToursTheRealAppAndStartsGuidedSip() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-reduce-motion",
            "--ui-testing-signed-in-onboarding-design-qa"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Capture Every Sip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Private by default · Yours to shape"].exists)
        attachScreenshot(named: "Onboarding 1 - Capture Every Sip")

        app.buttons["mugshot.onboarding.primary"].tap()
        XCTAssertTrue(app.staticTexts["Every sip leaves a little map"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Your first Mugshot starts Private"].exists)
        attachScreenshot(named: "Onboarding 2 - Every sip leaves a map")

        app.buttons["mugshot.onboarding.primary"].tap()
        XCTAssertTrue(app.staticTexts["Let’s make Mugshot yours"].waitForExistence(timeout: 2))
        let nearby = app.buttons["mugshot.onboarding.goal.nearby"]
        XCTAssertEqual(nearby.value as? String, "Selected")

        let journal = app.buttons["mugshot.onboarding.goal.journal"]
        journal.tap()
        XCTAssertEqual(journal.value as? String, "Selected")
        XCTAssertEqual(nearby.value as? String, "Not selected")
        attachScreenshot(named: "Onboarding 3 - Make Mugshot yours")

        app.buttons["mugshot.onboarding.primary"].tap()
        XCTAssertTrue(app.staticTexts["Read your coffee world at a glance"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["MAP · PINS + RANKINGS"].exists)
        attachScreenshot(named: "Onboarding 4 - Live Map tour")

        app.buttons["mugshot.productTour.next"].tap()
        XCTAssertTrue(app.staticTexts["See the sips worth noticing"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["mugshot.tab.feed"].value as? String, "Selected")
        attachScreenshot(named: "Onboarding 5 - Live Feed tour")

        app.buttons["mugshot.productTour.next"].tap()
        XCTAssertTrue(app.staticTexts["Turn curiosity into a plan"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["mugshot.tab.saved"].value as? String, "Selected")
        attachScreenshot(named: "Onboarding 6 - Live Saved and Lists tour")

        app.buttons["mugshot.productTour.next"].tap()
        XCTAssertTrue(app.staticTexts["Everything you log comes home here"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["mugshot.tab.journal"].value as? String, "Selected")
        attachScreenshot(named: "Onboarding 7 - Live Journal tour")

        app.buttons["mugshot.productTour.next"].tap()
        XCTAssertTrue(app.staticTexts["Ready to capture your first sip?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["mugshot.productTour.startFirstSip"].exists)
        XCTAssertTrue(app.buttons["mugshot.productTour.later"].exists)
        attachScreenshot(named: "Onboarding 8 - First sip choice")

        app.buttons["mugshot.productTour.startFirstSip"].tap()
        XCTAssertTrue(app.staticTexts["Start with the scene"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Ready to capture your first sip?"].exists)
        attachScreenshot(named: "First Sip 1 - Mugsy guided setup")
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
