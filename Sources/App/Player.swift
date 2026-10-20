import Foundation
import UserNotifications

/// Everything the player holds that is not the town: miracle charges, invitations,
/// today's wish and the wish streak, the daily gift calendar, the Season track, the
/// weekly challenges, the stamp album and the Club Chest. Saved in UserDefaults
/// under "pb."; the town file is untouched.
@MainActor
final class Player: ObservableObject {
    @Published private(set) var miracles = 0
    @Published private(set) var invites = 0
    @Published private(set) var wish: Wish?
    @Published private(set) var streak = 0
    @Published private(set) var bestStreak = 0
    /// The day the daily gift was last opened ("pb.claimed", the 1.2 free-miracle day).
    @Published private(set) var claimedDay = ""
    /// Which box of the 7-day gift calendar the last gift was (0...6).
    @Published private(set) var giftIndex = -1
    @Published private(set) var stars = 0
    @Published private(set) var claimedFree: Set<Int> = []
    @Published private(set) var claimedClub: Set<Int> = []
    @Published private(set) var weekCounts: [String: Int] = [:]
    @Published private(set) var weekDone: Set<String> = []
    @Published private(set) var counts: [String: Int] = [:]
    @Published private(set) var stamps: Set<String> = []
    @Published private(set) var faces: [String] = []
    @Published private(set) var chestMonth = ""
    @Published private(set) var seasonsFinished = 0
    @Published private(set) var wishesGranted = 0
    @Published var wishBanner: Wish?
    /// A short line that slides in over the town: a stamp, a finished challenge.
    @Published var toast: String?
    @Published var notify = false {
        didSet { if !loading { d.set(notify, forKey: "pb.notify"); Task { await scheduleReminders() } } }
    }

    /// Set from the app: the Club doubles gifts and opens the Club row; The Big Hand adds a miracle a day.
    @Published var club = false
    @Published var bigHand = false

    private let d = UserDefaults.standard
    private let demo: Bool
    private var loading = false
    private(set) var season = Season.at(Date())
    private(set) var weekKey = Challenges.weekKey(Date())

    static var today: String { dayKey(Date()) }
    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func yesterday() -> String { dayKey(Date().addingTimeInterval(-86_400)) }

    init() {
        let args = ProcessInfo.processInfo.arguments
        demo = args.contains("-screenshots") || args.contains("-demoAutoplay") || args.contains("-FASTLANE_SNAPSHOT") || args.contains("-previewTour")
        if demo {
            miracles = 6; invites = 2; streak = 6; bestStreak = 11; claimedDay = ""; giftIndex = 3
            stars = 52; claimedFree = [1, 2, 3]; claimedClub = args.contains("-clubOn") ? [1, 2, 3] : []
            let ch = Challenges.week(weekKey)
            weekCounts = [ch[0].kind: ch[0].goal, ch[1].kind: max(0, ch[1].goal - 1)]
            weekDone = [ch[0].kind]
            stamps = ["heist", "bigscore", "sheriff", "mainstreet", "fourdigits", "funnymoney", "lucky", "riddance",
                      "oldtown", "actofgod", "plusone", "fullcells", "dynasty"]
            faces = ["🎃"]
            wishesGranted = 9
            loading = true; notify = true; loading = false
            return
        }
        load()
    }

    /// Read everything back from UserDefaults (also after an iCloud restore).
    func load() {
        loading = true; defer { loading = false }
        // 1.2 opens with a little of everything to try.
        if !d.bool(forKey: "pb.welcome12") {
            d.set(true, forKey: "pb.welcome12")
            d.set(d.integer(forKey: "pb.miracles") + 3, forKey: "pb.miracles")
            d.set(d.integer(forKey: "pb.invites") + 1, forKey: "pb.invites")
        }
        miracles = d.integer(forKey: "pb.miracles")
        invites = d.integer(forKey: "pb.invites")
        streak = d.integer(forKey: "pb.streak")
        bestStreak = d.integer(forKey: "pb.bestStreak")
        claimedDay = d.string(forKey: "pb.claimed") ?? ""
        giftIndex = d.object(forKey: "pb.giftIndex") as? Int ?? -1
        notify = d.bool(forKey: "pb.notify")
        counts = d.dictionary(forKey: "pb.counts") as? [String: Int] ?? [:]
        stamps = Set(d.stringArray(forKey: "pb.stamps") ?? [])
        faces = d.stringArray(forKey: "pb.faces") ?? []
        chestMonth = d.string(forKey: "pb.chestMonth") ?? ""
        seasonsFinished = d.integer(forKey: "pb.seasonsFinished")
        wishesGranted = d.integer(forKey: "pb.wishesGranted")
        if let data = d.data(forKey: "pb.wish"), let w = try? JSONDecoder().decode(Wish.self, from: data) { wish = w }
        // A streak survives yesterday's wish, not a gap.
        if let last = d.string(forKey: "pb.lastWish"), last != Self.today, last != Self.yesterday() { streak = 0 }
        rollPeriods()
    }

