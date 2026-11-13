import XCTest
import Vision

/// Run on a disposable Simulator with the documented recipe screenshot added
/// to Photos and MUGSHOT_NATIVE_SHARE_FIXTURE=1 in the test runner environment.
final class HomeNativeShareUITests: XCTestCase {
    @MainActor func testPhotosShareReopensTheRecipeSourceAndPocketSipDraft() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MUGSHOT_NATIVE_SHARE_FIXTURE"] == "1")
        continueAfterFailure = false
        let mugshot = XCUIApplication()
        mugshot.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion"]
        mugshot.launch()
        let photos = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        photos.terminate()
        photos.launch()
        let deny = photos.alerts.buttons["Don’t Allow"]
        if deny.exists && deny.isHittable { deny.tap() }
        let cancel = photos.buttons["Cancel"]
        if cancel.isHittable { cancel.tap() }
        try openMugshotShare(from: photos)
        _ = try visibleText("Pocket Sip")
        capture("09-native-image-destinations")
        try tapVisibleText("Recipe screenshot", on: photos)
        _ = try visibleText("Save recipe source")
        capture("09b-native-recipe-source-preview")
        try tapVisibleText("Save recipe source", on: photos)
        _ = try visibleText("Open Add")
        capture("10-native-recipe-source-saved")
        try tapVisibleText("Done", on: photos)
        relaunch(mugshot)
        openHome(mugshot)
        let resume = mugshot.buttons["home.entry.continueRecipe"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8)); resume.tap()
        let count = mugshot.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@ AND label CONTAINS %@",
                                                              "home.recipe.extractedCount", "4 ingredients", "3 steps")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 8))
        capture("11-shared-recipe-review")
        mugshot.buttons["Cancel"].tap()
        relaunch(mugshot)
        openHome(mugshot)
        XCTAssertTrue(resume.waitForExistence(timeout: 6)); resume.tap()
        XCTAssertTrue(count.waitForExistence(timeout: 8))
        let name = mugshot.textFields["home.recipe.name"]
        if name.value as? String == "Recipe name" {
            let missing = mugshot.buttons["Add a recipe name"]
            let scroll = mugshot.scrollViews["home.recipe.captureScroll"]
            for _ in 0..<4 where !missing.isHittable { scroll.swipeDown(velocity: .slow) }
            XCTAssertTrue(missing.isHittable); missing.tap()
            name.typeText("Iced Maple Oat Matcha")
            mugshot.buttons["home.recipe.keyboardDone"].tap()
        }
        mugshot.buttons["home.recipe.saveIdea"].tap()
        XCTAssertTrue(mugshot.buttons["home.makeWithGuidance"].waitForExistence(timeout: 6))
        XCTAssertFalse(resume.exists)

        mugshot.buttons["Close Log a Sip"].tap()
        photos.activate()
        try openMugshotShare(from: photos)
        try tapVisibleText("Pocket Sip", on: photos)
        try tapVisibleText("Save draft", on: photos)
        _ = try visibleText("Draft saved")
        capture("12-system-pocket-sip-saved")
        try tapVisibleText("Done", on: photos)
        relaunch(mugshot)
        openPocketDraft(mugshot, expectedPhotos: 1)
        capture("13-system-pocket-sip-reopened")
    }

    @MainActor func testGuestPhotoDraftKeepsTwoPhotosAcrossRelaunch() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MUGSHOT_NATIVE_SHARE_FIXTURE"] == "1")
        continueAfterFailure = false
        let mugshot = XCUIApplication()
        mugshot.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion"]
        mugshot.launch()
        openGuestDrafts(mugshot)
        let photos = mugshot.buttons["drafts.addPhotos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 5)); photos.tap()
        try saveTwoPhotos(mugshot)
        capture("14-guest-photo-draft-saved")
        relaunch(mugshot)
        openPocketDraft(mugshot, expectedPhotos: 2)
        capture("15-guest-photo-draft-reopened")
    }

    @MainActor func testJournalPhotoDraftCanOpenImmediatelyAndAfterRelaunch() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MUGSHOT_NATIVE_SHARE_FIXTURE"] == "1")
        continueAfterFailure = false
        let mugshot = XCUIApplication()
        mugshot.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-home-account", "--ui-testing-reduce-motion"]
        mugshot.launch()
        openJournalDrafts(mugshot)
        let photos = mugshot.buttons["drafts.addPhotos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 5)); photos.tap()
        try saveTwoPhotos(mugshot)
        mugshot.buttons["pocketSip.open"].tap()
        assertDraftPhotos(in: mugshot, count: 2)
        relaunch(mugshot)
        openJournalDrafts(mugshot)
        let draft = mugshot.buttons["Resume Pocket Sip"]
        XCTAssertTrue(draft.waitForExistence(timeout: 6)); draft.tap()
        assertDraftPhotos(in: mugshot, count: 2)
        capture("journal-photo-draft-reopened")
    }

    @MainActor func testSafariLinkOffersRecipeAndCafeAndReopensTheSource() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MUGSHOT_NATIVE_SHARE_FIXTURE"] == "1")
        continueAfterFailure = false
        let mugshot = XCUIApplication()
        mugshot.launchArguments = ["--ui-testing", "--ui-testing-reset", "--ui-testing-signed-out", "--ui-testing-reduce-motion"]
        mugshot.launch()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.terminate()
        safari.open(try XCTUnwrap(URL(string: "https://example.invalid/iced-matcha")))
        let share = safari.buttons["ShareButton"].firstMatch
        if !share.waitForExistence(timeout: 3) || !share.isHittable {
            let pageMenu = safari.buttons["MoreMenuButton"].firstMatch
            XCTAssertTrue(pageMenu.waitForExistence(timeout: 6)); pageMenu.tap()
        }
        XCTAssertTrue(share.waitForExistence(timeout: 8)); share.tap()
        try tapVisibleText("Mugshot", on: safari, below: 0.25)
        _ = try visibleText("Save a recipe")
        capture("16-native-link-destinations")
        try tapVisibleText("Save a cafe", on: safari)
        _ = try visibleText("Save cafe")
        capture("17-native-link-cafe-lookup")
        try tapVisibleText("Back", on: safari)
        try tapVisibleText("Save a recipe", on: safari)
        try tapVisibleText("Save recipe source", on: safari)
        _ = try visibleText("Open Add")
        try tapVisibleText("Done", on: safari)
        relaunch(mugshot)
        openHome(mugshot)
        let resume = mugshot.buttons["home.entry.continueRecipe"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8)); resume.tap()
        let editSource = mugshot.buttons["home.recipe.editSource"]
        XCTAssertTrue(editSource.waitForExistence(timeout: 6)); editSource.tap()
        let editLink = mugshot.buttons["home.recipe.link"]
        XCTAssertTrue(editLink.waitForExistence(timeout: 6)); editLink.tap()
        let link = mugshot.textFields["home.recipe.sourceURL"]
        XCTAssertTrue(link.waitForExistence(timeout: 6))
        XCTAssertEqual(link.value as? String, "https://example.invalid/iced-matcha")
        capture("18-native-shared-link-review")
    }

    @MainActor private func relaunch(_ app: XCUIApplication) {
        app.terminate()
        app.launchArguments.removeAll { $0 == "--ui-testing-reset" }
        app.launch()
    }

    @MainActor private func openHome(_ app: XCUIApplication) {
        app.buttons["mugshot.tab.add"].tap()
        let home = app.buttons["logASipV3.context.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 6)); home.tap()
    }

    @MainActor private func openPocketDraft(_ app: XCUIApplication, expectedPhotos: Int) {
        openGuestDrafts(app)
        let pocketSip = app.buttons["Resume Pocket Sip"]
        XCTAssertTrue(pocketSip.waitForExistence(timeout: 6)); pocketSip.tap()
        assertDraftPhotos(in: app, count: expectedPhotos)
    }

    @MainActor private func assertDraftPhotos(in app: XCUIApplication, count: Int) {
        for index in 0..<count {
            let photo = app.descendants(matching: .any)["logASipV3.photos.thumbnail.\(index)"].firstMatch
            XCTAssertTrue(photo.waitForExistence(timeout: 6))
        }
    }

    @MainActor private func openJournalDrafts(_ app: XCUIApplication) {
        app.buttons["mugshot.tab.journal"].tap()
        let drafts = app.buttons["journal.drafts.manage"]
        XCTAssertTrue(drafts.waitForExistence(timeout: 8)); drafts.tap()
    }

    @MainActor private func saveTwoPhotos(_ app: XCUIApplication) throws {
        app.buttons["pocketSip.choose"].tap()
        let pickerTitle = try visibleText("Select up to 10 photos")
        let privacyCard = try? visibleText("Private Access to Photos", timeout: 1)
        // The first row contains two fictional QA images in a three-column grid.
        let firstRow = privacyCard.map { $0.dy + 0.235 } ?? (pickerTitle.dy + 0.165)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: firstRow)).tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: firstRow)).tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: pickerTitle.dy + 0.045)).tap()
        XCTAssertTrue(app.staticTexts["2 photos are ready in your private draft."].waitForExistence(timeout: 10))
    }

    @MainActor private func openGuestDrafts(_ app: XCUIApplication) {
        app.buttons["mugshot.tab.saved"].tap()
        let library = app.buttons["home.library.entry"]
        XCTAssertTrue(library.waitForExistence(timeout: 8)); library.tap()
        let drafts = app.buttons["home.drafts.open"]
        XCTAssertTrue(drafts.waitForExistence(timeout: 8)); drafts.tap()
    }

    @MainActor private func openMugshotShare(from photos: XCUIApplication) throws {
        let share = photos.buttons["Share"].firstMatch
        if !share.waitForExistence(timeout: 3) || !share.isHittable {
            let latest = photos.images.matching(identifier: "PXGGridLayout-Info").allElementsBoundByIndex.last
            if let latest {
                latest.tap()
            } else {
                // Newer Photos versions omit grid images from the host AX tree.
                // Locate text on the fictional recipe image instead.
                try tapVisibleText("Ingredients:", on: photos)
            }
        }
        XCTAssertTrue(share.waitForExistence(timeout: 5)); share.tap()
        try tapVisibleText("Mugshot", on: photos, below: 0.25)
    }

    /// The Photos activity controller and extension may sit outside the host's
    /// accessibility tree. Use live on-device text bounds on this QA Simulator.
    @MainActor private func visibleText(_ label: String, below top: CGFloat = 0, timeout: TimeInterval = 20) throws -> CGVector {
        let until = Date.now.addingTimeInterval(timeout)
        repeat {
            let screenshot = XCUIScreen.main.screenshot()
            guard let cgImage = screenshot.image.cgImage else { continue }
            let recognition = VNRecognizeTextRequest()
            recognition.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: cgImage).perform([recognition])
            for row in recognition.results ?? [] where 1 - row.boundingBox.midY >= top {
                guard let candidate = row.topCandidates(1).first,
                      let match = candidate.string.range(of: label, options: .caseInsensitive) else { continue }
                let bounds = (try? candidate.boundingBox(for: match))?.boundingBox ?? row.boundingBox
                return CGVector(dx: bounds.midX, dy: 1 - bounds.midY)
            }
        } while Date.now < until
        capture("native-share-missing-\(label)")
        throw NSError(domain: "HomeNativeShareUITests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "The isolated Simulator did not display \(label) in the remote share sheet."
        ])
    }

    @MainActor private func tapVisibleText(_ label: String, on host: XCUIApplication, below top: CGFloat = 0) throws {
        let offset = try visibleText(label, below: top)
        host.coordinate(withNormalizedOffset: offset).tap()
    }

    @MainActor private func capture(_ label: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = label
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
