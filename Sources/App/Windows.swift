import SwiftUI
import WidgetKit

/// Every window the Start menu can open.
enum Panel: String, Identifiable {
    case wish, miracles, invite, laws, records, yards, settings
    var id: String { rawValue }
}

// MARK: - Taskbar and Start menu

/// The bottom of the screen, the way it always was: a START button, open windows,
/// and a tray with the clock. Here the tray holds the streak and the charges.
struct Taskbar: View {
    @EnvironmentObject private var player: Player
    @Binding var startOpen: Bool
    let town: Town

    var body: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { startOpen.toggle() }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(spacing: 4) {
                    Text("🫵").font(.system(size: 14))
                    Text("START").font(UI.font(13, .black)).italic()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(LinearGradient(colors: [Color(red: 0.25, green: 0.62, blue: 0.25), Color(red: 0.12, green: 0.45, blue: 0.14)], startPoint: .top, endPoint: .bottom))
                .bevel(raised: !startOpen, fill: .clear)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start menu")
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                tray("🔥", "\(player.streak)")
                tray("✨", "\(player.miracles)")
                tray("🎟️", "\(player.invites)")
                Text("Day \(town.day)").font(UI.font(11, .black)).foregroundStyle(UI.ink)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .bevel(raised: false, fill: UI.chrome)
        }
        .padding(4)
        .background(UI.chrome)
        .bevel()
    }

    private func tray(_ icon: String, _ v: String) -> some View {
        HStack(spacing: 2) { Text(icon).font(.system(size: 12)); Text(v).font(UI.font(11, .black)).foregroundStyle(UI.ink) }
    }
}

struct StartMenu: View {
    @EnvironmentObject private var model: TownModel
    @EnvironmentObject private var pro: Pro
    @EnvironmentObject private var player: Player
    var open: (Panel) -> Void
    var close: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // The vertical banner down the side.
            Text("POCKET BEINGS")
                .font(UI.font(15, .black)).kerning(2).foregroundStyle(.white.opacity(0.9))
                .rotationEffect(.degrees(-90)).fixedSize()
                .frame(width: 30)
                .frame(maxHeight: .infinity)
                .background(LinearGradient(colors: [UI.barB, UI.barA], startPoint: .top, endPoint: .bottom))
            VStack(alignment: .leading, spacing: 0) {
                item("🌠", "Wish of the day", player.wish?.done == true ? "done ✓" : "+1 ✨") { open(.wish) }
                item("✨", "Miracles", "\(player.miracles) left") { open(.miracles) }
                item("🎟️", "Invite a stranger", "\(player.invites) left") { open(.invite) }
                item("📜", "Town laws", pro.unlocked ? "\(model.town?.activeLaws.count ?? 0)/\(Law.maxActive)" : "🔒") { open(.laws) }
                item("🏆", "Hall of records", "") { open(.records) }
                item("🏡", "Yards", "") { open(.yards) }
                Divider().padding(.vertical, 2)
                item("🫵", pro.unlocked ? "The Big Hand ✓" : "The Big Hand", pro.unlocked ? "" : pro.price) {
                    close(); if !pro.unlocked { pro.showPaywall = true }
                }
                item("⚙️", "Settings", "") { open(.settings) }
                item("🚪", "Title screen", "") { close(); model.leaveTown() }
            }
            .padding(4)
        }
        .frame(width: 260)
        .fixedSize(horizontal: false, vertical: true)
        .bevel()
    }

    private func item(_ icon: String, _ title: String, _ trailing: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(icon).font(.system(size: 18)).frame(width: 26)
                Text(title).font(UI.font(14, .bold)).foregroundStyle(UI.ink)
                Spacer()
                Text(trailing).font(UI.font(11, .black)).foregroundStyle(UI.ink.opacity(0.55))
            }
            .padding(.horizontal, 6).padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRow())
    }
}

/// A menu row that turns blue under the finger.
struct MenuRow: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? UI.barB.opacity(0.35) : .clear)
    }
}

