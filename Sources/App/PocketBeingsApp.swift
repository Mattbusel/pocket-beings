import SwiftUI

@main
struct PocketBeingsApp: App {
    @StateObject private var model = TownModel()
    @StateObject private var pro = Pro()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(pro)
                .preferredColorScheme(.light)
        }
    }
}
