import XCTest

@testable import PocketBeings

/// Runs whole towns in memory. On a machine that cannot run the app, these are
/// how the society is known to still work.
final class SocietyTests: XCTestCase {

    private func run(_ seed: UInt64, ticks: Int) -> Town {
        var t = Founding.town(seed: seed)
        for _ in 0..<ticks { Society.step(&t) }
        return t
    }

    func testSameSeedSameTown() {
        let a = run(42, ticks: 300)
        let b = run(42, ticks: 300)
        XCTAssertEqual(a.ledger.map(\.text), b.ledger.map(\.text))
        XCTAssertEqual(a.beings.map(\.wallet), b.beings.map(\.wallet))
    }

    func testNobodyGoesNegativeAndTheTownStaysPopulated() {
        for seed in 1...20 {
            let t = run(UInt64(seed), ticks: 500)
            XCTAssertEqual(t.beings.count, Town.population, "seed \(seed)")
            XCTAssertTrue(t.beings.allSatisfy { $0.wallet >= 0 }, "seed \(seed)")
            XCTAssertGreaterThanOrEqual(t.treasury, 0)
        }
    }

    func testCoinsAreOnlyCreatedByPrintingAndLuck() {
        // Everything in the town is accounted for: coins are moved, taxed or
        // fined into the treasury, or minted (which the price index records).
        var t = Founding.town(seed: 9)
        let start = t.totalCoins
        for _ in 0..<400 { Society.step(&t) }
        XCTAssertEqual(t.totalCoins, start + t.minted)
    }

    func testEveryVerbGetsUsedOverALongEnoughRun() {
        var kinds = Set<String>()
        for seed in 1...8 {
            kinds.formUnion(run(UInt64(seed), ticks: 800).ledger.map(\.kind))
        }
        for k in ["found", "fee", "steal", "gift", "friend", "enemy", "faction", "office",
                  "gang", "heist", "gamble", "mint", "tax", "jail", "event"] {
            XCTAssertTrue(kinds.contains(k), "never saw \(k)")
        }
    }

    func testSomebodyEndsUpInChargeAndPrintsMoney() {
        // Over a few towns and a long afternoon, the Crown gets taken and the
        // printing starts. That is the arc the whole game is built around.
        let towns = (1...6).map { run(UInt64($0), ticks: 1500) }
        XCTAssertTrue(towns.contains { $0.holder(of: .crown) != nil })
        let printed = towns.first { $0.minted > 0 }
        XCTAssertNotNil(printed)
        if let p = printed {
            XCTAssertGreaterThan(p.priceIndex, 1)
            XCTAssertGreaterThan(p.seatPrice(.crown), p.seatPrice(.sheriff))
        }
    }

    func testJailEndsOnItsOwn() {
        var t = Founding.town(seed: 3)
        let b = t.beings[0]
        Society.meddle(&t, .jail, on: b)
        XCTAssertTrue(t.beings.first { $0.id == b.id }!.isJailed(at: t.tick))
        for _ in 0..<13 { Society.step(&t) }
        XCTAssertFalse(t.beings.first { $0.id == b.id }!.isJailed(at: t.tick))
    }

    func testMeddlingIsRemembered() {
        var t = Founding.town(seed: 3)
        let b = t.beings[1]
        Society.meddle(&t, .gift, on: b)
        XCTAssertEqual(t.beings.first { $0.id == b.id }!.wallet, b.wallet + 50)
        XCTAssertEqual(t.ledger.first?.actor, "You")
        Society.meddle(&t, .crown, on: b)
        XCTAssertEqual(t.holder(of: .crown)?.id, b.id)
        let coins = t.totalCoins
        Society.meddle(&t, .exile, on: b)
        XCTAssertNil(t.beings.first { $0.id == b.id })
        XCTAssertEqual(t.beings.count, Town.population)
        XCTAssertEqual(t.totalCoins, coins + 100)
    }

    func testAmbitionPullsTowardTheWeakestFacet() {
        let t = Founding.town(seed: 1)
        let p = t.power(of: t.beings[0])
        // A newcomer has no office, company or gang, so those are the gaps.
        XCTAssertTrue(Set(p.gaps.prefix(3)).isSubset(of: [.office, .company, .crime, .allies]))
        XCTAssertEqual(p.gaps.last, .money)
    }

    func testCatchUpIsCappedAndReportsOnlyTheBigStuff() {
        var t = Founding.town(seed: 11)
        let before = t.tick
        let news = Society.catchUp(&t, elapsed: 3_000_000, secondsPerTick: 2.4)
        XCTAssertEqual(t.tick - before, 160)
        XCTAssertLessThanOrEqual(news.count, 6)
        XCTAssertTrue(news.allSatisfy(\.big))
    }

    func testTownRoundTripsThroughJSON() throws {
        let t = run(77, ticks: 50)
        let data = try JSONEncoder().encode(t)
        let back = try JSONDecoder().decode(Town.self, from: data)
        XCTAssertEqual(back.tick, t.tick)
        XCTAssertEqual(back.beings, t.beings)
        XCTAssertEqual(back.ledger.map(\.text), t.ledger.map(\.text))
        XCTAssertEqual(back.dice, t.dice)
    }

    func testLedgerIsCapped() {
        let t = run(2, ticks: 2000)
        XCTAssertLessThanOrEqual(t.ledger.count, Town.ledgerCap)
    }
}
