import SwiftUI

/// Two screens: the title, and the town. Everything else is a window on top.
struct RootView: View {
    @EnvironmentObject private var model: TownModel

    var body: some View {
        ZStack {
            UI.sky.ignoresSafeArea()
            if model.town == nil {
                TitleView().transition(.opacity)
            } else {
                TownView().transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.town == nil)
        .task { await demo() }
    }

    /// For the App Review recording: run for a while, then tell the workflow
    /// it can stop. Debug builds only.
    private func demo() async {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-demoAutoplay") else { return }
        try? await Task.sleep(for: .seconds(70))
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        FileManager.default.createFile(atPath: url.appendingPathComponent("demo_done").path, contents: nil)
        #endif
    }
}

struct TitleView: View {
    @EnvironmentObject private var model: TownModel
    @State private var bob = false

    private let faces = ["📈", "🧶", "😈", "📎", "🦞", "🔮", "👺"]

    var body: some View {
        VStack {
            Spacer()
            WindowBox(title: "Pocket Beings", trailing: "v1.0") {
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
                            Button("CONTINUE") { model.continueTown() }
                                .buttonStyle(ChunkyButton())
                        }
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
        .onAppear { bob = true }
    }
}

struct TownView: View {
    @EnvironmentObject private var model: TownModel
    @State private var selected: UUID?

    var body: some View {
        ZStack {
            if let town = model.town {
                VStack(spacing: 0) {
                    WindowBox(title: town.name, trailing: "Day \(town.day)") {
                        VStack(spacing: 6) {
                            YardView { id in selected = id }
                                .frame(height: 300)
                                .bevel(raised: false, fill: UI.grass)
                                .padding(.horizontal, 8)
                                .padding(.top, 8)

                            Text(model.latest?.text ?? "The town is quiet.")
                                .font(UI.font(12, .bold))
                                .foregroundStyle(UI.ink)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .bevel(raised: false, fill: UI.paper)
                                .padding(.horizontal, 8)

                            Newspaper(deeds: town.ledger)
                                .padding(.horizontal, 8)

                            HStack {
                                Text("Tap someone to meddle.")
                                    .font(UI.font(12, .semibold))
                                    .foregroundStyle(UI.ink.opacity(0.7))
                                Spacer()
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
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-showCard") {
                selected = model.town?.beings.max { $0.wallet < $1.wallet }?.id
            }
        }
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
                    Text(d.text)
                        .font(UI.font(12, d.big ? .black : .medium))
                        .foregroundStyle(d.actor == "You" ? UI.link : UI.ink)
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
                        row("Heat", being.heat >= 30 ? "🔥 \(being.heat) (wanted)" : "\(being.heat)")
                        if being.isJailed(at: town.tick) { row("Status", "🔒 in jail") }
                    }
                    .padding(10)
                    .bevel(raised: false, fill: UI.paper)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Society.Meddle.allCases) { m in
                            Button {
                                model.meddle(m, on: being)
                                if m == .exile { onClose() }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(m.icon).font(.system(size: 22))
                                    Text(m.label).font(UI.font(11, .black))
                                }
                            }
                            .buttonStyle(ChunkyButton())
                            .disabled(!model.canMeddle)
                            .opacity(model.canMeddle ? 1 : 0.5)
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
