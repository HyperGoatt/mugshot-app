import XCTest

final class testMugshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGuidedQuickSipTenCleanRunsUnderTwentySeconds() throws {
        let app = launch(reset: true)
        var durations: [TimeInterval] = []

        for run in 1...10 {
            let startedAt = Date()
            openHomeQuickSip(in: app, drinkName: "Phase zero cortado \(run)")
            chooseQuickRating(in: app)

            let primaryAction = app.buttons["sipComposer.primaryAction"]
            XCTAssertTrue(primaryAction.isEnabled, "Quick Sip should be saveable after context, drink, and rating.")
            primaryAction.tap()

            XCTAssertTrue(
                app.buttons["Add"].waitForExistence(timeout: 5),
                "A successful save should return to the prior tab and expose Add for the next run."
            )
            let duration = Date().timeIntervalSince(startedAt)
            durations.append(duration)
            XCTAssertLessThan(duration, 20, "Clean Quick Sip run \(run) took \(duration) seconds.")
        }

        let median = durations.sorted()[durations.count / 2]
        XCTAssertLessThan(median, 20, "Median clean Quick Sip time was \(median) seconds.")

        let report = durations.enumerated()
            .map { "Run \($0.offset + 1): \(String(format: "%.2f", $0.element))s" }
            .joined(separator: "\n") + "\nMedian: \(String(format: "%.2f", median))s"
        let attachment = XCTAttachment(string: report)
        attachment.name = "Phase 0 Quick Sip timing"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testEveryoneTextOnlyGuardAndDraftRestoration() throws {
        let app = launch(reset: true)
        openHomeQuickSip(in: app, drinkName: "Draft restoration latte")
        chooseQuickRating(in: app)

        app.buttons["Add optional details"].tap()
        XCTAssertTrue(app.staticTexts["Keep what mattered."].waitForExistence(timeout: 2))

        app.buttons["Everyone"].tap()
        app.buttons["sipComposer.primaryAction"].tap()
        XCTAssertTrue(
            app.staticTexts["Add a one-line thought or photo before sharing this sip with Everyone."].waitForExistence(timeout: 2),
            "Everyone must reject a textless, photo-less post."
        )

        app.buttons["Previous step"].tap()
        app.buttons["Previous step"].tap()
        let caption = app.textFields["sipComposer.socialCaption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 2))
        caption.tap()
        caption.typeText("A text-only sip worth remembering")
        app.buttons["sipComposer.primaryAction"].tap()
        app.buttons["Add optional details"].tap()
        app.buttons["sipComposer.primaryAction"].tap()

        XCTAssertTrue(app.alerts["Publish without a photo?"].waitForExistence(timeout: 2))
        app.alerts["Publish without a photo?"].buttons["Cancel"].tap()

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        XCTAssertTrue(
            app.staticTexts["Keep what mattered."].waitForExistence(timeout: 3),
            "A meaningful draft should restore to its persisted guided step after relaunch."
        )
        XCTAssertTrue(app.buttons["Everyone"].isSelected, "The selected audience should restore with the draft.")
        app.buttons["Private"].tap()
        XCTAssertTrue(app.buttons["Private"].isSelected)
        app.buttons["Previous step"].tap()
        app.buttons["Previous step"].tap()
        XCTAssertEqual(app.textFields["sipComposer.socialCaption"].value as? String, "A text-only sip worth remembering")
    }

    @MainActor
    func testHomeTastingLensFriendsSaveReopensWithBreakdown() throws {
        let app = launch(reset: true)
        let drinkName = "Friends tasting lens Chemex"
        openHomeQuickSip(in: app, drinkName: drinkName)

        let tastingLens = app.buttons["sipComposer.ratingMode.lens"]
        tastingLens.tap()
        XCTAssertTrue(tastingLens.isSelected)
        XCTAssertFalse(app.otherElements["sipComposer.overallRating"].exists)

        let presentationRating = app.otherElements["Presentation"]
        XCTAssertTrue(presentationRating.waitForExistence(timeout: 2))
        presentationRating.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["sipComposer.primaryAction"].isEnabled)

        app.scrollViews.firstMatch.swipeUp()
        tapAfterRevealing(app.buttons["Add optional details"], in: app)
        XCTAssertTrue(app.staticTexts["Keep what mattered."].waitForExistence(timeout: 2))
        tapAfterRevealing(app.buttons["Friends"], in: app)
        let friendsSelected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: app.buttons["Friends"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [friendsSelected], timeout: 2), .completed)
        app.buttons["sipComposer.primaryAction"].tap()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        let savedDrink = app.staticTexts[drinkName]
        XCTAssertTrue(savedDrink.waitForExistence(timeout: 3))
        app.buttons["Open sip"].tap()

