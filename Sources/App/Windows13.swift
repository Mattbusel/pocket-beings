import Charts
import SwiftUI
import WidgetKit

// 1.3 windows: the daily gift, the Season, the stamp album, the almanac and the
// widget gallery. Same 2001 chrome as everything else.

// MARK: - Daily gift

struct GiftWindow: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var pro: Pro
    @State private var opened: Reward?
    @State private var wiggle = false
    var close: () -> Void

    var body: some View {
        Modal(title: "Daily gift", trailing: "box \(player.nextGiftIndex + 1) of 7", close: close) {
            VStack(spacing: 10) {
                Text(opened != nil ? "Opened! Come back tomorrow for box \((player.giftIndex + 1) % 7 + 1)." :
                     player.canClaim ? "Come back every day to walk along the calendar. Miss a day and it starts again." :
                     "Today's gift is open. The next box unlocks tomorrow.")
                    .font(UI.font(12, .semibold)).foregroundStyle(UI.ink.opacity(0.75)).multilineTextAlignment(.center)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in box(i) }
                }
                if let r = opened {
                    Text("+ " + r.label + "  + \(DailyGift.stars) ⭐").font(UI.font(18, .black)).foregroundStyle(UI.ink)
                        .transition(.scale.combined(with: .opacity))
                }
                if player.canClaim {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { opened = player.claim() }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gift.fill").symbolEffect(.bounce, options: .repeating, value: wiggle)
                            Text("OPEN TODAY'S GIFT")
                        }
                    }
                    .buttonStyle(ChunkyButton(fill: UI.coin))
                }
                VStack(alignment: .leading, spacing: 3) {
                    line(pro.hasBigHand ? "Your Big Hand adds a miracle to every box." : "The Big Hand adds a miracle to every box.")
                    line(player.club ? "Town Club: every box is doubled. 🎉" : "Town Club members get every box doubled.")
                    line("Each gift also gives \(DailyGift.stars) Season stars.")
                }
                .padding(8).frame(maxWidth: .infinity, alignment: .leading).bevel(raised: false, fill: UI.paper)
            }
        }
        .onAppear { wiggle.toggle() }
    }

    private func box(_ i: Int) -> some View {
        let r = DailyGift.reward(index: i, bigHand: pro.hasBigHand, club: player.club)
        let done = !player.canClaim ? i <= player.giftIndex : i < player.nextGiftIndex
        let today = player.canClaim && i == player.nextGiftIndex
        return VStack(spacing: 2) {
            Text("DAY \(i + 1)").font(UI.font(9, .black)).foregroundStyle(UI.ink.opacity(0.6))
            Text(done ? "✅" : i == 6 ? "🎁" : "🎀").font(.system(size: i == 6 ? 30 : 24))
                .scaleEffect(today && wiggle ? 1.12 : 1)
                .animation(today ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: wiggle)
            Text(r.label).font(UI.font(10, .black)).foregroundStyle(UI.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.vertical, 6).frame(maxWidth: .infinity)
        .bevel(raised: !done, fill: today ? UI.coin.opacity(0.55) : done ? Color(red: 0.86, green: 0.95, blue: 0.84) : UI.chrome)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day \(i + 1): \(r.miracles) miracles, \(r.invites) invitations\(done ? ", opened" : "")")
    }

    private func line(_ t: String) -> some View { Text("• " + t).font(UI.font(11, .semibold)).foregroundStyle(UI.ink.opacity(0.75)) }
}

// MARK: - Season

