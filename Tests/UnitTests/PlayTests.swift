import XCTest
@testable import PocketBeings

final class PlayTests: XCTestCase {

    private func run(_ seed: UInt64, ticks: Int, laws: [Law] = []) -> Town {
        var t = Founding.town(seed: seed)
        t.laws = laws.map(\.rawValue)
        for _ in 0..<ticks { Society.step(&t) }
        return t
    }

    /// A town saved by 1.1 has no laws, records or invited flags. It must still open.
    func testA11SaveStillDecodes() throws {
        var t = Founding.town(seed: 5)
        for _ in 0..<40 { Society.step(&t) }
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(t)) as! [String: Any]
        json.removeValue(forKey: "laws")
        json.removeValue(forKey: "records")
        var beings = json["beings"] as! [[String: Any]]
        for i in beings.indices { beings[i].removeValue(forKey: "invited") }
        json["beings"] = beings
        let data = try JSONSerialization.data(withJSONObject: json)
        let back = try JSONDecoder().decode(Town.self, from: data)
        XCTAssertEqual(back.beings.count, t.beings.count)
        XCTAssertNil(back.laws)
    }

    func testNoGamblingMeansNoGambling() {
        for seed in 1...6 {
            let t = run(UInt64(seed), ticks: 800, laws: [.noGambling])
            XCTAssertFalse(t.ledger.contains { $0.kind == "gamble" }, "seed \(seed)")
        }
    }

    func testTermLimitsEmptyTheSeats() {
        let t = run(3, ticks: 600, laws: [.termLimits])
        XCTAssertTrue(t.ledger.contains { $0.kind == "terms" })
    }

    func testMiraclesKeepTheBooksBalanced() {
        for m in Miracle.allCases {
            var t = run(9, ticks: 120)
            let before = t.totalCoins - t.minted
            Society.miracle(&t, m)
            XCTAssertEqual(t.totalCoins - t.minted, before, "\(m) created or destroyed coins")
            XCTAssertTrue(t.beings.allSatisfy { $0.wallet >= 0 })
            XCTAssertEqual(t.ledger.first?.kind, "miracle")
        }
    }

    func testInviteAddsAndReplaces() {
        var t = run(4, ticks: 30)
        let n = t.beings.count
        let fresh = Society.invite(&t, name: "Grandma Jo", face: "👵", replacing: nil)
        XCTAssertEqual(t.beings.count, n + 1)
        XCTAssertEqual(fresh.invited, true)
        let gone = t.beings[0]
        _ = Society.invite(&t, name: "Cousin Al", face: "🤠", replacing: gone)
        XCTAssertEqual(t.beings.count, n + 1)
        XCTAssertNil(t.beings.first { $0.id == gone.id })
    }

    func testWishIsStableAndNotAlreadyTrue() {
        let t = run(12, ticks: 80)
        let a = Wishes.make(day: "2026-10-09", town: t)
        let b = Wishes.make(day: "2026-10-09", town: t)
        XCTAssertEqual(a, b)
        XCTAssertFalse(Wishes.check(a, town: t))
    }

    func testRecordsFillIn() {
        let t = run(2, ticks: 900)
        let r = t.records ?? Records()
        XCTAssertGreaterThan(r.richest, 0)
        XCTAssertGreaterThan(r.businesses, 0)
    }
}
