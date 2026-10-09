import StoreKit
import SwiftUI

/// The 99-cent corner, separate from The Big Hand so its grandfathering is untouched.
/// Miracle Jar and Invitations are consumables you can buy again and again; the yards
/// are one-time, each with its own app icon. No randomised rewards: you get exactly
/// what the button says.
@MainActor
final class Extras: ObservableObject {
    static let miraclesID = "com.mattbusel.pocketbeings.miracles5"
    static let invitesID = "com.mattbusel.pocketbeings.invites3"
    static func yardID(_ id: String) -> String { "com.mattbusel.pocketbeings.yard." + id }
    static var allIDs: [String] { [miraclesID, invitesID] + YardTheme.all.filter { $0.id != "classic" }.map { yardID($0.id) } }

    @Published private(set) var owned: Set<String> = []
    @Published private(set) var products: [String: Product] = [:]
    @Published var busy: String?
    @Published var message: String?

    /// Hands each cleared consumable to the player.
    var onConsumable: ((String) -> Void)?
    private var updates: Task<Void, Never>?
    private let demo: Bool

    init() {
        let args = ProcessInfo.processInfo.arguments
        demo = args.contains("-screenshots") || args.contains("-demoAutoplay") || args.contains("-FASTLANE_SNAPSHOT")
        if demo {
            owned = args.contains("-ownYards") ? Set(Self.allIDs) : [Self.yardID("snow")]
            return
        }
        owned = Set(UserDefaults.standard.stringArray(forKey: "pb.owned") ?? [])
    }

    func start() {
        guard !demo, updates == nil else { return }
        updates = Task { [weak self] in
            for await r in Transaction.updates {
                guard let self else { return }
                if case .verified(let t) = r { self.credit(t); await t.finish() }
                await self.refresh()
            }
        }
        Task {
            await load()
            await refresh()
            for await r in Transaction.unfinished {
                if case .verified(let t) = r { credit(t); await t.finish() }
            }
        }
    }

    func load() async {
        guard !demo, products.count < Self.allIDs.count else { return }
        if let ps = try? await Product.products(for: Self.allIDs) { for p in ps { products[p.id] = p } }
    }

    func price(_ id: String) -> String { products[id]?.displayPrice ?? "$0.99" }
    func owns(yard id: String) -> Bool { id == "classic" || owned.contains(Self.yardID(id)) }

    func refresh() async {
        guard !demo else { return }
        var has: Set<String> = []
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, t.revocationDate == nil, t.productType == .nonConsumable, Self.allIDs.contains(t.productID) {
                has.insert(t.productID)
            }
        }
        owned = has
        UserDefaults.standard.set(Array(has), forKey: "pb.owned")
        if !owns(yard: Shared.yard) { YardTheme.apply("classic") }
    }

    /// Credit a consumable once per transaction, however many times StoreKit reports it.
    private func credit(_ t: StoreKit.Transaction) {
        guard t.productType == .consumable, t.revocationDate == nil else { return }
        let d = UserDefaults.standard
        var seen = Set(d.stringArray(forKey: "pb.credited") ?? [])
        guard !seen.contains(String(t.id)) else { return }
        seen.insert(String(t.id))
        d.set(Array(seen), forKey: "pb.credited")
        onConsumable?(t.productID)
    }

    @discardableResult
    func buy(_ id: String) async -> Bool {
        message = nil
        if demo { if id == Self.miraclesID || id == Self.invitesID { onConsumable?(id) } else { owned.insert(id) }; return true }
        await load()
        guard let p = products[id] else { message = "The App Store did not answer. Check your connection and try again."; return false }
        busy = id; defer { busy = nil }
        do {
            switch try await p.purchase() {
            case .success(let r):
                guard case .verified(let t) = r else { message = "Apple could not confirm that purchase. You were not charged twice."; return false }
                credit(t)
                await t.finish()
                await refresh()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return true
            case .pending: message = "Waiting for approval. It arrives by itself once it is approved."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "The purchase did not go through: \(error.localizedDescription)" }
        return false
    }

    func restore() async {
        guard !demo else { return }
        try? await AppStore.sync()
        await refresh()
    }
}
