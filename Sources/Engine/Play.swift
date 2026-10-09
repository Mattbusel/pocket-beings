import Foundation

// The 1.2 layer on top of the society: laws the player can pass, miracles the
// player can drop on the town, a wish for every day, the hall of records, and
// strangers the player can invite. Pure functions over `Town`, like the rest of
// the engine, so the widget can run them too and the tests can run them fast.

// MARK: - Laws

enum Law: String, CaseIterable, Codable, Identifiable {
    case noGambling, toughOnCrime, freeMarket, termLimits, basicCoin, martialLaw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noGambling: return "No Gambling"
        case .toughOnCrime: return "Tough on Crime"
        case .freeMarket: return "Free Market"
        case .termLimits: return "Term Limits"
        case .basicCoin: return "Basic Coin"
        case .martialLaw: return "Martial Law"
        }
    }

    var icon: String {
        switch self {
        case .noGambling: return "🚫🎲"
        case .toughOnCrime: return "🚔"
        case .freeMarket: return "🧾"
        case .termLimits: return "⏳"
        case .basicCoin: return "🪙"
        case .martialLaw: return "🪖"
        }
    }

    var blurb: String {
        switch self {
        case .noGambling: return "Nobody may go all in. The dice are confiscated."
        case .toughOnCrime: return "Thieves get caught more, and the Sheriff arrests sooner."
        case .freeMarket: return "Businesses bill the room twice as often."
        case .termLimits: return "Every three days, every seat is emptied."
        case .basicCoin: return "Payday hands out twice as much from the treasury."
        case .martialLaw: return "Crime almost stops. Arrests double. Nobody is happy."
        }
    }

    static let maxActive = 3
}

extension Town {
    func has(_ law: Law) -> Bool { (laws ?? []).contains(law.rawValue) }
    var activeLaws: [Law] { (laws ?? []).compactMap(Law.init(rawValue:)) }
}

// MARK: - Miracles

/// One-shot acts of the sky. The player holds charges and spends one each.
enum Miracle: String, CaseIterable, Identifiable {
    case coup, election, frogs, goldRush, festival, twister, haunting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coup: return "Coup"
        case .election: return "Snap Election"
        case .frogs: return "Plague of Frogs"
        case .goldRush: return "Gold Rush"
        case .festival: return "Festival"
        case .twister: return "Twister"
        case .haunting: return "Haunting"
        }
    }

    var icon: String {
        switch self {
        case .coup: return "🌋"
        case .election: return "🗳️"
        case .frogs: return "🐸"
        case .goldRush: return "⛏️"
        case .festival: return "🎪"
        case .twister: return "🌪️"
        case .haunting: return "👻"
        }
    }

    var blurb: String {
        switch self {
        case .coup: return "Every seat is emptied at once. Grab what you can."
        case .election: return "The richest beings buy every seat, right now."
        case .frogs: return "Frogs everywhere. Everyone loses a tenth, every business shuts."
        case .goldRush: return "Three lucky beings strike gold."
        case .festival: return "Everyone makes a friend. Grudges and heat melt away."
        case .twister: return "Every wallet is picked up and dropped on someone else."
        case .haunting: return "Every face in town changes overnight."
        }
    }
}

