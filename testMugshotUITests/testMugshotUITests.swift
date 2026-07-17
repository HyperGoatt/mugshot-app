import XCTest

final class testMugshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSignedOutShellKeepsMapAndSavedOpenAndGatesJournalActions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out"]
        app.launch()

        XCTAssertTrue(app.buttons["Map"].waitForExistence(timeout: 5))
        let savedTab = app.buttons["mugshot.tab.saved"]
        XCTAssertTrue(savedTab.exists)
        XCTAssertTrue(
            app.buttons.matching(identifier: "Map").allElementsBoundByIndex.contains(where: \.isSelected)
        )
        XCTAssertTrue(app.textFields["Search places"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.alerts.firstMatch.exists, "Guest discovery should not request permission at launch.")

        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Start your sip journal"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Keep exploring"].exists)
        app.buttons["Keep exploring"].tap()

        XCTAssertTrue(app.buttons["Map"].waitForExistence(timeout: 2))
        app.buttons["Feed"].tap()
        XCTAssertTrue(app.staticTexts["Friends make discovery better"].waitForExistence(timeout: 3))
        app.buttons["Keep exploring"].tap()

        savedTab.tap()
        XCTAssertTrue(savedTab.isSelected)
    }

    @MainActor
    func testJournalAccountMenuOpensSettings() throws {
        let app = launch(reset: true)
        app.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["Open your profile"].waitForExistence(timeout: 3))
        app.buttons["Open your profile"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Coffee Preferences"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    @MainActor
    func testRepeatedTabSwitchingKeepsJournalInteractive() throws {
        let app = launch(reset: true)
        let map = app.buttons["mugshot.tab.map"]
        let feed = app.buttons["mugshot.tab.feed"]
        let saved = app.buttons["mugshot.tab.saved"]
        let journal = app.buttons["mugshot.tab.journal"]

        for pass in 1...4 {
            map.tap()
            XCTAssertTrue(app.textFields["Search places"].waitForExistence(timeout: 3), "Map failed on pass \(pass)")
            feed.tap()
            XCTAssertTrue(app.staticTexts["Feed"].waitForExistence(timeout: 3), "Feed failed on pass \(pass)")
            saved.tap()
            XCTAssertTrue(saved.isSelected, "Saved failed on pass \(pass)")
            journal.tap()
            XCTAssertTrue(
                app.buttons["Open your profile"].waitForExistence(timeout: 3),
                "Journal stopped responding on pass \(pass)"
            )
        }

        app.buttons["Open your profile"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
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
            XCTAssertTrue(app.staticTexts["Who should see this sip?"].waitForExistence(timeout: 2))
            primaryAction.tap()
            finishSuccessfulSip(in: app)

            XCTAssertTrue(
                app.buttons["Add"].waitForExistence(timeout: 5),
                "The explicit completion action should open Journal and expose Add for the next run."
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

        app.buttons["sipComposer.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Who should see this sip?"].waitForExistence(timeout: 2))

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
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 2))
        app.buttons["sipComposer.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Who should see this sip?"].waitForExistence(timeout: 2))
        app.buttons["sipComposer.primaryAction"].tap()

        XCTAssertTrue(app.alerts["Publish without a photo?"].waitForExistence(timeout: 2))
        app.alerts["Publish without a photo?"].buttons["Cancel"].tap()

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        XCTAssertTrue(
            app.staticTexts["Who should see this sip?"].waitForExistence(timeout: 3),
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
        XCTAssertTrue(app.staticTexts["Make the Lens fit the drink."].waitForExistence(timeout: 3))

        let lensPrimary = app.buttons["tastingLens2.primary"]
        XCTAssertTrue(lensPrimary.isEnabled)
        lensPrimary.tap()

        let ownWords = app.descendants(matching: .any)["tastingLens2.ownWords"]
        XCTAssertTrue(ownWords.waitForExistence(timeout: 2))
        ownWords.tap()
        ownWords.typeText("Citrus, tea-like, silky")
        lensPrimary.tap()

        let customFlavor = app.textFields["tastingLens2.flavor.custom"]
        XCTAssertTrue(customFlavor.waitForExistence(timeout: 2))
        customFlavor.tap()
        customFlavor.typeText("orange peel")
        lensPrimary.tap()

        XCTAssertTrue(app.staticTexts["Notice what arrives first."].waitForExistence(timeout: 2))
        lensPrimary.tap()

        var answeredCriteria = 0
        let unsure = app.buttons["tastingLens2.criterion.state.unsure"]
        let enjoyment = app.otherElements["tastingLens2.enjoyment.stars"]
        while !enjoyment.exists, answeredCriteria < 24 {
            XCTAssertTrue(
                unsure.waitForExistence(timeout: 2),
                "Every typed observation must preserve a Not sure yet path."
            )
            unsure.tap()
            lensPrimary.tap()
            answeredCriteria += 1
        }
        XCTAssertLessThan(answeredCriteria, 24, "Guided Lens did not reach independent enjoyment.")
        XCTAssertTrue(enjoyment.waitForExistence(timeout: 2))
        enjoyment.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.5)).tap()
        lensPrimary.tap()

        XCTAssertTrue(app.staticTexts["A memory, not a formula."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Citrus, tea-like, silky")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["The observations do not calculate these stars"].exists == false)
        lensPrimary.tap()

        XCTAssertTrue(app.staticTexts["Your guided tasting is captured"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["sipComposer.primaryAction"].isEnabled)

        tapAfterRevealing(app.buttons["sipComposer.primaryAction"], in: app)
        XCTAssertTrue(app.staticTexts["Who should see this sip?"].waitForExistence(timeout: 2))
        tapAfterRevealing(app.buttons["Friends"], in: app)
        let friendsSelected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: app.buttons["Friends"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [friendsSelected], timeout: 2), .completed)
        app.buttons["sipComposer.primaryAction"].tap()
        finishSuccessfulSip(in: app, captureCompletion: true)

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        let savedDrink = app.staticTexts[drinkName]
        XCTAssertTrue(savedDrink.waitForExistence(timeout: 3))
        app.buttons["Open sip"].tap()

        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Taste snapshot"].exists)
        XCTAssertFalse(app.staticTexts["Presentation"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Citrus, tea-like, silky")).firstMatch.exists)
        XCTAssertTrue(app.buttons["View sensory trail"].exists)

        app.buttons["View sensory trail"].tap()

        XCTAssertTrue(app.staticTexts["Not sure yet"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Hide details"].exists)
    }

    @MainActor
    func testFeedSipUsesImmersivePourPushAndOwnerSurfaces() throws {
        let app = launch(reset: true)
        let drinkName = "Immersive Pour cortado"
        openHomeQuickSip(in: app, drinkName: drinkName)
        chooseQuickRating(in: app)
        tapAfterRevealing(app.buttons["sipComposer.primaryAction"], in: app)
        tapAfterRevealing(app.buttons["Friends"], in: app)
        app.buttons["sipComposer.primaryAction"].tap()
        finishSuccessfulSip(in: app)

        app.buttons["Feed"].tap()
        XCTAssertTrue(app.staticTexts[drinkName].waitForExistence(timeout: 4))
        let openSip = app.buttons["Open sip"]

        XCTAssertTrue(openSip.waitForExistence(timeout: 3))
        openSip.tap()

        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["sip.detail.screen"].exists)
        XCTAssertTrue(app.staticTexts["Taste snapshot"].exists)
        XCTAssertTrue(app.staticTexts["Visit details"].exists)
        XCTAssertFalse(app.buttons["mugshot.tab.feed"].exists, "The app dock should yield to sip detail.")
        XCTAssertTrue(app.buttons["Sip actions"].exists)

        app.buttons["Sip actions"].tap()
        XCTAssertTrue(app.buttons["Edit Sip"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Delete Sip"].exists)
        app.buttons["Edit Sip"].tap()

        XCTAssertTrue(app.staticTexts["Edit sip"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Public note"].exists)
        XCTAssertTrue(app.staticTexts["Private note"].exists)
        XCTAssertTrue(app.buttons["Save sip"].exists)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testSavedCafeEntryPointPreselectsCafeAndReopensSip() throws {
        let app = launch(reset: true)
        let drinkName = "Preselected cafe flat white"

        app.buttons["Saved"].tap()
        XCTAssertTrue(app.staticTexts["Mugshot Test Cafe"].waitForExistence(timeout: 3))
        tapAfterRevealing(app.buttons["Log a visit"], in: app)

        XCTAssertTrue(app.staticTexts["Where did this happen?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mugshot Test Cafe"].exists)
        XCTAssertTrue(app.buttons["Cafe"].isSelected)
        app.buttons["sipComposer.primaryAction"].tap()

        let drinkField = app.textFields["sipComposer.drinkName"]
        XCTAssertTrue(drinkField.waitForExistence(timeout: 2))
        drinkField.tap()
        drinkField.typeText(drinkName)
        app.buttons["sipComposer.primaryAction"].tap()
        chooseQuickRating(in: app)
        tapAfterRevealing(app.buttons["sipComposer.primaryAction"], in: app)
        tapAfterRevealing(app.buttons["Friends"], in: app)
        app.buttons["sipComposer.primaryAction"].tap()
        finishSuccessfulSip(in: app)

        XCTAssertTrue(app.buttons["Feed"].waitForExistence(timeout: 5))
        app.buttons["Feed"].tap()
        XCTAssertTrue(app.staticTexts[drinkName].waitForExistence(timeout: 3))
        app.buttons["Open sip"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Mugshot Test Cafe"].exists)
    }

    @MainActor
    func testPhotoDraftSurvivesFailedSaveRelaunchAndRetry() throws {
        let failureArguments = ["--ui-testing-seed-photo", "--ui-testing-fail-first-save"]
        let app = launch(reset: true, extraArguments: failureArguments)
        let drinkName = "Recovered photo cappuccino"

        openHomeQuickSip(in: app, drinkName: drinkName, expectedPhotoCount: 1)
        chooseQuickRating(in: app)
        tapAfterRevealing(app.buttons["sipComposer.primaryAction"], in: app)
        tapAfterRevealing(app.buttons["Friends"], in: app)
        app.buttons["sipComposer.primaryAction"].tap()

        XCTAssertTrue(app.staticTexts["We couldn’t finish this save. Your sip is safe—try again."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Retry save"].exists)

        app.terminate()
        app.launchArguments = ["--ui-testing"] + failureArguments
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["Who should see this sip?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Retry save"].exists)
        app.buttons["Previous step"].tap()
        app.buttons["Previous step"].tap()
        XCTAssertTrue(app.staticTexts["1 photo"].waitForExistence(timeout: 2))
        app.buttons["sipComposer.primaryAction"].tap()
        app.buttons["sipComposer.primaryAction"].tap()
        XCTAssertTrue(app.buttons["Friends"].isSelected)
        XCTAssertTrue(app.staticTexts["Retry save"].exists)
        app.buttons["sipComposer.primaryAction"].tap()
        finishSuccessfulSip(in: app)

        XCTAssertTrue(app.buttons["Feed"].waitForExistence(timeout: 5))
        app.buttons["Feed"].tap()
        XCTAssertTrue(app.staticTexts[drinkName].waitForExistence(timeout: 3))
        app.buttons["Open sip"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["No photo saved"].exists)
    }

    @MainActor
    func testAuthenticationInterruptionKeepsPrivateDraftUntilRelaunch() throws {
        let app = launch(reset: true, extraArguments: ["--ui-testing-interrupt-auth-once"])
        let drinkName = "Interrupted auth mocha"

        openHomeQuickSip(in: app, drinkName: drinkName)
        chooseQuickRating(in: app)
        app.buttons["sipComposer.primaryAction"].tap()
        app.buttons["sipComposer.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Sign back in to save. Your draft will stay here."].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["Who should see this sip?"].waitForExistence(timeout: 3))
        app.buttons["Previous step"].tap()
        app.buttons["Previous step"].tap()
        XCTAssertTrue(app.textFields["sipComposer.drinkName"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields["sipComposer.drinkName"].value as? String, drinkName)
        app.buttons["sipComposer.primaryAction"].tap()
        app.buttons["sipComposer.primaryAction"].tap()
        app.buttons["sipComposer.primaryAction"].tap()
        finishSuccessfulSip(in: app)

        XCTAssertTrue(app.buttons["Journal"].waitForExistence(timeout: 5))
        app.buttons["Journal"].tap()
        let savedDrink = app.staticTexts[drinkName]
        for _ in 0..<6 where !savedDrink.exists {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(savedDrink.waitForExistence(timeout: 3))
        app.buttons["Open sip"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
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
    func testPolishedTabSurfacesPassAccessibilityAudit() throws {
        let app = launch(reset: true)

        app.buttons["mugshot.tab.map"].tap()
        XCTAssertTrue(app.textFields["Search places"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait]) { issue in
            if issue.element?.label == "Legal",
               issue.detailedDescription.contains("MKAttributionLabel") {
                return true
            }
            let elementDescription = issue.element.map {
                "\($0.debugDescription)\nFrame: \($0.frame)\nLabel: \($0.label)\nIdentifier: \($0.identifier)"
            } ?? "No associated element"
            let attachment = XCTAttachment(
                string: "\(issue.compactDescription)\n\(issue.detailedDescription)\n\(elementDescription)"
            )
            attachment.name = "Map accessibility audit diagnostic"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            return false
        }

        app.buttons["mugshot.tab.feed"].tap()
        XCTAssertTrue(app.staticTexts["Feed"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait])

        app.buttons["mugshot.tab.saved"].tap()
        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait])

        app.buttons["mugshot.tab.journal"].tap()
        XCTAssertTrue(app.staticTexts["Recent sips"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait]) { issue in
            let elementDescription = issue.element.map {
                "\($0.debugDescription)\nFrame: \($0.frame)\nLabel: \($0.label)\nIdentifier: \($0.identifier)"
            } ?? "No associated element"
            let attachment = XCTAttachment(
                string: "\(issue.compactDescription)\n\(issue.detailedDescription)\n\(elementDescription)"
            )
            attachment.name = "Accessibility audit diagnostic"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            return false
        }
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
    private func finishSuccessfulSip(in app: XCUIApplication, captureCompletion: Bool = false) {
        let viewInJournal = app.buttons["View in Journal"]
        XCTAssertTrue(
            viewInJournal.waitForExistence(timeout: 5),
            "A successful save should pause on an informative completion state."
        )
        if captureCompletion {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Effort-aware sip completion"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        viewInJournal.tap()
        XCTAssertTrue(app.buttons["Journal"].waitForExistence(timeout: 3))
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
        while swipes < maximumSwipes, !element.isHittable {
            let frame = element.frame
            if frame.midY < app.windows.firstMatch.frame.midY {
                app.scrollViews.firstMatch.swipeDown()
            } else {
                app.scrollViews.firstMatch.swipeUp()
            }
            swipes += 1
        }
        XCTAssertTrue(
            element.isHittable,
            "Expected \(element) to become tappable after scrolling."
        )
        element.tap()
    }
}
