import StoreKit
import SwiftUI

/// The Town Club: an auto-renewable subscription, monthly or yearly (the yearly one
/// starts with a free week for new subscribers). Separate from The Big Hand, whose
/// one-time purchase and grandfathering are untouched: a Big Hand owner keeps
/// everything whether or not they ever join.
@MainActor
final class Club: ObservableObject {
    static let monthlyID = "com.mattbusel.pocketbeings.club.monthly"
    static let yearlyID = "com.mattbusel.pocketbeings.club.yearly"
    static let ids = [yearlyID, monthlyID]
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://tensorust.com/apps/pocket-beings/privacy/")!

    @Published private(set) var active: Bool
    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var currentID: String?
    @Published private(set) var renews: Date?
    @Published private(set) var willRenew = true
    @Published private(set) var trialEligible = true
    @Published var busy = false
    @Published var message: String?

    private var updates: Task<Void, Never>?
    private let demo: Bool

    init() {
        let args = ProcessInfo.processInfo.arguments
        demo = args.contains("-screenshots") || args.contains("-demoAutoplay") || args.contains("-FASTLANE_SNAPSHOT") || args.contains("-previewTour")
        if demo {
            active = args.contains("-clubOn")
            if active { currentID = Self.yearlyID; renews = Date().addingTimeInterval(300 * 86_400) }
            return
        }
        active = UserDefaults.standard.bool(forKey: "pb.club")
        Shared.club = active
        updates = Task { [weak self] in
            for await r in Transaction.updates {
                if case .verified(let t) = r { await t.finish() }
                await self?.refresh()
            }
        }
        Task { await load(); await refresh() }
    }

    func load() async {
        guard !demo, products.count < Self.ids.count else { return }
        if let ps = try? await Product.products(for: Self.ids) { for p in ps { products[p.id] = p } }
        if let sub = products[Self.yearlyID]?.subscription {
            trialEligible = await sub.isEligibleForIntroOffer
        }
    }

    func refresh() async {
        guard !demo else { return }
        var on = false, cur: String?, until: Date?
        for await r in Transaction.currentEntitlements {
            guard case .verified(let t) = r, Self.ids.contains(t.productID), t.revocationDate == nil else { continue }
            if let e = t.expirationDate, e < Date() { continue }
            on = true; cur = t.productID; until = t.expirationDate
        }
        if let cur, let statuses = try? await products[cur]?.subscription?.status {
            for s in statuses {
                if case .verified(let info) = s.renewalInfo, info.currentProductID == cur { willRenew = info.willAutoRenew }
            }
        }
        active = on; currentID = cur; renews = until
        UserDefaults.standard.set(on, forKey: "pb.club")
        Shared.club = on
    }

    func price(_ id: String) -> String {
        products[id]?.displayPrice ?? (id == Self.yearlyID ? "$14.99" : "$2.99")
    }

