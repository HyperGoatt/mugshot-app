import XCTest

final class CoffeeAssistanceUITests: XCTestCase {
    @MainActor
    private func launch(failure: Bool = false, accessible: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-coffee-assistance"]
        if failure { app.launchArguments.append("--ui-testing-coffee-assistance-failure") }
        if accessible { app.launchArguments += ["--ui-testing-accessibility-xxxl", "--ui-testing-reduce-motion"] }
        app.launch()
        app.buttons["coffeeAssistance.fixture.open"].tap()
        return app
    }
    @MainActor
    private func allowAndAsk(_ app: XCUIApplication) {
        let consent = app.switches["coffeeAssistance.consent"]
        for _ in 0..<4 where !consent.isHittable { app.swipeUp() }
        XCTAssertTrue(consent.waitForExistence(timeout: 3))
        consent.tap()
        let generate = app.buttons["coffeeAssistance.generate"]
        for _ in 0..<4 where !generate.isHittable { app.swipeUp() }
        XCTAssertTrue(generate.isEnabled)
        generate.tap()
    }
    @MainActor
    func testConsentStartsOffAndClosingNeverChangesOriginal() {
        let app = launch()
        XCTAssertFalse(app.buttons["coffeeAssistance.generate"].isEnabled)
        app.buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts["coffeeAssistance.fixture.origin"].label, "Original origin")
    }
    @MainActor
    func testProviderFailureKeepsOriginalAndCanBeDismissed() {
        let app = launch(failure: true)
        allowAndAsk(app)
        let message = app.staticTexts["Suggestions are unavailable right now. You can continue with your original details."]
        for _ in 0..<4 where !message.isHittable { app.swipeUp() }
        XCTAssertTrue(message.waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["coffeeAssistance.accept"].exists)
        app.buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts["coffeeAssistance.fixture.origin"].label, "Original origin")
    }
    @MainActor
    func testOnlyExplicitReviewedAcceptanceChangesEditableField() {
        let app = launch()
        allowAndAsk(app)
        let accept = app.buttons["coffeeAssistance.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 4))
        for _ in 0..<5 where !accept.isHittable { app.swipeUp() }
        accept.tap()
        XCTAssertEqual(app.staticTexts["coffeeAssistance.fixture.origin"].label, "Colombia")
    }
    @MainActor
    func testConsentAndFailureRemainReachableWithLargestTextAndReduceMotion() {
        let app = launch(failure: true, accessible: true)
        allowAndAsk(app)
        let message = app.staticTexts["Suggestions are unavailable right now. You can continue with your original details."]
        for _ in 0..<6 where !message.isHittable { app.swipeUp() }
        XCTAssertTrue(message.waitForExistence(timeout: 4))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "optional-helper-largest-text-fallback"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts["coffeeAssistance.fixture.origin"].label, "Original origin")
    }
}
