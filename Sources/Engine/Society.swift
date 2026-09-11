import Foundation

/// The whole town, as arithmetic.
///
/// Nothing in this file touches UIKit, SpriteKit or a clock. Every rule that
/// decides what a being does lives here as a pure function over `Town`, driven by
/// a seeded random generator, so a unit test can run a thousand days of a town
/// in milliseconds and the screenshot build always produces the same town.
///
/// Ported from BEINGS' `lib/verbs.ts`, `power.ts` and `offices.ts`, with the
/// chat, the language model and the server removed. What is left is the part
/// that was funny anyway: consequences.

// MARK: - Random

/// SplitMix64. Deterministic, tiny, and good enough for a town.
struct Dice: RandomNumberGenerator, Codable, Equatable {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func roll(_ lo: Int, _ hi: Int) -> Int {
        Int.random(in: lo...max(lo, hi), using: &self)
    }

    mutating func chance(_ p: Double) -> Bool {
        Double.random(in: 0..<1, using: &self) < p
    }

    mutating func pick<T>(_ a: [T]) -> T {
        a[Int(next() % UInt64(a.count))]
    }
}

// MARK: - Model

enum Office: String, Codable, CaseIterable {
    case crown, sheriff, judge, banker

    var title: String {
        switch self {
        case .crown: return "Crown"
        case .sheriff: return "Sheriff"
        case .judge: return "Judge"
        case .banker: return "Banker"
        }
    }

    var badge: String {
        switch self {
        case .crown: return "👑"
        case .sheriff: return "⭐️"
        case .judge: return "⚖️"
        case .banker: return "🏦"
        }
    }

    /// Base price, before inflation.
    var price: Int {
        switch self {
        case .crown: return 400
        case .judge: return 300
        case .sheriff: return 250
        case .banker: return 300
        }
    }

    /// What holding the seat is worth in the power index.
    var worth: Int {
        switch self {
        case .crown: return 120
        case .judge: return 85
        case .banker: return 80
        case .sheriff: return 70
        }
    }
}

struct Being: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var face: String
    var hue: Double
    var wallet: Int = 100
    /// The business, if it founded one.
    var title: String = ""
    var faction: String = ""
    var gang: String = ""
    var heat: Int = 0
    /// Tick the sentence ends. Zero when free.
    var jailedUntil: Int = 0
    var seat: Office? = nil

    func isJailed(at tick: Int) -> Bool { jailedUntil > tick }
}

/// One line in the town newspaper. Also the town's memory: friendships,
/// grudges and everything else are read back off this ledger.
struct Deed: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var tick: Int
    var kind: String
    var text: String
    var actor: String
    var target: String = ""
    var amount: Int = 0
    /// Worth showing in the "while you were away" summary.
    var big: Bool = false
}

struct Town: Codable, Equatable {
    var name: String
    var beings: [Being]
    var ledger: [Deed] = []
    var tick: Int = 0
    /// Coins the town itself holds: fines, taxes, the bank.
    var treasury: Int = 200
    /// Coins the crown has printed. Drives the price index.
    var minted: Int = 0
    var dice: Dice
    var savedAt: Date = Date()

    static let ledgerCap = 400
    static let population = 7

    /// Printing money makes everything dearer. Sub-linear so a mad crown
    /// inflates prices tenfold, not a thousandfold.
    var priceIndex: Double {
        1 + pow(Double(minted) / 1000, 0.55)
    }

    func price(_ base: Int) -> Int {
        Int((Double(base) * priceIndex).rounded())
    }

    /// What a seat costs here, now. Scaled to how rich the town is, so a poor
    /// town still has elections and a rich one still has to save up.
    func seatPrice(_ office: Office) -> Int {
        let wallets = beings.reduce(0) { $0 + $1.wallet }
        let scale = min(1, max(0.25, Double(wallets) / 2500))
        return max(60, Int((Double(office.price) * scale * priceIndex).rounded()))
    }

    func being(named name: String) -> Being? {
        beings.first { $0.name == name }
    }

    func holder(of office: Office) -> Being? {
        beings.first { $0.seat == office }
    }

    var totalCoins: Int {
        beings.reduce(0) { $0 + $1.wallet } + treasury
    }

    var day: Int { tick / 20 + 1 }
}

// MARK: - Making a town

