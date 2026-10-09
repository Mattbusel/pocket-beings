import SwiftUI
import WidgetKit

@main
struct PocketWidgets: WidgetBundle {
    var body: some Widget {
        GrudgeWidget()
        TownHallWidget()
    }
}

/// What the town looks like right now. The widget runs the same engine the app
/// does: it catches the saved town up to the present (capped, exactly as the app
/// does on opening), so the headline here is the one waiting in the app.
struct TownSnap {
    var name: String
    var day: Int
    var headlines: [String]
    var crown: String
    var richest: String
    var jailed: Int
    var prices: Double
    var hasTown: Bool
    var bigHand: Bool

    static func now() -> TownSnap {
        YardTheme.reload()
        guard var t = Shared.loadTown() else {
            return TownSnap(name: "Pocket Beings", day: 1, headlines: ["Start a town and seven tiny people move in."],
                            crown: "nobody", richest: "", jailed: 0, prices: 1, hasTown: false, bigHand: Shared.bigHand)
        }
        _ = Society.catchUp(&t, elapsed: Date().timeIntervalSince(t.savedAt), secondsPerTick: 2.4)
        let big = t.ledger.filter(\.big).prefix(4).map(\.text)
        let rich = t.beings.max { $0.wallet < $1.wallet }
        return TownSnap(name: t.name, day: t.day, headlines: big.isEmpty ? Array(t.ledger.prefix(3).map(\.text)) : Array(big),
                        crown: t.holder(of: .crown).map { "\($0.face) \($0.name)" } ?? "nobody",
                        richest: rich.map { "\($0.face) \($0.name) \($0.wallet)" } ?? "",
                        jailed: t.beings.filter { $0.isJailed(at: t.tick) }.count,
                        prices: t.priceIndex, hasTown: true, bigHand: Shared.bigHand)
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snap: TownSnap
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snap: TownSnap(name: "Grudge Hollow", day: 8, headlines: ["👑 Malvora bought the Crown's seat for 312.", "💼 the Cousins hit Gary for 88. Snik planned it."],
                                         crown: "😈 Malvora", richest: "📈 Braxton 410", jailed: 1, prices: 1.4, hasTown: true, bigHand: true))
    }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let s = TownSnap.now()
        completion(context.isPreview && !s.hasTown ? placeholder(in: context) : Entry(date: .now, snap: s))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now, snap: TownSnap.now())], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

/// The front page, small: one headline from the town. Free.
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

/// Town hall, medium: the front page and who runs the place. Comes with The Big Hand.
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

struct GrudgeView: View {
    let snap: TownSnap
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("THE DAILY GRUDGE").font(UI.font(9, .black)).kerning(1.2).foregroundStyle(UI.ink.opacity(0.55))
                Spacer()
                Text("d\(snap.day)").font(UI.font(9, .black)).foregroundStyle(UI.ink.opacity(0.4))
            }
            Rectangle().fill(UI.ink.opacity(0.7)).frame(height: 1.5)
            Text(snap.headlines.first ?? "").font(UI.font(13, .black)).foregroundStyle(UI.ink)
                .lineLimit(5).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text(snap.name).font(UI.font(10, .bold)).foregroundStyle(UI.link).lineLimit(1)
        }
    }
}

struct TownHallView: View {
    let snap: TownSnap
    var body: some View {
        if !snap.bigHand {
            VStack(alignment: .leading, spacing: 6) {
                Text("🫵 THE BIG HAND").font(UI.font(13, .black)).foregroundStyle(UI.ink)
                Text("The Town Hall widget comes with The Big Hand. The Daily Grudge widget is free.")
                    .font(UI.font(11, .semibold)).foregroundStyle(UI.ink.opacity(0.7))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(snap.name.uppercased()).font(UI.font(10, .black)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(LinearGradient(colors: [UI.barA, UI.barB], startPoint: .leading, endPoint: .trailing))
                    ForEach(Array(snap.headlines.prefix(3).enumerated()), id: \.offset) { _, h in
                        Text(h).font(UI.font(11, .bold)).foregroundStyle(UI.ink).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 4) {
                    stat("👑", snap.crown)
                    stat("💰", snap.richest)
                    stat("🔒", "\(snap.jailed) in jail")
                    stat("📈", String(format: "prices ×%.1f", snap.prices))
                    stat("📅", "day \(snap.day)")
                }
                .padding(6)
                .frame(width: 118, alignment: .leading)
                .background(UI.paper)
            }
        }
    }
    private func stat(_ i: String, _ v: String) -> some View {
        HStack(spacing: 3) { Text(i).font(.system(size: 10)); Text(v).font(UI.font(10, .black)).foregroundStyle(UI.ink).lineLimit(1).minimumScaleFactor(0.7) }
    }
}