/// A modal window with a dimmed backdrop and a close button.
struct Modal<Content: View>: View {
    let title: String
    var trailing = ""
    var close: () -> Void
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea().onTapGesture(perform: close)
            WindowBox(title: title, trailing: trailing) {
                VStack(spacing: 10) {
                    content()
                    Button("CLOSE", action: close).buttonStyle(ChunkyButton())
                }
                .padding(10)
            }
            .padding(.horizontal, 20)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}

// MARK: - Wish of the day

/// Today's wish on a strip above the stats, tap for the window.
struct WishStrip: View {
    @EnvironmentObject private var player: Player
    var tap: () -> Void
    var body: some View {
        if let w = player.wish {
            Button(action: tap) {
                HStack(spacing: 6) {
                    Text(w.done ? "✅" : "🌠").font(.system(size: 14))
                    Text(w.done ? "Wish granted. New one tomorrow." : w.text)
                        .font(UI.font(12, .bold)).foregroundStyle(UI.ink).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    Text("🔥\(player.streak)").font(UI.font(11, .black)).foregroundStyle(UI.red)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .bevel(raised: true, fill: w.done ? Color(red: 0.86, green: 0.95, blue: 0.84) : UI.paper)
            }
            .buttonStyle(.plain)
        }
    }
}

struct WishWindow: View {
    @EnvironmentObject private var player: Player
    let town: Town
    var close: () -> Void
    var body: some View {
        Modal(title: "Wish of the day", trailing: "🔥 \(player.streak) day streak", close: close) {
            VStack(spacing: 10) {
                if let w = player.wish {
                    Text(w.done ? "✅" : "🌠").font(.system(size: 46))
                    Text(w.text).font(UI.font(17, .black)).foregroundStyle(UI.ink).multilineTextAlignment(.center)
                    Text(w.done ? "Granted. You earned a miracle. ✨" : Wishes.progress(w, town: town))
                        .font(UI.font(12, .bold)).foregroundStyle(w.done ? Color(red: 0.1, green: 0.5, blue: 0.15) : UI.ink.opacity(0.65))
                    VStack(alignment: .leading, spacing: 4) {
                        line("Make it happen any way you like: meddles, miracles, laws, patience.")
                        line("A granted wish gives one ✨ miracle and grows the streak.")
                        line("Miss a day and the streak starts again. Best: \(player.bestStreak).")
                    }
                    .padding(8).bevel(raised: false, fill: UI.paper)
                }
            }
        }
    }
    private func line(_ t: String) -> some View { Text("• " + t).font(UI.font(11, .semibold)).foregroundStyle(UI.ink.opacity(0.75)) }
}

/// The pop when a wish comes true.
struct WishGranted: View {
    let wish: Wish
    var close: () -> Void
    @State private var pop = false
    var body: some View {
        Modal(title: "Wish granted!", close: close) {
            VStack(spacing: 8) {
                Text("🌠✨").font(.system(size: 52)).scaleEffect(pop ? 1 : 0.4)
                Text(wish.text).font(UI.font(15, .black)).foregroundStyle(UI.ink).multilineTextAlignment(.center)
                Text("+1 miracle. Come back tomorrow for the next one.").font(UI.font(12, .bold)).foregroundStyle(UI.ink.opacity(0.7))
            }
        }
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { pop = true } }
    }
}

// MARK: - Miracles

struct MiracleWindow: View {
    @EnvironmentObject private var model: TownModel
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var pro: Pro
    @EnvironmentObject private var extras: Extras
    var close: () -> Void
    var body: some View {
        Modal(title: "Miracles", trailing: "✨ \(player.miracles)", close: close) {
            VStack(spacing: 8) {
                if player.canClaim {
                    Button("TAKE TODAY'S FREE MIRACLE (+\(player.dailyAllowance(pro: pro.unlocked)))") { player.claim(pro: pro.unlocked) }
                        .buttonStyle(ChunkyButton(fill: UI.coin))
                } else {
                    Text("Today's free miracle is taken. Another tomorrow\(pro.unlocked ? " (two with The Big Hand)" : "").")
                        .font(UI.font(11, .bold)).foregroundStyle(UI.ink.opacity(0.6)).multilineTextAlignment(.center)
                }
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Miracle.allCases) { m in
                            Button {
                                guard player.spendMiracle() else { return }
                                model.cast(m)
                                close()
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(m.icon).font(.system(size: 24)).frame(width: 32)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(m.title).font(UI.font(14, .black)).foregroundStyle(UI.ink)
                                        Text(m.blurb).font(UI.font(11, .medium)).foregroundStyle(UI.ink.opacity(0.7)).multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Text("✨1").font(UI.font(12, .black)).foregroundStyle(UI.ink)
                                }
                                .padding(8)
                                .bevel(raised: true, fill: UI.chrome)
                            }
                            .buttonStyle(.plain)
                            .disabled(player.miracles == 0)
                            .opacity(player.miracles == 0 ? 0.55 : 1)
                        }
                    }
                }
                .frame(maxHeight: 330)
                BuyRow(icon: "🫙", title: "Miracle Jar", detail: "Five more miracles. Buy as many jars as you like.",
                       id: Extras.miraclesID)
            }
        }
    }
}

