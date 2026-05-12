import XCTest
@testable import GolfYardageCheatsheet

final class GolfBagRepositoryTests: XCTestCase {
    func testCreateProfileTrimsNameAndSelectsProfile() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)

        let profile = try repository.createProfile(name: "  Rod  ")
        let data = try repository.loadData()

        XCTAssertEqual(profile.name, "Rod")
        XCTAssertEqual(data.selectedProfileID, profile.id)
        XCTAssertEqual(data.profiles, [profile])
    }

    func testCreateProfileRejectsBlankName() {
        let repository = GolfBagRepository(store: InMemoryGolfBagStore())

        XCTAssertThrowsError(try repository.createProfile(name: "   ")) { error in
            XCTAssertEqual(error as? GolfBagRepositoryError, .profileNameRequired)
        }
    }

    func testSaveClubRequiresExistingProfile() {
        let repository = GolfBagRepository(store: InMemoryGolfBagStore())
        let club = Club(
            profileID: UUID(),
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet(full: 155)
        )

        XCTAssertThrowsError(try repository.saveClub(club)) { error in
            XCTAssertEqual(error as? GolfBagRepositoryError, .profileNotFound)
        }
    }

    func testSaveClubPersistsValidClub() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let club = Club(
            profileID: profile.id,
            clubType: .gapWedge,
            wedgeLoft: 50,
            swingDistances: SwingDistanceSet(full: 110)
        )

        try repository.saveClub(club)

        XCTAssertEqual(try repository.clubs(for: profile.id), [club])
    }

    func testSaveClubRejectsInvalidClub() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let club = Club(
            profileID: profile.id,
            clubType: .driver,
            swingDistances: SwingDistanceSet()
        )

        XCTAssertThrowsError(try repository.saveClub(club)) { error in
            XCTAssertEqual(
                error as? GolfBagRepositoryError,
                .invalidClub([.missingSwingDistance])
            )
        }
    }

    func testSetClubInactiveKeepsClubButHidesFromActiveList() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let club = Club(
            profileID: profile.id,
            clubType: .eightIron,
            swingDistances: SwingDistanceSet(full: 145)
        )

        try repository.saveClub(club)
        try repository.setClubActive(false, clubID: club.id)

        XCTAssertEqual(try repository.clubs(for: profile.id).count, 1)
        XCTAssertTrue(try repository.clubs(for: profile.id, includeInactive: false).isEmpty)
    }

    func testDeleteClubRemovesClubCompletely() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let club = Club(
            profileID: profile.id,
            clubType: .putter,
            putterDistances: PutterDistanceSet(short: 3)
        )

        try repository.saveClub(club)
        try repository.deleteClub(id: club.id)

        XCTAssertTrue(try repository.clubs(for: profile.id).isEmpty)
    }
}

private final class InMemoryGolfBagStore: GolfBagStore {
    private var data: GolfBagData = .empty

    func load() throws -> GolfBagData {
        data
    }

    func save(_ data: GolfBagData) throws {
        self.data = data
    }
}

