import XCTest

final class MapSearchRecentUITests: XCTestCase {
    private enum Identifier {
        static let addTab = "mugshot.tab.add"
        static let mapTab = "mugshot.tab.map"
        static let drinkName = "logASipV3.drinkName"
        static let cafeSelector = "logASipV3.cafe.selector"
        static let cafeSearchSheet = "logASipV3.cafeSearch.sheet"
        static let cafeSearchRecent =
            "logASipV3.cafeSearch.recent.Mugshot Test Cafe|1 Test Street, Charleston, SC"
        static let seededPhoto = "logASipV3.photos.thumbnail.0"
        static let mapSearchQuery = "map.search.query"
        static let mapSearchCancel = "map.search.cancel"
        static let mapSearchResults = "map.search.results"
        static let mapSearchRecent =
            "map.search.recent.Mugshot Test Cafe|1 Test Street, Charleston, SC"
        static let mapCafeCard = "map.cafeDetail.sheet"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLogASipRecentSelectsCafeInOneTapWithoutLosingSetup() throws {
        let app = launch(seedPhoto: true)

        element(Identifier.addTab, in: app).tap()
        type("Iced latte", into: Identifier.drinkName, in: app)

        let cafeSelector = element(Identifier.cafeSelector, in: app)
        reveal(cafeSelector, in: app)
        let searchSheet = element(Identifier.cafeSearchSheet, in: app)
        openCafeSearch(from: cafeSelector, sheet: searchSheet, in: app)
        let recent = element(Identifier.cafeSearchRecent, in: app)
        XCTAssertTrue(recent.waitForExistence(timeout: 3))

        recent.tap()

        XCTAssertTrue(cafeSelector.waitForExistence(timeout: 3))
        XCTAssertEqual(cafeSelector.value as? String, "Mugshot Test Cafe")
        XCTAssertTrue(waitForAbsence(of: searchSheet), "One recent tap should dismiss Choose a cafe.")
        XCTAssertEqual(
            (element(Identifier.drinkName, in: app).value as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            "Iced latte"
        )
        XCTAssertTrue(element(Identifier.seededPhoto, in: app).exists)
        attachScreenshot(named: "08 After - One tap composer cafe selection")
    }

    @MainActor
    func testMapRecentOpensCafeCardInOneTapAndRestoresMapBackground() throws {
        let app = launch(seedPhoto: false)

        element(Identifier.mapTab, in: app).tap()
        let searchField = element(Identifier.mapSearchQuery, in: app)
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()

        let searchResults = element(Identifier.mapSearchResults, in: app)
        XCTAssertTrue(searchResults.waitForExistence(timeout: 3))
        let recent = element(Identifier.mapSearchRecent, in: app)
        XCTAssertTrue(recent.waitForExistence(timeout: 3))

        recent.tap()

        let cafeCard = element(Identifier.mapCafeCard, in: app)
        XCTAssertTrue(cafeCard.waitForExistence(timeout: 3), "One recent tap should open the cafe card.")
        XCTAssertTrue(app.staticTexts["Mugshot Test Cafe"].exists)
        XCTAssertTrue(
            waitForAbsence(of: searchResults),
            "The search results should leave the background when the cafe card opens."
        )
        XCTAssertTrue(
            waitForAbsence(of: element(Identifier.mapSearchCancel, in: app)),
            "Cancel should leave with the active search interface."
        )
        XCTAssertTrue(
            waitForAbsence(of: searchField),
            "The search field should leave so the cafe card sits over only the map."
        )
        XCTAssertFalse(app.staticTexts["Recent"].exists)
        attachScreenshot(named: "09 After - One tap Map cafe selection")

        let closeCafeCard = app.buttons["Close cafe card"]
        XCTAssertTrue(closeCafeCard.waitForExistence(timeout: 3))
        closeCafeCard.tap()
        XCTAssertTrue(
            element(Identifier.mapSearchQuery, in: app).waitForExistence(timeout: 3),
            "Closing the cafe card should restore Map discovery controls."
        )
    }

    @MainActor
    private func launch(seedPhoto: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-seed-map-search-recent"
        ] + (seedPhoto ? ["--ui-testing-seed-photo"] : [])
        app.launch()
        XCTAssertTrue(element(Identifier.addTab, in: app).waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func type(_ value: String, into identifier: String, in app: XCUIApplication) {
        let field = element(identifier, in: app)
        reveal(field, in: app)
        field.tap()
        field.typeText(value)
    }

    @MainActor
    private func openCafeSearch(
        from selector: XCUIElement,
        sheet: XCUIElement,
        in app: XCUIApplication
    ) {
        dismissKeyboardIfNeeded(in: app)
        positionAboveComposerFooter(selector, in: app)
        selector.tap()
        if !sheet.waitForExistence(timeout: 1) {
            // XCTest can consume the first synthetic tap solely to end text-field
            // editing. Reposition after the keyboard transition, then retry the
            // same real user action instead of inserting text with Return.
            XCTAssertTrue(
                app.keyboards.firstMatch.waitForNonExistence(timeout: 3),
                "Expected tapping the cafe selector to end drink-name editing."
            )
            positionAboveComposerFooter(selector, in: app)
            selector.tap()
        }
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
    }

    @MainActor
    private func dismissKeyboardIfNeeded(in app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        // The composer also contains a horizontal photo strip. Drag the
        // full-height vertical surface so SwiftUI's interactive keyboard
        // dismissal receives the gesture instead of the photo scroller.
        let scrollView = composerScrollView(in: app)
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(
            keyboard.waitForNonExistence(timeout: 3),
            "Expected the composer drag to dismiss the drink-name keyboard."
        )
    }

    @MainActor
    private func composerScrollView(in app: XCUIApplication) -> XCUIElement {
        app.scrollViews.allElementsBoundByIndex.max { lhs, rhs in
            lhs.frame.height < rhs.frame.height
        } ?? app.scrollViews.firstMatch
    }

    @MainActor
    private func positionAboveComposerFooter(
        _ target: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 10
    ) {
        let footer = element("logASipV3.primaryAction", in: app)
        XCTAssertTrue(target.waitForExistence(timeout: 3))
        XCTAssertTrue(footer.waitForExistence(timeout: 3))

        var swipes = 0
        while swipes < maximumSwipes {
            let targetFrame = target.frame
            let isSafelyVisible = target.isHittable
                && targetFrame.minY >= 112
                && targetFrame.maxY <= footer.frame.minY - 8
            if isSafelyVisible { break }
            if targetFrame.maxY > footer.frame.minY - 8 {
                composerScrollView(in: app).swipeUp()
            } else {
                composerScrollView(in: app).swipeDown()
            }
            swipes += 1
        }
        XCTAssertTrue(
            target.isHittable
                && target.frame.minY >= 112
                && target.frame.maxY <= footer.frame.minY - 8,
            "Expected \(target) to sit above the fixed composer action before tapping."
        )
    }

    @MainActor
    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 10
    ) {
        var swipes = 0
        while swipes < maximumSwipes, !element.isHittable {
            composerScrollView(in: app).swipeUp()
            swipes += 1
        }
        XCTAssertTrue(
            element.waitForExistence(timeout: 3) && element.isHittable,
            "Expected \(element) to become visible and tappable."
        )
    }

    @MainActor
    private func waitForAbsence(of element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
