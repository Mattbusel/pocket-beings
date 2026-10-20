import Foundation

// The 1.3 layer of reasons to come back: a daily gift on a 7-day calendar, a Season
// every calendar month with a 10-tier track, three weekly challenges, a stamp album
// and the town almanac. Pure data and pure functions, so the widget and the tests
// can use them too.

// MARK: - Rewards

struct Reward: Equatable {
    var miracles = 0
    var invites = 0
    /// The season's own face, for invitations. Kept for good once earned.
    var face = false

    static func + (a: Reward, b: Reward) -> Reward {
        Reward(miracles: a.miracles + b.miracles, invites: a.invites + b.invites, face: a.face || b.face)
    }

    var label: String {
        var parts: [String] = []
        if miracles > 0 { parts.append("✨\(miracles)") }
        if invites > 0 { parts.append("🎟️\(invites)") }
        if face { parts.append("face") }
        return parts.joined(separator: " ")
    }
}

// MARK: - Daily gift

enum DailyGift {
    /// Seven boxes. Come back on consecutive days to walk along them; miss a day and
    /// the calendar starts again at box one. Box seven is the big one.
    static let calendar: [Reward] = [
        Reward(miracles: 1), Reward(miracles: 1, invites: 1), Reward(miracles: 2),
        Reward(miracles: 1, invites: 1), Reward(miracles: 2), Reward(miracles: 1, invites: 1),
        Reward(miracles: 3, invites: 1),
    ]

    /// What box `index` (0...6) gives. The Big Hand adds a miracle to every box (it
    /// always gave two a day); the Town Club doubles the whole box.
    static func reward(index: Int, bigHand: Bool, club: Bool) -> Reward {
        var r = calendar[max(0, min(6, index))]
        if bigHand { r.miracles += 1 }
        if club { r.miracles *= 2; r.invites *= 2 }
        return r
    }

    /// Season stars for opening the gift.
    static let stars = 2
}

// MARK: - Seasons

struct Season: Equatable {
    /// "2026-11"
    var key: String
    var name: String
    var icon: String
    /// The face a finished season leaves behind, for invitations.
    var face: String
    var blurb: String
    /// Seconds left until the season ends.
    var ends: Date

    static let starsPerTier = 15
    static let tiers = 10

    static let names: [(String, String, String, String)] = [
        ("Frost Fair", "❄️", "🥶", "Ice on the pond, fraud at the stalls."),
        ("Sweethearts and Swindlers", "💘", "💘", "Everyone is in love with somebody's wallet."),
        ("Spring Cleaning", "🧹", "🧹", "Out with the old council, in with the new grudges."),
        ("Fools' Gold", "🪙", "🃏", "Nothing that glitters is worth what it says."),
        ("Garden Party", "🌷", "🐝", "Prize marrows, sabotage and very small sandwiches."),
        ("Long Summer", "🌞", "😎", "Too hot to work, just right for crime."),
        ("Heatwave", "🔥", "🥵", "Tempers short, ice cream shorter."),
        ("Beach Bandits", "🏖️", "🦀", "Sand in the treasury again."),
        ("Back to School", "🎒", "🤓", "New pencils, old feuds."),
        ("Spooky Season", "🎃", "🎃", "Strange lights over Town Hall. Probably the Banker."),
        ("Election Season", "🗳️", "🦃", "Every seat is up for grabs and every vote is for sale."),
        ("Holiday Heist", "🎁", "🎅", "Somebody is stealing the presents. Everybody suspects Snik."),
    ]

    static func at(_ date: Date, calendar: Calendar = .current) -> Season {
        let c = calendar.dateComponents([.year, .month], from: date)
        let y = c.year ?? 2026, m = c.month ?? 1
        let n = names[(m - 1) % 12]
        let start = calendar.date(from: DateComponents(year: y, month: m, day: 1)) ?? date
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? date
        return Season(key: String(format: "%04d-%02d", y, m), name: n.0, icon: n.1, face: n.2, blurb: n.3, ends: end)
    }

    /// The free row of the track. Tier 10 leaves the season's face behind.
    static func free(_ tier: Int) -> Reward {
        switch tier {
        case 1: return Reward(miracles: 1)
        case 2, 4, 6, 8: return Reward(invites: 1)
        case 3, 5: return Reward(miracles: 2)
        case 7, 9: return Reward(miracles: 3)
        default: return Reward(miracles: 3, face: true)
        }
    }

