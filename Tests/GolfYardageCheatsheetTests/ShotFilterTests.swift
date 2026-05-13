import XCTest
@testable import GolfYardageCheatsheet

final class ShotFilterTests: XCTestCase {
    func testAllFilterIncludesEveryClub() {
        let normalClub = Club(
            profileID: UUID(),
            clubType: .sevenIron,
            shotType: .normal,
            swingDistances: SwingDistanceSet(full: 150)
        )
        let punchClub = Club(
            profileID: UUID(),
            clubType: .fourIron,
            shotType: .punch,
            swingDistances: SwingDistanceSet(full: 170)
        )
        let putter = Club(
            profileID: UUID(),
            clubType: .putter,
            putterDistances: PutterDistanceSet(short: 3)
        )

        XCTAssertTrue(ShotFilter.all.includes(normalClub))
        XCTAssertTrue(ShotFilter.all.includes(punchClub))
        XCTAssertTrue(ShotFilter.all.includes(putter))
    }

    func testPunchOnlyFilterIncludesOnlyPunchClubs() {
        let normalClub = Club(
            profileID: UUID(),
            clubType: .sevenIron,
            shotType: .normal,
            swingDistances: SwingDistanceSet(full: 150)
        )
        let punchClub = Club(
            profileID: UUID(),
            clubType: .fourIron,
            shotType: .punch,
            swingDistances: SwingDistanceSet(full: 170)
        )
        let putter = Club(
            profileID: UUID(),
            clubType: .putter,
            putterDistances: PutterDistanceSet(short: 3)
        )

        XCTAssertFalse(ShotFilter.punchOnly.includes(normalClub))
        XCTAssertTrue(ShotFilter.punchOnly.includes(punchClub))
        XCTAssertFalse(ShotFilter.punchOnly.includes(putter))
    }
}