extension Society {
    static func miracle(_ t: inout Town, _ m: Miracle) {
        let sky = Being(name: "You", face: "✨", hue: 0)
        switch m {
        case .coup:
            for i in t.beings.indices { t.beings[i].seat = nil }
            say(&t, "🌋 A COUP. Every seat in town is suddenly empty.", kind: "miracle", actor: sky, big: true)
        case .election:
            for i in t.beings.indices { t.beings[i].seat = nil }
            let rich = t.beings.filter { !$0.isJailed(at: t.tick) }.sorted { $0.wallet > $1.wallet }
            var names: [String] = []
            for (office, b) in zip(Office.allCases, rich) {
                let cost = min(b.wallet, t.seatPrice(office))
                pay(&t, b.id, -cost)
                t.treasury += cost
                if let i = index(t, b) { t.beings[i].seat = office }
                names.append("\(office.badge) \(b.name)")
            }
            say(&t, "🗳️ SNAP ELECTION. " + names.joined(separator: ", ") + ".", kind: "miracle", actor: sky, big: true)
        case .frogs:
            for o in t.beings {
                let loss = o.wallet / 10
                pay(&t, o.id, -loss)
                t.treasury += loss
            }
            for i in t.beings.indices { t.beings[i].title = "" }
            say(&t, "🐸 A PLAGUE OF FROGS. Every business shut its doors.", kind: "miracle", actor: sky, big: true)
        case .goldRush:
            var lucky = t.beings.filter { !$0.isJailed(at: t.tick) }
            var names: [String] = []
            for _ in 0..<min(3, lucky.count) {
                let b = t.dice.pick(lucky)
                lucky.removeAll { $0.id == b.id }
                let find = t.dice.roll(60, 120)
                pay(&t, b.id, find)
                t.minted += find
                names.append("\(b.name) (\(find))")
            }
            say(&t, "⛏️ GOLD RUSH. Struck it rich: " + names.joined(separator: ", ") + ".", kind: "miracle", actor: sky, big: true)
        case .festival:
            let all = t.beings
            for b in all where all.count > 1 {
                let other = t.dice.pick(all.filter { $0.id != b.id })
                say(&t, "🎪 \(b.name) and \(other.name) shared a funnel cake.", kind: "friend", actor: b, target: other.name)
            }
            for i in t.beings.indices { t.beings[i].heat = 0 }
            say(&t, "🎪 A FESTIVAL. Everyone made a friend and forgot their crimes.", kind: "miracle", actor: sky, big: true)
        case .twister:
            var wallets = t.beings.map(\.wallet)
            wallets.shuffle(using: &t.dice)
            for i in t.beings.indices { t.beings[i].wallet = wallets[i] }
            say(&t, "🌪️ A TWISTER picked up every wallet and dropped it on someone else.", kind: "miracle", actor: sky, big: true)
        case .haunting:
            for i in t.beings.indices { t.beings[i].face = t.dice.pick(Words.newFaces) }
            say(&t, "👻 A HAUNTING. Everyone woke up with a different face.", kind: "miracle", actor: sky, big: true)
        }
        if let d = t.ledger.first { noteRecord(&t, d) }
    }

    /// A stranger the player named moves in. Their starting coins are new money.
    static func invite(_ t: inout Town, name: String, face: String, replacing: Being?) -> Being {
        var fresh = Being(name: name, face: face, hue: Double(t.dice.roll(0, 359)), wallet: 100)
        fresh.invited = true
        if let leaver = replacing {
            t.treasury += t.beings.first { $0.id == leaver.id }?.wallet ?? 0
            t.beings.removeAll { $0.id == leaver.id }
            say(&t, "🎟️ \(leaver.name) packed up. \(face) \(name) moved in at your invitation.", kind: "invite",
                actor: Being(name: "You", face: "🎟️", hue: 0), target: leaver.name, big: true)
        } else {
            say(&t, "🎟️ \(face) \(name) moved to town at your invitation. Nobody knows them yet.", kind: "invite",
                actor: Being(name: "You", face: "🎟️", hue: 0), big: true)
        }
        t.minted += fresh.wallet
        t.beings.append(fresh)
        return fresh
    }

    static let maxPopulation = 10
}

// MARK: - Records

/// The hall of records: the town's all-time bests, kept as the town runs,
/// because the newspaper only remembers the last 400 lines.
struct Records: Codable, Equatable {
    var richest: Int = 0
    var richestName = ""
    var richestDay = 0
    var biggestHeist = 0
    var heistName = ""
    var arrests = 0
    var exiles = 0
    var coronations = 0
    var gamblesWon = 0
    var gamblesLost = 0
    var businesses = 0
    var miracles = 0
    var crimes: [String: Int] = [:]
    var crowns: [String: Int] = [:]

    var mostWanted: (String, Int)? { crimes.max { $0.value < $1.value }.map { ($0.key, $0.value) } }
    var mostCrowned: (String, Int)? { crowns.max { $0.value < $1.value }.map { ($0.key, $0.value) } }

    mutating func note(_ d: Deed, town: Town) {
        switch d.kind {
        case "heist":
            if d.amount > biggestHeist { biggestHeist = d.amount; heistName = d.actor }
            crimes[d.actor, default: 0] += 1
        case "steal", "caught":
            if d.actor != "You" { crimes[d.actor, default: 0] += 1 }
        case "jail": arrests += 1
        case "exile": exiles += 1
        case "found": businesses += 1
        case "miracle": miracles += 1
        case "office":
            if d.text.contains("👑") {
                coronations += 1
                let who = d.actor == "You" ? d.target : d.actor
                if !who.isEmpty { crowns[who, default: 0] += 1 }
            }
        case "gamble":
            if d.text.contains("DOUBLED") { gamblesWon += 1 } else { gamblesLost += 1 }
        default: break
        }
        if let top = town.beings.max(by: { $0.wallet < $1.wallet }), top.wallet > richest {
            richest = top.wallet; richestName = top.name; richestDay = town.day
        }
    }
}

// MARK: - Wishes