    /// A new month is a new Season; a new week is three new challenges.
    func rollPeriods() {
        guard !demo else { return }
        season = Season.at(Date())
        weekKey = Challenges.weekKey(Date())
        stars = d.integer(forKey: "pb.season.\(season.key).stars")
        claimedFree = Set(d.array(forKey: "pb.season.\(season.key).free") as? [Int] ?? [])
        claimedClub = Set(d.array(forKey: "pb.season.\(season.key).club") as? [Int] ?? [])
        weekCounts = d.dictionary(forKey: "pb.week.\(weekKey)") as? [String: Int] ?? [:]
        weekDone = Set(d.stringArray(forKey: "pb.week.\(weekKey).done") ?? [])
    }

    private func save() {
        guard !demo else { return }
        d.set(miracles, forKey: "pb.miracles")
        d.set(invites, forKey: "pb.invites")
        d.set(streak, forKey: "pb.streak")
        d.set(bestStreak, forKey: "pb.bestStreak")
        d.set(claimedDay, forKey: "pb.claimed")
        d.set(giftIndex, forKey: "pb.giftIndex")
        d.set(counts, forKey: "pb.counts")
        d.set(Array(stamps), forKey: "pb.stamps")
        d.set(faces, forKey: "pb.faces")
        d.set(chestMonth, forKey: "pb.chestMonth")
        d.set(seasonsFinished, forKey: "pb.seasonsFinished")
        d.set(wishesGranted, forKey: "pb.wishesGranted")
        d.set(stars, forKey: "pb.season.\(season.key).stars")
        d.set(Array(claimedFree), forKey: "pb.season.\(season.key).free")
        d.set(Array(claimedClub), forKey: "pb.season.\(season.key).club")
        d.set(weekCounts, forKey: "pb.week.\(weekKey)")
        d.set(Array(weekDone), forKey: "pb.week.\(weekKey).done")
        if let wish, let data = try? JSONEncoder().encode(wish) { d.set(data, forKey: "pb.wish") }
    }

    // MARK: miracles and invitations

    func addMiracles(_ n: Int) { miracles += n; save() }
    func addInvites(_ n: Int) { invites += n; save() }
    func spendMiracle() -> Bool { guard miracles > 0 else { return false }; miracles -= 1; save(); return true }
    func spendInvite() -> Bool { guard invites > 0 else { return false }; invites -= 1; save(); return true }

    private func grant(_ r: Reward) {
        miracles += r.miracles
        invites += r.invites
        if r.face, !faces.contains(season.face) { faces.append(season.face) }
    }

    // MARK: daily gift

    var canClaim: Bool { claimedDay != Self.today }

    /// The box today's gift comes from: the next one if yesterday's was opened, else box one.
    var nextGiftIndex: Int {
        claimedDay == Self.yesterday() || (demo && giftIndex >= 0) ? (giftIndex + 1) % 7 : 0
    }

    var todaysGift: Reward { DailyGift.reward(index: nextGiftIndex, bigHand: bigHand, club: club) }

    @discardableResult
    func claim() -> Reward? {
        guard canClaim else { return nil }
        let r = todaysGift
        giftIndex = nextGiftIndex
        claimedDay = Self.today
        grant(r)
        addStars(DailyGift.stars)
        bump("daily")
        save()
        Task { await scheduleReminders() }
        return r
    }

    // MARK: Season

    var tier: Int { Season.tier(stars: stars) }

    func addStars(_ n: Int) {
        let before = tier
        stars += n
        if tier >= Season.tiers, before < Season.tiers {
            seasonsFinished += 1
            toast = "\(season.icon) Season finished! Claim your tier 10 rewards."
        } else if tier > before {
            toast = "⭐ Tier \(tier) reached. Rewards are waiting in the Season."
        }
        save()
    }

