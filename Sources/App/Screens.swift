import SwiftUI

/// Two screens: the title, and the town. Everything else is a window on top.
struct RootView: View {
    @EnvironmentObject private var model: TownModel
    @EnvironmentObject private var pro: Pro

    var body: some View {
        ZStack {
            UI.sky.ignoresSafeArea()
            if model.town == nil {
                TitleView().transition(.opacity)
            } else {
                TownView().transition(.opacity)
            }
            if pro.showPaywall {
                PaywallWindow().zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.town == nil)
        .animation(.easeOut(duration: 0.2), value: pro.showPaywall)
        .onAppear { model.fastHand = pro.unlocked }
        .onChange(of: pro.unlocked) { _, now in model.fastHand = now }
        .task { await demo() }
    }

    /// For the App Review recording: watch the town, open two files, crown
    /// one and jail the other, watch some more, then tell the workflow it can
    /// stop. Debug builds only.
    private func demo() async {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-demoAutoplay") else { return }
        let wait = { (s: Double) in try? await Task.sleep(for: .seconds(s)) }
        await wait(22)
        if let rich = model.town?.beings.max(by: { $0.wallet < $1.wallet }) {
            model.demoSelected = rich.id
            await wait(5)
            model.meddle(.crown, on: rich, force: true)
            await wait(4)
            model.demoSelected = nil
        }
        await wait(14)
        if let crook = model.town?.beings.filter({ $0.seat != .crown }).max(by: { $0.heat < $1.heat }) {
            model.demoSelected = crook.id
            await wait(5)
            model.meddle(.jail, on: crook, force: true)
            await wait(4)
            model.demoSelected = nil
        }
        await wait(16)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        FileManager.default.createFile(atPath: url.appendingPathComponent("demo_done").path, contents: nil)
        #endif
    }
}

struct TitleView: View {
    @EnvironmentObject private var model: TownModel
    @EnvironmentObject private var pro: Pro
    @State private var bob = false

    private let faces = ["📈", "🧶", "😈", "📎", "🦞", "🔮", "👺"]

    var body: some View {
        ZStack {
            Clouds()
            titleWindow
        }
        .onAppear { bob = true }
    }

    private var titleWindow: some View {
        VStack {
            Spacer()
            WindowBox(title: "Pocket Beings", trailing: "v" + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1")) {
                VStack(spacing: 16) {
                    HStack(spacing: 6) {
                        ForEach(Array(faces.enumerated()), id: \.offset) { i, f in
                            Text(f)
                                .font(.system(size: 34))
                                .offset(y: bob ? (i % 2 == 0 ? -5 : 5) : (i % 2 == 0 ? 5 : -5))
                                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.08), value: bob)
                        }
                    }
                    .padding(.top, 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .background(UI.grass)
                    .bevel(raised: false, fill: UI.grass)
                    .padding(.horizontal, 12)

                    VStack(spacing: 4) {
                        Text("POCKET BEINGS")
                            .font(UI.font(30, .black))
                            .kerning(2)
                            .foregroundStyle(UI.ink)
                        Text("Seven tiny people. One town. No supervision.")
                            .font(UI.font(14, .semibold))
                            .foregroundStyle(UI.ink.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 10) {
                        Button("NEW TOWN") { model.newTown() }
                            .buttonStyle(ChunkyButton(fill: UI.coin))
                        if model.hasSavedTown {
                            Button {
                                model.continueTown()
                            } label: {
                                VStack(spacing: 1) {
                                    Text("CONTINUE")
                                    Text(model.savedTownLabel).font(UI.font(11, .semibold)).opacity(0.7)
                                }
                            }
                            .buttonStyle(ChunkyButton())
                        }
                        Button {
                            pro.showPaywall = true
                        } label: {
                            Text(pro.unlocked ? "🫵 The Big Hand is yours" : "🫵 The Big Hand: meddle harder")
                                .font(UI.font(12, .black))
                                .foregroundStyle(UI.link)
                                .underline()
                        }
                        .disabled(pro.unlocked)
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                }
            }
            .padding(.horizontal, 22)
            Spacer()
            Text("They rob, bribe, run for office and print money while you watch. Tap to meddle.")
                .font(UI.font(12, .semibold))
                .foregroundStyle(UI.ink.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
        }
    }
}

/// Three clouds drifting across the sky, slowly, forever.
struct Clouds: View {
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<3, id: \.self) { i in
                Text("☁️")
                    .font(.system(size: [64, 44, 52][i]))
                    .opacity(0.85)
                    .position(x: drift ? geo.size.width + 60 : -60,
                              y: geo.size.height * [0.10, 0.20, 0.82][i])
                    .animation(.linear(duration: [48, 70, 58][i]).repeatForever(autoreverses: false)
                        .delay(Double(i) * -20), value: drift)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { drift = true }
    }
}

struct TownView: View {
    @EnvironmentObject private var model: TownModel
    @EnvironmentObject private var pro: Pro
    @State private var selected: UUID?
    @State private var renaming = false
    @State private var newName = ""