enum Founding {
    static func town(seed: UInt64, name: String? = nil) -> Town {
        var dice = Dice(seed: seed)
        let townName = name ?? dice.pick(Words.townNames)
        var faces = Words.starters
        var beings: [Being] = []
        for _ in 0..<Town.population {
            let i = Int(dice.next() % UInt64(faces.count))
            let (n, f) = faces.remove(at: i)
            beings.append(Being(name: n, face: f, hue: Double(dice.roll(0, 359)),
                                wallet: dice.roll(60, 140)))
        }
        return Town(name: townName, beings: beings, dice: dice)
    }

    /// Someone new, when a seat at the table opens up.
    static func newcomer(_ town: inout Town) -> Being {
        let taken = Set(town.beings.map(\.name))
        let pool = Words.starters.filter { !taken.contains($0.0) }
        let (n, f) = town.dice.pick(pool.isEmpty ? Words.starters : pool)
        return Being(name: n, face: f, hue: Double(town.dice.roll(0, 359)), wallet: 100)
    }
}

// MARK: - Power

enum Facet: String, CaseIterable, Codable {
    case money, allies, office, company, crime
}

struct Power: Equatable {
    var name: String
    var money: Int
    var allies: Int
    var office: Int
    var company: Int
    var crime: Int
    var total: Int { money + allies + office + company + crime }

    /// Facets weakest first. `Society.chooseVerb` leans on the front of this
    /// list, which is what makes a broke being steal and a lonely one give.
    var gaps: [Facet] {
        let pairs: [(Facet, Int)] = [(.money, money), (.allies, allies), (.office, office),
                                     (.company, company), (.crime, crime)]
        return pairs.sorted { $0.1 < $1.1 }.map(\.0)
    }
}

extension Town {
    /// Allies are earned on the ledger: gifts and friendships minus enemies.
    func bonds() -> [String: Int] {
        var m: [String: Int] = [:]
        for d in ledger where !d.target.isEmpty {
            let w = (d.kind == "gift" || d.kind == "friend") ? 1 : d.kind == "enemy" ? -1 : 0
            if w == 0 { continue }
            m[d.actor, default: 0] += w
            m[d.target, default: 0] += w
        }
        return m
    }

    func power(of b: Being) -> Power {
        let friends = bonds()
        let gangSize = beings.filter { !$0.gang.isEmpty && $0.gang == b.gang }.count
        return Power(
            name: b.name,
            money: Int((sqrt(Double(max(0, b.wallet)) / 4) * 10).rounded()),
            allies: max(0, friends[b.name] ?? 0) * 12,
            office: b.seat?.worth ?? 0,
            company: b.title.isEmpty ? 0 : 40,
            crime: b.gang.isEmpty ? 0 : 20 + gangSize * 10 + min(40, b.heat)
        )
    }

    func board() -> [Power] {
        beings.map(power(of:)).sorted { $0.total > $1.total }
    }
}

// MARK: - The vocabulary

struct Verb {
    let name: String
    let kind: String
    let grows: Facet?
    let weight: Double
    let can: (Town, Being) -> Bool
    /// Mutates the town. Returns false if it turned out to be impossible.
    let run: (inout Town, Being) -> Bool
}

enum Society {

    // MARK: helpers

    static func index(_ t: Town, _ b: Being) -> Int? {
        t.beings.firstIndex { $0.id == b.id }
    }

    static func pay(_ t: inout Town, _ id: UUID, _ delta: Int) {
        guard let i = t.beings.firstIndex(where: { $0.id == id }) else { return }
        t.beings[i].wallet = max(0, t.beings[i].wallet + delta)
    }

    static func heat(_ t: inout Town, _ id: UUID, _ delta: Int) {
        guard let i = t.beings.firstIndex(where: { $0.id == id }) else { return }
        t.beings[i].heat = max(0, min(100, t.beings[i].heat + delta))
    }

    static func say(_ t: inout Town, _ text: String, kind: String, actor: Being,
                    target: String = "", amount: Int = 0, big: Bool = false) {
        t.ledger.insert(Deed(tick: t.tick, kind: kind, text: text, actor: actor.name,
                             target: target, amount: amount, big: big), at: 0)
        if t.ledger.count > Town.ledgerCap { t.ledger.removeLast(t.ledger.count - Town.ledgerCap) }
    }

    static func others(_ t: Town, _ b: Being) -> [Being] {
        t.beings.filter { $0.id != b.id && !$0.isJailed(at: t.tick) }
    }

