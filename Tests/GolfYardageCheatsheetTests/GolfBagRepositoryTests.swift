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

    func testSaveClubUpdatesExistingClubWithoutDuplicating() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let createdAt = Date(timeIntervalSince1970: 100)
        let original = Club(
            profileID: profile.id,
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet(full: 155),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let edited = Club(
            id: original.id,
            profileID: profile.id,
            nickname: "Knockdown",
            clubType: .sevenIron,
            shotType: .punch,
            swingDistances: SwingDistanceSet(full: 145, threeQuarter: 132),
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        try repository.saveClub(original)
        try repository.saveClub(edited)

        XCTAssertEqual(try repository.clubs(for: profile.id), [edited])
    }

    func testSaveClubRejectsCrossProfileOverwriteAndKeepsOriginal() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let firstProfile = try repository.createProfile(name: "Rod")
        let secondProfile = try repository.createProfile(name: "Friend")
        let original = Club(
            profileID: firstProfile.id,
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet(full: 155)
        )
        let crossProfileEdit = Club(
            id: original.id,
            profileID: secondProfile.id,
            clubType: .eightIron,
            swingDistances: SwingDistanceSet(full: 145)
        )

        try repository.saveClub(original)

        XCTAssertThrowsError(try repository.saveClub(crossProfileEdit)) { error in
            XCTAssertEqual(error as? GolfBagRepositoryError, .clubDoesNotBelongToProfile)
        }
        XCTAssertEqual(try repository.clubs(for: firstProfile.id), [original])
        XCTAssertTrue(try repository.clubs(for: secondProfile.id).isEmpty)
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

    func testSaveShotRecordPersistsOptionalDistanceAndTimestamp() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let club = Club(
            profileID: profile.id,
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet(full: 155)
        )
        let createdAt = Date(timeIntervalSince1970: 500)
        let record = ShotRecord(
            profileID: profile.id,
            clubID: club.id,
            category: .normal,
            power: .full,
            distance: nil,
            strikeQuality: .pure,
            direction: .straight,
            createdAt: createdAt
        )

        try repository.saveClub(club)
        try repository.saveShotRecord(record)

        XCTAssertEqual(try repository.shotRecords(for: profile.id), [record])
        XCTAssertEqual(try repository.loadData().shotRecords.first?.createdAt, createdAt)
    }

    func testSaveShotRecordRejectsInvalidPowerForCategory() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let club = Club(
            profileID: profile.id,
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet(full: 155)
        )
        let record = ShotRecord(
            profileID: profile.id,
            clubID: club.id,
            category: .normal,
            power: .stinger,
            distance: 150,
            strikeQuality: .pure,
            direction: .straight
        )

        try repository.saveClub(club)

        XCTAssertThrowsError(try repository.saveShotRecord(record)) { error in
            XCTAssertEqual(
                error as? GolfBagRepositoryError,
                .invalidShotRecord([.unsupportedPowerForCategory])
            )
        }
    }

    func testShotAveragesIgnoreMissingDistanceAndNonPureStrikes() {
        let clubID = UUID()
        let calculator = ShotStatsCalculator()
        let records = [
            ShotRecord(
                profileID: UUID(),
                clubID: clubID,
                category: .normal,
                power: .full,
                distance: 100,
                strikeQuality: .pure,
                direction: .straight
            ),
            ShotRecord(
                profileID: UUID(),
                clubID: clubID,
                category: .normal,
                power: .full,
                distance: nil,
                strikeQuality: .pure,
                direction: .straight
            ),
            ShotRecord(
                profileID: UUID(),
                clubID: clubID,
                category: .normal,
                power: .full,
                distance: 160,
                strikeQuality: .thin,
                direction: .straight
            ),
            ShotRecord(
                profileID: UUID(),
                clubID: clubID,
                category: .normal,
                power: .full,
                distance: 120,
                strikeQuality: .pure,
                direction: .fade
            )
        ]

        XCTAssertEqual(
            calculator.averageDistance(for: records, clubID: clubID, category: .normal, power: .full),
            110
        )
    }

    func testMissingClubMutationsThrowClubNotFound() throws {
        let repository = GolfBagRepository(store: InMemoryGolfBagStore())

        XCTAssertThrowsError(try repository.setClubActive(false, clubID: UUID())) { error in
            XCTAssertEqual(error as? GolfBagRepositoryError, .clubNotFound)
        }
        XCTAssertThrowsError(try repository.deleteClub(id: UUID())) { error in
            XCTAssertEqual(error as? GolfBagRepositoryError, .clubNotFound)
        }
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
