import AppIntents
import SwiftUI
import WidgetKit

// Widget faces, shared by the widget extension and the app (the app shows them in
// the Widgets window, so people can see what they are adding). The intents live here
// too: the widget's refresh button, the Control Center button and Siri's town report.

/// What the town looks like right now. The widget runs the same engine the app
/// does: it catches the saved town up to the present (capped, exactly as the app
/// does on opening), so the headline here is the one waiting in the app.
struct TownSnap {
    struct Face: Hashable {
        var face: String
        var name: String
        var crown = false
        var jailed = false
    }

    var name: String
    var day: Int
    var headlines: [String]
    var crown: String
    var richest: String
    var jailed: Int
    var prices: Double
    var hasTown: Bool
    var bigHand: Bool
    var faces: [Face] = []

    static func from(_ t: Town, paid: Bool) -> TownSnap {
        let big = t.ledger.filter(\.big).prefix(4).map(\.text)
        let rich = t.beings.max { $0.wallet < $1.wallet }
        return TownSnap(name: t.name, day: t.day, headlines: big.isEmpty ? Array(t.ledger.prefix(3).map(\.text)) : Array(big),
                        crown: t.holder(of: .crown).map { "\($0.face) \($0.name)" } ?? "nobody",
                        richest: rich.map { "\($0.face) \($0.name) \($0.wallet)" } ?? "",
                        jailed: t.beings.filter { $0.isJailed(at: t.tick) }.count,
                        prices: t.priceIndex, hasTown: true, bigHand: paid,
                        faces: t.beings.map { Face(face: $0.face, name: $0.name, crown: $0.seat == .crown, jailed: $0.isJailed(at: t.tick)) })
    }

    static func now() -> TownSnap {
        YardTheme.reload()
        guard var t = Shared.loadTown() else { return empty }
        _ = Society.catchUp(&t, elapsed: Date().timeIntervalSince(t.savedAt), secondsPerTick: 2.4)
        return from(t, paid: Shared.paid)
    }

    static var empty: TownSnap {
        TownSnap(name: "Pocket Beings", day: 1, headlines: ["Start a town and seven tiny people move in."],
                 crown: "nobody", richest: "", jailed: 0, prices: 1, hasTown: false, bigHand: Shared.paid)
    }

    static var sample: TownSnap {
        TownSnap(name: "Grudge Hollow", day: 8,
                 headlines: ["👑 Malvora bought the Crown's seat for 312.", "💼 the Cousins hit Gary for 88. Snik planned it."],
                 crown: "😈 Malvora", richest: "📈 Braxton 410", jailed: 1, prices: 1.4, hasTown: true, bigHand: true,
                 faces: [Face(face: "😈", name: "Malvora", crown: true), Face(face: "📈", name: "Braxton"), Face(face: "🦞", name: "Gary"),
                         Face(face: "👺", name: "Snik", jailed: true), Face(face: "🧶", name: "Nan"), Face(face: "🪩", name: "Cheryl"),
                         Face(face: "📎", name: "The Intern")])
    }
}

// MARK: - The Daily Grudge (small)

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

// MARK: - Town Hall (medium, The Big Hand or the Town Club)