    func claimTier(_ t: Int, clubRow: Bool) {
        guard t >= 1, t <= tier else { return }
        if clubRow {
            guard club, !claimedClub.contains(t) else { return }
            claimedClub.insert(t); grant(Season.club(t))
        } else {
            guard !claimedFree.contains(t) else { return }
            claimedFree.insert(t); grant(Season.free(t))
        }
        save()
    }

    var unclaimedTiers: Int {
        guard tier > 0 else { return 0 }
        return (1...tier).filter { !claimedFree.contains($0) || (club && !claimedClub.contains($0)) }.count
    }

    // MARK: weekly challenges and counters

    var challenges: [Challenge] { Challenges.week(weekKey) }

    /// Count something the player did, for the challenges and the album.
    func bump(_ kind: String, by n: Int = 1) {
        if Challenges.weekKey(Date()) != weekKey { rollPeriods() }
        counts[kind, default: 0] += n
        weekCounts[kind, default: 0] += n
        for c in challenges where c.kind == kind && !weekDone.contains(kind) && (weekCounts[kind] ?? 0) >= c.goal {
            weekDone.insert(kind)
            toast = "\(c.icon) Challenge done: \(c.text). +\(Challenge.stars) ⭐"
            addStars(Challenge.stars)
        }
        save()
    }

    // MARK: stamps

    func checkStamps(town: Town) {
        let got = Stamps.earned(StampContext(town: town, counts: counts, bestStreak: bestStreak, seasonsFinished: seasonsFinished))
        let fresh = got.subtracting(stamps)
        guard !fresh.isEmpty, !demo else { return }
        stamps.formUnion(fresh)
        if let s = Stamps.all.first(where: { fresh.contains($0.id) }) {
            toast = "\(s.icon) New stamp: \(s.title). +\(Stamp.stars) ⭐"
        }
        addStars(Stamp.stars * fresh.count)
    }

    // MARK: Club Chest

    static var monthKey: String { Season.at(Date()).key }
    var canOpenChest: Bool { club && chestMonth != Self.monthKey }

    func openChest() {
        guard canOpenChest else { return }
        chestMonth = Self.monthKey
        grant(Reward(miracles: 25, invites: 5))
        toast = "🧰 Club Chest: +25 ✨ and +5 🎟️"
        save()
    }

    // MARK: wishes

    /// Today's wish for this town, made once and kept for the day.
    func refreshWish(town: Town) {
        if demo {
            if wish == nil { wish = Wishes.make(day: Self.today, town: town) }
            return
        }
        if Season.at(Date()).key != season.key || Challenges.weekKey(Date()) != weekKey { rollPeriods() }
        if wish?.day != Self.today { wish = Wishes.make(day: Self.today, town: town); save() }
    }

    /// Called as the town runs. True the moment today's wish comes true.
    @discardableResult
    func check(town: Town) -> Bool {
        checkStamps(town: town)
        // Screenshots and the preview keep today's wish open: no banner over the shot.
        if demo { return false }
        guard var w = wish, w.day == Self.today, !w.done, Wishes.check(w, town: town) else { return false }
        w.done = true
        wish = w
        let last = d.string(forKey: "pb.lastWish")
        streak = last == Self.yesterday() ? streak + 1 : (last == Self.today ? streak : 1)
        bestStreak = max(bestStreak, streak)
        d.set(Self.today, forKey: "pb.lastWish")
        miracles += 1
        wishesGranted += 1
        wishBanner = w
        bump("wish")
        addStars(4)
        save()
        Task { await scheduleReminders() }
        return true
    }

    // MARK: reminders

    /// A nudge at 10:00 on the days ahead, skipping today once the gift is open and the wish is done.
    func scheduleReminders() async {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: (0..<7).map { "pb-wish-\($0)" })
        guard notify, !demo else { return }
        let cal = Calendar.current
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: i, to: Date()),
                  let fire = cal.date(bySettingHour: 10, minute: 0, second: 0, of: day), fire > Date() else { continue }
            if i == 0, wish?.done == true, !canClaim { continue }
            let content = UNMutableNotificationContent()
            content.title = "Your daily gift is waiting"
            content.body = streak > 1 ? "Open it, then keep the \(streak)-day wish streak going. The town has been busy without you."
                                      : "Open it and see what the town got up to without you."
            content.sound = .default
            try? await c.add(UNNotificationRequest(identifier: "pb-wish-\(i)", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)))
        }
    }

    func askToNotify() async {
        let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        notify = ok
    }
}
