import AppIntents
import TipKit

/// Siri and Shortcuts. The intents themselves live in Sources/Shared so the widget can use them too.
struct PocketShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TownReportIntent(),
                    phrases: ["\(.applicationName) town report",
                              "What is happening in \(.applicationName)",
                              "How is my \(.applicationName) town"],
                    shortTitle: "Town Report", systemImageName: "newspaper")
        AppShortcut(intent: OpenTownIntent(),
                    phrases: ["Open my town in \(.applicationName)", "Visit my \(.applicationName) town"],
                    shortTitle: "Open My Town", systemImageName: "house")
    }
}

/// TipKit: two tips for the first visit, gone once the player has done the thing.
struct MeddleTip: Tip {
    var title: Text { Text("Tap anyone to meddle") }
    var message: Text? { Text("Give coins, rob, jail, crown or exile. The town remembers.") }
    var image: Image? { Image(systemName: "hand.tap.fill") }
}

struct StartTip: Tip {
    var title: Text { Text("Start is where the fun is") }
    var message: Text? { Text("Your daily gift, the wish, the Season, stamps, miracles and widgets.") }
    var image: Image? { Image(systemName: "star.circle.fill") }
}