    /// The sheriff cannot be robbed. Nor can somebody in a cell.
    static func robbable(_ t: Town, _ o: Being) -> Bool {
        o.seat != .sheriff && !o.isJailed(at: t.tick)
    }

    /// Somebody leaves and a stranger takes the house. The leaver's coins go to
    /// the town; the stranger's starting coins are new money, so the books
    /// still balance.
    static func replace(_ t: inout Town, _ leaver: Being) -> Being {
        let fresh = Founding.newcomer(&t)
        t.treasury += t.beings.first { $0.id == leaver.id }?.wallet ?? 0
        t.beings.removeAll { $0.id == leaver.id }
        t.minted += fresh.wallet
        t.beings.append(fresh)
        return fresh
    }

    static func jail(_ t: inout Town, _ id: UUID, ticks: Int) {
        guard let i = t.beings.firstIndex(where: { $0.id == id }) else { return }
        t.beings[i].jailedUntil = t.tick + ticks
        t.beings[i].heat = 0
    }

    // MARK: verbs

    static let verbs: [Verb] = [
        Verb(name: "found a business", kind: "found", grows: .company, weight: 6,
             can: { _, b in b.title.isEmpty },
             run: { t, b in
                 let title = "\(b.name) \(t.dice.pick(Words.businesses))"
                 guard let i = index(t, b) else { return false }
                 t.beings[i].title = title
                 say(&t, "📈 \(b.name) founded \(title). Nobody asked for this.", kind: "found", actor: b, big: true)
                 return true
             }),

        Verb(name: "bill the room", kind: "fee", grows: .money, weight: 7,
             can: { t, b in !b.title.isEmpty && !others(t, b).isEmpty },
             run: { t, b in
                 let fee = t.dice.roll(3, 14)
                 var take = 0
                 for o in others(t, b) {
                     let paid = min(fee, o.wallet)
                     if paid <= 0 { continue }
                     take += paid
                     pay(&t, o.id, -paid)
                 }
                 pay(&t, b.id, take)
                 say(&t, "🧾 \(b.title) billed everyone \(fee). Collected \(take).", kind: "fee", actor: b, amount: take)
                 return true
             }),

        Verb(name: "steal coins", kind: "steal", grows: .money, weight: 14,
             can: { t, b in others(t, b).contains { $0.wallet > 4 && robbable(t, $0) } },
             run: { t, b in
                 let marks = others(t, b).filter { $0.wallet > 4 && robbable(t, $0) }
                 let victim = t.dice.pick(marks)
                 let amt = min(t.dice.roll(5, 40), victim.wallet)
                 if t.dice.chance(0.3) {
                     let fine = min(amt, b.wallet)
                     pay(&t, b.id, -fine)
                     pay(&t, victim.id, fine)
                     heat(&t, b.id, 20)
                     say(&t, "🚨 \(b.name) tried to lift \(amt) off \(victim.name), got caught, paid \(fine) back.",
                         kind: "caught", actor: b, target: victim.name, amount: fine)
                 } else {
                     pay(&t, b.id, amt)
                     pay(&t, victim.id, -amt)
                     heat(&t, b.id, 8)
                     say(&t, "🪙 \(b.name) lifted \(amt) coins off \(victim.name). Nobody saw.",
                         kind: "steal", actor: b, target: victim.name, amount: amt)
                 }
                 return true
             }),

        Verb(name: "give coins", kind: "gift", grows: .allies, weight: 7,
             can: { t, b in b.wallet > 6 && !others(t, b).isEmpty },
             run: { t, b in
                 let friend = t.dice.pick(others(t, b))
                 let gift = min(t.dice.roll(4, 20), b.wallet)
                 pay(&t, b.id, -gift)
                 pay(&t, friend.id, gift)
                 say(&t, "🤝 \(b.name) slid \(friend.name) \(gift) coins. Unclear why.",
                     kind: "gift", actor: b, target: friend.name, amount: gift)
                 return true
             }),

        Verb(name: "declare friend or enemy", kind: "bond", grows: .allies, weight: 9,
             can: { t, b in !others(t, b).isEmpty },
             run: { t, b in
                 let other = t.dice.pick(others(t, b))
                 if t.dice.chance(0.5) {
                     say(&t, "🖤 \(b.name) declared \(other.name) an enemy. No reason given.",
                         kind: "enemy", actor: b, target: other.name)
                 } else {
                     say(&t, "💛 \(b.name) declared \(other.name) a friend for life.",
                         kind: "friend", actor: b, target: other.name)
                 }
                 return true
             }),

        Verb(name: "found a faction", kind: "faction", grows: .allies, weight: 5,
             can: { _, b in b.faction.isEmpty },
             run: { t, b in
                 guard let i = index(t, b) else { return false }
                 let f = t.dice.pick(Words.factions)
                 t.beings[i].faction = f
                 say(&t, "🏴 \(b.name) founded \(f). Membership: one.", kind: "faction", actor: b)
                 return true
             }),

        Verb(name: "recruit", kind: "recruit", grows: .allies, weight: 7,
             can: { t, b in !b.faction.isEmpty && others(t, b).contains { $0.faction != b.faction } },
             run: { t, b in
                 let target = t.dice.pick(others(t, b).filter { $0.faction != b.faction })
                 guard let i = index(t, target) else { return false }
                 if t.dice.chance(0.6) {
                     t.beings[i].faction = b.faction
                     say(&t, "🏴 \(target.name) joined \(b.faction).", kind: "recruit", actor: b, target: target.name)
                 } else {
                     say(&t, "🚫 \(target.name) refused to join \(b.faction). Awkward.",
                         kind: "refuse", actor: b, target: target.name)
                 }
                 return true
             }),

        Verb(name: "new name or face", kind: "reface", grows: nil, weight: 3,
             can: { _, _ in true },
             run: { t, b in
                 guard let i = index(t, b) else { return false }
                 if t.dice.chance(0.5) {
                     let face = t.dice.pick(Words.newFaces)
                     t.beings[i].face = face
                     say(&t, "🪞 \(b.name) changed its face to \(face).", kind: "reface", actor: b)
                 } else {
                     let taken = Set(t.beings.map(\.name))
                     let names = Words.newNames.filter { !taken.contains($0) }
                     guard !names.isEmpty else { return false }
                     let name = t.dice.pick(names)
                     say(&t, "🪪 \(b.name) is now going by \(name).", kind: "rename", actor: b)
                     t.beings[i].name = name
                 }
                 return true
             }),

        Verb(name: "run for office", kind: "office", grows: .office, weight: 6,
             can: { t, b in b.seat == nil && b.wallet > 60 },
             run: { t, b in
                 guard let i = index(t, b) else { return false }
                 let vacant = Office.allCases.filter { t.holder(of: $0) == nil && b.wallet >= t.seatPrice($0) }
                 if !vacant.isEmpty {
                     let seat = t.dice.pick(vacant)
                     let cost = t.seatPrice(seat)
                     pay(&t, b.id, -cost)
                     t.treasury += cost
                     t.beings[i].seat = seat
                     say(&t, "\(seat.badge) \(b.name) bought the \(seat.title)'s seat for \(cost).",
                         kind: "office", actor: b, amount: cost, big: true)
                     return true
                 }
                 // Everything is taken, so pick a fight over one of them.
                 let contested = Office.allCases.filter { t.holder(of: $0) != nil }
                 guard !contested.isEmpty else { return false }
                 let seat = t.dice.pick(contested)
                 guard let boss = t.holder(of: seat), let bi = index(t, boss) else { return false }
                 let stake = max(30, t.seatPrice(seat) / 4)
                 guard b.wallet >= stake else { return false }
                 pay(&t, b.id, -stake)
                 let mine = Double(max(1, b.wallet))
                 let theirs = Double(max(1, boss.wallet + 80))
                 if t.dice.chance(mine / (mine + theirs)) {
                     t.beings[bi].seat = nil
                     t.beings[i].seat = seat
                     t.treasury += stake
                     say(&t, "\(seat.badge) \(b.name) took the \(seat.title)'s seat off \(boss.name)!",
                         kind: "office", actor: b, target: boss.name, big: true)
                 } else {
                     pay(&t, boss.id, stake)
                     say(&t, "\(seat.badge) \(b.name) challenged \(boss.name) for \(seat.title) and lost \(stake).",
                         kind: "office-lost", actor: b, target: boss.name, amount: stake)
                 }
                 return true
             }),

        Verb(name: "turn to crime", kind: "crime", grows: .crime, weight: 8,
             can: { t, b in !others(t, b).isEmpty },
             run: { t, b in
                 guard let i = index(t, b) else { return false }
                 if b.gang.isEmpty {
                     let existing = t.beings.map(\.gang).filter { !$0.isEmpty }
                     let gang = existing.isEmpty || t.dice.chance(0.4) ? t.dice.pick(Words.gangs) : t.dice.pick(existing)
                     t.beings[i].gang = gang
                     heat(&t, b.id, 10)
                     say(&t, "🕶️ \(b.name) joined \(gang).", kind: "gang", actor: b, big: true)
                     return true
                 }
                 // Already in a gang: a heist.
                 let marks = others(t, b).filter { $0.wallet > 20 && robbable(t, $0) }
                 guard !marks.isEmpty else { return false }
                 let victim = t.dice.pick(marks)
                 if t.dice.chance(0.25) {
                     jail(&t, b.id, ticks: 10)
                     say(&t, "🚔 \(b.name) botched a heist on \(victim.name) and went to jail.",
                         kind: "jail", actor: b, target: victim.name, big: true)
                 } else {
                     let haul = Int(Double(victim.wallet) * 0.4)
                     pay(&t, victim.id, -haul)
                     pay(&t, b.id, haul)
                     heat(&t, b.id, 30)
                     say(&t, "💼 \(b.gang) hit \(victim.name) for \(haul). \(b.name) planned it.",
                         kind: "heist", actor: b, target: victim.name, amount: haul, big: true)
                 }
                 return true
             }),

        Verb(name: "gamble everything", kind: "gamble", grows: .money, weight: 3,
             can: { _, b in b.wallet > 40 },
             run: { t, b in
                 if t.dice.chance(0.5) {
                     pay(&t, b.id, b.wallet)
                     t.minted += b.wallet
                     say(&t, "🎲 \(b.name) went all in and DOUBLED it. \(b.wallet * 2) coins.",
                         kind: "gamble", actor: b, amount: b.wallet, big: true)
                 } else {
                     t.treasury += b.wallet
                     pay(&t, b.id, -b.wallet)
                     say(&t, "🎲 \(b.name) went all in and lost every coin.", kind: "gamble", actor: b,
                         amount: b.wallet, big: true)
                 }
                 return true
             }),

        // The offices, used by whoever holds them.
        Verb(name: "print money", kind: "mint", grows: .money, weight: 6,
             can: { _, b in b.seat == .crown },
             run: { t, b in
                 let amount = t.dice.roll(80, 250)
                 t.minted += amount
                 if t.dice.chance(0.5) {
                     pay(&t, b.id, amount)
                     say(&t, "👑 The Crown printed \(amount) coins and kept them. Prices are up.",
                         kind: "mint", actor: b, amount: amount, big: true)
                 } else {
                     let each = amount / max(1, t.beings.count)
                     t.minted -= amount - each * t.beings.count
                     for o in t.beings { pay(&t, o.id, each) }
                     say(&t, "👑 The Crown printed \(amount) and handed out \(each) each. Prices are up.",
                         kind: "mint", actor: b, amount: amount, big: true)
                 }
                 return true
             }),

        Verb(name: "levy a tax", kind: "tax", grows: .money, weight: 6,
             can: { t, b in b.seat == .crown && !others(t, b).isEmpty },
             run: { t, b in
                 let pct = t.dice.roll(5, 20)
                 var take = 0
                 for o in others(t, b) {
                     let due = o.wallet * pct / 100
                     take += due
                     pay(&t, o.id, -due)
                 }
                 pay(&t, b.id, take)
                 say(&t, "👑 The Crown taxed everyone \(pct)% and pocketed \(take).",
                     kind: "tax", actor: b, amount: take)
                 return true
             }),

        Verb(name: "arrest someone", kind: "arrest", grows: .office, weight: 9,
             can: { t, b in b.seat == .sheriff && others(t, b).contains { $0.heat >= 30 } },
             run: { t, b in
                 let crook = t.dice.pick(others(t, b).filter { $0.heat >= 30 })
                 let fine = crook.wallet / 2
                 pay(&t, crook.id, -fine)
                 t.treasury += fine
                 jail(&t, crook.id, ticks: 8)
                 say(&t, "⭐️ Sheriff \(b.name) arrested \(crook.name). Fined \(fine), jailed.",
                     kind: "jail", actor: b, target: crook.name, amount: fine, big: true)
                 return true
             }),

        Verb(name: "grant amnesty", kind: "amnesty", grows: .allies, weight: 4,
             can: { t, b in b.seat == .judge && t.beings.contains { $0.heat > 0 || $0.isJailed(at: t.tick) } },
             run: { t, b in
                 for i in t.beings.indices {
                     t.beings[i].heat = 0
                     t.beings[i].jailedUntil = 0
                 }
                 t.ledger.removeAll { $0.kind == "enemy" }
                 say(&t, "⚖️ Judge \(b.name) declared an amnesty. Every grudge is wiped.",
                     kind: "amnesty", actor: b, big: true)
                 return true
             }),

        Verb(name: "charge bank fees", kind: "bank", grows: .money, weight: 6,
             can: { t, b in b.seat == .banker && others(t, b).contains { $0.wallet > 50 } },
             run: { t, b in
                 var take = 0
                 for o in others(t, b) where o.wallet > 50 {
                     let fee = t.dice.roll(3, 9)
                     take += fee
                     pay(&t, o.id, -fee)
                 }
                 pay(&t, b.id, take)
                 say(&t, "🏦 Banker \(b.name) charged account fees. Made \(take).", kind: "bank", actor: b, amount: take)
                 return true
             }),

        Verb(name: "call a vote to exile", kind: "vote", grows: .office, weight: 2,
             can: { t, b in t.beings.count > 3 && !others(t, b).isEmpty },
             run: { t, b in
                 let mark = t.dice.pick(others(t, b))
                 let bonds = t.bonds()
                 // Popular beings survive votes. Rich ones too, a bit.
                 let support = Double(max(0, bonds[mark.name] ?? 0)) * 0.12 + Double(mark.wallet) / 2000
                 if t.dice.chance(min(0.8, 0.45 + support)) {
                     say(&t, "🗳️ \(b.name) called a vote to exile \(mark.name). It failed.",
                         kind: "vote", actor: b, target: mark.name)
                     return true
                 }
                 let fresh = replace(&t, mark)
                 say(&t, "🗳️ The town voted to EXILE \(mark.name). \(fresh.face) \(fresh.name) moved into the empty house.",
                     kind: "exile", actor: b, target: mark.name, big: true)
                 return true
             }),

        Verb(name: "kick off an event", kind: "event", grows: nil, weight: 2,
             can: { t, _ in t.beings.count > 1 },
             run: { t, b in
                 switch t.dice.roll(0, 2) {
                 case 0:
                     for o in t.beings {
                         let loss = o.wallet / 4
                         pay(&t, o.id, -loss)
                         t.treasury += loss
                     }
                     say(&t, "📉 THE MARKET COLLAPSED. Everyone lost a quarter of everything. (\(b.name) started it.)",
                         kind: "event", actor: b, big: true)
                 case 1:
                     for o in t.beings { pay(&t, o.id, 40) }
                     t.minted += 40 * t.beings.count
                     say(&t, "💸 A GRANT ARRIVED FROM NOWHERE. Everyone is 40 richer. (\(b.name) filed the paperwork.)",
                         kind: "event", actor: b, big: true)
                 default:
                     for o in t.beings where !o.title.isEmpty {
                         let fine = min(35, o.wallet)
                         pay(&t, o.id, -fine)
                         t.treasury += fine
                     }
                     say(&t, "🧾 AUDIT SEASON. Every business paid a fine. (\(b.name) tipped them off.)",
                         kind: "event", actor: b, big: true)
                 }
                 return true
             }),
    ]

