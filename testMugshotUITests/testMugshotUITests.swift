import XCTest

final class testMugshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEditorialPourDisclosuresAndSafeVisitContext() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-sip-detail-design-qa"
        ]
        app.launch()

        XCTAssertTrue(app.scrollViews["sip.detail.screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Oops, missed the photo"].exists)

        let scrollView = app.scrollViews["sip.detail.screen"]
        scrollView.swipeUp()

        let taste = app.buttons["sip.detail.taste.toggle"]
        XCTAssertTrue(taste.waitForExistence(timeout: 3))
        XCTAssertEqual(taste.value as? String, "Collapsed")
        taste.tap()
        XCTAssertEqual(taste.value as? String, "Expanded")
        taste.tap()

        scrollView.swipeDown()
        let journal = app.buttons["sip.detail.journal.toggle"]
        tapAfterRevealing(journal, in: app)
        XCTAssertEqual(journal.value as? String, "Expanded")
        XCTAssertTrue(app.staticTexts["Friends can read this note"].exists)

        let visitContext = app.buttons["sip.detail.visitContext.toggle"]
        tapAfterRevealing(visitContext, in: app)
        XCTAssertEqual(visitContext.value as? String, "Expanded")
        XCTAssertTrue(app.staticTexts["Nook Tiny Cafe & Market"].exists)
        XCTAssertFalse(app.staticTexts["11 Cannon St"].exists)
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
    func testMapExplainsCafeAndSipRatingFallback() throws {
        let app = launch(reset: true)
        app.buttons["mugshot.tab.map"].tap()

        XCTAssertTrue(app.staticTexts["Your ratings"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.staticTexts["Cafe average when available · Sip average otherwise"].exists
        )
        XCTAssertEqual(app.staticTexts["High"].value as? String, "4.0 or higher")
        XCTAssertEqual(app.staticTexts["Mid"].value as? String, "3.0 to 3.9")
        XCTAssertEqual(app.staticTexts["Low"].value as? String, "Below 3.0")
        XCTAssertTrue(app.staticTexts["Tap a pin to see its source and evidence."].exists)
    }

    @MainActor
    func testV3HomeSipCompletesUnderTwoMinutes() throws {
        let app = launch(reset: true)
        let startedAt = Date()
        openV3HomeDraftToPublish(
            in: app,
            drinkName: "Timed cortado",
            caption: "A quick home sip"
        )
        publishV3(in: app)
        finishSuccessfulV3Sip(in: app)

        XCTAssertTrue(
            app.buttons["Add"].waitForExistence(timeout: 5),
            "Closing the V3 completion should open Journal and expose Add."
        )
        let duration = Date().timeIntervalSince(startedAt)
        XCTAssertLessThan(duration, 120, "The V3 home sip journey took \(duration) seconds.")

        let attachment = XCTAttachment(
            string: "V3 home sip: \(String(format: "%.2f", duration))s"
        )
        attachment.name = "V3 home sip timing"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testEveryoneAudienceAndDraftRestoration() throws {
        let app = launch(reset: true)
        openV3HomeDraftToPublish(
            in: app,
            drinkName: "Draft restoration latte",
            caption: "A home sip worth remembering"
        )

        let everyone = app.buttons["Everyone"].firstMatch
        XCTAssertTrue(everyone.waitForExistence(timeout: 2))
        everyone.tap()
        XCTAssertTrue(everyone.isSelected)

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        XCTAssertTrue(
            app.staticTexts["Publish Mugshot"].waitForExistence(timeout: 3),
            "A meaningful V3 draft should restore to its persisted publish step after relaunch."
        )
        XCTAssertTrue(app.buttons["Everyone"].firstMatch.isSelected, "The selected audience should restore with the draft.")
        XCTAssertEqual(
            v3Element("logASipV3.caption", in: app).value as? String,
            "A home sip worth remembering"
        )
        XCTAssertTrue(v3Element("logASipV3.primaryAction", in: app).isEnabled)
    }

    @MainActor
    func testHomeReflectionFriendsSaveReopensWithScores() throws {
        let app = launch(reset: true)
        let drinkName = "Friends Chemex"
        openV3HomeDraftToPublish(
            in: app,
            drinkName: drinkName,
            caption: "Citrus, tea-like, silky"
        )
        publishV3(in: app, audience: "Friends")
        finishSuccessfulV3Sip(in: app)

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        let savedDrink = app.staticTexts[drinkName]
        XCTAssertTrue(savedDrink.waitForExistence(timeout: 3))
        app.buttons["Open sip"].tap()

        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
        let tasteEvidence = app.buttons["sip.detail.taste.toggle"]
        XCTAssertTrue(tasteEvidence.exists)
        XCTAssertFalse(app.staticTexts["Presentation"].exists)
        XCTAssertEqual(tasteEvidence.value as? String, "Collapsed")
    }

    @MainActor
    func testFeedSipUsesImmersivePourPushAndOwnerSurfaces() throws {
        let app = launch(reset: true)
        let drinkName = "Immersive cortado"
        openV3HomeDraftToPublish(
            in: app,
            drinkName: drinkName,
            caption: "An immersive pour worth remembering"
        )
        publishV3(in: app, audience: "Friends")
        finishSuccessfulV3Sip(in: app)

        app.buttons["Feed"].tap()
        XCTAssertTrue(app.staticTexts[drinkName].waitForExistence(timeout: 4))
        let openSip = app.buttons["Open sip"]

        XCTAssertTrue(openSip.waitForExistence(timeout: 3))
        openSip.tap()

        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["sip.detail.screen"].exists)
        XCTAssertTrue(app.buttons["sip.detail.taste.toggle"].exists)
        let visitContext = app.buttons["sip.detail.visitContext.toggle"]
        XCTAssertTrue(visitContext.exists)
        XCTAssertEqual(visitContext.value as? String, "Collapsed")
        XCTAssertFalse(app.buttons["mugshot.tab.feed"].exists, "The app dock should yield to sip detail.")
        XCTAssertTrue(app.buttons["Sip actions"].exists)

        app.buttons["Sip actions"].tap()
        XCTAssertTrue(app.buttons["Edit Sip"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Delete Sip"].exists)
        app.buttons["Edit Sip"].tap()

        XCTAssertTrue(app.staticTexts["Edit sip"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Public note"].exists)
        XCTAssertTrue(
            app.staticTexts[
                "Your structured journal notes stay unchanged in this editor."
            ].exists
        )
        XCTAssertTrue(app.buttons["Save sip"].exists)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testSavedCafeEntryPointPreselectsCafeAndReopensSip() throws {
        let app = launch(reset: true)
        let drinkName = "Preselected cafe flat white"

        openV3SavedCafeDraftToPublish(in: app, drinkName: drinkName)
        publishV3(in: app, audience: "Friends")
        finishSuccessfulV3Sip(in: app)

        XCTAssertTrue(app.buttons["Feed"].waitForExistence(timeout: 5))
        app.buttons["Feed"].tap()
        XCTAssertTrue(app.staticTexts[drinkName].waitForExistence(timeout: 3))
        app.buttons["Open sip"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Mugshot Test Cafe"].exists)
    }

    @MainActor
    func testCafePulseKeepsTwoTruthsAndRestoresAddAnotherAfterRelaunch() throws {
        let app = launch(reset: true)
        let firstDrink = "Elsewhere cortado"
        let secondDrink = "Session sparkling espresso"

        openV3SavedCafeDraftToPublish(in: app, drinkName: firstDrink)
        publishV3(in: app)
        let pourAnother = app.buttons["Pour another one"]
        XCTAssertTrue(pourAnother.exists)

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()
        XCTAssertTrue(
            app.buttons["Pour another one"].waitForExistence(timeout: 3),
            "The completed cafe-session handoff should survive process termination."
        )
        tapAfterRevealing(app.buttons["Pour another one"], in: app, maximumSwipes: 16)
        completeCurrentV3CafeDraftToPublish(in: app, drinkName: secondDrink)
        publishV3(in: app)
        finishSuccessfulV3Sip(in: app)
        XCTAssertTrue(app.staticTexts[firstDrink].waitForExistence(timeout: 4))
    }

    @MainActor
    func testPhotoDraftSurvivesFailedSaveRelaunchAndRetry() throws {
        let failureArguments = ["--ui-testing-seed-photo", "--ui-testing-fail-first-save"]
        let app = launch(reset: true, extraArguments: failureArguments)
        let drinkName = "Recovered photo cappuccino"

        openV3HomeDraftToPublish(
            in: app,
            drinkName: drinkName,
            caption: "A recovered photo memory",
            usesSeededPhoto: true
        )
        app.buttons["Friends"].firstMatch.tap()
        tapV3PrimaryAction(in: app)

        XCTAssertTrue(app.staticTexts["We couldn’t finish this save. Your sip is safe—try again."].waitForExistence(timeout: 2))
        XCTAssertTrue(v3Element("logASipV3.primaryAction", in: app).isEnabled)

        app.terminate()
        app.launchArguments = ["--ui-testing"] + failureArguments
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["Publish Mugshot"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Friends"].firstMatch.isSelected)
        app.buttons["Previous step"].tap()
        app.buttons["Previous step"].tap()
        app.buttons["Previous step"].tap()
        XCTAssertTrue(v3Element("logASipV3.photos.thumbnail.0", in: app).waitForExistence(timeout: 2))
        tapV3PrimaryAction(in: app)
        tapV3PrimaryAction(in: app)
        tapV3PrimaryAction(in: app)
        XCTAssertTrue(app.buttons["Friends"].firstMatch.isSelected)
        tapV3PrimaryAction(in: app)
        XCTAssertTrue(v3Element("logASipV3.shareHub", in: app).waitForExistence(timeout: 5))
        finishSuccessfulV3Sip(in: app)

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

        openV3HomeDraftToPublish(
            in: app,
            drinkName: drinkName,
            caption: "A private draft that survives authentication changes"
        )
        XCTAssertTrue(app.buttons["Private"].firstMatch.isSelected)
        tapV3PrimaryAction(in: app)
        XCTAssertTrue(app.staticTexts["Sign back in to save. Your draft will stay here."].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["Publish Mugshot"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Private"].firstMatch.isSelected)
        XCTAssertTrue(app.staticTexts[drinkName].exists)
        XCTAssertEqual(
            v3Element("logASipV3.caption", in: app).value as? String,
            "A private draft that survives authentication changes"
        )
        tapV3PrimaryAction(in: app)

        XCTAssertTrue(v3Element("logASipV3.shareHub", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mugshot published"].exists)
    }

    @MainActor
    func testGuidedCoreStepsPassAccessibilityAudit() throws {
        let app = launch(reset: true, extraArguments: ["--ui-testing-seed-photo"])
        app.buttons["Add"].tap()
        let home = v3Element("logASipV3.context.home", in: app)
        XCTAssertTrue(home.waitForExistence(timeout: 3))
        home.tap()
        XCTAssertTrue(v3Element("logASipV3.drinkName", in: app).exists)
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait])

        let drinkField = v3Element("logASipV3.drinkName", in: app)
        drinkField.tap()
        drinkField.typeText("Accessibility audit cortado")
        if !app.staticTexts["How was the sip?"].waitForExistence(timeout: 1) {
            tapV3PrimaryAction(in: app)
        }
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait])

        let sipScore = v3Element("logASipV3.sipScore", in: app)
        tapAfterRevealing(sipScore, in: app)
        sipScore.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.5)).tap()
        tapV3PrimaryAction(in: app)
        XCTAssertTrue(app.staticTexts["Would you make it again?"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait])
    }

    @MainActor
    func testPolishedTabSurfacesPassAccessibilityAudit() throws {
        let app = launch(reset: true)

        app.buttons["mugshot.tab.map"].tap()
        XCTAssertTrue(app.textFields["Search places"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .textClipped, .trait]) { issue in
            if issue.element?.label == "Legal",
               issue.element?.elementType == .link {
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
    private func v3Element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func tapV3PrimaryAction(in app: XCUIApplication) {
        let action = v3Element("logASipV3.primaryAction", in: app)
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        XCTAssertTrue(action.isEnabled)
        tapAfterRevealing(action, in: app)
    }

    @MainActor
    private func openV3HomeDraftToPublish(
        in app: XCUIApplication,
        drinkName: String,
        caption: String,
        usesSeededPhoto: Bool = false
    ) {
        app.buttons["Add"].tap()

        let home = v3Element("logASipV3.context.home", in: app)
        XCTAssertTrue(home.waitForExistence(timeout: 3))
        home.tap()

        if usesSeededPhoto {
            XCTAssertTrue(
                v3Element("logASipV3.photos.thumbnail.0", in: app)
                    .waitForExistence(timeout: 2)
            )
        } else {
            let missedPhoto = v3Element("logASipV3.photoFallback.missed", in: app)
            XCTAssertTrue(missedPhoto.waitForExistence(timeout: 2))
            missedPhoto.tap()
        }

        let drinkField = v3Element("logASipV3.drinkName", in: app)
        tapAfterRevealing(drinkField, in: app)
        drinkField.typeText(drinkName)
        if !app.staticTexts["How was the sip?"].waitForExistence(timeout: 1) {
            tapV3PrimaryAction(in: app)
        }
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 3))

        let sipScore = v3Element("logASipV3.sipScore", in: app)
        tapAfterRevealing(sipScore, in: app)
        tapV3PrimaryAction(in: app)

        XCTAssertTrue(app.staticTexts["Would you make it again?"].waitForExistence(timeout: 3))
        tapAfterRevealing(v3Element("logASipV3.homeMakeAgain.yes", in: app), in: app)
        tapV3PrimaryAction(in: app)

        XCTAssertTrue(app.staticTexts["Publish Mugshot"].waitForExistence(timeout: 3))
        let captionField = v3Element("logASipV3.caption", in: app)
        tapAfterRevealing(captionField, in: app)
        captionField.typeText(caption)
        dismissKeyboard(in: app)
    }

    @MainActor
    private func openV3SavedCafeDraftToPublish(
        in app: XCUIApplication,
        drinkName: String
    ) {
        app.buttons["Saved"].tap()
        XCTAssertTrue(app.staticTexts["Mugshot Test Cafe"].waitForExistence(timeout: 3))
        tapAfterRevealing(app.buttons["Log a Sip"], in: app)
        completeCurrentV3CafeDraftToPublish(in: app, drinkName: drinkName)
    }

    @MainActor
    private func completeCurrentV3CafeDraftToPublish(
        in app: XCUIApplication,
        drinkName: String
    ) {
        let cafe = v3Element("logASipV3.context.cafe", in: app)
        XCTAssertTrue(cafe.waitForExistence(timeout: 3))
        XCTAssertTrue(cafe.isSelected)
        XCTAssertEqual(
            v3Element("logASipV3.cafe.selector", in: app).value as? String,
            "Mugshot Test Cafe"
        )

        let missedPhoto = v3Element("logASipV3.photoFallback.missed", in: app)
        XCTAssertTrue(missedPhoto.waitForExistence(timeout: 2))
        missedPhoto.tap()

        let drinkField = v3Element("logASipV3.drinkName", in: app)
        tapAfterRevealing(drinkField, in: app)
        drinkField.typeText(drinkName)
        tapV3PrimaryAction(in: app)

        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 3))
        tapAfterRevealing(v3Element("logASipV3.sipScore", in: app), in: app)
        tapV3PrimaryAction(in: app)

        XCTAssertTrue(app.staticTexts["How was the cafe?"].waitForExistence(timeout: 3))
        tapAfterRevealing(v3Element("logASipV3.contextScore", in: app), in: app)
        tapV3PrimaryAction(in: app)

        XCTAssertTrue(app.staticTexts["Publish Mugshot"].waitForExistence(timeout: 3))
        let captionField = v3Element("logASipV3.caption", in: app)
        tapAfterRevealing(captionField, in: app)
        captionField.typeText("Cafe memory: \(drinkName)")
        dismissKeyboard(in: app)
    }

    @MainActor
    private func publishV3(
        in app: XCUIApplication,
        audience: String = "Private"
    ) {
        let audienceButton = app.buttons[audience].firstMatch
        XCTAssertTrue(audienceButton.waitForExistence(timeout: 2))
        if !audienceButton.isSelected {
            tapAfterRevealing(audienceButton, in: app)
        }
        tapV3PrimaryAction(in: app)
        XCTAssertTrue(v3Element("logASipV3.shareHub", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mugshot published"].exists)
    }

    @MainActor
    private func finishSuccessfulV3Sip(in app: XCUIApplication) {
        XCTAssertTrue(v3Element("logASipV3.shareHub", in: app).waitForExistence(timeout: 5))
        let close = app.buttons["Close Taste Passport"]
        XCTAssertTrue(close.waitForExistence(timeout: 2))
        close.tap()
        XCTAssertTrue(app.buttons["Journal"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 2))
        done.tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 1))
    }

    @MainActor
    private func tapAfterRevealing(_ element: XCUIElement, in app: XCUIApplication, maximumSwipes: Int = 8) {
        let pinnedAction = v3Element("logASipV3.primaryAction", in: app)
        var swipes = 0
        while swipes < maximumSwipes {
            let isCoveredByPinnedAction = pinnedAction.exists
                && element.identifier != "logASipV3.primaryAction"
                && element.frame.maxY > pinnedAction.frame.minY - 8
            if element.isHittable && !isCoveredByPinnedAction {
                break
            }
            if element.exists, element.frame.maxY < 116 {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
            swipes += 1
        }
        let isCoveredByPinnedAction = pinnedAction.exists
            && element.identifier != "logASipV3.primaryAction"
            && element.frame.maxY > pinnedAction.frame.minY - 8
        XCTAssertTrue(
            element.waitForExistence(timeout: 5)
                && element.isHittable
                && !isCoveredByPinnedAction,
            "Expected \(element) to be visible and tappable after scrolling."
        )
        element.tap()
    }

}
