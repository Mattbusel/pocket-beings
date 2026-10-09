import Combine
import Foundation
import UIKit
import WidgetKit

/// Holds the town, runs the clock, and saves. The only object in the app that
/// owns state; every view reads it.
@MainActor
final class TownModel: ObservableObject {
    @Published private(set) var town: Town?
    /// The most recent deed, for the yard to show as a speech bubble.
    @Published private(set) var latest: Deed?
    /// What happened while the app was closed. Shown once, then cleared.
    @Published var awayNews: [Deed] = []
    /// Seconds until the player may meddle again.
    @Published private(set) var cooldown: Double = 0
    /// Bumped when the yard theme changes, so the scene repaints.
    @Published var yardTick = 0
    /// The demo script opening a being's file, for the review recording.
    @Published var demoSelected: UUID?

    static let secondsPerTick: Double = 2.4
    static let meddleCooldown: Double = 5
    /// The Big Hand rests for less.
    static let fastCooldown: Double = 2

    /// Set from Pro: whether the hand rests two seconds or five.
    var fastHand = false
    private var handRest: Double { fastHand ? Self.fastCooldown : Self.meddleCooldown }

    private var clock: AnyCancellable?
    private var lastMeddle = Date.distantPast
    private var ticksSinceSave = 0

    /// In the app group container, so the widget reads the same town (1.1 kept it in Documents).
    private static var file: URL { Shared.townFile }

    /// Called after every turn, so today's wish can notice when it comes true.
    var onTurn: ((Town) -> Void)?

    var hasSavedTown: Bool { FileManager.default.fileExists(atPath: Self.file.path) }

    /// "Grudge Hollow, day 8", for the CONTINUE button.
    var savedTownLabel: String {
        guard let data = try? Data(contentsOf: Self.file),
              let t = try? JSONDecoder().decode(Town.self, from: data) else { return "" }
        return "\(t.name), day \(t.day)"
    }

    init() {
        Shared.migrate()
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.save()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-yard"), i + 1 < args.count {
            YardTheme.current = YardTheme.byID(args[i + 1])
        }
        if args.contains("-screenshots") {
            // A fixed town with a morning of history, so the store screenshots
            // are the same every run and are never an empty yard.
            var t = Founding.town(seed: 20260911, name: "Grudge Hollow")
            for _ in 0..<150 { Society.step(&t) }
            if args.contains("-showLaws") { t.laws = [Law.toughOnCrime.rawValue, Law.basicCoin.rawValue] }
            if args.contains("-invited") {
                _ = Society.invite(&t, name: "Grandma Jo", face: "👵", replacing: nil)
            }
            town = t
            latest = t.ledger.first
            if args.contains("-showNews") {
                awayNews = Array(t.ledger.filter(\.big).prefix(6))
            }
            start()
        } else if args.contains("-demoAutoplay") {
            newTown()
        }
    }

    // MARK: lifecycle

    func newTown() {
        var t = Founding.town(seed: UInt64.random(in: 1...UInt64.max))
        // A little history, so day one is not seven strangers standing still.
        for _ in 0..<12 { Society.step(&t) }
        town = t
        latest = t.ledger.first
        awayNews = []
        save()
        start()
    }

    func continueTown() {
        guard let data = try? Data(contentsOf: Self.file),
              var t = try? JSONDecoder().decode(Town.self, from: data)
        else { newTown(); return }
        let away = Date().timeIntervalSince(t.savedAt)
        awayNews = Society.catchUp(&t, elapsed: away, secondsPerTick: Self.secondsPerTick)
        town = t
        latest = t.ledger.first
        save()
        start()
    }

    func leaveTown() {
        clock?.cancel()
        save()
        town = nil
    }

    private func start() {
        clock?.cancel()
        clock = Timer.publish(every: Self.secondsPerTick, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard var t = town else { return }
        if let deed = Society.step(&t) {
            latest = deed
            if deed.big { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
        town = t
        onTurn?(t)
        cooldown = max(0, handRest - Date().timeIntervalSince(lastMeddle))
        ticksSinceSave += 1
        if ticksSinceSave >= 5 { save() }
    }

    private func save() {
        guard var t = town else { return }
        t.savedAt = Date()
        town?.savedAt = t.savedAt
        if let data = try? JSONEncoder().encode(t) {
            try? data.write(to: Self.file, options: .atomic)
        }
        ticksSinceSave = 0
    }

    // MARK: the player

    var canMeddle: Bool { Date().timeIntervalSince(lastMeddle) >= handRest }

    func meddle(_ m: Society.Meddle, on being: Being, force: Bool = false) {
        guard canMeddle || force, var t = town else { return }
        Society.meddle(&t, m, on: being)
        UIImpactFeedbackGenerator(style: m == .exile || m == .jail ? .heavy : .medium).impactOccurred()
        lastMeddle = Date()
        cooldown = handRest
        latest = t.ledger.first
        town = t
        onTurn?(t)
        save()
    }

    /// The Big Hand: call the town something else.
    func rename(_ name: String) {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        guard !clean.isEmpty, var t = town, clean != t.name else { return }
        let old = t.name
        t.name = clean
        Society.say(&t, "🪧 \(old) is now called \(clean). The sign painter is thrilled.", kind: "rename",
                    actor: Being(name: "You", face: "🫵", hue: 0), big: true)
        latest = t.ledger.first
        town = t
        save()
    }

    // MARK: 1.2: miracles, laws, invitations

    /// Drop a miracle on the town. The charge is spent by the caller.
    func cast(_ m: Miracle) {
        guard var t = town else { return }
        Society.miracle(&t, m)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        latest = t.ledger.first
        town = t
        onTurn?(t)
        save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func toggle(_ law: Law) {
        guard var t = town else { return }
        var laws = t.laws ?? []
        let hand = Being(name: "You", face: "📜", hue: 0)
        if let i = laws.firstIndex(of: law.rawValue) {
            laws.remove(at: i)
            Society.say(&t, "📜 \(law.title) was repealed.", kind: "law", actor: hand)
        } else {
            guard laws.count < Law.maxActive else { return }
            laws.append(law.rawValue)
            Society.say(&t, "📜 NEW LAW: \(law.title). \(law.blurb)", kind: "law", actor: hand, big: true)
        }
        t.laws = laws
        latest = t.ledger.first
        town = t
        save()
    }

    /// Bring in a stranger the player named. Replaces someone once the town is full.
    func invite(name: String, face: String, replacing: Being?) {
        guard var t = town else { return }
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(18))
        guard !clean.isEmpty else { return }
        let leaving = t.beings.count >= Society.maxPopulation ? (replacing ?? t.beings.first) : replacing
        _ = Society.invite(&t, name: clean, face: face, replacing: leaving)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        latest = t.ledger.first
        town = t
        onTurn?(t)
        save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func being(_ id: UUID) -> Being? {
        town?.beings.first { $0.id == id }
    }
}
