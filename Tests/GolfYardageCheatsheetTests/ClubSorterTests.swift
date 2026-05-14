import XCTest
@testable import GolfYardageCheatsheet

final class ClubSorterTests: XCTestCase {
    private let profileID = UUID()
    private let sorter = ClubSorter()

    func testDegreeSpecificWedgesSortByLoftAscending() {
        let wedge54 = Club(
            id: UUID(),
            profileID: profileID,
            clubType: .sandWedge,
            wedgeLoft: 54,
            normalDistances: SwingDistanceSet(full: 104),
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let wedge60 = Club(
            id: UUID(),
            profileID: profileID,
            clubType: .lobWedge,
            wedgeLoft: 60,
            flopDistances: SwingDistanceSet(full: 50),
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let wedge52 = Club(
            id: UUID(),
            profileID: profileID,
            clubType: .gapWedge,
            wedgeLoft: 52,
            normalDistances: SwingDistanceSet(full: 108),
            createdAt: Date(timeIntervalSince1970: 3)
        )

        let sorted = sorter.sortedForDistanceTab([wedge54, wedge60, wedge52])

        XCTAssertEqual(sorted.map(\.wedgeLoft), [52, 54, 60])
    }

    func testMixedWedgesWithFullDistancesSortByLongestNormalFullDistance() {
        let unspecifiedWedge = Club(
            id: UUID(),
            profileID: profileID,
            clubType: .gapWedge,
            normalDistances: SwingDistanceSet(full: 98)
        )
        let degreeWedge = Club(
            id: UUID(),
            profileID: profileID,
            clubType: .sandWedge,
            wedgeLoft: 54,
            normalDistances: SwingDistanceSet(full: 104)
        )

        let sorted = sorter.sortedForDistanceTab([unspecifiedWedge, degreeWedge])

        XCTAssertEqual(sorted.map(\.id), [degreeWedge.id, unspecifiedWedge.id])
    }

    func testMixedWedgesWithMissingFullDistancePutUnspecifiedWedgeFirst() {
        let unspecifiedWedge = Club(
            id: UUID(),
            profileID: profileID,
            clubType: .lobWedge,
            flopDistances: SwingDistanceSet(full: 50)
        )
        let degreeWedge = Club(
            id: UUID(),
            profileID: profileID,
            clubType: .sandWedge,
            wedgeLoft: 54,
            flopDistances: SwingDistanceSet(full: 75)
        )

        let sorted = sorter.sortedForDistanceTab([degreeWedge, unspecifiedWedge])

        XCTAssertEqual(sorted.map(\.id), [unspecifiedWedge.id, degreeWedge.id])
    }
}
