import XCTest

final class HomeJournalParityUITests: XCTestCase {
    private let home = "home-00000000-0000-4000-8000-000000000081"
    private let cafe = "visit-00000000-0000-4000-8000-000000000082"
    private let elsewhere = "visit-00000000-0000-4000-8000-000000000083"

    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out",
                               "--ui-testing-reduce-motion", "--ui-testing-home-journal"] + extra
        app.launch(); return app
    }

    @MainActor func testHomeCafeAndElsewhereUseTheSameActualPhotoGeometryAndMetadata() {
        let app = launch()
        let homePhoto = app.descendants(matching: .any)["journal.thumbnail.\(home)"].firstMatch
        XCTAssertTrue(homePhoto.waitForExistence(timeout: 8))
        for id in [cafe, elsewhere] {
            let photo = app.descendants(matching: .any)["journal.thumbnail.\(id)"].firstMatch
            XCTAssertTrue(photo.exists)
            XCTAssertEqual(homePhoto.frame.width, photo.frame.width, accuracy: 0.5)
            XCTAssertEqual(homePhoto.frame.height, photo.frame.height, accuracy: 0.5)
        }
        XCTAssertTrue(app.buttons["Open Cinnamon latte at Kitchen counter"].exists)
        XCTAssertGreaterThan(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "journal.open.\(home)", "Cinnamon latte")).count, 0)
        app.buttons["journal.open.\(home)"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Opened Cinnamon latte"].waitForExistence(timeout: 3))
        capture(app, "01-journal-card-parity")
    }

    @MainActor func testHomeArchiveUsesTheSharedRowsAndCalendarDateFiltering() {
        let app = launch()
        app.buttons["journal.fixture.archive"].tap()
        XCTAssertTrue(app.staticTexts["Your Journal"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Private Home sips"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["journal.thumbnail.\(home)"].firstMatch.exists)
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["Cinnamon latte"].waitForExistence(timeout: 3))
        capture(app, "02-home-calendar")
    }

    @MainActor func testLargeTextAndStaleHomeScopeKeepControlsAndPrivateIdentitySafe() {
        let app = launch(["--ui-testing-accessibility-xxxl"])
        let photo = app.descendants(matching: .any)["journal.thumbnail.\(home)"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["journal.open.\(home)"].firstMatch.isHittable)
        XCTAssertTrue(app.buttons["Open Cinnamon latte at Kitchen counter"].exists)
        capture(app, "03-journal-largest-text")
        for _ in 0..<5 where !app.buttons["journal.fixture.switchScope"].isHittable { app.swipeUp() }
        app.buttons["journal.fixture.switchScope"].tap()
        XCTAssertFalse(app.buttons["Open Cinnamon latte at Kitchen counter"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["journal.thumbnail.\(home)"].firstMatch.exists)
    }

    @MainActor func testHomeCoffeeFilterDoesNotStrandElsewhereEntries() {
        let app = launch()
        app.buttons["journal.fixture.archive"].tap()
        let archive = app.scrollViews["journal.archive.entries"].firstMatch
        XCTAssertTrue(archive.waitForExistence(timeout: 5))
        let homeRow = archive.descendants(matching: .any)["journal.sip.\(home)"].firstMatch
        let elsewhereRow = archive.descendants(matching: .any)["journal.sip.\(elsewhere)"].firstMatch
        let coffee = archive.buttons["journal.coffee.00000000-0000-4000-8000-000000000084"]
        XCTAssertTrue(coffee.waitForExistence(timeout: 5)); coffee.tap()
        XCTAssertTrue(coffee.isSelected)
        XCTAssertTrue(homeRow.exists)
        XCTAssertTrue(archive.staticTexts["Cinnamon latte"].exists)
        assertAbsent(elsewhereRow)
        assertAbsent(archive.staticTexts["Iced matcha"])
        let elsewhereFilter = archive.buttons["journal.context.elsewhere"]
        elsewhereFilter.tap()
        XCTAssertTrue(elsewhereFilter.isSelected)
        XCTAssertTrue(elsewhereRow.waitForExistence(timeout: 3))
        XCTAssertTrue(archive.staticTexts["Iced matcha"].exists)
        assertAbsent(homeRow)
        assertAbsent(archive.staticTexts["Cinnamon latte"])
        archive.buttons["journal.context.all"].tap()
        XCTAssertTrue(archive.buttons["journal.coffee.all"].isSelected)
        XCTAssertTrue(homeRow.waitForExistence(timeout: 3))
        XCTAssertTrue(elsewhereRow.exists, "Returning to All must not restore the hidden bean filter")
    }

    @MainActor private func assertAbsent(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let absent = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [absent], timeout: 3), .completed,
                       "Filtered content must leave the archive accessibility tree", file: file, line: line)
        XCTAssertFalse(element.exists, file: file, line: line)
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