/// A 99-cent row with its price button.
struct BuyRow: View {
    @EnvironmentObject private var extras: Extras
    let icon: String
    let title: String
    let detail: String
    let id: String
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text(icon).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(UI.font(14, .black)).foregroundStyle(UI.ink)
                    Text(detail).font(UI.font(11, .medium)).foregroundStyle(UI.ink.opacity(0.7))
                }
                Spacer()
                Button(extras.busy == id ? "..." : extras.price(id)) { Task { await extras.buy(id) } }
                    .buttonStyle(ChunkyButton(fill: UI.coin))
                    .frame(width: 92)
                    .disabled(extras.busy != nil)
            }
            if let m = extras.message { Text(m).font(UI.font(10, .bold)).foregroundStyle(UI.red) }
        }
        .padding(8)
        .bevel(raised: false, fill: UI.paper)
    }
}

// MARK: - Invitations

struct InviteWindow: View {
    @EnvironmentObject private var model: TownModel
    @EnvironmentObject private var player: Player
    let town: Town
    var close: () -> Void
    @State private var name = ""
    @State private var face = "👵"
    @State private var replacing: UUID?
    static let faces = ["👵", "🧔", "👩‍🎤", "🤠", "🧙", "🦸", "🧛", "🤖", "🐸", "🦊", "🐻", "🦄", "👽", "🤡", "🥷", "🧑‍🍳", "🧑‍🚀", "💅"]

    var body: some View {
        Modal(title: "Invite a stranger", trailing: "🎟️ \(player.invites)", close: close) {
            VStack(spacing: 8) {
                Text("Name anyone. Your friends, your boss, your cat. They move in with 100 coins and no friends.")
                    .font(UI.font(12, .semibold)).foregroundStyle(UI.ink.opacity(0.75)).multilineTextAlignment(.center)
                TextField("Their name", text: $name)
                    .font(UI.font(16, .bold)).padding(8).bevel(raised: false, fill: .white)
                    .textInputAutocapitalization(.words)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 9), spacing: 4) {
                    ForEach(Self.faces, id: \.self) { f in
                        Button { face = f } label: {
                            Text(f).font(.system(size: 22)).frame(maxWidth: .infinity).padding(.vertical, 3)
                                .bevel(raised: face != f, fill: face == f ? UI.coin.opacity(0.6) : UI.chrome)
                        }.buttonStyle(.plain)
                    }
                }
                if town.beings.count >= Society.maxPopulation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Town is full (\(Society.maxPopulation)). Who moves out?").font(UI.font(11, .black)).foregroundStyle(UI.ink)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(town.beings) { b in
                                    Button { replacing = b.id } label: {
                                        Text("\(b.face) \(b.name)").font(UI.font(11, .bold)).padding(.horizontal, 6).padding(.vertical, 4)
                                            .bevel(raised: replacing != b.id, fill: replacing == b.id ? UI.red.opacity(0.3) : UI.chrome)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                } else {
                    Text("Room for \(Society.maxPopulation - town.beings.count) more.").font(UI.font(11, .bold)).foregroundStyle(UI.ink.opacity(0.6))
                }
                Button(player.invites > 0 ? "SEND THE INVITATION 🎟️" : "NO INVITATIONS LEFT") {
                    guard player.spendInvite() else { return }
                    model.invite(name: name, face: face, replacing: town.beings.first { $0.id == replacing })
                    close()
                }
                .buttonStyle(ChunkyButton(fill: UI.coin))
                .disabled(player.invites == 0 || name.trimmingCharacters(in: .whitespaces).isEmpty)
                BuyRow(icon: "💌", title: "Invitations", detail: "Three more. Fill the town with people you know.", id: Extras.invitesID)
            }
        }
    }
}