        XCTAssertTrue(app.buttons["Close sip"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Flavor map"].exists)
        XCTAssertTrue(app.staticTexts["Presentation"].exists)
    }

    @MainActor
    func testSavedCafeEntryPointPreselectsCafeAndReopensSip() throws {
        let app = launch(reset: true)
        let drinkName = "Preselected cafe flat white"

        app.buttons["Saved"].tap()
        XCTAssertTrue(app.staticTexts["Mugshot Test Cafe"].waitForExistence(timeout: 3))
        app.buttons["Log a visit"].tap()

        XCTAssertTrue(app.staticTexts["Where did this happen?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Mugshot Test Cafe"].exists)
        XCTAssertTrue(app.buttons["Cafe"].isSelected)
        app.buttons["sipComposer.primaryAction"].tap()

        let drinkField = app.textFields["sipComposer.drinkName"]
        XCTAssertTrue(drinkField.waitForExistence(timeout: 2))
        drinkField.tap()
        drinkField.typeText(drinkName)
        app.buttons["sipComposer.primaryAction"].tap()
        chooseQuickRating(in: app)
        tapAfterRevealing(app.buttons["Add optional details"], in: app)
        tapAfterRevealing(app.buttons["Friends"], in: app)
        app.buttons["sipComposer.primaryAction"].tap()

        XCTAssertTrue(app.buttons["Feed"].waitForExistence(timeout: 5))
        app.buttons["Feed"].tap()
        XCTAssertTrue(app.staticTexts[drinkName].waitForExistence(timeout: 3))
        app.buttons["Open sip"].tap()
        XCTAssertTrue(app.buttons["Close sip"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Mugshot Test Cafe"].exists)
    }

    @MainActor
    func testPhotoDraftSurvivesFailedSaveRelaunchAndRetry() throws {
        let failureArguments = ["--ui-testing-seed-photo", "--ui-testing-fail-first-save"]
        let app = launch(reset: true, extraArguments: failureArguments)
        let drinkName = "Recovered photo cappuccino"

        openHomeQuickSip(in: app, drinkName: drinkName, expectedPhotoCount: 1)
        chooseQuickRating(in: app)
        tapAfterRevealing(app.buttons["Add optional details"], in: app)
        tapAfterRevealing(app.buttons["Friends"], in: app)
        app.buttons["sipComposer.primaryAction"].tap()

        XCTAssertTrue(app.staticTexts["We couldn’t finish this save. Your sip is safe—try again."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Retry save"].exists)

        app.terminate()
        app.launchArguments = ["--ui-testing"] + failureArguments
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["Keep what mattered."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Retry save"].exists)
        app.buttons["Previous step"].tap()
        app.buttons["Previous step"].tap()
        XCTAssertTrue(app.staticTexts["1 photo"].waitForExistence(timeout: 2))
        app.buttons["sipComposer.primaryAction"].tap()
        app.buttons["Add optional details"].tap()
        XCTAssertTrue(app.buttons["Friends"].isSelected)
        XCTAssertTrue(app.staticTexts["Retry save"].exists)
        app.buttons["sipComposer.primaryAction"].tap()

        XCTAssertTrue(app.buttons["Feed"].waitForExistence(timeout: 5))
        app.buttons["Feed"].tap()
        XCTAssertTrue(app.staticTexts[drinkName].waitForExistence(timeout: 3))
        app.buttons["Open sip"].tap()
        XCTAssertTrue(app.buttons["Close sip"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["No photo saved"].exists)
    }

    @MainActor
    func testAuthenticationInterruptionKeepsPrivateDraftUntilRelaunch() throws {
        let app = launch(reset: true, extraArguments: ["--ui-testing-interrupt-auth-once"])
        let drinkName = "Interrupted auth mocha"

        openHomeQuickSip(in: app, drinkName: drinkName)
        chooseQuickRating(in: app)
        app.buttons["sipComposer.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Sign back in to save. Your draft will stay here."].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 3))
        app.buttons["Previous step"].tap()
        XCTAssertTrue(app.textFields["sipComposer.drinkName"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields["sipComposer.drinkName"].value as? String, drinkName)
        app.buttons["sipComposer.primaryAction"].tap()
        app.buttons["sipComposer.primaryAction"].tap()

        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 5))
        app.buttons["Profile"].tap()
        let savedDrink = app.staticTexts[drinkName]
        for _ in 0..<6 where !savedDrink.exists {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(savedDrink.waitForExistence(timeout: 3))
        app.buttons["Open sip"].tap()
        XCTAssertTrue(app.buttons["Close sip"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testGuidedCoreStepsPassAccessibilityAudit() throws {
        let app = launch(reset: true)
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Where did this happen?"].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait])

        app.buttons["Home"].tap()
        app.buttons["sipComposer.primaryAction"].tap()
        let drinkField = app.textFields["sipComposer.drinkName"]
        XCTAssertTrue(drinkField.waitForExistence(timeout: 2))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait])

        drinkField.tap()
        drinkField.typeText("Accessibility audit cortado")
        app.buttons["sipComposer.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait])
    }

    @MainActor
    private func launch(reset: Bool, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + (reset ? ["--ui-testing-reset"] : []) + extraArguments
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func openHomeQuickSip(
        in app: XCUIApplication,
        drinkName: String,
        expectedPhotoCount: Int? = nil
    ) {
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Where did this happen?"].waitForExistence(timeout: 2))
        app.buttons["Home"].tap()
        app.buttons["sipComposer.primaryAction"].tap()

        let drinkField = app.textFields["sipComposer.drinkName"]
        XCTAssertTrue(drinkField.waitForExistence(timeout: 2))
        drinkField.tap()
        drinkField.typeText(drinkName)
        if let expectedPhotoCount {
            XCTAssertTrue(
                app.staticTexts["\(expectedPhotoCount) photo\(expectedPhotoCount == 1 ? "" : "s")"].waitForExistence(timeout: 2)
            )
        }
        app.buttons["sipComposer.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 2))
    }

    @MainActor
    private func chooseQuickRating(in app: XCUIApplication) {
        let rating = app.otherElements["sipComposer.overallRating"]
        XCTAssertTrue(rating.waitForExistence(timeout: 2))
        rating.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["sipComposer.primaryAction"].isEnabled)
    }

    @MainActor
    private func tapAfterRevealing(_ element: XCUIElement, in app: XCUIApplication, maximumSwipes: Int = 8) {
        XCTAssertTrue(element.waitForExistence(timeout: 2))
        var swipes = 0
        let safeTop: CGFloat = 120
        let safeBottom: CGFloat = 680
        while swipes < maximumSwipes {
            let frame = element.frame
            if element.isHittable, frame.minY >= safeTop, frame.maxY <= safeBottom { break }
            if frame.minY < safeTop {
                app.scrollViews.firstMatch.swipeDown()
            } else {
                app.scrollViews.firstMatch.swipeUp()
            }
            swipes += 1
        }
        XCTAssertTrue(
            element.isHittable && element.frame.minY >= safeTop && element.frame.maxY <= safeBottom,
            "Expected \(element) to become fully visible after scrolling."
        )
        element.tap()
    }
}
