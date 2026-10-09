import Foundation
import UserNotifications

/// Everything the player holds that is not the town: miracle charges, invitations,
/// today's wish and the wish streak. Saved in UserDefaults; the town file is untouched.
@MainActor
final class Player: ObservableObject {
    @Published private(set) var miracles: Int
    @Published private(set) var invites: Int
    @Published private(set) var wish: Wish?
    @Published private(set) var streak: Int
    @Published private(set) var bestStreak: Int
    /// The day the free daily miracle was last taken.
    @Published private(set) var claimedDay: String
    @Published var wishBanner: Wish?
    @Published var notify: Bool {
        didSet { d.set(notify, forKey: "pb.notify"); Task { await scheduleReminders() } }
    }

    private let d = UserDefaults.standard
    private let demo: Bool

    static var today: String { dayKey(Date()) }
    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func yesterday() -> String { dayKey(Date().addingTimeInterval(-86_400)) }

    init() {
        let args = ProcessInfo.processInfo.arguments
        demo = args.contains("-screenshots") || args.contains("-demoAutoplay") || args.contains("-FASTLANE_SNAPSHOT")
        if demo {
            miracles = 4; invites = 2; streak = 6; bestStreak = 11; claimedDay = ""; notify = true
            wish = nil
            return
        }
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
        notify = d.bool(forKey: "pb.notify")
        if let data = d.data(forKey: "pb.wish"), let w = try? JSONDecoder().decode(Wish.self, from: data) { wish = w }
        // A streak survives yesterday's wish, not a gap.
        if let last = d.string(forKey: "pb.lastWish"), last != Self.today, last != Self.yesterday() { streak = 0; save() }
    }

    private func save() {
        guard !demo else { return }
        d.set(miracles, forKey: "pb.miracles")
        d.set(invites, forKey: "pb.invites")
        d.set(streak, forKey: "pb.streak")
        d.set(bestStreak, forKey: "pb.bestStreak")
        d.set(claimedDay, forKey: "pb.claimed")
        if let wish, let data = try? JSONEncoder().encode(wish) { d.set(data, forKey: "pb.wish") }
    }

    // MARK: miracles and invitations

    func addMiracles(_ n: Int) { miracles += n; save() }
    func addInvites(_ n: Int) { invites += n; save() }
    func spendMiracle() -> Bool { guard miracles > 0 else { return false }; miracles -= 1; save(); return true }
    func spendInvite() -> Bool { guard invites > 0 else { return false }; invites -= 1; save(); return true }

    /// One free miracle a day; two with The Big Hand.
    func dailyAllowance(pro: Bool) -> Int { pro ? 2 : 1 }
    var canClaim: Bool { claimedDay != Self.today }
    func claim(pro: Bool) {
        guard canClaim else { return }
        claimedDay = Self.today
        miracles += dailyAllowance(pro: pro)
        save()
    }

    // MARK: wishes

    /// Today's wish for this town, made once and kept for the day.
    func refreshWish(town: Town) {
        if demo {
            if wish == nil { wish = Wishes.make(day: Self.today, town: town) }
            return
        }
        if wish?.day != Self.today { wish = Wishes.make(day: Self.today, town: town); save() }
    }

    /// Called as the town runs. True the moment today's wish comes true.
    @discardableResult
    func check(town: Town) -> Bool {
        guard var w = wish, w.day == Self.today, !w.done, Wishes.check(w, town: town) else { return false }
        w.done = true
        wish = w
        let last = d.string(forKey: "pb.lastWish")
        streak = last == Self.yesterday() ? streak + 1 : (last == Self.today ? streak : 1)
        bestStreak = max(bestStreak, streak)
        d.set(Self.today, forKey: "pb.lastWish")
        miracles += 1
        wishBanner = w
        save()
        Task { await scheduleReminders() }
        return true
    }

    // MARK: reminders

    /// A nudge at 10:00 on the days ahead, skipping today once the wish is done.
    func scheduleReminders(townName: String = "") async {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: (0..<7).map { "pb-wish-\($0)" })
        guard notify, !demo else { return }
        let cal = Calendar.current
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: i, to: Date()),
                  let fire = cal.date(bySettingHour: 10, minute: 0, second: 0, of: day), fire > Date() else { continue }
            if i == 0, wish?.done == true { continue }
            let content = UNMutableNotificationContent()
            content.title = "Today's wish is waiting"
            content.body = streak > 1 ? "Keep the \(streak)-day streak going. The town has been busy without you." : "The town has been busy without you. Come and meddle."
            content.sound = .default
            c.add(UNNotificationRequest(identifier: "pb-wish-\(i)", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)))
        }
    }

    func askToNotify() async {
        let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        notify = ok
    }
}
