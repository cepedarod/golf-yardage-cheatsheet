import XCTest
@testable import GolfYardageCheatsheet

final class ShotFilterTests: XCTestCase {
    func testNormalFilterIncludesNormalFlopAndPutterClubs() {
        let normalClub = Club(
            profileID: UUID(),
            clubType: .sevenIron,
            normalDistances: SwingDistanceSet(full: 150)
        )
        let lowTrajectoryClub = Club(
            profileID: UUID(),
            clubType: .fourIron,
            lowTrajectoryDistances: LowTrajectoryDistanceSet(stinger: 170)
        )
        let flopClub = Club(
            profileID: UUID(),
            clubType: .lobWedge,
            flopDistances: SwingDistanceSet(full: 70)
        )
        let putter = Club(
            profileID: UUID(),
            clubType: .putter,
            putterDistances: PutterDistanceSet(short: 3)
        )

        XCTAssertTrue(ShotFilter.normal.includes(normalClub))
        XCTAssertFalse(ShotFilter.normal.includes(lowTrajectoryClub))
        XCTAssertTrue(ShotFilter.normal.includes(flopClub))
        XCTAssertTrue(ShotFilter.normal.includes(putter))
    }

    func testNormalTargetMatchFilterExcludesLowTrajectoryOnlyClubs() {
        let normalClub = Club(
            profileID: UUID(),
            clubType: .sevenIron,
            normalDistances: SwingDistanceSet(full: 150)
        )
        let lowTrajectoryClub = Club(
            profileID: UUID(),
            clubType: .fourIron,
            lowTrajectoryDistances: LowTrajectoryDistanceSet(stinger: 170)
        )
        let putter = Club(
            profileID: UUID(),
            clubType: .putter,
            putterDistances: PutterDistanceSet(short: 3)
        )

        XCTAssertTrue(ShotFilter.normal.includesTargetMatch(normalClub))
        XCTAssertFalse(ShotFilter.normal.includesTargetMatch(lowTrajectoryClub))
        XCTAssertTrue(ShotFilter.normal.includesTargetMatch(putter))
    }

    func testLowTrajectoryFilterIncludesOnlyLowTrajectoryClubs() {
        let normalClub = Club(
            profileID: UUID(),
            clubType: .sevenIron,
            normalDistances: SwingDistanceSet(full: 150)
        )
        let lowTrajectoryClub = Club(
            profileID: UUID(),
            clubType: .fourIron,
            lowTrajectoryDistances: LowTrajectoryDistanceSet(stinger: 170)
        )
        let putter = Club(
            profileID: UUID(),
            clubType: .putter,
            putterDistances: PutterDistanceSet(short: 3)
        )

        XCTAssertFalse(ShotFilter.lowTrajectory.includes(normalClub))
        XCTAssertTrue(ShotFilter.lowTrajectory.includes(lowTrajectoryClub))
        XCTAssertFalse(ShotFilter.lowTrajectory.includes(putter))
    }
}
