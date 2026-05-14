import XCTest
@testable import GolfYardageCheatsheet

final class YardageMatcherTests: XCTestCase {
    private let profileID = UUID()
    private let matcher = YardageMatcher()

    func testClosestMatchesReturnClosestLongAndShortShots() {
        let firstClubID = UUID()
        let secondClubID = UUID()
        let clubs = [
            Club(
                id: firstClubID,
                profileID: profileID,
                clubType: .eightIron,
                swingDistances: SwingDistanceSet(full: 150, half: 149)
            ),
            Club(
                id: secondClubID,
                profileID: profileID,
                clubType: .nineIron,
                swingDistances: SwingDistanceSet(full: 140)
            )
        ]

        let matches = matcher.closestMatches(targetYardage: 145, clubs: clubs)

        XCTAssertEqual(matches.map(\.club.id), [firstClubID, secondClubID])
        XCTAssertEqual(matches.map(\.distance), [149, 140])
    }

    func testInactiveClubsAreExcluded() {
        let activeClubID = UUID()
        let clubs = [
            Club(
                profileID: profileID,
                clubType: .sevenIron,
                isActive: false,
                swingDistances: SwingDistanceSet(full: 150)
            ),
            Club(
                id: activeClubID,
                profileID: profileID,
                clubType: .eightIron,
                swingDistances: SwingDistanceSet(full: 145)
            )
        ]

        let matches = matcher.closestMatches(targetYardage: 150, clubs: clubs)

        XCTAssertEqual(matches.map(\.club.id), [activeClubID])
    }

    func testLowTrajectoryFilterOnlyReturnsLowTrajectoryClubValues() {
        let lowTrajectoryClubID = UUID()
        let clubs = [
            Club(
                profileID: profileID,
                clubType: .sevenIron,
                normalDistances: SwingDistanceSet(full: 150)
            ),
            Club(
                id: lowTrajectoryClubID,
                profileID: profileID,
                clubType: .fourIron,
                lowTrajectoryDistances: LowTrajectoryDistanceSet(stinger: 170, punch: 150)
            )
        ]

        let matches = matcher.closestMatches(targetYardage: 150, clubs: clubs, filter: .lowTrajectory)

        XCTAssertEqual(matches.map(\.club.id), [lowTrajectoryClubID])
        XCTAssertEqual(matches.map(\.label), [.punch])
    }

    func testNormalTargetMatchesExcludeLowTrajectoryValues() {
        let normalShortClubID = UUID()
        let normalLongClubID = UUID()
        let lowTrajectoryClubID = UUID()
        let clubs = [
            Club(
                id: normalShortClubID,
                profileID: profileID,
                clubType: .sevenIron,
                normalDistances: SwingDistanceSet(full: 150)
            ),
            Club(
                id: lowTrajectoryClubID,
                profileID: profileID,
                clubType: .fourIron,
                lowTrajectoryDistances: LowTrajectoryDistanceSet(stinger: 162)
            ),
            Club(
                id: normalLongClubID,
                profileID: profileID,
                clubType: .sixIron,
                normalDistances: SwingDistanceSet(full: 180)
            )
        ]

        let matches = matcher.closestMatches(targetYardage: 160, clubs: clubs, filter: .normal)

        XCTAssertEqual(matches.map(\.club.id), [normalShortClubID, normalLongClubID])
        XCTAssertFalse(matches.map(\.club.id).contains(lowTrajectoryClubID))
    }

    func testNormalTargetMatchesIncludeWedgeFlopValues() {
        let wedgeID = UUID()
        let clubs = [
            Club(
                id: wedgeID,
                profileID: profileID,
                clubType: .sandWedge,
                normalDistances: SwingDistanceSet(full: 105),
                flopDistances: SwingDistanceSet(full: 65, half: 40)
            )
        ]

        let matches = matcher.closestMatches(targetYardage: 65, clubs: clubs, filter: .normal)

        XCTAssertEqual(matches.map(\.club.id), [wedgeID])
        XCTAssertEqual(matches.map(\.category), [.flop])
        XCTAssertEqual(matches.map(\.displayLabel), ["Flop Full"])
    }

    func testInvalidTargetOrLimitReturnsNoMatches() {
        let clubs = [
            Club(
                profileID: profileID,
                clubType: .sevenIron,
                swingDistances: SwingDistanceSet(full: 150)
            )
        ]

        XCTAssertTrue(matcher.closestMatches(targetYardage: 0, clubs: clubs).isEmpty)
        XCTAssertTrue(matcher.closestMatches(targetYardage: -1, clubs: clubs).isEmpty)
        XCTAssertTrue(matcher.closestMatches(targetYardage: 150, clubs: clubs, limit: 0).isEmpty)
    }

    func testNonPositiveDistancesAreIgnoredWhenMatching() {
        let validClubID = UUID()
        let clubs = [
            Club(
                profileID: profileID,
                clubType: .sevenIron,
                swingDistances: SwingDistanceSet(full: 0)
            ),
            Club(
                id: validClubID,
                profileID: profileID,
                clubType: .eightIron,
                swingDistances: SwingDistanceSet(full: 140)
            )
        ]

        let matches = matcher.closestMatches(targetYardage: 150, clubs: clubs)

        XCTAssertEqual(matches.map(\.club.id), [validClubID])
    }

    func testTiesPreferFullSwingDistanceClosestToTarget() {
        let oldest = Date(timeIntervalSince1970: 1)
        let middle = Date(timeIntervalSince1970: 2)
        let newest = Date(timeIntervalSince1970: 3)
        let farFullSwingClubID = UUID()
        let closeFullSwingClubID = UUID()
        let closestFullSwingClubID = UUID()
        let clubs = [
            Club(
                id: farFullSwingClubID,
                profileID: profileID,
                clubType: .sevenIron,
                swingDistances: SwingDistanceSet(full: 120, threeQuarter: 100),
                createdAt: oldest
            ),
            Club(
                id: closeFullSwingClubID,
                profileID: profileID,
                clubType: .eightIron,
                swingDistances: SwingDistanceSet(full: 102, half: 100),
                createdAt: middle
            ),
            Club(
                id: closestFullSwingClubID,
                profileID: profileID,
                clubType: .nineIron,
                swingDistances: SwingDistanceSet(full: 101, quarter: 100),
                createdAt: newest
            )
        ]

        let matches = matcher.closestMatches(targetYardage: 100, clubs: clubs)

        XCTAssertEqual(matches.map(\.club.id), [closestFullSwingClubID, closeFullSwingClubID])
    }
}
