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
        snapshot("x0_Title")
        app.terminate()

        // 01-10 are the store set: no prices anywhere in them (Guideline 2.3.7).
        // x* are for App Review screenshots of the purchases and are never uploaded as store shots.
        let shots: [(String, [String])] = [
            ("01_Town", []),
            ("02_Meddle", ["-showCard"]),
            ("03_Gift", ["-showGift"]),
            ("04_Season", ["-showSeason", "-clubOn"]),
            ("05_Album", ["-showAlbum"]),
            ("06_Widgets", ["-showWidgets"]),
            ("07_Miracles", ["-showMiracles", "-clubOn"]),
            ("08_Invite", ["-showInvite", "-invited"]),
            ("09_Laws", ["-showLaws", "-proOn"]),
            ("10_Almanac", ["-showAlmanac", "-clubOn"]),
            ("x1_Club", ["-showClub"]),
            ("x2_Paywall", ["-showPaywall"]),
            ("x3_Yards", ["-showYards", "-showPrices"]),
            ("x4_Jar", ["-showMiracles", "-showPrices"]),
            ("x5_Invites", ["-showInvite", "-showPrices"]),
            ("x6_Boost", ["-showSeason", "-showPrices"]),
            ("x7_Records", ["-showRecords"]),
            ("x8_Wish", ["-showWish"]),
            ("x9_Start", ["-showStart"]),
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
