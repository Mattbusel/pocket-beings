import XCTest
@testable import PocketBeings

final class SeasonTests: XCTestCase {

    func testGiftCalendarAndMultipliers() {
        XCTAssertEqual(DailyGift.calendar.count, 7)
        let plain = DailyGift.reward(index: 0, bigHand: false, club: false)
        XCTAssertEqual(plain.miracles, 1)
        // The Big Hand always gave two miracles a day: every box still does at least that.
        for i in 0..<7 {
            XCTAssertGreaterThanOrEqual(DailyGift.reward(index: i, bigHand: true, club: false).miracles, 2)
            let base = DailyGift.reward(index: i, bigHand: false, club: false)
            let club = DailyGift.reward(index: i, bigHand: false, club: true)
            XCTAssertEqual(club.miracles, base.miracles * 2)
            XCTAssertEqual(club.invites, base.invites * 2)
        }
    }

    func testSeasonsCoverEveryMonth() {
        var c = DateComponents(); c.year = 2026; c.day = 15
        var keys = Set<String>()
        for m in 1...12 {
            c.month = m
            let s = Season.at(Calendar(identifier: .gregorian).date(from: c)!, calendar: Calendar(identifier: .gregorian))
            keys.insert(s.key)
            XCTAssertFalse(s.name.isEmpty)
            XCTAssertGreaterThan(s.ends, Calendar(identifier: .gregorian).date(from: c)!)
        }
        XCTAssertEqual(keys.count, 12)
    }

    func testTrackRewardsAndTiers() {
        XCTAssertEqual(Season.tier(stars: 0), 0)
        XCTAssertEqual(Season.tier(stars: Season.starsPerTier), 1)
        XCTAssertEqual(Season.tier(stars: 10_000), Season.tiers)
        XCTAssertTrue(Season.free(Season.tiers).face)
        for t in 1...Season.tiers {
            let f = Season.free(t), c = Season.club(t)
            XCTAssertGreaterThanOrEqual(c.miracles + c.invites, f.miracles + f.invites, "tier \(t)")
        }
    }

    func testWeeklyChallengesAreStableAndDistinct() {
        let a = Challenges.week("2026-W43"), b = Challenges.week("2026-W43")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(Set(a.map(\.kind)).count, 3)
        let weeks = (1...20).map { Challenges.week(String(format: "2026-W%02d", $0)).map(\.kind) }
        XCTAssertGreaterThan(Set(weeks.map { $0.joined() }).count, 5)
    }

    func testStampsFromALongTown() {
        var t = Founding.town(seed: 7)
        for _ in 0..<900 { Society.step(&t) }
        let got = Stamps.earned(StampContext(town: t, counts: ["exile": 1, "miracle": 1, "invite": 1], bestStreak: 8, seasonsFinished: 0))
        XCTAssertTrue(got.contains("oldtown"))
        XCTAssertTrue(got.contains("riddance"))
        XCTAssertTrue(got.contains("weekofwishes"))
        XCTAssertFalse(got.contains("finisher"))
        XCTAssertEqual(Set(Stamps.all.map(\.id)).count, Stamps.all.count)
    }

    func testAlmanacWritesADayAtATime() {
        var t = Founding.town(seed: 11)
        for _ in 0..<200 { Society.step(&t) }
        let h = t.history ?? []
        XCTAssertEqual(h.count, 10)
        XCTAssertEqual(h.first?.day, 1)
        XCTAssertEqual(h.last?.day, 10)
    }

    func testClubMiraclesKeepTheBooksBalanced() {
        for m in Miracle.allCases where m.isClub {
            var t = Founding.town(seed: 3)
            for _ in 0..<100 { Society.step(&t) }
            let before = t.totalCoins - t.minted
            Society.miracle(&t, m)
            XCTAssertEqual(t.totalCoins - t.minted, before)
            XCTAssertTrue(t.beings.allSatisfy { $0.heat <= 100 })
        }
    }
}
