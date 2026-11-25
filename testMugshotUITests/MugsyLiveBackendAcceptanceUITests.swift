import XCTest

/// Explicit owner-promoted acceptance against the existing signed-in app.
/// This test never enables Mugsy consent or enters a fixture/reset flow.
final class MugsyLiveBackendAcceptanceUITests: XCTestCase {
    private var needsRestoration = false

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOwnerPreferencesPersistThroughRealBackendWithoutEnrollment() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Live owner acceptance only runs on explicitly authorized hardware.")
#endif
        guard ProcessInfo.processInfo.environment["MUGSHOT_LIVE_OWNER_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Live owner acceptance requires explicit per-run authorization.")
        }
        let app = XCUIApplication()
        launchRealSettings(app)
        try requireReady(app)
        guard consentIsOff(app) else {
            throw XCTSkip("Owner consent is already on or unreadable. No settings were changed.")
        }
        guard reveal(app.staticTexts[standardDescription], in: app, toward: .up) else {
            throw XCTSkip("Owner pace is already customized. No settings were changed.")
        }
        guard reveal(app.staticTexts[pauseExplanation], in: app, toward: .up) else {
            throw XCTSkip("Could not verify the original pause state. No settings were changed.")
        }
        guard !app.buttons["mugsy.settings.resume"].exists else {
            throw XCTSkip("Owner reminders are already paused. No settings were changed.")
        }

        // Mutation begins only after the real owner defaults are verified.
        // Teardown is independent of the main journey so a failed assertion or
        // network operation still attempts to restore those verified defaults.
        needsRestoration = true
        addTeardownBlock { [weak self] in
            await MainActor.run { self?.attemptRestoration(app) }
        }
        capture(app, "Live-Mugsy-01-original-owner-preferences")

        try saveAndConfirm(app)
        launchRealSettings(app)
        try requireReady(app)
        try require(consentIsOff(app), "An unchanged save must keep consent off.")
        try require(reveal(app.staticTexts[standardDescription], in: app, toward: .up),
            "The real backend must retain Standard pace after relaunch.")

        try choosePace("Light", in: app)
        try saveAndConfirm(app)
        launchRealSettings(app)
        try requireReady(app)
        try require(consentIsOff(app), "Light pace must not enable Mugsy consent.")
        try require(reveal(app.staticTexts[lightDescription], in: app, toward: .up),
            "Light pace must reload from the real backend.")
        capture(app, "Live-Mugsy-02-light-readback")

        let pause = app.buttons["mugsy.settings.pause7"]
        try require(reveal(pause, in: app, toward: .up), "The seven-day pause control must be reachable.")
        pause.tap()
        try saveAndConfirm(app)
        launchRealSettings(app)
        try requireReady(app)
        try require(consentIsOff(app), "Pausing must not enable consent.")
        let resume = app.buttons["mugsy.settings.resume"]
        try require(reveal(resume, in: app, toward: .up), "The saved pause must reload after relaunch.")
        capture(app, "Live-Mugsy-03-pause-readback")

        resume.tap()
        try choosePace("Standard", in: app, toward: .down)
        try saveAndConfirm(app)
        launchRealSettings(app)
        try requireReady(app)
        try require(consentIsOff(app), "Restoration must leave consent off.")
        try require(reveal(app.staticTexts[standardDescription], in: app, toward: .up),
            "Restoration must reload Standard pace.")
        try require(reveal(app.staticTexts[pauseExplanation], in: app, toward: .up),
            "The restored pause controls must remain accessible.")
        try require(!app.buttons["mugsy.settings.resume"].exists, "Restoration must leave optional reminders unpaused.")
        needsRestoration = false
        capture(app, "Live-Mugsy-04-restored-owner-preferences")
    }

    private let standardDescription = "Three a week at most, with at least two days between them."
    private let lightDescription = "One a week at most. A little more room between visits."
    private let pauseExplanation = "Tap Save to apply your pause across supported devices. Direct friend notifications keep their own settings."
    private let confirmation = "Your reminder preferences are saved."
    private enum Direction { case up, down }
    private struct AcceptanceFailure: Error { let message: String }

    @MainActor
    private func launchRealSettings(_ app: XCUIApplication) {
        if app.state != .notRunning { app.terminate() }
        app.launchArguments = ["--debug-open-mugsy-reminders"]
        app.launch()
    }

    @MainActor
    private func requireReady(_ app: XCUIApplication) throws {
        let consent = app.switches["mugsy.settings.consent"]
        try require(consent.waitForExistence(timeout: 40), "Real authenticated Mugsy settings did not open.")
        let save = app.buttons["mugsy.settings.save"]
        let ready = NSPredicate { _, _ in
            save.exists && save.isEnabled && consent.isEnabled
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 20)
        try require(result == .completed, "The live backend did not enable preference saving.")
    }

    @MainActor
    private func consentIsOff(_ app: XCUIApplication) -> Bool {
        let consent = app.switches["mugsy.settings.consent"]
        return consent.exists && (consent.value as? String) == "0"
    }

    @MainActor
    private func choosePace(_ title: String, in app: XCUIApplication, toward direction: Direction = .up) throws {
        let pace = app.descendants(matching: .any).matching(identifier: "mugsy.settings.pace").firstMatch
        try require(reveal(pace, in: app, toward: direction), "The pace control must be reachable.")
        pace.tap()
        let choice = app.buttons[title]
        try require(choice.waitForExistence(timeout: 5), "The requested pace must be offered.")
        choice.tap()
    }

    @MainActor
    private func saveAndConfirm(_ app: XCUIApplication) throws {
        let consent = app.switches["mugsy.settings.consent"]
        try require(reveal(consent, in: app, toward: .down), "Consent must remain inspectable before saving.")
        try require(consentIsOff(app), "Live acceptance never saves an opted-in consent state.")
        let save = app.buttons["mugsy.settings.save"]
        try require(save.exists && save.isEnabled, "The real Save action must be enabled.")
        save.tap()
        try require(reveal(app.staticTexts[confirmation], in: app, toward: .up),
            "The real backend must confirm the save.")
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, toward direction: Direction) -> Bool {
        for _ in 0..<10 {
            var nextDirection = direction
            if element.exists {
                if element.isHittable { return true }
                let frame = element.frame
                let visible = app.frame.insetBy(dx: 0, dy: 88)
                if element.elementType == .staticText && frame.height > 0 && visible.contains(frame) { return true }
                // A previous swipe may place the requested row just above the
                // toolbar. Correct direction rather than repeatedly scrolling
                // farther away from an existing real control.
                if frame.height > 0 {
                    if frame.maxY < visible.minY { nextDirection = .down }
                    else if frame.minY > visible.maxY { nextDirection = .up }
                }
            }
            if nextDirection == .up { app.swipeUp() } else { app.swipeDown() }
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func attemptRestoration(_ app: XCUIApplication) {
        guard needsRestoration else { return }
        launchRealSettings(app)
        do {
            try requireReady(app)
            let consent = app.switches["mugsy.settings.consent"]
            guard reveal(consent, in: app, toward: .down) else {
                throw AcceptanceFailure(message: "Could not reach the consent control for restoration.")
            }
            // Never overwrite consent changed outside this journey.
            try require(consentIsOff(app), "Consent changed outside this journey; do not overwrite it.")
            try choosePace("Standard", in: app)
            _ = reveal(app.staticTexts[pauseExplanation], in: app, toward: .up)
            let resume = app.buttons["mugsy.settings.resume"]
            if resume.exists {
                try require(reveal(resume, in: app, toward: .down), "Could not reach Resume during restoration.")
                resume.tap()
            }
            try saveAndConfirm(app)
            needsRestoration = false
            capture(app, "Live-Mugsy-cleanup-restored")
        } catch {
            XCTFail("Live preference cleanup could not confirm restoration; inspect the owner's saved pace and pause before reporting completion.")
        }
    }

    @MainActor
    private func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw AcceptanceFailure(message: message) }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        // Call sites are restricted to the Mugsy preferences screen.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
