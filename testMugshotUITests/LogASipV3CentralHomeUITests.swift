import XCTest

final class LogASipV3CentralHomeUITests: XCTestCase {
    private enum Identifier {
        static let homeContext = "logASipV3.context.home"
        static let homeQuickLog = "logASipV3.home.quickLog"
        static let homeChooseRecipe = "logASipV3.home.chooseRecipe"
        static let homeChooseMethod = "logASipV3.home.chooseMethod"
        static let homeProgress = "logASipV3.home.progress"
        static let addPhotos = "logASipV3.photos.add"
        static let missedPhoto = "logASipV3.photoFallback.missed"
        static let drinkName = "logASipV3.drinkName"
        static let cafeSelector = "logASipV3.cafe.selector"
        static let cafeSearchSheet = "logASipV3.cafeSearch.sheet"
        static let cafeSearchQuery = "logASipV3.cafeSearch.query"
        static let testCafe = "logASipV3.cafeSearch.local.00000000-0000-4000-8000-000000000002"
        static let locationName = "logASipV3.locationName"
        static let primaryAction = "logASipV3.primaryAction"
        static let sipScore = "logASipV3.sipScore"
        static let makeAgainYes = "logASipV3.homeMakeAgain.yes"
        static let homeScanBag = "logASipV3.home.scanBag"
        static let homeEspresso = "logASipV3.home.method.espresso"
        static let homeDose = "logASipV3.home.dose"
        static let homeYield = "logASipV3.home.yield"
        static let homePreinfusion = "logASipV3.home.preinfusion"
        static let homeActualYield = "logASipV3.home.actuals.yield"
        static let homeCreateRecipe = "logASipV3.home.recipeDecision.create_new_version"
        static let homePublishSummary = "logASipV3.home.publishSummary"
        static let caption = "logASipV3.caption"
        static let shareHub = "logASipV3.shareHub"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCentralAddHomeOpensSetupFirstInsideComposer() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-reduce-motion"]
        app.launch()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        let homeContext = element(Identifier.homeContext, in: app)
        XCTAssertTrue(homeContext.waitForExistence(timeout: 3))
        homeContext.tap()

        XCTAssertTrue(app.staticTexts["Start your Home sip"].waitForExistence(timeout: 3))
        XCTAssertTrue(element(Identifier.homeChooseRecipe, in: app).exists)
        XCTAssertTrue(element(Identifier.homeChooseMethod, in: app).exists)
        XCTAssertTrue(element(Identifier.homeQuickLog, in: app).exists)
        XCTAssertFalse(app.navigationBars["What did you make?"].exists)
        XCTAssertFalse(app.staticTexts["Home is under construction"].exists)
        attachScreenshot(named: "01-central-add-home-setup-first", app: app)
    }

    @MainActor
    func testHomeQuickLogSavesAnUnratedPrivateSipInTwoInputSurfaces() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-reduce-motion",
            "--ui-testing-seed-home-quick-name"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()
        let homeContext = element(Identifier.homeContext, in: app)
        XCTAssertTrue(homeContext.waitForExistence(timeout: 3))
        homeContext.tap()

        let quickLog = element(Identifier.homeQuickLog, in: app)
        XCTAssertTrue(quickLog.waitForExistence(timeout: 3))
        quickLog.tap()
        XCTAssertTrue(app.staticTexts["Quick log"].waitForExistence(timeout: 3))
        let quickProgress = element(Identifier.homeProgress, in: app)
        XCTAssertTrue(quickProgress.waitForExistence(timeout: 3))
        XCTAssertEqual(quickProgress.label, "Step 1 of 2")

