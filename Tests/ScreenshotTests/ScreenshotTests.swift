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
        dismissSystemSignIn(app)
        snapshot("01_Title")
        app.terminate()

        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-screenshots"]
        app.launch()
        sleep(6)
        dismissSystemSignIn(app)
        snapshot("02_Town")
        app.terminate()

        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-screenshots", "-showCard"]
        app.launch()
        sleep(3)
        dismissSystemSignIn(app)
        snapshot("03_Meddle")
        app.terminate()

        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-screenshots", "-showNews"]
        app.launch()
        sleep(3)
        dismissSystemSignIn(app)
        snapshot("04_Away")
        app.terminate()

        // The Big Hand's paywall, for the in-app purchase review screenshot.
        // Not one of the store screenshots: it is deleted before committing.
        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-screenshots", "-showPaywall"]
        app.launch()
        sleep(3)
        dismissSystemSignIn(app)
        snapshot("05_Paywall")
    }

    /// The CI simulator is not signed in to an Apple Account, and iOS 26 puts up a
    /// "Sign in to Apple Account" system prompt over the app. It is not the app's doing
    /// (Pro stays off StoreKit in snapshot runs); cancel it so it is not in the shot.
    private func dismissSystemSignIn(_ app: XCUIApplication) {
        let hosts = [XCUIApplication(bundleIdentifier: "com.apple.springboard"), app]
        for _ in 0..<3 {
            var tapped = false
            for host in hosts {
                let cancel = host.buttons["Cancel"]
                if cancel.waitForExistence(timeout: 1.5) && cancel.isHittable { cancel.tap(); tapped = true }
            }
            if !tapped { return }
            sleep(1)
        }
    }
}
