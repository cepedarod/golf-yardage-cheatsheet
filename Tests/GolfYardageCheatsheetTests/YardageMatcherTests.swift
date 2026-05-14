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

    func testRealModeTargetMatchesUsePureShotAverages() {
        let longClubID = UUID()
        let shortClubID = UUID()
        let clubs = [
            Club(
                id: longClubID,
                profileID: profileID,
                clubType: .sevenIron,
                normalDistances: SwingDistanceSet(full: 200)
            ),
            Club(
                id: shortClubID,
                profileID: profileID,
                clubType: .nineIron,
                normalDistances: SwingDistanceSet(full: 100)
            )
        ]
        let records = [
            ShotRecord(
                profileID: profileID,
                clubID: longClubID,
                category: .normal,
                power: .full,
                distance: 148,
                strikeQuality: .pure,
                direction: .straight
            ),
            ShotRecord(
                profileID: profileID,
                clubID: longClubID,
                category: .normal,
                power: .full,
                distance: 150,
                strikeQuality: .pure,
                direction: .straight
            ),
            ShotRecord(
                profileID: profileID,
                clubID: longClubID,
                category: .normal,
                power: .full,
                distance: 300,
                strikeQuality: .thin,
                direction: .straight
            ),
            ShotRecord(
                profileID: profileID,
                clubID: shortClubID,
                category: .normal,
                power: .full,
                distance: 135,
                strikeQuality: .pure,
                direction: .draw
            )
        ]

        let matches = matcher.closestMatches(
            targetYardage: 145,
            clubs: clubs,
            valueMode: .real,
            shotRecords: records
        )

        XCTAssertEqual(matches.map(\.club.id), [longClubID, shortClubID])
        XCTAssertEqual(matches.map(\.distance), [149, 135])
        XCTAssertEqual(matches.map(\.isSupplemental), [false, false])
    }

    func testRealModeTargetMatchesCanAppendCloserManualSupplementalResult() {
        let realLongClubID = UUID()
        let realShortClubID = UUID()
        let supplementalClubID = UUID()
        let clubs = [
            Club(id: realLongClubID, profileID: profileID, clubType: .sevenIron),
            Club(id: realShortClubID, profileID: profileID, clubType: .nineIron),
            Club(
                id: supplementalClubID,
                profileID: profileID,
                clubType: .pitchingWedge,
                normalDistances: SwingDistanceSet(full: 151)
            )
        ]
        let records = [
            ShotRecord(
                profileID: profileID,
                clubID: realLongClubID,
                category: .normal,
                power: .full,
                distance: 170,
                strikeQuality: .pure,
                direction: .straight
            ),
            ShotRecord(
                profileID: profileID,
                clubID: realShortClubID,
                category: .normal,
                power: .full,
                distance: 130,
                strikeQuality: .pure,
                direction: .fade
            )
        ]

        let matches = matcher.closestMatches(
            targetYardage: 150,
            clubs: clubs,
            valueMode: .real,
            shotRecords: records
        )

        XCTAssertEqual(Set(matches.prefix(2).map(\.club.id)), Set([realLongClubID, realShortClubID]))
        XCTAssertEqual(Set(matches.prefix(2).map(\.distance)), Set([170, 130]))
        XCTAssertEqual(matches.last?.club.id, supplementalClubID)
        XCTAssertEqual(matches.last?.distance, 151)
        XCTAssertEqual(matches.map(\.isSupplemental), [false, false, true])
        XCTAssertEqual(matches.last?.formattedDistance, "(151)")
    }

    func testRealModeTargetMatchesCanAppendCloserManualSupplementalWhenOnlyOneRealMatchExists() {
        let realClubID = UUID()
        let supplementalClubID = UUID()
        let clubs = [
            Club(id: realClubID, profileID: profileID, clubType: .fiveIron),
            Club(
                id: supplementalClubID,
                profileID: profileID,
                clubType: .sixIron,
                normalDistances: SwingDistanceSet(half: 166)
            )
        ]
        let records = [
            ShotRecord(
                profileID: profileID,
                clubID: realClubID,
                category: .normal,
                power: .half,
                distance: 160,
                strikeQuality: .pure,
                direction: .straight
            )
        ]

        let matches = matcher.closestMatches(
            targetYardage: 165,
            clubs: clubs,
            filter: .normal,
            valueMode: .real,
            shotRecords: records
        )

        XCTAssertEqual(matches.map(\.club.id), [realClubID, supplementalClubID])
        XCTAssertEqual(matches.map(\.distance), [160, 166])
        XCTAssertEqual(matches.map(\.isSupplemental), [false, true])
        XCTAssertEqual(matches.last?.formattedDistance, "(166)")
    }

    func testManualModeTargetMatchesCanAppendCloserRealSupplementalResult() {
        let manualLongClubID = UUID()
        let manualShortClubID = UUID()
        let supplementalClubID = UUID()
        let clubs = [
            Club(
                id: manualLongClubID,
                profileID: profileID,
                clubType: .sevenIron,
                normalDistances: SwingDistanceSet(full: 170)
            ),
            Club(
                id: manualShortClubID,
                profileID: profileID,
                clubType: .nineIron,
                normalDistances: SwingDistanceSet(full: 130)
            ),
            Club(id: supplementalClubID, profileID: profileID, clubType: .pitchingWedge)
        ]
        let records = [
            ShotRecord(
                profileID: profileID,
                clubID: supplementalClubID,
                category: .normal,
                power: .full,
                distance: 151,
                strikeQuality: .pure,
                direction: .straight
            )
        ]

        let matches = matcher.closestMatches(
            targetYardage: 150,
            clubs: clubs,
            valueMode: .manual,
            shotRecords: records
        )

        XCTAssertEqual(matches.map(\.club.id), [manualLongClubID, manualShortClubID, supplementalClubID])
        XCTAssertEqual(matches.map(\.distance), [170, 130, 151])
        XCTAssertEqual(matches.map(\.isSupplemental), [false, false, true])
    }

    func testDisplayResolverMarksFallbackDistancesAsSupplemental() {
        let clubID = UUID()
        let club = Club(
            id: clubID,
            profileID: profileID,
            clubType: .sandWedge,
            normalDistances: SwingDistanceSet(full: 100)
        )
        let records = [
            ShotRecord(
                profileID: profileID,
                clubID: clubID,
                category: .normal,
                power: .half,
                distance: 70,
                strikeQuality: .pure,
                direction: .straight
            )
        ]
        let resolver = DistanceValueResolver()

        let manualEntries = resolver
            .displayEntries(for: club, filter: .normal, mode: .manual, shotRecords: records)
        let realEntries = resolver
            .displayEntries(for: club, filter: .normal, mode: .real, shotRecords: records)

        XCTAssertEqual(manualEntries.first(where: { $0.label == .half })?.resolvedValue(for: .manual)?.formattedDistance, "(70)")
        XCTAssertEqual(realEntries.first(where: { $0.label == .full })?.resolvedValue(for: .real)?.formattedDistance, "(100)")
    }

    func testFlopOnlyWedgeDisplaysNormalPlaceholderAndFlopSection() {
        let club = Club(
            profileID: profileID,
            clubType: .lobWedge,
            wedgeLoft: 60,
            flopDistances: SwingDistanceSet(full: 50, half: 35)
        )
        let resolver = DistanceValueResolver()

        let sections = resolver.displaySections(for: club, filter: .normal, mode: .manual, shotRecords: [])

        XCTAssertEqual(sections.map(\.title), ["Normal", "Flop"])
        XCTAssertTrue(sections[0].entries.allSatisfy { $0.resolvedValue(for: .manual) == nil })
        XCTAssertEqual(sections[1].entries.first?.resolvedValue(for: .manual)?.distance, 50)
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
