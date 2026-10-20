import Foundation
import SwiftUI

/// What the app and its widget share: the town file and a few flags, in the app
/// group container so the widget can read the same town the app plays.
enum Shared {
    static let group = "group.com.mattbusel.pocketbeings"
    static let defaults = UserDefaults(suiteName: group) ?? .standard

    static var container: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var townFile: URL { container.appendingPathComponent("town.json") }

    /// 1.1 kept the town in the app's own Documents, where the widget cannot see it.
    /// Copied (not moved) once, so the old file is still there if anything goes wrong.
    static func migrate() {
        let old = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("town.json")
        let fm = FileManager.default
        guard townFile != old, !fm.fileExists(atPath: townFile.path), fm.fileExists(atPath: old.path) else { return }
        try? fm.copyItem(at: old, to: townFile)
    }

    /// The Big Hand, mirrored by the app so the widget knows.
    static var bigHand: Bool {
        get { defaults.bool(forKey: "bighand") }
        set { defaults.set(newValue, forKey: "bighand") }
    }

    /// The Town Club, mirrored by the app so the widget knows (1.3).
    static var club: Bool {
        get { defaults.bool(forKey: "club") }
        set { defaults.set(newValue, forKey: "club") }
    }

    /// Either one unlocks the Town Hall widget.
    static var paid: Bool { bigHand || club }

    static var yard: String {
        get { defaults.string(forKey: "yard") ?? "classic" }
        set { defaults.set(newValue, forKey: "yard") }
    }

    static func loadTown() -> Town? {
        guard let data = try? Data(contentsOf: townFile) else { return nil }
        return try? JSONDecoder().decode(Town.self, from: data)
    }
}

/// A yard: the sky, the lawn and what grows on it. Classic is free; the rest are
/// 99-cent buys, each with a matching app icon.
struct YardTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let blurb: String
    let sky: Color
    let grass: Color
    let grassDark: Color
    let flowers: [String]
    /// Light names on a dark lawn.
    var dark = false
    var icon: String? { id == "classic" ? nil : "AppIcon-" + name.replacingOccurrences(of: " ", with: "") }

    static func rgb(_ h: UInt32) -> Color {
        Color(red: Double((h >> 16) & 0xFF) / 255, green: Double((h >> 8) & 0xFF) / 255, blue: Double(h & 0xFF) / 255)
    }

    static let all: [YardTheme] = [
        YardTheme(id: "classic", name: "Classic", blurb: "Mown stripes. The original lawn.",
                  sky: rgb(0x9ED9FA), grass: rgb(0x7DCC6B), grassDark: rgb(0x66B359), flowers: ["🌼", "🌸", "🍄", "🌷", "🪨"]),
        YardTheme(id: "snow", name: "Snow Day", blurb: "School is cancelled. Crime is not.",
                  sky: rgb(0xC9DCEB), grass: rgb(0xF2F6FA), grassDark: rgb(0xDDE7F1), flowers: ["⛄️", "❄️", "🌲", "🧤", "🛷"]),
        YardTheme(id: "night", name: "Night Market", blurb: "Lanterns, noodles, shady deals.",
                  sky: rgb(0x1B2550), grass: rgb(0x2E4D3A), grassDark: rgb(0x26402F), flowers: ["🏮", "🍜", "🕯️", "🌙", "🎐"], dark: true),
        YardTheme(id: "beach", name: "Beach Town", blurb: "Sand in everything, especially the treasury.",
                  sky: rgb(0x8EE3F0), grass: rgb(0xF3DDA2), grassDark: rgb(0xE9CF8C), flowers: ["🐚", "🌴", "🦀", "⛱️", "🪸"]),
        YardTheme(id: "mars", name: "Mars Colony", blurb: "Seven settlers, one oxygen budget.",
                  sky: rgb(0xF0AE86), grass: rgb(0xC9673F), grassDark: rgb(0xB65833), flowers: ["🪨", "🛸", "👽", "🌋", "🛰️"], dark: true),
    ]

    /// Read once and kept: the yard asks for these colours every frame.
    static var current: YardTheme = byID(Shared.yard)
    static func byID(_ id: String) -> YardTheme { all.first { $0.id == id } ?? all[0] }
    static func reload() { current = byID(Shared.yard) }
    static func apply(_ id: String) { Shared.yard = id; current = byID(id) }
}
