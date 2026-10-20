import Foundation

/// Town Club: the town file and the player's stash, copied to the player's own iCloud
/// key-value store. Nothing goes anywhere else. Restoring is always allowed, member or
/// not, so a backup is never held hostage.
enum Backup {
    private static var store: NSUbiquitousKeyValueStore { .default }
    private static let key = "pb.backup"
    private static let whenKey = "pb.backup.at"

    static var last: Date? {
        store.synchronize()
        let t = store.double(forKey: whenKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// Copy everything now. Called when the app goes to the background, members only.
    static func save() {
        guard let town = try? Data(contentsOf: Shared.townFile) else { return }
        var defaults: [String: Any] = [:]
        for (k, v) in UserDefaults.standard.dictionaryRepresentation() where k.hasPrefix("pb.") && k != "pb.club" {
            defaults[k] = v
        }
        let payload: [String: Any] = ["town": town, "defaults": defaults, "yard": Shared.yard]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0),
              data.count < 900_000 else { return }
        store.set(data, forKey: key)
        store.set(Date().timeIntervalSince1970, forKey: whenKey)
        store.synchronize()
    }

    /// Put the backup back on this phone. True when there was one.
    @discardableResult
    static func restore() -> Bool {
        store.synchronize()
        guard let data = store.data(forKey: key),
              let payload = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let town = payload["town"] as? Data else { return false }
        try? town.write(to: Shared.townFile, options: .atomic)
        if let defaults = payload["defaults"] as? [String: Any] {
            for (k, v) in defaults { UserDefaults.standard.set(v, forKey: k) }
        }
        if let y = payload["yard"] as? String { YardTheme.apply(y) }
        return true
    }
}
