import XCTest

final class Pi100UITests: XCTestCase {
    @MainActor func testPlayPauseRotateAndRestore() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["start"].waitForExistence(timeout: 10))
        app.buttons["start"].tap()
        for digit in [1, 4, 1, 5, 9] { app.buttons["digit-\(digit)"].tap() }
        XCTAssertEqual(app.staticTexts["progress"].label, "5 / 100")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(app.staticTexts["progress"].label, "5 / 100")
        XCTAssertTrue(app.buttons["digit-1"].waitForExistence(timeout: 5))
        XCTAssertLessThan(app.staticTexts["progress"].frame.maxY, app.buttons["digit-1"].frame.minY,
                          "The keypad must stay below the digit board after resizing.")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Landscape"; shot.lifetime = .keepAlways; add(shot)
        XCUIDevice.shared.orientation = .portrait
        app.buttons["pause"].tap()
        XCTAssertFalse(app.buttons["digit-2"].isEnabled)
        app.buttons["start"].tap()
        app.buttons["digit-2"].tap()
        XCTAssertEqual(app.staticTexts["progress"].label, "6 / 100")
        app.terminate()
        app.launchArguments.append("--restore")
        app.launch()
        XCTAssertTrue(app.buttons["start"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["progress"].label, "6 / 100")
        let final = XCTAttachment(screenshot: app.screenshot()); final.name = "Restored portrait"; final.lifetime = .keepAlways; add(final)
    }
    @MainActor func testHintsSettingsAndRestartConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.buttons["start"].tap()
        app.buttons["hint"].tap()
        app.buttons["digit-1"].tap()
        app.buttons["restart"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["progress"].label, "1 / 100")
        app.buttons["settings"].tap()
        XCTAssertTrue(app.staticTexts["Zhu Hong"].exists)
        app.buttons["Done"].tap()
        app.buttons["history"].tap()
        XCTAssertTrue(app.buttons["game-center"].exists)
    }
}
