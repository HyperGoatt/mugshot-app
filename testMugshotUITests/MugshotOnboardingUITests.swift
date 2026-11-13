import XCTest

final class MugshotOnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchMarketingOnboardingShowsAllEightImplementedScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-reduce-motion",
            "--ui-testing-first-launch-onboarding-design-qa"
        ]
        app.launch()

        let continueButton = app.buttons["mugshot.firstLaunch.continue"]
        let skipButton = app.buttons["mugshot.firstLaunch.accountSetup"]

        for step in 1...7 {
            XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
            XCTAssertTrue(skipButton.exists)
            attachScreenshot(named: "First Launch \(step) of 8")
            continueButton.tap()
        }

        XCTAssertTrue(app.buttons["mugshot.firstLaunch.createAccount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mugshot.firstLaunch.signIn"].exists)
        XCTAssertTrue(app.buttons["mugshot.firstLaunch.exploreWithoutAccount"].exists)
        XCTAssertFalse(continueButton.exists)
        attachScreenshot(named: "First Launch 8 of 8")
    }

    @MainActor
    func testFirstLaunchSkipJumpsToAccountChoice() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-reduce-motion",
            "--ui-testing-first-launch-onboarding-design-qa"
        ]
        app.launch()

        let skipButton = app.buttons["mugshot.firstLaunch.skip"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        XCTAssertTrue(app.buttons["mugshot.firstLaunch.createAccount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mugshot.firstLaunch.signIn"].exists)
        XCTAssertTrue(app.buttons["mugshot.firstLaunch.exploreWithoutAccount"].exists)
        XCTAssertFalse(app.buttons["mugshot.firstLaunch.continue"].exists)
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
        let tourLabels = ["YOUR COFFEE MAP", "THE FEED", "YOUR CAFE LIBRARY", "YOUR JOURNAL", "A SHORTCUT YOU’LL LOVE"]
        for (index, label) in tourLabels.enumerated() {
            let heading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
            XCTAssertTrue(heading.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["mugshot.onboarding.primary"].exists, "Introduction must dismiss before the tour can receive input.")
            attachScreenshot(named: "Onboarding tour \(index + 1)")
            if index < tourLabels.count - 1 { app.buttons["mugshot.productTour.next"].tap() }
        }
        XCTAssertTrue(app.buttons["mugshot.productTour.startFirstSip"].exists)
        XCTAssertTrue(app.buttons["mugshot.productTour.later"].exists)

        app.buttons["mugshot.productTour.startFirstSip"].tap()
        XCTAssertTrue(app.buttons["logASipV3.context.cafe"].waitForExistence(timeout: 5))
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
