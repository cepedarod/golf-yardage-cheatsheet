import XCTest
@testable import GolfYardageCheatsheet

final class YardageMatcherTests: XCTestCase {
    private let profileID = UUID()
    private let matcher = YardageMatcher()

    func testClosestMatchesReturnBestUniqueClubMatches() {
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

        let matches = matcher.closestMatches(targetYardage: 150, clubs: clubs)

        XCTAssertEqual(matches.map(\.club.id), [firstClubID, secondClubID])
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

    func testPunchFilterOnlyReturnsPunchClubs() {
        let punchClubID = UUID()
        let clubs = [
            Club(
                profileID: profileID,
                clubType: .sevenIron,
                shotType: .normal,
                swingDistances: SwingDistanceSet(full: 150)
            ),
            Club(
                id: punchClubID,
                profileID: profileID,
                clubType: .fourIron,
                shotType: .punch,
                swingDistances: SwingDistanceSet(full: 170, threeQuarter: 150)
            )
        ]

        let matches = matcher.closestMatches(targetYardage: 150, clubs: clubs, filter: .punchOnly)

        XCTAssertEqual(matches.map(\.club.id), [punchClubID])
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