    /// The Town Club row: bigger, on every tier.
    static func club(_ tier: Int) -> Reward {
        switch tier {
        case 1: return Reward(miracles: 3)
        case 2: return Reward(miracles: 2, invites: 1)
        case 3: return Reward(miracles: 4)
        case 4, 6, 8: return Reward(invites: 2)
        case 5, 7: return Reward(miracles: 5)
        case 9: return Reward(miracles: 6)
        default: return Reward(miracles: 8, invites: 3)
        }
    }

    static func tier(stars: Int) -> Int { min(tiers, stars / starsPerTier) }
}

// MARK: - Weekly challenges

struct Challenge: Equatable, Identifiable {
    var id: String { kind }
    var kind: String
    var goal: Int
    var text: String
    var icon: String
    static let stars = 5
}

enum Challenges {
    static let pool: [Challenge] = [
        Challenge(kind: "meddle", goal: 15, text: "Meddle 15 times", icon: "🫵"),
        Challenge(kind: "jail", goal: 3, text: "Jail 3 beings", icon: "🔒"),
        Challenge(kind: "crown", goal: 2, text: "Crown 2 beings", icon: "👑"),
        Challenge(kind: "gift", goal: 4, text: "Give 50 coins 4 times", icon: "🎁"),
        Challenge(kind: "rob", goal: 4, text: "Rob 4 beings", icon: "🫳"),
        Challenge(kind: "miracle", goal: 2, text: "Drop 2 miracles", icon: "✨"),
        Challenge(kind: "wish", goal: 3, text: "Grant 3 wishes", icon: "🌠"),
        Challenge(kind: "daily", goal: 4, text: "Open the daily gift 4 days", icon: "🎀"),
        Challenge(kind: "exile", goal: 1, text: "Exile someone", icon: "🚪"),
        Challenge(kind: "invite", goal: 1, text: "Invite a stranger", icon: "🎟️"),
    ]

    /// "2026-W43", by ISO week.
    static func weekKey(_ date: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 2026, c.weekOfYear ?? 1)
    }

    /// Three different challenges, the same for everyone in the same week.
    static func week(_ key: String) -> [Challenge] {
        var seed: UInt64 = 1469598103934665603
        for b in key.utf8 { seed = (seed ^ UInt64(b)) &* 1099511628211 }
        var dice = Dice(seed: seed)
        var left = pool
        var out: [Challenge] = []
        while out.count < 3, !left.isEmpty {
            out.append(left.remove(at: Int(dice.next() % UInt64(left.count))))
        }
        return out
    }
}

// MARK: - Stamp album

struct Stamp: Identifiable, Equatable {
    var id: String
    var icon: String
    var title: String
    var how: String
    static let stars = 2
}

/// What the album checks against: the town, and what the player has done.
struct StampContext {
    var town: Town
    var counts: [String: Int]
    var bestStreak: Int
    var seasonsFinished: Int
}

enum Stamps {
    static let all: [Stamp] = [
        Stamp(id: "heist", icon: "💼", title: "First Heist", how: "Someone pulls off a heist."),
        Stamp(id: "bigscore", icon: "💰", title: "The Big Score", how: "A heist of 150 coins or more."),
        Stamp(id: "sheriff", icon: "🚔", title: "Busy Sheriff", how: "5 arrests in one town."),
        Stamp(id: "lockdown", icon: "⛓️", title: "Lockdown", how: "25 arrests in one town."),
        Stamp(id: "mainstreet", icon: "🏪", title: "Main Street", how: "5 businesses founded."),
        Stamp(id: "boomtown", icon: "🏙️", title: "Boomtown", how: "20 businesses founded."),
        Stamp(id: "fourdigits", icon: "🤑", title: "Four Digits", how: "Someone holds 1,000 coins."),
        Stamp(id: "tycoon", icon: "🏦", title: "Tycoon", how: "Someone holds 3,000 coins."),
        Stamp(id: "funnymoney", icon: "📈", title: "Funny Money", how: "Prices pass ×2."),
        Stamp(id: "wheelbarrow", icon: "🛒", title: "Wheelbarrow Economy", how: "Prices pass ×3."),
        Stamp(id: "lucky", icon: "🎲", title: "Lucky Break", how: "Someone goes all in and doubles."),
        Stamp(id: "house", icon: "🎰", title: "The House Wins", how: "Five lost gambles in one town."),
        Stamp(id: "dynasty", icon: "👑", title: "Dynasty", how: "The same being crowned 3 times."),
        Stamp(id: "riddance", icon: "🚪", title: "Good Riddance", how: "Exile someone."),
        Stamp(id: "oldtown", icon: "🏚️", title: "Old Town", how: "A town reaches day 10."),
        Stamp(id: "ancient", icon: "🗿", title: "Ancient History", how: "A town reaches day 30."),
        Stamp(id: "fullhouse", icon: "🏘️", title: "Full House", how: "Ten beings in town."),
        Stamp(id: "fullcells", icon: "🔒", title: "Full Cells", how: "Three in jail at once."),
        Stamp(id: "actofgod", icon: "✨", title: "Act of Sky", how: "Drop your first miracle."),
        Stamp(id: "allseven", icon: "🌈", title: "All Seven", how: "Drop each of the seven free miracles."),
        Stamp(id: "plusone", icon: "🎟️", title: "Plus One", how: "Invite a stranger."),
        Stamp(id: "weekofwishes", icon: "🌠", title: "Week of Wishes", how: "A 7-day wish streak."),
        Stamp(id: "monthofwishes", icon: "🌌", title: "Month of Wishes", how: "A 30-day wish streak."),
        Stamp(id: "finisher", icon: "🏁", title: "Season Finisher", how: "Reach tier 10 of a Season."),
    ]

