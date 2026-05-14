import XCTest
@testable import GolfYardageCheatsheet

final class ClubValidatorTests: XCTestCase {
    private let profileID = UUID()
    private let validator = ClubValidator()

    func testNonPutterRequiresAtLeastOneSwingDistance() {
        let club = Club(
            profileID: profileID,
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet()
        )

        XCTAssertTrue(validator.validate(club).contains(.missingSwingDistance))
    }

    func testPutterRequiresAtLeastOnePutterDistance() {
        let club = Club(
            profileID: profileID,
            clubType: .putter,
            putterDistances: PutterDistanceSet()
        )

        XCTAssertTrue(validator.validate(club).contains(.missingPutterDistance))
    }

    func testValidWedgeLoftIsAccepted() {
        let club = Club(
            profileID: profileID,
            clubType: .gapWedge,
            wedgeLoft: 50,
            shotType: .normal,
            swingDistances: SwingDistanceSet(full: 110)
        )

        XCTAssertTrue(validator.isValid(club))
    }

    func testWedgeLoftMustBeBetweenThirtyAndEighty() {
        let lowLoftClub = Club(
            profileID: profileID,
            clubType: .sandWedge,
            wedgeLoft: 29,
            swingDistances: SwingDistanceSet(full: 95)
        )
        let highLoftClub = Club(
            profileID: profileID,
            clubType: .lobWedge,
            wedgeLoft: 81,
            swingDistances: SwingDistanceSet(full: 70)
        )

        XCTAssertTrue(validator.validate(lowLoftClub).contains(.wedgeLoftOutOfRange))
        XCTAssertTrue(validator.validate(highLoftClub).contains(.wedgeLoftOutOfRange))
    }

    func testWedgeLoftIsOnlyAllowedForWedges() {
        let club = Club(
            profileID: profileID,
            clubType: .sevenIron,
            wedgeLoft: 54,
            swingDistances: SwingDistanceSet(full: 155)
        )

        XCTAssertTrue(validator.validate(club).contains(.wedgeLoftNotAllowedForClubType))
    }

    func testWedgesCanUseLowTrajectoryDistances() {
        let club = Club(
            profileID: profileID,
            clubType: .sandWedge,
            shotType: .punch,
            swingDistances: SwingDistanceSet(full: 90)
        )

        XCTAssertTrue(validator.isValid(club))
    }

    func testNonWedgesCannotUseFlopShotType() {
        let club = Club(
            profileID: profileID,
            clubType: .eightIron,
            shotType: .flop,
            swingDistances: SwingDistanceSet(full: 140)
        )

        XCTAssertTrue(validator.validate(club).contains(.invalidNonWedgeShotType))
    }

    func testDistancesMustBePositive() {
        let club = Club(
            profileID: profileID,
            clubType: .driver,
            swingDistances: SwingDistanceSet(full: 0, half: -10)
        )

        let errors = validator.validate(club)

        XCTAssertTrue(errors.contains(.nonPositiveDistance(label: .full)))
        XCTAssertTrue(errors.contains(.nonPositiveDistance(label: .half)))
    }

    func testLowTrajectoryDistancesMustBePositive() {
        let club = Club(
            profileID: profileID,
            clubType: .fiveIron,
            lowTrajectoryDistances: LowTrajectoryDistanceSet(stinger: 0, punch: -5)
        )

        let errors = validator.validate(club)

        XCTAssertTrue(errors.contains(.nonPositiveLowTrajectoryDistance(power: .stinger)))
        XCTAssertTrue(errors.contains(.nonPositiveLowTrajectoryDistance(power: .punch)))
    }

    func testPutterCannotCarryShotTypeOrSwingDistancesFromCorruptData() {
        var club = Club(
            profileID: profileID,
            clubType: .putter,
            putterDistances: PutterDistanceSet(short: 3)
        )
        club.shotType = .normal
        club.swingDistances = SwingDistanceSet(full: 10)

        let errors = validator.validate(club)

        XCTAssertTrue(errors.contains(.putterCannotHaveShotType))
        XCTAssertTrue(errors.contains(.putterCannotHaveSwingDistances))
    }

    func testNonPutterCannotCarryPutterDistancesFromCorruptData() {
        let club = Club(
            profileID: profileID,
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet(full: 155),
            putterDistances: PutterDistanceSet(short: 3)
        )

        XCTAssertTrue(validator.validate(club).contains(.nonPutterCannotHavePutterDistances))
    }
}
