import XCTest
@testable import GolfYardageCheatsheet

final class ClubDisplayNameFormatterTests: XCTestCase {
    private let profileID = UUID()
    private let formatter = ClubDisplayNameFormatter()

    func testWedgeLoftReplacesWedgeTypeWhenNicknameIsEmpty() {
        let club = Club(
            profileID: profileID,
            clubType: .sandWedge,
            wedgeLoft: 54,
            swingDistances: SwingDistanceSet(full: 95)
        )

        XCTAssertEqual(formatter.displayName(for: club), "54\u{00B0} Wedge")
    }

    func testWedgeLoftKeepsFlopSuffix() {
        let club = Club(
            profileID: profileID,
            clubType: .lobWedge,
            wedgeLoft: 60,
            shotType: .flop,
            swingDistances: SwingDistanceSet(full: 70)
        )

        XCTAssertEqual(formatter.displayName(for: club), "60\u{00B0} Wedge (Flop)")
    }

    func testNicknamePrefixesWedgeLoftAndKeepsFlopSuffix() {
        let club = Club(
            profileID: profileID,
            nickname: "Trusty",
            clubType: .sandWedge,
            wedgeLoft: 54,
            shotType: .flop,
            swingDistances: SwingDistanceSet(full: 80)
        )

        XCTAssertEqual(formatter.displayName(for: club), "Trusty 54\u{00B0} Wedge (Flop)")
    }

    func testNicknamePrefixesClubTypeAndKeepsLowTrajectorySuffix() {
        let club = Club(
            profileID: profileID,
            nickname: "Stinger",
            clubType: .fourIron,
            shotType: .punch,
            swingDistances: SwingDistanceSet(full: 190)
        )

        XCTAssertEqual(formatter.displayName(for: club), "Stinger 4 Iron (Low Trajectory)")
    }

    func testNicknamePrefixesDriverType() {
        let club = Club(
            profileID: profileID,
            nickname: "Qi10",
            clubType: .driver,
            swingDistances: SwingDistanceSet(full: 255)
        )

        XCTAssertEqual(formatter.displayName(for: club), "Qi10 Driver")
    }
}
