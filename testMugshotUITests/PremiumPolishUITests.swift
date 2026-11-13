import XCTest

final class PremiumPolishUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testSupportCopyAcknowledgesTheActionOnTheCurrentScreen() {
        let app = settings()
        open("Support and Feedback", app)
        let copy = app.buttons["Copy Email Address"]
        reveal(copy, app); copy.tap()
        XCTAssertTrue(app.buttons["Email address copied"].waitForExistence(timeout: 3))
        capture("support-copy-feedback", app)
    }

    @MainActor func testUnavailableDiscoveryDoesNotPresentUnknownValuesAsOff() {
        let app = settings()
        open("Friend Discovery", app)
        XCTAssertTrue(app.staticTexts["Sign in to manage discovery settings."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["Let contacts find me by email"].exists)
        capture("discovery-unavailable", app)
    }

    @MainActor func testLargestTextOnboardingHasReadableNativeContentAndReachableActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-reduce-motion", "--ui-testing-accessibility-xxxl", "--ui-testing-first-launch-onboarding-design-qa"]
        app.launch()
        let title = app.staticTexts["mugshot.firstLaunch.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Capture Every Sip")
        let next = app.buttons["mugshot.firstLaunch.continue"]
        reveal(next, app); next.tap()
        XCTAssertEqual(title.label, "Watch your world take shape.")
        let skip = app.buttons["mugshot.firstLaunch.skip"]
        reveal(skip, app); skip.tap()
        let guest = app.buttons["mugshot.firstLaunch.exploreWithoutAccount"]
        reveal(guest, app)
        XCTAssertTrue(guest.isHittable)
        capture("onboarding-largest-text-account-actions", app)
    }

    @MainActor func testUnavailableReflectionPreferencesOfferAUsefulExplanation() {
        let app = settings()
        open("Reflections and Recaps", app)
        XCTAssertTrue(app.staticTexts["Sign in to manage reflection preferences."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["Monthly reflections"].exists)
        XCTAssertFalse(app.buttons["Save preferences"].exists)
        capture("reflection-unavailable", app)
    }

    @MainActor func testSupportActionsRemainReachableAtLargestText() {
        let app = settings(extra: ["--ui-testing-accessibility-xxxl"])
        open("Support and Feedback", app)
        let copy = app.buttons["Copy Email Address"]
        reveal(copy, app); copy.tap()
        XCTAssertTrue(app.buttons["Email address copied"].waitForExistence(timeout: 3))
        capture("support-largest-text", app)
    }

    @MainActor func testDiscoveryReloadReconcilesAnUncertainWrite() {
        let app = polishFixture()
        app.buttons["Discovery recovery"].tap()
        let retry = app.buttons["settings.discovery.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["People suggestions"].exists)
        capture("discovery-load-failure", app)
        retry.tap()
        let suggestions = app.switches["People suggestions"]
        XCTAssertTrue(suggestions.waitForExistence(timeout: 5))
        XCTAssertEqual(suggestions.value as? String, "1")
        suggestions.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertEqual(suggestions.value as? String, "1", "Last confirmed value must return after a lost acknowledgement.")
        XCTAssertFalse(suggestions.isEnabled)
        capture("discovery-save-uncertain", app)
        retry.tap()
        let reconciled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            suggestions.isEnabled && suggestions.value as? String == "0"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reconciled], timeout: 5), .completed)
    }

    @MainActor func testReflectionLoadRetryAndFailedSaveKeepTheEdits() {
        let app = polishFixture()
        app.buttons["Reflection recovery"].tap()
        let retry = app.buttons["settings.reflections.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5)); retry.tap()
        let monthly = app.switches["Monthly reflections"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5))
        monthly.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(monthly.value as? String, "0")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Mugshot couldn’t confirm the save. Your edits are still here. Try saving again."].waitForExistence(timeout: 5))
        XCTAssertEqual(monthly.value as? String, "0")
        capture("reflection-save-retry", app)
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Saved"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons["Save"].isEnabled)
    }

    @MainActor func testMapLegendHasOneReadableDescriptionAndPassesAccessibilityAudit() throws {
        let app = polishFixture(extra: ["--ui-testing-accessibility-xxxl"])
        app.buttons["Map key"].tap()
        let openKey = app.buttons["map.ratingsLegend.open"]
        XCTAssertTrue(openKey.waitForExistence(timeout: 5)); openKey.tap()
        let legend = app.staticTexts["map.ratingsLegend"]
        XCTAssertTrue(legend.waitForExistence(timeout: 5))
        XCTAssertEqual(legend.label, "Your ratings")
        XCTAssertTrue((legend.value as? String)?.contains("4.0 or higher") == true)
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait])
        capture("map-legend-semantics", app)
        app.buttons["map.ratingsLegend.close"].tap()
        XCTAssertTrue(openKey.waitForExistence(timeout: 5))
    }

    @MainActor func testLargestTextMapKeepsLocationAndKeyReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-accessibility-xxxl", "--ui-testing-reduce-motion"]
        app.launch()
        let key = app.buttons["map.ratingsLegend.open"]
        let location = app.buttons["location.fill"]
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        XCTAssertTrue(location.isHittable)
        XCTAssertLessThanOrEqual(location.frame.maxY, key.frame.minY)
        key.tap()
        XCTAssertTrue(app.staticTexts["map.ratingsLegend"].waitForExistence(timeout: 5))
        app.buttons["map.ratingsLegend.close"].tap()
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        capture("map-largest-text-controls", app)
    }

    @MainActor private func polishFixture(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-reduce-motion", "--ui-testing-premium-polish"] + extra
        app.launch()
        return app
    }

    @MainActor private func settings(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-reduce-motion"] + extra
        app.launch()
        app.buttons["mugshot.tab.journal"].tap()
        app.buttons["Open your profile"].tap()
        open("Settings", app)
        return app
    }

    @MainActor private func open(_ label: String, _ app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        reveal(button, app); button.tap()
    }

    @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<14 {
            if element.exists && element.isHittable && element.frame.minY >= 60 && element.frame.maxY < app.frame.maxY - 24 { return }
            let scroll = app.scrollViews.allElementsBoundByIndex.last ?? app.collectionViews.firstMatch
            if element.exists && element.frame.minY < 60 { scroll.swipeDown() }
            else { scroll.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, "Expected \(element.identifier) to be reachable")
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name
        shot.lifetime = .keepAlways; add(shot)
    }
}