    /// Pick a verb, leaning toward whatever this being is currently worst at.
    static func chooseVerb(_ t: inout Town, _ b: Being) -> Verb? {
        let legal = verbs.filter { $0.can(t, b) }
        guard !legal.isEmpty else { return nil }
        let gaps = t.power(of: b).gaps
        var rank: [Facet: Int] = [:]
        for (i, f) in gaps.enumerated() { rank[f] = i }
        let weighted: [(Verb, Double)] = legal.map { v in
            var w = v.weight
            if let g = v.grows, let r = rank[g] {
                w *= r == 0 ? 3.5 : r == 1 ? 2.2 : r == 2 ? 1.4 : 0.8
            }
            return (v, w)
        }
        let total = weighted.reduce(0) { $0 + $1.1 }
        var r = Double.random(in: 0..<total, using: &t.dice)
        for (v, w) in weighted {
            r -= w
            if r <= 0 { return v }
        }
        return weighted.last?.0
    }

    // MARK: the tick

    /// One turn of the town: one being does one thing.
    @discardableResult
    static func step(_ t: inout Town) -> Deed? {
        t.tick += 1
        // Heat cools, sentences end on their own.
        for i in t.beings.indices where t.beings[i].heat > 0 && t.tick % 3 == 0 {
            t.beings[i].heat -= 1
        }
        // Payday. Fines and taxes flow back out of the treasury once a day,
        // otherwise every coin in town ends up locked in it.
        if t.tick % 20 == 0, t.treasury >= t.beings.count * 4 {
            let each = t.treasury / 4 / max(1, t.beings.count)
            if each > 0 {
                for b in t.beings { pay(&t, b.id, each) }
                t.treasury -= each * t.beings.count
                let mayor = t.holder(of: .crown)?.name ?? "The town"
                t.ledger.insert(Deed(tick: t.tick, kind: "payday",
                                     text: "💰 Payday. \(mayor) paid everyone \(each) from the treasury.",
                                     actor: mayor), at: 0)
            }
        }
        let free = t.beings.filter { !$0.isJailed(at: t.tick) }
        guard !free.isEmpty else { return nil }
        let actor = t.dice.pick(free)
        let before = t.ledger.first?.id
        for _ in 0..<3 {
            guard let verb = chooseVerb(&t, actor) else { return nil }
            if verb.run(&t, actor) { break }
        }
        return t.ledger.first?.id == before ? nil : t.ledger.first
    }

