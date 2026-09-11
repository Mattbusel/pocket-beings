import SwiftUI

@main
struct PocketBeingsApp: App {
    @StateObject private var model = TownModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.light)
        }
    }
}
