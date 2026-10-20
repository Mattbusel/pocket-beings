import AppIntents
import SwiftUI
import WidgetKit

@main
struct PocketWidgets: WidgetBundle {
    var body: some Widget {
        GrudgeWidget()
        TownSquareWidget()
        TownHallWidget()
        LockWidget()
        if #available(iOS 18.0, *) {
            OpenTownControl()
        }
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snap: TownSnap
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snap: .sample)
    }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let s = TownSnap.now()
        completion(context.isPreview && !s.hasTown ? placeholder(in: context) : Entry(date: .now, snap: s))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now, snap: TownSnap.now())], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

/// The front page, small: one headline from the town. Free. Also StandBy.
struct GrudgeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "grudge", provider: Provider()) { e in
            GrudgeView(snap: e.snap).containerBackground(UI.paper, for: .widget)
        }
        .configurationDisplayName("The Daily Grudge")
        .description("The latest scandal from your town.")
        .supportedFamilies([.systemSmall])
    }
}

/// The yard itself, with everyone in it, the Crown and the jail. Free.
struct TownSquareWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "square", provider: Provider()) { e in
            SquareEntryView(snap: e.snap).containerBackground(UI.chrome, for: .widget)
        }
        .configurationDisplayName("Town Square")
        .description("Your whole town on your Home Screen. Tap refresh to catch up.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct SquareEntryView: View {
    @Environment(\.widgetFamily) private var family
    let snap: TownSnap
    var body: some View {
        TownSquareView(snap: snap, large: family == .systemLarge)
    }
}

/// Town hall, medium: the front page and who runs the place. With The Big Hand or the Town Club.
struct TownHallWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "townhall", provider: Provider()) { e in
            TownHallView(snap: e.snap).containerBackground(UI.chrome, for: .widget)
        }
        .configurationDisplayName("Town Hall")
        .description("Headlines, the Crown, the richest being and who is in jail.")
        .supportedFamilies([.systemMedium])
    }
}

/// Lock Screen: the headline, the Crown and the day. Free.
struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "lock", provider: Provider()) { e in
            LockView(snap: e.snap).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Town on the Lock Screen")
        .description("The latest headline, who holds the Crown, and the day.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

/// Control Center (iOS 18): one button straight into the town.
@available(iOS 18.0, *)
struct OpenTownControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mattbusel.pocketbeings.open") {
            ControlWidgetButton(action: OpenTownIntent()) {
                Label("My Town", systemImage: "house.fill")
            }
        }
        .displayName("Open My Town")
        .description("Jump straight into your Pocket Beings town.")
    }
}