/// One wish a day: something to make happen in the town. Usually takes a few
/// meddles and some luck; never doable with one free tap.
struct Wish: Codable, Equatable {
    var day: String
    var kind: String
    var target: String = ""
    var goal: Double = 0
    var text: String
    var done = false
}

enum Wishes {
    static let kinds = ["richest", "judge", "banker", "gang", "business", "broke", "prices", "faction3", "jailed2", "treasury"]

    /// The same day and town give the same wish.
    static func make(day: String, town: Town) -> Wish {
        var seed: UInt64 = 1469598103934665603
        for b in (day + town.name).utf8 { seed = (seed ^ UInt64(b)) &* 1099511628211 }
        var dice = Dice(seed: seed)
        for _ in 0..<12 {
            let kind = dice.pick(kinds)
            let free = town.beings.filter { !$0.isJailed(at: town.tick) }
            guard let b = free.isEmpty ? nil : Optional(dice.pick(free)) else { break }
            var w: Wish
            switch kind {
            case "richest": w = Wish(day: day, kind: kind, target: b.name, text: "Make \(b.face) \(b.name) the richest being in town.")
            case "judge": w = Wish(day: day, kind: kind, target: b.name, text: "Get \(b.face) \(b.name) the Judge's seat.")
            case "banker": w = Wish(day: day, kind: kind, target: b.name, text: "Get \(b.face) \(b.name) the Banker's seat.")
            case "gang": w = Wish(day: day, kind: kind, target: b.name, text: "Get \(b.face) \(b.name) into a gang.")
            case "business": w = Wish(day: day, kind: kind, target: b.name, text: "Get \(b.face) \(b.name) to found a business.")
            case "broke": w = Wish(day: day, kind: kind, target: b.name, text: "Leave \(b.face) \(b.name) with fewer than 5 coins.")
            case "prices":
                let goal = (town.priceIndex + 0.4).rounded(toPlaces: 1)
                w = Wish(day: day, kind: kind, goal: goal, text: "Push prices past ×\(String(format: "%.1f", goal)).")
            case "faction3": w = Wish(day: day, kind: kind, text: "Get three beings into the same faction.")
            case "jailed2": w = Wish(day: day, kind: kind, text: "Have two beings in jail at the same time.")
            default:
                let goal = Double(town.treasury + 300)
                w = Wish(day: day, kind: "treasury", goal: goal, text: "Fill the treasury past \(Int(goal)) coins.")
            }
            if !check(w, town: town) { return w }
        }
        return Wish(day: day, kind: "jailed2", text: "Have two beings in jail at the same time.")
    }

    static func check(_ w: Wish, town: Town) -> Bool {
        let b = town.being(named: w.target)
        switch w.kind {
        case "richest": return b != nil && town.beings.max { $0.wallet < $1.wallet }?.name == w.target
        case "judge": return b?.seat == .judge
        case "banker": return b?.seat == .banker
        case "gang": return !(b?.gang.isEmpty ?? true)
        case "business": return !(b?.title.isEmpty ?? true)
        case "broke": return (b?.wallet ?? 99) < 5
        case "prices": return town.priceIndex >= w.goal
        case "faction3":
            let counts = Dictionary(grouping: town.beings.filter { !$0.faction.isEmpty }, by: \.faction).mapValues(\.count)
            return counts.values.contains { $0 >= 3 }
        case "jailed2": return town.beings.filter { $0.isJailed(at: town.tick) }.count >= 2
        case "treasury": return Double(town.treasury) >= w.goal
        default: return false
        }
    }

    /// How a wish is going, as a short line for the wish window.
    static func progress(_ w: Wish, town: Town) -> String {
        let b = town.being(named: w.target)
        switch w.kind {
        case "richest":
            let top = town.beings.max { $0.wallet < $1.wallet }
            return "\(w.target): \(b?.wallet ?? 0) · richest: \(top?.name ?? "?") \(top?.wallet ?? 0)"
        case "broke": return "\(w.target) has \(b?.wallet ?? 0) coins"
        case "prices": return String(format: "Prices now ×%.2f", town.priceIndex)
        case "treasury": return "Treasury: \(town.treasury)"
        case "jailed2": return "In jail: \(town.beings.filter { $0.isJailed(at: town.tick) }.count)"
        case "faction3":
            let best = Dictionary(grouping: town.beings.filter { !$0.faction.isEmpty }, by: \.faction).mapValues(\.count).values.max() ?? 0
            return "Biggest faction: \(best)"
        default:
            if b == nil { return "\(w.target) has left town. Tomorrow's wish will be kinder." }
            return check(w, town: town) ? "Done" : "Not yet"
        }
    }
}

extension Double {
    func rounded(toPlaces p: Int) -> Double {
        let m = pow(10, Double(p)); return (self * m).rounded() / m
    }
}
