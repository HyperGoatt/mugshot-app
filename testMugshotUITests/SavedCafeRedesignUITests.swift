import XCTest

final class SavedCafeRedesignUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSavedDetailAndMapHandoff() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--saved-audit-scenario=populated"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Harborlight Coffee Roasters"].waitForExistence(timeout: 4))
        attachScreenshot(named: "implementation-saved-favorites")

        let harborlightCard = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Harborlight Coffee Roasters")
        ).firstMatch
        XCTAssertTrue(harborlightCard.waitForExistence(timeout: 3))
        harborlightCard.tap()

        let detail = element("cafe.detail.sheet", in: app)
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cafe.nextSip.repeat"].waitForExistence(timeout: 3))
        attachScreenshot(named: "implementation-saved-detail")

        let close = app.buttons["cafe.detail.back"]
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        XCTAssertTrue(close.label.contains("Saved"))
        close.tap()

        let moreActions = app.buttons["More actions for Harborlight Coffee Roasters"]
        XCTAssertTrue(moreActions.waitForExistence(timeout: 3))
        moreActions.tap()
        let showOnMap = app.buttons["Show on Map"]
        XCTAssertTrue(showOnMap.waitForExistence(timeout: 3))
        showOnMap.tap()

        XCTAssertTrue(element("map.surface", in: app).waitForExistence(timeout: 6))
        XCTAssertTrue(element("map.cafeDetail.sheet", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cafe.detail.back"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["cafe.detail.back"].label.contains("Map"))
        XCTAssertTrue(app.buttons["cafe.nextSip.repeat"].waitForExistence(timeout: 3))
        attachScreenshot(named: "implementation-map-detail")
        let scroll = app.scrollViews["cafe.detail.scroll"]
        let note = app.buttons["cafe.detail.privateNote"]
        for _ in 0..<5 where !note.isHittable { scroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(note.isHittable)
        XCTAssertTrue(app.staticTexts["Your Mugshot"].exists)
        attachScreenshot(named: "map-lower-cafe-detail")
    }

    @MainActor
    func testSavedSearchCategoriesAndUndo() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--saved-audit-scenario=populated"
        ]
        app.launch()

        let wantToTry = element("saved.category.Want to Try", in: app)
        XCTAssertTrue(wantToTry.waitForExistence(timeout: 6))
        wantToTry.tap()
        XCTAssertTrue(app.staticTexts["Juniper & Stone"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Paper Moon Espresso"].exists)

        let search = app.textFields["saved.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("Cedar")
        XCTAssertTrue(app.staticTexts["Cedar Room"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Juniper & Stone"].exists)
        app.buttons["Clear search"].tap()

        let favorites = element("saved.category.Favorites", in: app)
        favorites.tap()
        let firstFavorited = app.buttons["Favorited"].firstMatch
        XCTAssertTrue(firstFavorited.waitForExistence(timeout: 3))
        firstFavorited.tap()
        XCTAssertTrue(app.staticTexts["Removed from Favorites"].waitForExistence(timeout: 3))
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        XCTAssertTrue(app.buttons["Favorited"].firstMatch.waitForExistence(timeout: 3))

        app.terminate()
        app.launchArguments = [
            "--ui-testing",
            "--saved-audit-scenario=populated"
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Harborlight Coffee Roasters"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Favorited"].firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testAccessibilityXXXLReflowsSavedAndDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--saved-audit-scenario=populated",
            "--ui-testing-accessibility-xxxl"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Log a Sip"].firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Favorited"].firstMatch.waitForExistence(timeout: 3))
        attachScreenshot(named: "implementation-saved-accessibility-xxxl")

        let harborlightCard = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Harborlight Coffee Roasters")
        ).firstMatch
        XCTAssertTrue(harborlightCard.waitForExistence(timeout: 3))
        harborlightCard.tap()
        XCTAssertTrue(element("cafe.detail.sheet", in: app).waitForExistence(timeout: 5))
        let scroll = app.scrollViews["cafe.detail.scroll"]
        let repeatAction = app.buttons["cafe.nextSip.repeat"]
        for _ in 0..<4 where !repeatAction.isHittable { scroll.swipeUp() }
        XCTAssertTrue(repeatAction.isHittable)
        attachScreenshot(named: "implementation-detail-accessibility-xxxl")
        let note = app.buttons["cafe.detail.privateNote"]
        for _ in 0..<8 where !note.isHittable { scroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(note.isHittable)
        attachScreenshot(named: "cafe-private-note-largest-text")
        note.tap()
        XCTAssertTrue(element("cafe.detail.noteEditor", in: app).waitForExistence(timeout: 5))
        let save = app.buttons["cafe.detail.saveNote"]
        XCTAssertTrue(save.exists)
        if !save.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(save.isHittable)
    }

    @MainActor
    func testSipCafeLinkReturnsToTheCafeDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-reset",
            "--saved-audit-scenario=populated"
        ]
        app.launch()

        let harborlightCard = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Harborlight Coffee Roasters")
        ).firstMatch
        XCTAssertTrue(harborlightCard.waitForExistence(timeout: 6))
        harborlightCard.tap()

        let cafeDetail = element("cafe.detail.sheet", in: app)
        XCTAssertTrue(cafeDetail.waitForExistence(timeout: 4))
        let sip = app.buttons["cafe.nextSip.original"]
        XCTAssertTrue(sip.waitForExistence(timeout: 3) && sip.isHittable)
        sip.tap()

        let sipDetail = element("sip.detail.screen", in: app)
        XCTAssertTrue(sipDetail.waitForExistence(timeout: 4))
        let cafeLink = element("sip.detail.cafe", in: app)
        XCTAssertTrue(cafeLink.waitForExistence(timeout: 3))
        cafeLink.tap()

        XCTAssertTrue(cafeDetail.waitForExistence(timeout: 4))
        XCTAssertFalse(sipDetail.exists)
        XCTAssertTrue(app.staticTexts["Harborlight Coffee Roasters"].exists)
    }

    @MainActor
    func testLowerCafeSectionsAndPrivateNoteEditor() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out",
                               "--saved-audit-scenario=populated", "--ui-testing-cafe-lower-sections"]
        app.launch()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Harborlight Coffee Roasters")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 6)); card.tap()
        let scroll = app.scrollViews["cafe.detail.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let note = app.buttons["cafe.detail.privateNote"]
        for _ in 0..<5 where !note.isHittable { scroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(note.isHittable)
        XCTAssertTrue(app.staticTexts["Your Mugshot"].exists)
        XCTAssertFalse(element("cafe.detail.noteEditor", in: app).exists)
        attachScreenshot(named: "cafe-private-note-and-your-mugshot")
        note.tap()
        let editor = element("cafe.detail.noteEditor", in: app)
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        attachScreenshot(named: "cafe-private-note-editor")
        editor.tap()
        editor.typeText("Try the window seat")
        let save = app.buttons["cafe.detail.saveNote"]
        XCTAssertTrue(save.isHittable); save.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Saved privately")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertTrue(note.label.contains("Try the window seat"))

        let about = app.staticTexts["About this cafe"]
        for _ in 0..<5 where !about.isHittable { scroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(about.isHittable)
        XCTAssertTrue(app.staticTexts["Friends at this cafe"].exists)
        XCTAssertTrue(app.staticTexts["1 friend shared a sip here"].exists)
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Copy address")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Share cafe"].exists)
        attachScreenshot(named: "cafe-friends-and-about")
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
