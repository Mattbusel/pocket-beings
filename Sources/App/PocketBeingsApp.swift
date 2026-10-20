import SwiftUI
import TipKit

@main
struct PocketBeingsApp: App {
    @StateObject private var model = TownModel()
    @StateObject private var pro = Pro()
    @StateObject private var player = Player()
    @StateObject private var extras = Extras()
    @StateObject private var club = Club()

    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-screenshots") || args.contains("-FASTLANE_SNAPSHOT") || args.contains("-demoAutoplay") || args.contains("-previewTour") {
            Tips.hideAllTipsForTesting()
        }
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(pro)
                .environmentObject(player)
                .environmentObject(extras)
                .environmentObject(club)
                .preferredColorScheme(.light)
        }
    }
}
