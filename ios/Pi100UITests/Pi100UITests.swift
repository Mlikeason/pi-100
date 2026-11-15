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

    /// App Store screenshots (zh-Hans): start, a round in progress with one mistake, results, history.
    /// TEST_RUNNER_STORE_LANDSCAPE=1 rotates first (iPad two-pane layout).
    @MainActor func testStoreScreenshots() {
        let pi = Array("1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679").map { Int(String($0))! }
        if ProcessInfo.processInfo.environment["STORE_LANDSCAPE"] == "1" { XCUIDevice.shared.orientation = .landscapeLeft }
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["start"].waitForExistence(timeout: 10))
        shot("Store-1-Start")
        app.buttons["start"].tap()
        func type(_ range: Range<Int>, wrongAt: Int? = nil) {
            for i in range {
                let d = i == wrongAt ? (pi[i] + 3) % 10 : pi[i]
                app.buttons["digit-\(d)"].tap()
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        type(0..<38, wrongAt: 22)
        XCTAssertEqual(app.staticTexts["progress"].label, "38 / 100")
        shot("Store-2-Playing")
        type(38..<100)
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
        shot("Store-3-Results")
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["history"].waitForExistence(timeout: 5))
        app.buttons["history"].tap()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        shot("Store-4-History")
    }
    @MainActor private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