struct SeasonWindow: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var pro: Pro
    @EnvironmentObject private var extras: Extras
    var close: () -> Void

    var body: some View {
        let s = player.season
        Modal(title: "\(s.icon) \(s.name)", trailing: "ends " + s.ends.formatted(.dateTime.month(.abbreviated).day()), close: close) {
            VStack(spacing: 8) {
                Text(s.blurb).font(UI.font(12, .semibold)).foregroundStyle(UI.ink.opacity(0.75)).multilineTextAlignment(.center)
                VStack(spacing: 3) {
                    HStack {
                        Text("⭐ \(player.stars)").font(UI.font(15, .black)).foregroundStyle(UI.ink)
                        Spacer()
                        Text("Tier \(player.tier) of \(Season.tiers)").font(UI.font(12, .black)).foregroundStyle(UI.ink.opacity(0.7))
                    }
                    ProgressView(value: Double(min(player.stars, Season.starsPerTier * Season.tiers)), total: Double(Season.starsPerTier * Season.tiers))
                        .tint(Color(red: 0.12, green: 0.45, blue: 0.14))
                }
                .padding(8).bevel(raised: false, fill: UI.paper)

                VStack(alignment: .leading, spacing: 4) {
                    Text("THIS WEEK").font(UI.font(10, .black)).kerning(1.5).foregroundStyle(UI.ink.opacity(0.55))
                    ForEach(player.challenges) { c in
                        let n = min(c.goal, player.weekCounts[c.kind] ?? 0)
                        let done = player.weekDone.contains(c.kind)
                        HStack(spacing: 6) {
                            Text(done ? "✅" : c.icon).font(.system(size: 15)).frame(width: 22)
                            Text(c.text).font(UI.font(12, .bold)).foregroundStyle(UI.ink).strikethrough(done)
                            Spacer()
                            Text(done ? "+\(Challenge.stars)⭐" : "\(n)/\(c.goal)").font(UI.font(11, .black)).foregroundStyle(UI.ink.opacity(0.7))
                        }
                    }
                }
                .padding(8).frame(maxWidth: .infinity, alignment: .leading).bevel(raised: false, fill: UI.paper)

                ScrollView {
                    VStack(spacing: 4) {
                        HStack {
                            Text("TIER").frame(width: 36)
                            Text("FREE").frame(maxWidth: .infinity)
                            Text("🏛️ CLUB").frame(maxWidth: .infinity)
                        }
                        .font(UI.font(10, .black)).foregroundStyle(UI.ink.opacity(0.6))
                        ForEach(1...Season.tiers, id: \.self) { t in
                            HStack(spacing: 6) {
                                Text("\(t)").font(UI.font(13, .black)).foregroundStyle(t <= player.tier ? UI.ink : UI.ink.opacity(0.4)).frame(width: 36)
                                cell(t, club: false)
                                cell(t, club: true)
                            }
                        }
                    }
                }
                .frame(maxHeight: 250)
                Text("Earn stars: daily gift \(DailyGift.stars), granted wish 4, weekly challenge \(Challenge.stars), new stamp \(Stamp.stars). \(Season.starsPerTier) stars a tier. Tier 10 leaves the season's face \(s.face) for your invitations.")
                    .font(UI.font(10, .semibold)).foregroundStyle(UI.ink.opacity(0.6)).multilineTextAlignment(.center)
                if player.tier < Season.tiers {
                    BuyRow(icon: "🚀", title: "Season Boost", detail: "\(Season.starsPerTier) stars: one tier, right now.", id: Extras.boostID)
                }
            }
        }
    }

    private func cell(_ t: Int, club: Bool) -> some View {
        let r = club ? Season.club(t) : Season.free(t)
        let reached = t <= player.tier
        let taken = club ? player.claimedClub.contains(t) : player.claimedFree.contains(t)
        let locked = club && !player.club
        return Button {
            if locked { pro.showClub = true; return }
            player.claimTier(t, clubRow: club)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 3) {
                if locked { Text("🔒").font(.system(size: 10)) }
                Text(r.face ? "\(player.season.face) " + Reward(miracles: r.miracles, invites: r.invites).label : r.label)
                    .font(UI.font(11, .black)).foregroundStyle(UI.ink).lineLimit(1).minimumScaleFactor(0.7)
                if taken { Text("✓").font(UI.font(11, .black)).foregroundStyle(Color(red: 0.12, green: 0.45, blue: 0.14)) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .bevel(raised: reached && !taken && !locked,
                   fill: taken ? Color(red: 0.86, green: 0.95, blue: 0.84) : reached && !locked ? UI.coin.opacity(0.55) : UI.chrome)
            .opacity(reached || locked ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!locked && (!reached || taken))
    }
}

// MARK: - Stamp album

struct AlbumWindow: View {
    @EnvironmentObject private var player: Player
    @State private var picked: Stamp?
    var close: () -> Void

    var body: some View {
        Modal(title: "Stamp album", trailing: "\(player.stamps.count)/\(Stamps.all.count)", close: close) {
            VStack(spacing: 8) {
                Text(picked.map { "\($0.icon) \($0.title): \($0.how)" } ?? "Stamps come from what happens in your towns. Tap one to see how to earn it.")
                    .font(UI.font(12, .bold)).foregroundStyle(UI.ink.opacity(0.8)).multilineTextAlignment(.center)
                    .frame(minHeight: 34)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(Stamps.all) { s in
                        let has = player.stamps.contains(s.id)
                        Button { picked = s } label: {
                            VStack(spacing: 2) {
                                Text(has ? s.icon : "❔").font(.system(size: 26)).grayscale(has ? 0 : 1).opacity(has ? 1 : 0.5)
                                Text(s.title).font(UI.font(8.5, .black)).foregroundStyle(UI.ink.opacity(has ? 1 : 0.45))
                                    .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .padding(3)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                                    .foregroundStyle(has ? UI.red.opacity(0.6) : UI.ink.opacity(0.25))
                            )
                            .background(has ? UI.paper : UI.chrome)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(has ? "\(s.title), collected" : "\(s.title), not yet. \(s.how)")
                    }
                }
                Text("Each new stamp gives \(Stamp.stars) Season stars.").font(UI.font(10, .semibold)).foregroundStyle(UI.ink.opacity(0.6))
            }
        }
    }
}

// MARK: - Almanac (Town Club)

struct AlmanacWindow: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var pro: Pro
    let town: Town
    var close: () -> Void
    @State private var metric = 0

    var body: some View {
        let h = town.history ?? []
        Modal(title: "Town almanac", trailing: town.name, close: close) {
            VStack(spacing: 8) {
                Picker("", selection: $metric) {
                    Text("Wealth").tag(0); Text("Prices").tag(1); Text("Crime").tag(2)
                }
                .pickerStyle(.segmented)
                ZStack {
                    chart(h)
                        .frame(height: 190)
                        .padding(8)
                        .bevel(raised: false, fill: UI.paper)
                        .blur(radius: player.club ? 0 : 6)
                    if !player.club {
                        VStack(spacing: 6) {
                            Text("📊 The almanac is in the Town Club").font(UI.font(14, .black)).foregroundStyle(UI.ink)
                            Button("SEE THE CLUB") { pro.showClub = true }.buttonStyle(ChunkyButton(fill: UI.coin)).frame(width: 180)
                        }
                        .padding(10).bevel()
                    }
                }
                if player.club, let last = h.last {
                    VStack(spacing: 0) {
                        row("📅", "Days recorded", "\(h.count)")
                        row("💰", "Wealth on day \(last.day)", "\(last.wealth)")
                        row("🏦", "Treasury", "\(last.treasury)")
                        row("📈", "Prices", String(format: "×%.2f", last.prices))
                        row("🕶️", "Crimes that day", "\(last.crimes)")
                        row("👑", "Richest that day", last.richest)
                    }
                    .bevel(raised: false, fill: UI.paper)
                } else if player.club {
                    Text("The almanac writes a line at the end of every town day. Check back tomorrow.")
                        .font(UI.font(11, .semibold)).foregroundStyle(UI.ink.opacity(0.7)).multilineTextAlignment(.center)
                }
            }
        }
    }

    @ViewBuilder private func chart(_ h: [DaySnap]) -> some View {
        let data = h.isEmpty ? Self.placeholder : h
        let green = Color(red: 0.12, green: 0.45, blue: 0.14)
        switch metric {
        case 1:
            Chart(data, id: \.day) { s in
                LineMark(x: .value("Day", s.day), y: .value("Prices", s.prices))
                    .foregroundStyle(UI.red)
            }
            .chartXAxisLabel("day")
        case 2:
            Chart(data, id: \.day) { s in
                BarMark(x: .value("Day", s.day), y: .value("Crimes", s.crimes))
                    .foregroundStyle(UI.barA)
            }
            .chartXAxisLabel("day")
        default:
            Chart(data, id: \.day) { s in
                LineMark(x: .value("Day", s.day), y: .value("Wealth", s.wealth))
                    .foregroundStyle(green)
            }
            .chartXAxisLabel("day")
        }
    }

    static let placeholder: [DaySnap] = {
        var out: [DaySnap] = []
        for d in 1...12 {
            let wealth: Int = 700 + d * 60 + (d % 3) * 90
            let prices: Double = 1.0 + Double(d) * 0.08
            out.append(DaySnap(day: d, wealth: wealth, treasury: 200, prices: prices, jailed: d % 3, crimes: 3 + d % 5, richest: ""))
        }
        return out
    }()

    private func row(_ icon: String, _ k: String, _ v: String) -> some View {
        HStack(spacing: 6) {
            Text(icon).font(.system(size: 13)).frame(width: 22)
            Text(k).font(UI.font(12, .bold)).foregroundStyle(UI.ink.opacity(0.6))
            Spacer()
            Text(v).font(UI.font(12, .black)).foregroundStyle(UI.ink).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
    }
}

// MARK: - Widget gallery

struct WidgetsWindow: View {
    let town: Town
    var close: () -> Void

    var body: some View {
        let snap = TownSnap.from(town, paid: Shared.paid || ProcessInfo.processInfo.arguments.contains("-screenshots"))
        Modal(title: "Widgets", trailing: "Home + Lock Screen", close: close) {
            ScrollView {
                VStack(spacing: 10) {
                    Text("Your town on your Home Screen. Touch and hold the Home Screen, tap Edit, Add Widget, then Pocket Beings.")
                        .font(UI.font(11, .semibold)).foregroundStyle(UI.ink.opacity(0.75)).multilineTextAlignment(.center)
                    tile("Town Square", "free · tap ↻ to catch up") {
                        TownSquareView(snap: snap, large: true).frame(width: 300, height: 300)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        tile("The Daily Grudge", "free") {
                            GrudgeView(snap: snap).padding(12).frame(width: 145, height: 145).background(UI.paper)
                        }
                        tile("Lock Screen", "free") {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("THE DAILY GRUDGE · d\(snap.day)").font(.system(size: 9, weight: .black, design: .rounded))
                                Text(snap.headlines.first ?? "").font(.system(size: 12, weight: .semibold, design: .rounded)).lineLimit(3)
                            }
                            .foregroundStyle(.white)
                            .padding(10).frame(width: 145, height: 145, alignment: .leading)
                            .background(LinearGradient(colors: [UI.barA, Color(red: 0.25, green: 0.1, blue: 0.35)], startPoint: .top, endPoint: .bottom))
                        }
                    }
                    tile("Town Hall", "The Big Hand or Town Club") {
                        TownHallView(snap: snap).padding(12).frame(width: 300, height: 141).background(UI.chrome)
                    }
                    Text("Also: a Control Center button that opens your town, and \"Town Report\" in Siri and Shortcuts.")
                        .font(UI.font(11, .semibold)).foregroundStyle(UI.ink.opacity(0.7)).multilineTextAlignment(.center)
                }
            }
            .frame(maxHeight: 620)
        }
    }

    private func tile<C: View>(_ name: String, _ note: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 3) {
            content()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            Text(name).font(UI.font(11, .black)).foregroundStyle(UI.ink)
            Text(note).font(UI.font(9, .bold)).foregroundStyle(UI.ink.opacity(0.55))
        }
    }
}