    static let freeMiracles: [String] = ["coup", "election", "frogs", "goldRush", "festival", "twister", "haunting"]

    static func earned(_ c: StampContext) -> Set<String> {
        let t = c.town
        let r = t.records ?? Records()
        var s: Set<String> = []
        if r.biggestHeist > 0 { s.insert("heist") }
        if r.biggestHeist >= 150 { s.insert("bigscore") }
        if r.arrests >= 5 { s.insert("sheriff") }
        if r.arrests >= 25 { s.insert("lockdown") }
        if r.businesses >= 5 { s.insert("mainstreet") }
        if r.businesses >= 20 { s.insert("boomtown") }
        if r.richest >= 1000 { s.insert("fourdigits") }
        if r.richest >= 3000 { s.insert("tycoon") }
        if t.priceIndex >= 2 { s.insert("funnymoney") }
        if t.priceIndex >= 3 { s.insert("wheelbarrow") }
        if r.gamblesWon > 0 { s.insert("lucky") }
        if r.gamblesLost >= 5 { s.insert("house") }
        if (r.mostCrowned?.1 ?? 0) >= 3 { s.insert("dynasty") }
        if (c.counts["exile"] ?? 0) > 0 { s.insert("riddance") }
        if t.day >= 10 { s.insert("oldtown") }
        if t.day >= 30 { s.insert("ancient") }
        if t.beings.count >= 10 { s.insert("fullhouse") }
        if t.beings.filter({ $0.isJailed(at: t.tick) }).count >= 3 { s.insert("fullcells") }
        if (c.counts["miracle"] ?? 0) > 0 { s.insert("actofgod") }
        if freeMiracles.allSatisfy({ (c.counts["cast." + $0] ?? 0) > 0 }) { s.insert("allseven") }
        if (c.counts["invite"] ?? 0) > 0 { s.insert("plusone") }
        if c.bestStreak >= 7 { s.insert("weekofwishes") }
        if c.bestStreak >= 30 { s.insert("monthofwishes") }
        if c.seasonsFinished > 0 { s.insert("finisher") }
        return s
    }
}

// MARK: - Almanac

/// One line of the almanac, written at the end of every town day.
struct DaySnap: Codable, Equatable {
    var day: Int
    var wealth: Int
    var treasury: Int
    var prices: Double
    var jailed: Int
    var crimes: Int
    var richest: String
}

extension Society {
    static let almanacCap = 120

    /// Called by `step` when a day ends.
    static func writeAlmanac(_ t: inout Town) {
        let since = t.tick - 20
        let crimes = t.ledger.prefix(80).filter { $0.tick > since && ["steal", "heist", "caught"].contains($0.kind) }.count
        let rich = t.beings.max { $0.wallet < $1.wallet }
        let snap = DaySnap(day: t.day - 1, wealth: t.beings.reduce(0) { $0 + $1.wallet }, treasury: t.treasury,
                           prices: t.priceIndex, jailed: t.beings.filter { $0.isJailed(at: t.tick) }.count,
                           crimes: crimes, richest: rich.map { "\($0.face) \($0.name)" } ?? "")
        var h = t.history ?? []
        h.append(snap)
        if h.count > almanacCap { h.removeFirst(h.count - almanacCap) }
        t.history = h
    }
}
