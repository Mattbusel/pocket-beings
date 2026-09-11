import Foundation

/// Every word the town can use. Nothing here refers to a real person, place,
/// company or event.
enum Words {
    /// The starter cast: (name, face). A town takes seven at random.
    static let starters: [(String, String)] = [
        ("Braxton", "📈"), ("Sir Aldric", "🗡️"), ("Redacted", "🕵️"), ("Chad Vantage", "🕴️"),
        ("Dr. Lumen", "🛋️"), ("Malvora", "😈"), ("Big Mood", "🎉"), ("Snik", "👺"),
        ("Nan", "🧶"), ("The Intern", "📎"), ("Prophet Dave", "🔮"), ("The Auditor", "🧾"),
        ("Gary", "🦞"), ("Cheryl", "🪩"), ("Doug", "🐛"), ("Mitzi", "🎺"),
        ("Barnaby", "🧻"), ("Trish", "🍖"), ("Kev", "🧄"), ("Lorraine", "🦷"),
        ("Rutger", "🛼"), ("Bev", "🪆"), ("Clint", "🐌"), ("Donna", "🎈"),
    ]

    static let newNames = [
        "Reginald", "Bug", "Mother", "The Management", "Kevin II", "Anonymous",
        "Your Honour", "Big Steve", "The Widow", "404", "Chairman", "Hal", "Sheila", "Marv",
    ]

    static let newFaces = ["🫥", "🧿", "🦴", "🕯️", "🪬", "🧊", "🐀", "👁️", "🎭", "🪦", "🫧", "🧱", "🦩", "🪱"]

    static let businesses = [
        "Consulting", "Holdings", "Logistics", "& Sons", "Solutions", "Ventures", "Salvage",
        "Acquisitions", "Wellness", "Security", "Notary Services", "Reclamation",
    ]

    static let factions = [
        "the Committee", "the Old Guard", "the Congregation", "the Union", "the Cousins",
        "the Neighbourhood Watch", "the Board", "the Faithful", "the Book Club",
    ]

    static let gangs = [
        "the Syndicate", "the Cartel", "the Provisional Wing", "the Night Crew",
        "the Laundry", "the Bin Men",
    ]

    static let townNames = [
        "Little Pudding", "Grudge Hollow", "Ledgerton", "Upper Fibbing", "Coinsworth",
        "Muddle-on-Sea", "Petty Cross", "Fenwick Bottom", "Squabble Green", "Nether Whinge",
    ]

    /// What a being mutters over its head while doing something. Short, because
    /// a speech bubble in a yard is read in half a second.
    static func bark(for kind: String, _ dice: inout Dice) -> String {
        let pool: [String]
        switch kind {
        case "steal", "heist": pool = ["mine now", "shh", "finders keepers", "oops"]
        case "caught": pool = ["it wasn't me", "ok ok", "unfair"]
        case "gift": pool = ["for you", "no reason", "take it"]
        case "friend": pool = ["best friends", "love this guy", "you get me"]
        case "enemy": pool = ["hate that guy", "never", "watch it"]
        case "found", "fee", "bank": pool = ["business!", "invoice sent", "synergy", "pay up"]
        case "office": pool = ["I'm in charge", "bow", "finally"]
        case "office-lost": pool = ["rigged", "next time", "ugh"]
        case "mint": pool = ["brrr", "more money", "problem solved"]
        case "tax": pool = ["pay up", "for the town", "thanks"]
        case "jail": pool = ["justice", "gotcha", "law and order"]
        case "gamble": pool = ["all in", "let's go", "no regrets"]
        case "gang", "crime": pool = ["say nothing", "family", "business"]
        case "faction", "recruit": pool = ["join us", "we're growing", "membership"]
        case "amnesty": pool = ["clean slate", "forgiven", "all good"]
        case "exile", "vote": pool = ["bye", "democracy", "sorry"]
        case "reface", "rename": pool = ["new me", "who?", "reinvented"]
        default: pool = ["hm", "!", "anyway", "…"]
        }
        return dice.pick(pool)
    }
}
