import XCTest

/// Drives the app to produce the App Store screenshots.
///
/// `-screenshots` seeds a fixed town with a morning of history, so the yard is
/// never empty and the shots are the same every run.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        var app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
        sleep(2)
        snapshot("01_Title")
        app.terminate()

        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-screenshots"]
        app.launch()
        sleep(6)
        snapshot("02_Town")
        app.terminate()

        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-screenshots", "-showCard"]
        app.launch()
        sleep(3)
        snapshot("03_Meddle")
        app.terminate()

        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-screenshots", "-showNews"]
        app.launch()
        sleep(3)
        snapshot("04_Away")
    }
}
