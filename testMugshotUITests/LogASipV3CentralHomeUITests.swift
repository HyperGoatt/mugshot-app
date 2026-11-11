import XCTest

final class LogASipV3CentralHomeUITests: XCTestCase {
    private enum Identifier {
        static let homeContext = "logASipV3.context.home"
        static let homeQuickLog = "logASipV3.primaryAction"
        static let homeChooseRecipe = "logASipV3.home.chooseRecipe"
        static let homeChooseMethod = "logASipV4.home.starter.other"
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
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion"]
        app.launch()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        let homeContext = element(Identifier.homeContext, in: app)
        XCTAssertTrue(homeContext.waitForExistence(timeout: 3))
        homeContext.tap()

        XCTAssertTrue(app.staticTexts["Log a Sip"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["What are you making?"].exists)
        XCTAssertTrue(element(Identifier.homeChooseRecipe, in: app).exists)
        XCTAssertTrue(app.textFields["home.entry.name"].exists)
        XCTAssertTrue(app.buttons["home.entry.saveRecipe"].exists)
        XCTAssertFalse(app.navigationBars["What did you make?"].exists)
        XCTAssertFalse(app.staticTexts["Home is under construction"].exists)
        attachScreenshot(named: "01-central-add-home-setup-first", app: app)
    }

    @MainActor
    func testSetupKeepsHeaderAndPillsFixedAsContextsAndScrollChange() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion"]
        app.launch()
        let add = app.buttons["mugshot.tab.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let title = app.staticTexts["Log a Sip"]
        let autosave = app.staticTexts["Drafts save automatically"]
        let pills = ["cafe", "home", "elsewhere"].map { element("logASipV3.context.\($0)", in: app) }
        XCTAssertTrue(pills[0].waitForExistence(timeout: 3))
        let chrome = [title, autosave] + pills
        let frames = chrome.map(\.frame)
        for frame in frames { XCTAssertFalse(frame.isEmpty) }

        for (index, panel) in [
            (1, app.staticTexts["What are you making?"]),
            (2, element(Identifier.locationName, in: app)),
            (0, element(Identifier.cafeSelector, in: app))
        ] {
            pills[index].tap()
            XCTAssertTrue(panel.waitForExistence(timeout: 3))
            XCTAssertTrue(pills[index].isSelected)
            for (control, frame) in zip(chrome, frames) {
                XCTAssertEqual(control.frame.minX, frame.minX, accuracy: 1, control.label)
                XCTAssertEqual(control.frame.minY, frame.minY, accuracy: 1, control.label)
            }
        }

        app.scrollViews["logASipV3.scroll"].swipeUp()
        XCTAssertTrue(pills.allSatisfy(\.isHittable))
        XCTAssertEqual(title.frame.minY, frames[0].minY, accuracy: 1)
        app.buttons["Close Log a Sip"].tap()
        add.tap()
        XCTAssertFalse(element("logASipV3.resumeDraft", in: app).exists, "Context selection alone must not create a draft.")
    }

