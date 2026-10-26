import XCTest

final class SignaturePolishUITests: XCTestCase {
    @MainActor
    func testFailedCafeActionRestoresStateWithoutSuccessNotice() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--saved-audit-scenario=save-failure"]
        app.launch()
        let favorite = app.buttons["Favorited"].firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.tap()
        XCTAssertTrue(app.staticTexts["Could not update this cafe. Your confirmed state was restored."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Removed from Favorites"].exists)
        let restored = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Harborlight Coffee Roasters", "Favorite")).firstMatch
        XCTAssertTrue(restored.exists)
    }

    @MainActor
    func testShortPullCancelsAndLeavingFeedCancelsAnActiveRefresh() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--ui-testing-reset", "--saved-audit-scenario=populated",
            "--ui-testing-feed-refresh-result=success", "--ui-testing-feed-refresh-delay-ms=9000"
        ]
        app.launch()
        let feed = app.buttons["mugshot.tab.feed"]
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let scroll = app.descendants(matching: .any).matching(identifier: "feed.scroll").firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 3))
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 20)))
        let indicator = app.descendants(matching: .any).matching(identifier: "feed.refresh.indicator").firstMatch
        let returnsToRest = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == ''"), object: indicator)
        let partialResult = XCTWaiter.wait(for: [returnsToRest], timeout: 1.5)
        XCTAssertEqual(partialResult, .completed, "Short pull did not return to rest: \(indicator.exists ? indicator.label : "hidden")")

        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 250)))
        let isRefreshing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Refreshing sips"), object: indicator)
        XCTAssertEqual(XCTWaiter.wait(for: [isRefreshing], timeout: 2), .completed)
        app.buttons["mugshot.tab.saved"].tap()
        feed.tap()
        let staysAtRest = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == ''"), object: indicator)
        XCTAssertEqual(XCTWaiter.wait(for: [staysAtRest], timeout: 2), .completed, "Returning to Feed must not restore stale refresh presentation")
    }
}
