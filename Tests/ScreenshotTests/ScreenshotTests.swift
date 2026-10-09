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
        // Warm-up launch: the first launch after install can draw a blank frame.
        var app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
        sleep(2)
        dismissSystemSignIn(app)
        snapshot("00_Title")
        app.terminate()

        let shots: [(String, [String])] = [
            ("01_Town", []),
            ("02_Wish", ["-showWish"]),
            ("03_Meddle", ["-showCard"]),
            ("04_Miracles", ["-showMiracles"]),
            ("05_Invite", ["-showInvite", "-invited"]),
            ("06_Laws", ["-showLaws", "-proOn"]),
            ("07_Yards", ["-showYards", "-yard", "night", "-ownYards"]),
            ("08_Start", ["-showStart"]),
            ("09_Records", ["-showRecords"]),
            ("10_Away", ["-showNews", "-yard", "snow"]),
            ("11_Paywall", ["-showPaywall"]),
        ]
        for (name, args) in shots {
            app = XCUIApplication()
            setupSnapshot(app)
            app.launchArguments += ["-screenshots"] + args
            app.launch()
            sleep(name == "01_Town" ? 6 : 4)
            dismissSystemSignIn(app)
            snapshot(name)
            app.terminate()
        }
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