    /// "1 week free, then $14.99 a year" for the yearly plan when the trial applies.
    func terms(_ id: String) -> String {
        let per = id == Self.yearlyID ? "year" : "month"
        if id == Self.yearlyID, trialEligible, let offer = products[id]?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            return "\(Self.describe(offer.period)) free, then \(price(id)) a \(per)"
        }
        if id == Self.yearlyID, trialEligible, products[id] == nil {
            return "1 week free, then \(price(id)) a \(per)"
        }
        return "\(price(id)) a \(per)"
    }

    static func describe(_ p: Product.SubscriptionPeriod) -> String {
        let unit: String
        switch p.unit {
        case .day: unit = p.value == 7 ? "week" : "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "period"
        }
        if p.unit == .day && p.value == 7 { return "1 week" }
        return "\(p.value) \(unit)\(p.value == 1 ? "" : "s")"
    }

    func buy(_ id: String) async {
        message = nil
        if demo { return }
        await load()
        guard let p = products[id] else { message = "The App Store did not answer. Check your connection and try again."; return }
        busy = true; defer { busy = false }
        do {
            switch try await p.purchase() {
            case .success(let r):
                guard case .verified(let t) = r else { message = "Apple could not confirm that purchase."; return }
                await t.finish()
                await refresh()
                if active { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            case .pending: message = "Waiting for approval. The Club opens by itself once it is approved."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "The purchase did not go through: \(error.localizedDescription)" }
    }

    func restore() async {
        guard !demo else { return }
        busy = true; defer { busy = false }
        try? await AppStore.sync()
        await refresh()
        message = active ? "Welcome back to the Town Club." : "No Town Club subscription found on this Apple Account."
    }
}

// MARK: - The Club window

struct ClubWindow: View {
    @EnvironmentObject private var club: Club
    @EnvironmentObject private var pro: Pro
    @EnvironmentObject private var player: Player
    @State private var plan = Club.yearlyID
    @State private var manage = false
    @State private var redeem = false
    @State private var shine = false
    var close: () -> Void

    static let perks: [(String, String, String)] = [
        ("🫵", "Everything in The Big Hand", "Pardon, Frame, Deputise, Rain 20, the fast hand, laws and naming your town."),
        ("🧰", "A Club Chest every month", "25 miracles and 5 invitations, fresh every calendar month."),
        ("🎀", "Double daily gifts", "Every box on the gift calendar, twice over."),
        ("🏁", "The Club row of every Season", "Bigger rewards on all ten tiers, every month."),
        ("🏖️", "Club miracles", "Tax Holiday and Crime Wave, only in the Club."),
        ("🏡", "Every yard", "Snow Day, Night Market, Beach Town and Mars Colony, icons included."),
        ("📊", "The Town Almanac", "Day by day charts of wealth, prices and crime."),
        ("☁️", "iCloud backup", "Your town and your stash follow you to a new phone."),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea().onTapGesture(perform: close)
            WindowBox(title: "Town Club", trailing: club.active ? "member" : "") {
                ScrollView {
                    VStack(spacing: 10) {
                        VStack(spacing: 2) {
                            Text("🏛️").font(.system(size: 46)).scaleEffect(shine ? 1.06 : 0.96)
                                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shine)
                            Text("JOIN THE TOWN CLUB").font(UI.font(21, .black)).kerning(1.5).foregroundStyle(UI.ink)
                            Text("More to do every month, for as long as you are a member.")
                                .font(UI.font(12, .semibold)).foregroundStyle(UI.ink.opacity(0.7)).multilineTextAlignment(.center)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(Array(Self.perks.enumerated()), id: \.offset) { _, p in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(p.0).font(.system(size: 17)).frame(width: 26)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(p.1).font(UI.font(13, .black)).foregroundStyle(UI.ink)
                                        Text(p.2).font(UI.font(11, .medium)).foregroundStyle(UI.ink.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .bevel(raised: false, fill: UI.paper)

                        if club.active { memberBox } else { plans }

                        if let m = club.message {
                            Text(m).font(UI.font(11, .bold)).foregroundStyle(UI.red).multilineTextAlignment(.center)
                        }

                        HStack(spacing: 8) {
                            Button("RESTORE") { Task { await club.restore() } }.buttonStyle(ChunkyButton()).disabled(club.busy)
                            Button("REDEEM CODE") { redeem = true }.buttonStyle(ChunkyButton())
                        }
                        if pro.unlocked && !club.active {
                            Text("Big Hand owners keep The Big Hand forever. The Club adds the monthly chest, the Club row of every Season, every yard, the almanac and backup on top.")
                                .font(UI.font(11, .bold)).foregroundStyle(UI.link).multilineTextAlignment(.center)
                        }
                        if !pro.unlocked && !club.active {
                            Button {
                                close(); pro.showPaywall = true
                            } label: {
                                Text("Rather pay once? The Big Hand: the extra meddles, laws and naming, yours for good.")
                                    .font(UI.font(11, .black)).foregroundStyle(UI.link).underline().multilineTextAlignment(.center)
                            }
                        }

                        Text(legal).font(UI.font(9.5, .medium)).foregroundStyle(UI.ink.opacity(0.6)).multilineTextAlignment(.center)
                        HStack(spacing: 16) {
                            Link("Terms of Use", destination: Club.terms)
                            Link("Privacy Policy", destination: Club.privacy)
                        }
                        .font(UI.font(11, .black)).foregroundStyle(UI.link)

                        Button("NOT NOW", action: close).buttonStyle(ChunkyButton())
                    }
                    .padding(10)
                }
                .frame(maxHeight: 640)
            }
            .padding(.horizontal, 16)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .onAppear { shine = true; Task { await club.load() } }
        .manageSubscriptionsSheet(isPresented: $manage)
        .offerCodeRedemption(isPresented: $redeem) { _ in Task { await club.refresh() } }
    }

    private var plans: some View {
        VStack(spacing: 6) {
            planRow(Club.yearlyID, "Yearly", club.trialEligible ? "1 WEEK FREE" : "BEST VALUE")
            planRow(Club.monthlyID, "Monthly", "")
            Button(club.busy ? "ONE MOMENT..." : (plan == Club.yearlyID && club.trialEligible ? "START THE FREE WEEK" : "JOIN THE CLUB")) {
                Task { await club.buy(plan) }
            }
            .buttonStyle(ChunkyButton(fill: UI.coin))
            .disabled(club.busy)
            Text(club.terms(plan) + ". Cancel any time.")
                .font(UI.font(11, .bold)).foregroundStyle(UI.ink.opacity(0.75))
        }
    }

    private func planRow(_ id: String, _ name: String, _ tag: String) -> some View {
        Button { plan = id } label: {
            HStack(spacing: 8) {
                Image(systemName: plan == id ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(UI.ink)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(name).font(UI.font(15, .black)).foregroundStyle(UI.ink)
                        if !tag.isEmpty {
                            Text(tag).font(UI.font(9, .black)).foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2).background(UI.red)
                        }
                    }
                    Text(club.terms(id)).font(UI.font(11, .semibold)).foregroundStyle(UI.ink.opacity(0.7))
                }
                Spacer()
                Text(club.price(id)).font(UI.font(15, .black)).foregroundStyle(UI.ink)
            }
            .padding(8)
            .bevel(raised: plan != id, fill: plan == id ? UI.coin.opacity(0.3) : UI.chrome)
        }
        .buttonStyle(.plain)
    }

    private var memberBox: some View {
        VStack(spacing: 6) {
            Text("You are in the Town Club. 🎉").font(UI.font(15, .black)).foregroundStyle(UI.ink)
            if let r = club.renews {
                Text((club.willRenew ? "Renews " : "Ends ") + r.formatted(date: .abbreviated, time: .omitted))
                    .font(UI.font(11, .bold)).foregroundStyle(UI.ink.opacity(0.7))
            }
            if player.canOpenChest {
                Button("OPEN THIS MONTH'S CLUB CHEST 🧰") { player.openChest() }
                    .buttonStyle(ChunkyButton(fill: UI.coin))
            } else {
                Text("This month's chest is open. The next one arrives on the 1st.")
                    .font(UI.font(11, .bold)).foregroundStyle(UI.ink.opacity(0.65)).multilineTextAlignment(.center)
            }
            Button("MANAGE SUBSCRIPTION") { manage = true }.buttonStyle(ChunkyButton())
        }
        .padding(8).bevel(raised: false, fill: UI.paper)
    }

    private var legal: String {
        "Payment is charged to your Apple Account when you confirm. The Town Club renews automatically at the price shown for the same period unless it is cancelled at least 24 hours before the end of the current period; your account is charged for renewal within 24 hours before the period ends. A free trial, if offered, converts to a paid subscription when it ends unless cancelled; any unused part of a trial ends when you subscribe. Manage or cancel any time in Settings > Apple Account > Subscriptions."
    }
}