// MARK: - Laws

struct LawsWindow: View {
    @EnvironmentObject private var model: TownModel
    @EnvironmentObject private var pro: Pro
    let town: Town
    var close: () -> Void
    var body: some View {
        Modal(title: "Town laws", trailing: "\(town.activeLaws.count)/\(Law.maxActive) in force", close: close) {
            VStack(spacing: 6) {
                Text(pro.unlocked ? "Pass up to three. The town lives by them until you repeal them."
                                  : "Laws come with The Big Hand. Here is what they do.")
                    .font(UI.font(12, .semibold)).foregroundStyle(UI.ink.opacity(0.75)).multilineTextAlignment(.center)
                ForEach(Law.allCases) { law in
                    let on = town.has(law)
                    Button {
                        guard pro.unlocked else { close(); pro.showPaywall = true; return }
                        model.toggle(law)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Text(law.icon).font(.system(size: 18)).frame(width: 40)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(law.title).font(UI.font(13, .black)).foregroundStyle(UI.ink)
                                Text(law.blurb).font(UI.font(11, .medium)).foregroundStyle(UI.ink.opacity(0.7)).multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Text(on ? "IN FORCE" : pro.unlocked ? "PASS" : "🔒").font(UI.font(10, .black))
                                .foregroundStyle(on ? .white : UI.ink)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(on ? Color(red: 0.12, green: 0.45, blue: 0.14) : .clear)
                        }
                        .padding(7)
                        .bevel(raised: !on, fill: on ? Color(red: 0.86, green: 0.95, blue: 0.84) : UI.chrome)
                    }
                    .buttonStyle(.plain)
                    .disabled(pro.unlocked && !on && town.activeLaws.count >= Law.maxActive)
                }
            }
        }
    }
}

// MARK: - Records

