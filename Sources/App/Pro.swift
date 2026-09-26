import StoreKit
import SwiftUI

/// The Big Hand: one non-consumable. The town, the seven beings, the newspaper
/// and all five original meddles are free forever. The Big Hand adds four more
/// meddles, a hand that rests two seconds instead of five, and naming the town.
///
/// Everyone who installed 1.0 paid for the app and keeps everything.
/// AppTransaction's originalAppVersion is the build number they first
/// installed; 1.0 shipped as build 1. Only trusted in production: sandbox and
/// Xcode report made-up values, and App Review must see the real paywall.
@MainActor
final class Pro: ObservableObject {
    static let productID = "com.mattbusel.pocketbeings.pro"
    /// The first build that has The Big Hand in it. Anything earlier had every feature.
    static let firstFreemiumBuild = 2

    @Published private(set) var unlocked: Bool
    @Published private(set) var product: Product?
    @Published var busy = false
    @Published var message: String?
    @Published var showPaywall = false

    private var grandfathered = false
    private var updates: Task<Void, Never>?
    private let key = "pocketbeings.bighand.unlocked"
    private let forced: Bool

    /// Screenshots and the review recording run with `forced`, which never
    /// touches StoreKit and shows the free game.
    init() {
        let args = ProcessInfo.processInfo.arguments
        // fastlane's setupSnapshot adds -FASTLANE_SNAPSHOT to every launch, including the title
        // shot that has no -screenshots: without it StoreKit asks the simulator to sign in, and
        // that system alert sits over every later screenshot.
        forced = args.contains("-screenshots") || args.contains("-demoAutoplay") || args.contains("-FASTLANE_SNAPSHOT")
        if forced {
            unlocked = false
            showPaywall = args.contains("-showPaywall")
            return
        }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$2.99" }

    /// True when the player may use `m`; otherwise opens the paywall.
    func allows(_ m: Society.Meddle) -> Bool {
        if !m.isPro || unlocked { return true }
        showPaywall = true
        return false
    }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production,
           (Int(app.originalAppVersion) ?? Int.max) < Pro.firstFreemiumBuild {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. The Big Hand arrives by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "The Big Hand is back. Welcome back." : "No Big Hand purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        unlocked = true
        showPaywall = false
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - Paywall

/// The Big Hand, sold from a window like everything else in town.
struct PaywallWindow: View {
    @EnvironmentObject private var pro: Pro
    @State private var wave = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea().onTapGesture { pro.showPaywall = false }
            WindowBox(title: "The Big Hand", trailing: "one-time") {
                VStack(spacing: 10) {
                    VStack(spacing: 4) {
                        Text("🫵")
                            .font(.system(size: 54))
                            .rotationEffect(.degrees(wave ? -12 : 12))
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: wave)
                        Text("MEDDLE HARDER")
                            .font(UI.font(22, .black))
                            .kerning(2)
                            .foregroundStyle(UI.ink)
                        Text("The town is free forever. The Big Hand gives you more ways to ruin it.")
                            .font(UI.font(12, .semibold))
                            .foregroundStyle(UI.ink.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Society.Meddle.allCases.filter(\.isPro)) { m in
                            feature(m.icon, m.label, m.blurb)
                        }
                        feature("⏱️", "Faster hand", "Meddle every 2 seconds instead of 5.")
                        feature("🪧", "Name your town", "Rename it whatever you like, whenever you like.")
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .bevel(raised: false, fill: UI.paper)

                    if let m = pro.message {
                        Text(m)
                            .font(UI.font(11, .bold))
                            .foregroundStyle(UI.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(pro.busy ? "ONE MOMENT..." : "GET THE BIG HAND  \(pro.price)") {
                        Task { await pro.buy() }
                    }
                    .buttonStyle(ChunkyButton(fill: UI.coin))
                    .disabled(pro.busy)

                    HStack(spacing: 8) {
                        Button("RESTORE") { Task { await pro.restore() } }
                            .buttonStyle(ChunkyButton())
                            .disabled(pro.busy)
                        Button("NOT NOW") { pro.showPaywall = false }
                            .buttonStyle(ChunkyButton())
                    }

                    Text("One payment, yours for good. No subscription, no ads. Family Sharing works. Your town is never locked.")
                        .font(UI.font(10, .semibold))
                        .foregroundStyle(UI.ink.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .padding(10)
            }
            .padding(.horizontal, 22)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .onAppear { wave = true }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(icon).font(.system(size: 18)).frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(UI.font(13, .black)).foregroundStyle(UI.ink)
                Text(detail).font(UI.font(11, .medium)).foregroundStyle(UI.ink.opacity(0.7))
            }
        }
    }
}