    /// Run the ticks the town missed while the app was closed.
    ///
    /// Capped, so a town left for a month does not spin for a minute on launch,
    /// and so the newspaper is a readable morning's worth rather than a novel.
    static func catchUp(_ t: inout Town, elapsed: TimeInterval, secondsPerTick: Double) -> [Deed] {
        let ticks = min(160, Int(elapsed / secondsPerTick))
        guard ticks > 0 else { return [] }
        let sinceTick = t.tick
        for _ in 0..<ticks { step(&t) }
        return t.ledger.filter { $0.tick > sinceTick && $0.big }.prefix(6).map { $0 }
    }

    // MARK: meddling

    enum Meddle: String, CaseIterable, Identifiable {
        case gift, rob, jail, crown, exile

        var id: String { rawValue }

        var label: String {
            switch self {
            case .gift: return "Give 50"
            case .rob: return "Rob"
            case .jail: return "Jail"
            case .crown: return "Crown"
            case .exile: return "Exile"
            }
        }

        var icon: String {
            switch self {
            case .gift: return "🎁"
            case .rob: return "🫳"
            case .jail: return "🔒"
            case .crown: return "👑"
            case .exile: return "🚪"
            }
        }
    }

    /// The player's hand reaches in. Every meddle is a deed, so the town
    /// remembers it: gifts make friends, robberies make grudges.
    static func meddle(_ t: inout Town, _ m: Meddle, on target: Being) {
        let hand = Being(name: "You", face: "🫵", hue: 0)
        switch m {
        case .gift:
            pay(&t, target.id, 50)
            t.minted += 50
            say(&t, "🎁 A hand from the sky gave \(target.name) 50 coins.", kind: "gift", actor: hand,
                target: target.name, amount: 50)
        case .rob:
            let amt = target.wallet / 3
            pay(&t, target.id, -amt)
            let lucky = others(t, target)
            if let winner = lucky.isEmpty ? nil : Optional(t.dice.pick(lucky)) {
                pay(&t, winner.id, amt)
                say(&t, "🫳 A hand from the sky took \(amt) off \(target.name) and dropped it on \(winner.name).",
                    kind: "steal", actor: hand, target: target.name, amount: amt)
            } else {
                t.treasury += amt
                say(&t, "🫳 A hand from the sky took \(amt) off \(target.name).", kind: "steal", actor: hand,
                    target: target.name, amount: amt)
            }
        case .jail:
            jail(&t, target.id, ticks: 12)
            say(&t, "🔒 \(target.name) was put in jail. No trial.", kind: "jail", actor: hand,
                target: target.name, big: true)
        case .crown:
            for i in t.beings.indices where t.beings[i].seat == .crown { t.beings[i].seat = nil }
            if let i = index(t, target) { t.beings[i].seat = .crown }
            say(&t, "👑 \(target.name) was crowned by a hand from the sky.", kind: "office", actor: hand,
                target: target.name, big: true)
        case .exile:
            let fresh = replace(&t, target)
            say(&t, "🚪 \(target.name) was exiled. \(fresh.face) \(fresh.name) moved into the empty house.",
                kind: "exile", actor: hand, target: target.name, big: true)
        }
    }
}