struct RecordsWindow: View {
    let town: Town
    var close: () -> Void
    var body: some View {
        let r = town.records ?? Records()
        Modal(title: "Hall of records", trailing: town.name, close: close) {
            VStack(spacing: 0) {
                row("💰", "Richest ever", r.richestName.isEmpty ? "nobody yet" : "\(r.richestName), \(r.richest) coins (day \(r.richestDay))")
                row("💼", "Biggest heist", r.heistName.isEmpty ? "none yet" : "\(r.heistName), \(r.biggestHeist) coins")
                row("🕶️", "Most wanted", r.mostWanted.map { "\($0.0), \($0.1) crimes" } ?? "a clean town")
                row("👑", "Crowned most", r.mostCrowned.map { "\($0.0), \($0.1) times" } ?? "nobody yet")
                row("🔒", "Arrests", "\(r.arrests)")
                row("🚪", "Exiles", "\(r.exiles)")
                row("📈", "Businesses founded", "\(r.businesses)")
                row("🎲", "Gambles won / lost", "\(r.gamblesWon) / \(r.gamblesLost)")
                row("✨", "Miracles", "\(r.miracles)")
                row("📅", "Days on record", "\(town.day)")
            }
            .bevel(raised: false, fill: UI.paper)
        }
    }
    private func row(_ icon: String, _ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(icon).font(.system(size: 14)).frame(width: 22)
            Text(k).font(UI.font(12, .bold)).foregroundStyle(UI.ink.opacity(0.6)).frame(width: 110, alignment: .leading)
            Text(v).font(UI.font(12, .black)).foregroundStyle(UI.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - Yards

struct YardsWindow: View {
    @EnvironmentObject private var model: TownModel
    @EnvironmentObject private var extras: Extras
    var close: () -> Void
    @State private var current = YardTheme.current.id
    var body: some View {
        Modal(title: "Yards", trailing: "\(extras.price(Extras.yardID("snow"))) each", close: close) {
            VStack(spacing: 6) {
                Text("Each yard repaints the lawn, the sky and the widget, and changes the app icon to match. Yours for good.")
                    .font(UI.font(11, .semibold)).foregroundStyle(UI.ink.opacity(0.75)).multilineTextAlignment(.center)
                ForEach(YardTheme.all) { y in
                    let owned = extras.owns(yard: y.id), on = current == y.id
                    Button {
                        if owned { use(y) } else { Task { if await extras.buy(Extras.yardID(y.id)) { use(y) } } }
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Rectangle().fill(y.sky).frame(height: 18)
                                    .frame(maxHeight: .infinity, alignment: .top)
                                Rectangle().fill(y.grass).frame(height: 26).frame(maxHeight: .infinity, alignment: .bottom)
                                HStack(spacing: 0) { ForEach(y.flowers.prefix(3), id: \.self) { Text($0).font(.system(size: 13)) } }
                                    .offset(y: 8)
                            }
                            .frame(width: 70, height: 44)
                            .bevel(raised: false, fill: y.grass)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(y.name).font(UI.font(14, .black)).foregroundStyle(UI.ink)
                                Text(y.blurb).font(UI.font(11, .medium)).foregroundStyle(UI.ink.opacity(0.7)).lineLimit(2)
                            }
                            Spacer()
                            Text(on ? "✓" : owned ? "USE" : extras.busy == Extras.yardID(y.id) ? "..." : extras.price(Extras.yardID(y.id)))
                                .font(UI.font(12, .black)).foregroundStyle(UI.ink)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .bevel(raised: true, fill: owned ? UI.chrome : UI.coin)
                        }
                        .padding(6)
                        .bevel(raised: !on, fill: on ? UI.coin.opacity(0.25) : UI.chrome)
                    }
                    .buttonStyle(.plain)
                    .disabled(extras.busy != nil)
                }
                if let m = extras.message { Text(m).font(UI.font(10, .bold)).foregroundStyle(UI.red) }
            }
        }
    }
    private func use(_ y: YardTheme) {
        YardTheme.apply(y.id)
        current = y.id
        model.yardTick += 1
        let demo = ProcessInfo.processInfo.arguments.contains("-screenshots")
        if !demo, UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != y.icon {
            UIApplication.shared.setAlternateIconName(y.icon)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Settings

struct SettingsWindow: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var pro: Pro
    @EnvironmentObject private var extras: Extras
    var close: () -> Void
    var body: some View {
        Modal(title: "Settings", close: close) {
            VStack(spacing: 8) {
                Toggle(isOn: Binding(get: { player.notify }, set: { on in
                    if on { Task { await player.askToNotify() } } else { player.notify = false }
                })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Wish reminder").font(UI.font(13, .black)).foregroundStyle(UI.ink)
                        Text("One nudge at 10:00, skipped once today's wish is granted.").font(UI.font(11, .medium)).foregroundStyle(UI.ink.opacity(0.7))
                    }
                }
                .tint(Color(red: 0.12, green: 0.45, blue: 0.14))
                .padding(8).bevel(raised: false, fill: UI.paper)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Widgets").font(UI.font(13, .black)).foregroundStyle(UI.ink)
                    Text("Touch and hold the Home Screen, tap Edit, Add Widget, Pocket Beings. The small Daily Grudge is free; the big Town Hall comes with The Big Hand.")
                        .font(UI.font(11, .medium)).foregroundStyle(UI.ink.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8).bevel(raised: false, fill: UI.paper)
                Button(pro.busy ? "ONE MOMENT..." : "RESTORE PURCHASES") {
                    Task { await pro.restore(); await extras.restore() }
                }
                .buttonStyle(ChunkyButton())
                if let m = pro.message { Text(m).font(UI.font(11, .bold)).foregroundStyle(UI.ink.opacity(0.7)) }
                Text("No accounts, no ads, no tracking. The town lives on this phone.")
                    .font(UI.font(10, .semibold)).foregroundStyle(UI.ink.opacity(0.55)).multilineTextAlignment(.center)
            }
        }
    }
}