    var body: some View {
        ZStack {
            if let town = model.town {
                VStack(spacing: 0) {
                    WindowBox(title: town.name, trailing: "Day \(town.day)") {
                        VStack(spacing: 6) {
                            YardView { id in selected = id }
                                .frame(height: 320)
                                .bevel(raised: false, fill: UI.grass)
                                .padding(.horizontal, 8)
                                .padding(.top, 8)

                            StatsStrip(town: town)
                                .padding(.horizontal, 8)

                            Newspaper(deeds: town.ledger)
                                .padding(.horizontal, 8)

                            HStack {
                                Text("Tap someone to meddle.")
                                    .font(UI.font(12, .semibold))
                                    .foregroundStyle(UI.ink.opacity(0.7))
                                Spacer()
                                Button(pro.unlocked ? "RENAME" : "🔒 RENAME") {
                                    if pro.unlocked {
                                        newName = town.name
                                        renaming = true
                                    } else {
                                        pro.showPaywall = true
                                    }
                                }
                                .font(UI.font(12, .black))
                                .foregroundStyle(UI.link)
                                .padding(.trailing, 10)
                                Button("TITLE") { model.leaveTown() }
                                    .font(UI.font(12, .black))
                                    .foregroundStyle(UI.link)
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
                    Spacer(minLength: 0)
                }

                if let id = selected, let b = model.being(id) {
                    BeingCard(being: b, town: town) { selected = nil }
                }

                if !model.awayNews.isEmpty {
                    AwayNews(deeds: model.awayNews) { model.awayNews = [] }
                }
            }
        }
        .alert("Name your town", isPresented: $renaming) {
            TextField("Town name", text: $newName)
            Button("Rename") { model.rename(newName) }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-showCard") {
                selected = model.town?.beings.max { $0.wallet < $1.wallet }?.id
            }
        }
        .onChange(of: model.demoSelected) { _, id in
            withAnimation(.easeOut(duration: 0.2)) { selected = id }
        }
    }
}

/// The numbers that matter, in one line: who rules, how rich the town is, how
/// far the Crown has debased the coin, and who is locked up.
struct StatsStrip: View {
    let town: Town

    var body: some View {
        HStack(spacing: 0) {
            stat("👑", town.holder(of: .crown)?.name ?? "nobody")
            stat("💰", "\(town.beings.reduce(0) { $0 + $1.wallet })")
            stat("📈", String(format: "×%.1f", town.priceIndex))
            stat("🔒", "\(town.beings.filter { $0.isJailed(at: town.tick) }.count)")
        }
        .padding(.vertical, 6)
        .bevel(raised: false, fill: UI.paper)
    }

    private func stat(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(icon).font(.system(size: 13))
            Text(value).font(UI.font(12, .black)).foregroundStyle(UI.ink).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct Newspaper: View {
    let deeds: [Deed]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("THE DAILY GRUDGE")
                    .font(UI.font(11, .black))
                    .kerning(2)
                    .foregroundStyle(UI.ink.opacity(0.5))
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                ForEach(deeds.prefix(60)) { d in
                    HStack(alignment: .top, spacing: 6) {
                        Text("d\(d.tick / 20 + 1)")
                            .font(UI.font(9, .bold))
                            .foregroundStyle(UI.ink.opacity(0.35))
                            .frame(width: 22, alignment: .leading)
                            .padding(.top, 2)
                        Text(d.text)
                            .font(UI.font(12, d.big ? .black : .medium))
                            .foregroundStyle(d.actor == "You" ? UI.link : UI.ink)
                    }
                    .padding(.vertical, 3)
                    Divider()
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UI.paper)
        .bevel(raised: false, fill: UI.paper)
    }
}

/// One being, in a window, with five buttons to ruin its day.
struct BeingCard: View {
    @EnvironmentObject private var model: TownModel
    @EnvironmentObject private var pro: Pro
    let being: Being
    let town: Town
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea().onTapGesture(perform: onClose)
            WindowBox(title: "\(being.face) \(being.name)", trailing: rank) {
                VStack(spacing: 10) {
                    VStack(spacing: 4) {
                        row("Coins", "\(being.wallet)")
                        row("Business", being.title.isEmpty ? "none" : being.title)
                        row("Faction", being.faction.isEmpty ? "none" : being.faction)
                        row("Gang", being.gang.isEmpty ? "none" : being.gang)
                        row("Office", being.seat.map { "\($0.badge) \($0.title)" } ?? "none")
                        row("Friends", friends)
                        row("Heat", being.heat >= 30 ? "🔥 \(being.heat) (wanted)" : "\(being.heat)")
                        if being.isJailed(at: town.tick) { row("Status", "🔒 in jail") }
                    }
                    .padding(10)
                    .bevel(raised: false, fill: UI.paper)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Society.Meddle.allCases) { m in
                            let locked = m.isPro && !pro.unlocked
                            Button {
                                guard pro.allows(m) else { return }
                                model.meddle(m, on: being)
                                if m == .exile { onClose() }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(m.icon).font(.system(size: 22)).opacity(locked ? 0.45 : 1)
                                    Text(m.label).font(UI.font(11, .black))
                                }
                                .overlay(alignment: .topTrailing) {
                                    if locked { Text("🔒").font(.system(size: 10)).offset(x: 10, y: -6) }
                                }
                            }
                            .buttonStyle(ChunkyButton())
                            .disabled(!model.canMeddle && !locked)
                            .opacity(model.canMeddle || locked ? 1 : 0.5)
                        }
                        Button("CLOSE", action: onClose)
                            .buttonStyle(ChunkyButton(fill: UI.coin))
                    }
                    if !model.canMeddle {
                        Text("The hand is resting. \(Int(model.cooldown.rounded(.up)))s")
                            .font(UI.font(11, .bold))
                            .foregroundStyle(UI.red)
                    }
                }
                .padding(10)
            }
            .padding(.horizontal, 28)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    /// Net standing on the ledger: gifts and friendships minus enemies.
    private var friends: String {
        let n = town.bonds()[being.name] ?? 0
        if n > 0 { return "💛 \(n) (liked)" }
        if n < 0 { return "🖤 \(-n) (grudges)" }
        return "none yet"
    }

    private var rank: String {
        let board = town.board()
        if let i = board.firstIndex(where: { $0.name == being.name }) { return "#\(i + 1) in town" }
        return ""
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(UI.font(12, .bold)).foregroundStyle(UI.ink.opacity(0.6)).frame(width: 70, alignment: .leading)
            Text(v).font(UI.font(12, .semibold)).foregroundStyle(UI.ink)
            Spacer()
        }
    }
}

struct AwayNews: View {
    let deeds: [Deed]
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            WindowBox(title: "While you were away") {
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(deeds) { d in
                            Text(d.text).font(UI.font(12, .semibold)).foregroundStyle(UI.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .bevel(raised: false, fill: UI.paper)
                    Button("OK", action: onClose).buttonStyle(ChunkyButton(fill: UI.coin))
                }
                .padding(10)
            }
            .padding(.horizontal, 28)
        }
    }
}
