import SwiftUI

@main
struct PocketBeingsApp: App {
    @StateObject private var model = TownModel()
    @StateObject private var pro = Pro()
    @StateObject private var player = Player()
    @StateObject private var extras = Extras()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(pro)
                .environmentObject(player)
                .environmentObject(extras)
                .preferredColorScheme(.light)
        }
    }
}