        XCTAssertEqual(element(Identifier.drinkName, in: app).value as? String, "Afternoon matcha")
        tapPrimaryAction(in: app)
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 4))
        XCTAssertEqual(element(Identifier.homeProgress, in: app).label, "Step 2 of 2")

        // Rating, criteria, note, make-again intent, and photo are all optional.
        tapPrimaryAction(in: app)
        XCTAssertTrue(app.staticTexts["Saved privately"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Unrated"].exists)
        XCTAssertEqual(element(Identifier.homeProgress, in: app).label, "Step 4 of 4")
        attachScreenshot(named: "02-home-quick-log-unrated-private-save", app: app)
    }

    @MainActor
    func testPopulatedSetupKeepsOneWideAddPhotosControlAndAccessibleRemoval() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-seed-photo"]
        app.launch()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        let addPhotos = elements(Identifier.addPhotos, in: app)
        XCTAssertTrue(addPhotos.firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(addPhotos.count, 1)
        XCTAssertEqual(addPhotos.firstMatch.label, "Add photos")
        XCTAssertFalse(app.buttons["Add photo"].exists)
        XCTAssertTrue(element("logASipV3.photos.thumbnail.0", in: app).exists)

        let removePhoto = element("logASipV3.photos.remove.0", in: app)
        XCTAssertTrue(removePhoto.exists)
        XCTAssertEqual(removePhoto.label, "Remove photo 1")
        removePhoto.tap()
        XCTAssertFalse(element("logASipV3.photos.thumbnail.0", in: app).exists)
        XCTAssertEqual(elements(Identifier.addPhotos, in: app).count, 1)
    }

    @MainActor
    func testNormalAddSelectsSavedCafeWithoutLosingSetup() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-seed-photo"]
        app.launch()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        type("Iced latte", into: Identifier.drinkName, in: app)
        let cafeSelector = element(Identifier.cafeSelector, in: app)
        reveal(cafeSelector, in: app)
        openCafeSearch(from: cafeSelector, in: app)

        XCTAssertTrue(
            element(Identifier.cafeSearchQuery, in: app).exists || app.textFields["Search places"].exists
        )
        let testCafe = element(Identifier.testCafe, in: app)
        XCTAssertTrue(testCafe.waitForExistence(timeout: 3))
        testCafe.tap()

        XCTAssertTrue(cafeSelector.waitForExistence(timeout: 3))
        XCTAssertEqual(cafeSelector.value as? String, "Mugshot Test Cafe")
        XCTAssertEqual(
            (element(Identifier.drinkName, in: app).value as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            "Iced latte"
        )
        XCTAssertTrue(element("logASipV3.photos.thumbnail.0", in: app).exists)

        let primaryAction = element(Identifier.primaryAction, in: app)
        reveal(primaryAction, in: app)
        XCTAssertTrue(primaryAction.isEnabled)
    }

    @MainActor
    func testCompactCriteriaInteractionsAndSipToCafeHandoff() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-seed-photo",
            "--ui-testing-seed-v3-lab-parity"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 4))

        let bodyPin = element("logASipV3.sip.criterion.body.pin", in: app)
        reveal(bodyPin, in: app)
        let bodyRating = element("logASipV3.sip.criterion.body.rating", in: app)
        XCTAssertTrue(bodyRating.exists)
        XCTAssertTrue(element("logASipV3.sip.criterion.presentation.rating", in: app).exists)
        XCTAssertTrue(element("logASipV3.sip.criterion.orange-balance.rating", in: app).exists)

        let bodyImportance = element("logASipV3.sip.criterion.body.importance", in: app)
        XCTAssertEqual(bodyImportance.value as? String, "More")
        bodyImportance.tap()
        let normalImportance = element("logASipV3.importance.normal", in: app)
        XCTAssertTrue(normalImportance.waitForExistence(timeout: 2))
        normalImportance.tap()
        XCTAssertEqual(bodyImportance.value as? String, "Normal")

        XCTAssertEqual(bodyPin.value as? String, "Pinned")
        bodyPin.tap()
        XCTAssertEqual(bodyPin.value as? String, "Not pinned")

        let removePresentation = element("logASipV3.sip.criterion.presentation.remove", in: app)
        tapAboveComposerFooter(removePresentation, in: app)
        XCTAssertTrue(app.staticTexts["Remove Presentation?"].waitForExistence(timeout: 3))
        let confirmRemoval = app.buttons["Remove"]
        XCTAssertTrue(confirmRemoval.waitForExistence(timeout: 2))
        confirmRemoval.tap()
        XCTAssertFalse(element("logASipV3.sip.criterion.presentation.rating", in: app).exists)
        XCTAssertTrue(app.staticTexts["30 ideas"].exists)
        attachScreenshot(named: "criteria-parity-sip", app: app)

        tapPrimaryAction(in: app)
        XCTAssertTrue(app.staticTexts["How was the cafe?"].waitForExistence(timeout: 4))

        let atmosphereImportance = element("logASipV3.cafe.criterion.atmosphere.importance", in: app)
        reveal(atmosphereImportance, in: app)
        XCTAssertTrue(element("logASipV3.cafe.criterion.value.rating", in: app).exists)
        XCTAssertEqual(
            atmosphereImportance.value as? String,
            "Most"
        )
        XCTAssertTrue(app.staticTexts["21 ideas"].exists)
        attachScreenshot(named: "criteria-parity-cafe", app: app)
    }

    @MainActor
    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func elements(_ identifier: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: identifier)
    }

    @MainActor
    private func type(_ value: String, into identifier: String, in app: XCUIApplication) {
        let field = element(identifier, in: app)
        dismissKeyboardIfNeeded(in: app)
        positionAboveComposerFooter(field, in: app)
        field.tap()
        for character in value {
            field.typeText(String(character))
        }
        XCTAssertEqual(field.value as? String, value)
    }

    @MainActor
    private func replaceText(with value: String, in identifier: String, app: XCUIApplication) {
        let field = element(identifier, in: app)
        dismissKeyboardIfNeeded(in: app)
        positionAboveComposerFooter(field, in: app)
        field.tap()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(value)
        XCTAssertEqual(field.value as? String, value)
    }

    @MainActor
    private func tapPrimaryAction(in app: XCUIApplication) {
        let action = element(Identifier.primaryAction, in: app)
        reveal(action, in: app)
        XCTAssertTrue(action.isEnabled)
        action.tap()
    }

    @MainActor
    private func waitForSelected(
        _ identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 2
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { evaluated, _ in
                (evaluated as? XCUIElement)?.isSelected == true
            },
            object: element(identifier, in: app)
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func openCafeSearch(from selector: XCUIElement, in app: XCUIApplication) {
        let sheet = element(Identifier.cafeSearchSheet, in: app)
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
    private func tapAboveComposerFooter(_ target: XCUIElement, in app: XCUIApplication) {
        positionAboveComposerFooter(target, in: app)
        target.tap()
    }

    @MainActor
    private func positionAboveComposerFooter(
        _ target: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 10
    ) {
        let footer = element(Identifier.primaryAction, in: app)
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
}
