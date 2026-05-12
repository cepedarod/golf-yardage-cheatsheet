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

    func testWedgesCannotUsePunchShotType() {
        let club = Club(
            profileID: profileID,
            clubType: .sandWedge,
            shotType: .punch,
            swingDistances: SwingDistanceSet(full: 90)
        )

        XCTAssertTrue(validator.validate(club).contains(.invalidWedgeShotType))
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
}