    @MainActor
    func testElsewhereSettingAloneAutosavesAcrossRelaunch() throws {
        let app = XCUIApplication()
        let launchArguments = ["--ui-testing", "--ui-testing-signed-out", "--ui-testing-reduce-motion"]
        app.launchArguments = launchArguments + ["--ui-testing-reset"]
        app.launch()
        let add = app.buttons["mugshot.tab.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let elsewhere = element("logASipV3.context.elsewhere", in: app)
        XCTAssertTrue(elsewhere.waitForExistence(timeout: 3))
        elsewhere.tap()
        type("Sunday market", into: Identifier.locationName, in: app)
        dismissKeyboardIfNeeded(in: app)

        // Stop without using Close, which also writes a draft.
        app.terminate()
        app.launchArguments = launchArguments
        app.launch()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let resume = element("logASipV3.resumeDraft", in: app)
        XCTAssertTrue(resume.waitForExistence(timeout: 3), "An entered setting must be enough for autosave.")
        resume.tap()
        let draft = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.drafts.resume.sip-"))
        XCTAssertTrue(draft.firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(draft.count, 1)
        XCTAssertEqual(draft.firstMatch.label, "Resume Sunday market")
        draft.firstMatch.tap()
        let setting = element(Identifier.locationName, in: app)
        XCTAssertTrue(setting.waitForExistence(timeout: 3))
        XCTAssertEqual(setting.value as? String, "Sunday market")
        XCTAssertTrue(elsewhere.isSelected)
    }

    @MainActor
    func testHomeQuickLogSavesAnUnratedPrivateSipAndReopensItFromJournal() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-home-account",
            "--ui-testing-reduce-motion",
            "--ui-testing-seed-home-quick-name"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()
        let homeContext = element(Identifier.homeContext, in: app)
        XCTAssertTrue(homeContext.waitForExistence(timeout: 3))
        homeContext.tap()

        let name = app.textFields["home.entry.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 4))
        if name.value as? String != "Afternoon matcha" {
            name.tap(); name.typeText("Afternoon matcha")
            app.buttons["home.entry.keyboardDone"].tap()
        }
        let quickLog = app.buttons["home.entry.rate"]
        XCTAssertTrue(quickLog.waitForExistence(timeout: 3))
        quickLog.tap()
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 4))
        XCTAssertEqual(element(Identifier.homeProgress, in: app).label, "Taste")

        // Rating, criteria, note, make-again intent, and photo are all optional.
        app.buttons["Previous step"].tap()
        XCTAssertEqual(name.value as? String, "Afternoon matcha")
        quickLog.tap()
        app.buttons["home.sip.savePrivate"].tap()
        XCTAssertTrue(app.staticTexts["Not rated"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Afternoon matcha"].exists)
        XCTAssertTrue(app.buttons["sip.detail.actions"].firstMatch.isHittable)
        attachScreenshot(named: "02-home-quick-log-unrated-private-save", app: app)
        app.terminate()
        app.launchArguments = ["--ui-testing", "--ui-testing-home-account", "--ui-testing-reduce-motion"]
        app.launch()
        app.buttons["mugshot.tab.journal"].tap()
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Afternoon matcha")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 6))
        entry.tap()
        XCTAssertTrue(app.staticTexts["Not rated"].waitForExistence(timeout: 5))
        let actions = app.buttons["sip.detail.actions"].firstMatch
        XCTAssertTrue(actions.isHittable)
        XCTAssertFalse(app.buttons["mugshot.tab.journal"].exists)
        attachScreenshot(named: "home-sip-from-journal", app: app)
        actions.tap()
        XCTAssertTrue(app.buttons["Edit Sip"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share Sip"].firstMatch.exists)
        attachScreenshot(named: "home-sip-menu-from-journal", app: app)
        app.buttons["Experiment with Mugsy"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Try a longer whisk"].waitForExistence(timeout: 6))
        XCTAssertFalse(app.staticTexts["Selected details"].exists)
        XCTAssertFalse(app.buttons["home.experiment.ask"].exists)
        attachScreenshot(named: "mugsy-experiment-sparse-sip", app: app)
        app.buttons["home.experiment.another"].tap()
        XCTAssertTrue(app.staticTexts["Taste it at two moments"].exists)
        app.buttons["home.experiment.start"].tap()
        let trial = element("home.experiment.draft", in: app)
        XCTAssertTrue(trial.waitForExistence(timeout: 6))
        attachScreenshot(named: "mugsy-experiment-private-draft", app: app)
        app.terminate()
        app.launch()
        app.buttons["mugshot.tab.journal"].tap()
        let drafts = app.buttons["journal.drafts.manage"]
        XCTAssertTrue(drafts.waitForExistence(timeout: 5)); drafts.tap()
        let resume = app.buttons.matching(NSPredicate(format: "label == %@ AND value BEGINSWITH %@",
            "Resume Afternoon matcha", "Taste it at two moments")).firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 5)); resume.tap()
        XCTAssertTrue(trial.waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Taste it at two moments"].exists)
        attachScreenshot(named: "mugsy-experiment-reopened-draft", app: app)
    }

    @MainActor
    func testV4LatteGuidanceActualsAndStandardPrivateDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion"]
        app.launch()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()
        let home = element(Identifier.homeContext, in: app)
        XCTAssertTrue(home.waitForExistence(timeout: 3))
        home.tap()
        app.buttons["home.start.guidance"].tap()
        let latte = element("logASipV4.home.starter.complete_drink", in: app)
        XCTAssertTrue(latte.waitForExistence(timeout: 4))
        reveal(latte, in: app)
        latte.tap()
        XCTAssertTrue(element("home.setup.appliedInputs", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("home.setup.part.Base", in: app).exists)
        XCTAssertTrue(element("home.setup.part.Milk", in: app).exists)
        attachScreenshot(named: "03a-home-latte-components", app: app)
        let change = app.buttons["home.setup.changeForThisBrew"]
        reveal(change, in: app); change.tap()
        let nickname = app.textFields["home.setup.nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5)); reveal(nickname, in: app)
        nickname.tap(); nickname.typeText(" test")
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertFalse(element("home.setup.appliedInputs", in: app).label.contains("test"))
        change.tap(); reveal(nickname, in: app); nickname.tap(); nickname.typeText(" bench")
        let keyboardReturn = app.keyboards.buttons["Return"].firstMatch
        if keyboardReturn.isHittable { keyboardReturn.tap() }
        let use = app.buttons["home.setup.useForThisBrew"]
        XCTAssertTrue(use.isHittable)
        attachScreenshot(named: "03b-apply-one-brew", app: app)
        use.tap()
        XCTAssertTrue(element("home.setup.appliedInputs", in: app).label.contains("bench"))
        app.buttons["home.makeWithGuidance"].tap()
        XCTAssertTrue(app.staticTexts["Make"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["36 g"].exists)
        for _ in 0..<8 where !app.staticTexts["How was the sip?"].exists { tapPrimaryAction(in: app) }
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 4))
        let measurements = app.buttons["home.capture.measurements"]
        XCTAssertTrue(measurements.waitForExistence(timeout: 3))
        tapAboveComposerFooter(measurements, in: app)
        XCTAssertTrue(app.staticTexts["How did it go?"].waitForExistence(timeout: 4))
        let confirm = app.buttons["As planned"].firstMatch
        XCTAssertTrue(confirm.exists)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["✓ As planned"].exists)
        app.buttons["home.measurements.done"].tap()
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 4))
        app.buttons["home.sip.savePrivate"].tap()
        XCTAssertTrue(app.staticTexts["How you made it"].waitForExistence(timeout: 4))
        let makeAgain = app.buttons["home.brewReview.makeAgain"]
        reveal(makeAgain, in: app)
        XCTAssertTrue(makeAgain.isHittable)
        XCTAssertTrue(app.staticTexts["Compare your brew"].exists)
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Coffee, Plan: 18 g, Actual: 18 g")).firstMatch.exists)
        attachScreenshot(named: "03-home-plan-and-actual", app: app)
        makeAgain.tap()
        let choose = app.buttons["home.repeat.chooseMeasurement"]
        XCTAssertTrue(choose.waitForExistence(timeout: 4))
        choose.tap()
        app.buttons["Yield"].tap()
        let amount = app.textFields["home.repeat.amount"]
        reveal(amount, in: app)
        amount.tap()
        amount.typeText("40")
        XCTAssertEqual(amount.value as? String, "40")
        let done = app.buttons["home.repeat.keyboardDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 4))
        done.tap()
        XCTAssertEqual(amount.value as? String, "40", "Closing the keyboard must keep the final digit.")
        let start = app.buttons["home.repeat.apply"]
        reveal(start, in: app)
        start.tap()
        let guide = app.buttons["home.makeWithGuidance"]
        XCTAssertTrue(guide.waitForExistence(timeout: 4))
        guide.tap()
        XCTAssertTrue(app.staticTexts["40 g"].waitForExistence(timeout: 4))
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

        let home = element(Identifier.homeContext, in: app)
        home.tap()
        XCTAssertTrue(home.isSelected)
        element("logASipV3.context.elsewhere", in: app).tap()
        XCTAssertTrue(element(Identifier.locationName, in: app).waitForExistence(timeout: 3))
        XCTAssertEqual(element(Identifier.drinkName, in: app).value as? String, "Iced latte")
        XCTAssertTrue(element("logASipV3.photos.thumbnail.0", in: app).exists)
        XCTAssertFalse(cafeSelector.exists, "The cafe picker and selection belong to the cafe context.")
    }

    @MainActor
    func testCompactCriteriaInteractionsAndSipToCafeHandoff() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--ui-testing-seed-photo",
            "--ui-testing-signed-out",
            "--ui-testing-seed-v3-lab-parity"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()
        let resume = element("logASipV3.resumeDraft", in: app)
        XCTAssertTrue(resume.waitForExistence(timeout: 3))
        resume.tap()
        let seededDraft = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Resume Iced Orange Creamsicle")).firstMatch
        if seededDraft.waitForExistence(timeout: 2) { seededDraft.tap() }
        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 4))

        let bodyPin = element("logASipV3.sip.criterion.body.pin", in: app)
        reveal(bodyPin, in: app)
        let bodyRating = element("logASipV3.sip.criterion.body.rating", in: app)
        XCTAssertTrue(bodyRating.exists)
        XCTAssertTrue(element("logASipV3.sip.criterion.presentation.rating", in: app).exists)
        XCTAssertTrue(element("logASipV3.sip.criterion.flavor-balance.rating", in: app).exists)

        let bodyImportance = element("logASipV3.sip.criterion.body.importance", in: app)
        XCTAssertEqual(bodyImportance.value as? String, "More")
        tapAboveComposerFooter(bodyImportance, in: app)
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
        XCTAssertTrue(element("logASipV3.sip.suggestion.presentation", in: app).exists)
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
        let footer = app.buttons["home.sip.savePrivate"].exists
            ? app.buttons["home.sip.savePrivate"] : element(Identifier.primaryAction, in: app)
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