struct TownHallView: View {
    let snap: TownSnap
    var body: some View {
        if !snap.bigHand {
            VStack(alignment: .leading, spacing: 6) {
                Text("🏛️ TOWN HALL").font(UI.font(13, .black)).foregroundStyle(UI.ink)
                Text("The Town Hall widget comes with The Big Hand or the Town Club. The Daily Grudge and Town Square widgets are free.")
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

// MARK: - Town Square (medium and large, free): the yard itself

struct TownSquareView: View {
    let snap: TownSnap
    var large = false

    var body: some View {
        let y = YardTheme.current
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(snap.name).font(UI.font(12, .black)).foregroundStyle(.white).lineLimit(1)
                Spacer(minLength: 2)
                Text("Day \(snap.day)").font(UI.font(10, .bold)).foregroundStyle(.white.opacity(0.9))
                Button(intent: RefreshTownIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(UI.ink)
                        .frame(width: 20, height: 16)
                        .background(UI.chrome)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh the town")
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(LinearGradient(colors: [UI.barA, UI.barB], startPoint: .leading, endPoint: .trailing))

            GeometryReader { geo in
                ZStack {
                    VStack(spacing: 0) {
                        ForEach(0..<(large ? 6 : 3), id: \.self) { i in
                            Rectangle().fill(i % 2 == 0 ? y.grass : y.grassDark)
                        }
                    }
                    ForEach(0..<(large ? 5 : 3), id: \.self) { i in
                        Text(y.flowers[i % y.flowers.count])
                            .font(.system(size: large ? 14 : 11))
                            .position(x: geo.size.width * [0.08, 0.92, 0.5, 0.2, 0.78][i],
                                      y: geo.size.height * [0.15, 0.82, 0.92, 0.6, 0.3][i])
                    }
                    ForEach(Array(snap.faces.prefix(10).enumerated()), id: \.offset) { i, f in
                        VStack(spacing: 0) {
                            Text(f.face)
                                .font(.system(size: large ? 30 : 22))
                                .opacity(f.jailed ? 0.6 : 1)
                                .overlay(alignment: .topTrailing) {
                                    if f.crown { Text("👑").font(.system(size: large ? 13 : 10)).offset(x: 7, y: -7) }
                                    else if f.jailed { Text("🔒").font(.system(size: large ? 12 : 9)).offset(x: 6, y: -5) }
                                }
                            if large {
                                Text(f.name).font(UI.font(8, .black)).foregroundStyle(y.dark ? .white : UI.ink).lineLimit(1)
                            }
                        }
                        .position(Self.spot(i, count: min(10, snap.faces.count), name: f.name, size: geo.size, large: large))
                    }
                }
            }
            .clipped()

            Text(snap.headlines.first ?? "")
                .font(UI.font(large ? 12 : 10, .bold)).foregroundStyle(UI.ink)
                .lineLimit(large ? 3 : 2).minimumScaleFactor(0.85)
                .padding(.horizontal, 7).padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(UI.paper)
        }
    }

    /// Spread out on a loose grid, nudged by name so the town does not look like a spreadsheet.
    static func spot(_ i: Int, count: Int, name: String, size: CGSize, large: Bool) -> CGPoint {
        let cols = large ? 4 : 5
        let rows = max(1, (count + cols - 1) / cols)
        let col = i % cols, row = i / cols
        var h: UInt64 = 1469598103934665603
        for b in name.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let jx = (Double(h % 100) / 100 - 0.5) * 0.5
        let jy = (Double((h / 100) % 100) / 100 - 0.5) * 0.4
        let shift = row % 2 == 1 ? 0.5 : 0
        let x = (Double(col) + 0.5 + shift * 0.5 + jx * 0.6) / Double(cols)
        let y = (Double(row) + 0.55 + jy) / Double(rows)
        return CGPoint(x: size.width * min(0.92, max(0.08, x)), y: size.height * min(0.85, max(0.18, y)))
    }
}

// MARK: - Lock Screen

struct LockView: View {
    @Environment(\.widgetFamily) private var family
    let snap: TownSnap
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(String(snap.crown.split(separator: " ").first ?? "👑")).font(.system(size: 20))
                    Text("d\(snap.day)").font(.system(size: 11, weight: .bold, design: .rounded))
                }
            }
        case .accessoryInline:
            Text("👑 \(snap.crown) rules \(snap.name)")
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("THE DAILY GRUDGE · d\(snap.day)").font(.system(size: 10, weight: .black, design: .rounded))
                Text(snap.headlines.first ?? "").font(.system(size: 13, weight: .semibold, design: .rounded)).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Intents

/// The widget's refresh button: catch the town up to now.
struct RefreshTownIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh My Town"
    static var description = IntentDescription("Catch the Pocket Beings widgets up with the latest news from your town.")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Control Center, the Action button and Shortcuts: straight into the town.
struct OpenTownIntent: AppIntent {
    static var title: LocalizedStringResource = "Open My Town"
    static var description = IntentDescription("Open Pocket Beings at your town.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// Siri: "Pocket Beings town report".
struct TownReportIntent: AppIntent {
    static var title: LocalizedStringResource = "Town Report"
    static var description = IntentDescription("Hear the latest scandal from your town and who holds the Crown.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let s = TownSnap.now()
        guard s.hasTown else {
            return .result(dialog: IntentDialog(stringLiteral: "You have no town yet. Open Pocket Beings and tap New Town."))
        }
        let text = "\(s.name), day \(s.day). \(s.headlines.first ?? "All quiet.") The Crown: \(s.crown)."
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}
