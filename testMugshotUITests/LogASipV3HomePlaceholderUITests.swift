import XCTest

final class LogASipV3HomePlaceholderUITests: XCTestCase {
    private enum Identifier {
        static let homeContext = "logASipV3.context.home"
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
        static let caption = "logASipV3.caption"
        static let passport = "logASipV3.passport"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomePlaceholderPublishesThroughV3ReflectionFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset"]
        app.launch()

        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()

        let homeContext = element(Identifier.homeContext, in: app)
        XCTAssertTrue(homeContext.waitForExistence(timeout: 3))
        homeContext.tap()
        XCTAssertTrue(homeContext.isSelected)

        let addPhotos = elements(Identifier.addPhotos, in: app)
        XCTAssertTrue(addPhotos.firstMatch.waitForExistence(timeout: 2))
        XCTAssertEqual(addPhotos.count, 1)
        XCTAssertEqual(addPhotos.firstMatch.label, "Add photos")
        XCTAssertFalse(app.buttons["Add photo"].exists)

        let missedPhoto = element(Identifier.missedPhoto, in: app)
        XCTAssertTrue(missedPhoto.waitForExistence(timeout: 2))
        missedPhoto.tap()
        XCTAssertTrue(app.staticTexts["Oops, missed the photo"].waitForExistence(timeout: 2))
        attachScreenshot(named: "01-setup", app: app)

        type("Placeholder ritual latte", into: Identifier.drinkName, in: app)
        if !app.staticTexts["How was the sip?"].waitForExistence(timeout: 1) {
            tapPrimaryAction(in: app)
        }

        XCTAssertTrue(app.staticTexts["How was the sip?"].waitForExistence(timeout: 3))
        attachScreenshot(named: "02-sip", app: app)
        let sipScore = element(Identifier.sipScore, in: app)
        reveal(sipScore, in: app)
        sipScore.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.5)).tap()
        XCTAssertNotEqual(sipScore.value as? String, "Not rated")
        tapPrimaryAction(in: app)

        XCTAssertTrue(app.staticTexts["Would you make it again?"].waitForExistence(timeout: 3))
        attachScreenshot(named: "03-home", app: app)
        let makeAgain = element(Identifier.makeAgainYes, in: app)
        reveal(makeAgain, in: app)
        makeAgain.tap()
        XCTAssertTrue(makeAgain.isSelected)
        tapPrimaryAction(in: app)

        XCTAssertTrue(app.staticTexts["Publish Mugshot"].waitForExistence(timeout: 3))
        attachScreenshot(named: "04-publish", app: app)
        type("A quiet home experiment worth keeping.", into: Identifier.caption, in: app)
        if !element(Identifier.passport, in: app).waitForExistence(timeout: 1) {
            tapPrimaryAction(in: app)
        }

        let passport = element(Identifier.passport, in: app)
        XCTAssertTrue(
            passport.waitForExistence(timeout: 5),
            "A successful V3 Home publication should land on Taste Passport."
        )
        XCTAssertTrue(app.staticTexts["Taste Passport"].exists)
        XCTAssertTrue(app.staticTexts["Mugshot published"].exists)
        XCTAssertTrue(app.staticTexts["Placeholder ritual latte"].exists)
        attachScreenshot(named: "05-passport", app: app)
    }

    @MainActor
    func testPopulatedSetupKeepsOneWideAddPhotosControl() throws {
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
        cafeSelector.tap()

        XCTAssertTrue(element(Identifier.cafeSearchSheet, in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(
            element(Identifier.cafeSearchQuery, in: app).exists || app.textFields["Search places"].exists
        )
        let testCafe = element(Identifier.testCafe, in: app)
        XCTAssertTrue(testCafe.waitForExistence(timeout: 3))
        testCafe.tap()

        XCTAssertTrue(cafeSelector.waitForExistence(timeout: 3))
        XCTAssertEqual(cafeSelector.value as? String, "Mugshot Test Cafe")
        XCTAssertEqual(element(Identifier.drinkName, in: app).value as? String, "Iced latte")
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
        reveal(removePresentation, in: app)
        removePresentation.tap()
        XCTAssertTrue(app.alerts.buttons["Remove"].waitForExistence(timeout: 2))
        app.alerts.buttons["Remove"].tap()
        XCTAssertFalse(element("logASipV3.sip.criterion.presentation.rating", in: app).exists)
        XCTAssertTrue(app.staticTexts["24 ideas"].exists)
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
        reveal(field, in: app)
        field.tap()
        field.typeText(value)
    }

    @MainActor
    private func tapPrimaryAction(in app: XCUIApplication) {
        let action = element(Identifier.primaryAction, in: app)
        reveal(action, in: app)
        XCTAssertTrue(action.isEnabled)
        action.tap()
    }

    @MainActor
    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 10
    ) {
        var swipes = 0
        while swipes < maximumSwipes, !element.isHittable {
            app.scrollViews.firstMatch.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(
            element.waitForExistence(timeout: 3) && element.isHittable,
            "Expected \(element) to become visible and tappable."
        )
    }
}
