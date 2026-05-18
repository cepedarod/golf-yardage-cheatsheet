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

    func testDeleteProfileRemovesProfileClubsAndShotRecords() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let firstProfile = try repository.createProfile(name: "Rod")
        let secondProfile = try repository.createProfile(name: "Friend")
        let firstClub = Club(
            profileID: firstProfile.id,
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet(full: 155)
        )
        let secondClub = Club(
            profileID: secondProfile.id,
            clubType: .driver,
            swingDistances: SwingDistanceSet(full: 250)
        )
        let firstRecord = ShotRecord(
            profileID: firstProfile.id,
            clubID: firstClub.id,
            category: .normal,
            power: .full,
            distance: 152,
            strikeQuality: .pure,
            direction: .straight
        )
        let secondRecord = ShotRecord(
            profileID: secondProfile.id,
            clubID: secondClub.id,
            category: .normal,
            power: .full,
            distance: 248,
            strikeQuality: .pure,
            direction: .straight
        )

        try repository.saveClub(firstClub)
        try repository.saveClub(secondClub)
        try repository.saveShotRecord(firstRecord)
        try repository.saveShotRecord(secondRecord)

        try repository.deleteProfile(id: firstProfile.id)

        XCTAssertEqual(try repository.profiles(), [secondProfile])
        XCTAssertThrowsError(try repository.clubs(for: firstProfile.id)) { error in
            XCTAssertEqual(error as? GolfBagRepositoryError, .profileNotFound)
        }
        XCTAssertEqual(try repository.clubs(for: secondProfile.id), [secondClub])
        XCTAssertEqual(try repository.shotRecords(for: secondProfile.id), [secondRecord])
        XCTAssertFalse(try repository.loadData().shotRecords.contains(firstRecord))
    }

    func testUpdateProfileShotTrackingModePersistsPreference() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let updatedAt = Date(timeIntervalSince1970: 250)

        try repository.updateProfileShotTrackingMode(profileID: profile.id, mode: .manual, now: updatedAt)

        let updatedProfile = try XCTUnwrap(try repository.profiles().first)
        XCTAssertEqual(updatedProfile.shotTrackingMode, .manual)
        XCTAssertEqual(updatedProfile.updatedAt, updatedAt)
    }

    func testRoundLifecycleTrimsNameAllowsRenameAndCompletion() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let startedAt = Date(timeIntervalSince1970: 100)
        let endedAt = Date(timeIntervalSince1970: 500)

        let startedRound = try repository.startRound(
            profileID: profile.id,
            name: "  Torrey Pines  ",
            courseName: "Torrey Pines",
            startedAt: startedAt
        )

        XCTAssertEqual(startedRound.name, "Torrey Pines")
        XCTAssertEqual(startedRound.courseName, "Torrey Pines")
        XCTAssertFalse(startedRound.nameWasEdited)
        XCTAssertEqual(try repository.rounds(for: profile.id), [startedRound])
        XCTAssertTrue(try repository.rounds(for: profile.id, includeActive: false).isEmpty)

        let renamedRound = try repository.updateRoundName(id: startedRound.id, name: "  Saturday Match  ")
        XCTAssertEqual(renamedRound.name, "Saturday Match")
        XCTAssertTrue(renamedRound.nameWasEdited)

        let completedRound = try repository.endRound(id: startedRound.id, endedAt: endedAt)
        XCTAssertEqual(completedRound.endedAt, endedAt)
        XCTAssertEqual(try repository.rounds(for: profile.id, includeActive: false), [completedRound])
    }

    func testRoundShotLookupAndDeleteRoundUnlinksShots() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let club = Club(
            profileID: profile.id,
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet(full: 155)
        )
        let round = try repository.startRound(profileID: profile.id, name: "Round May 18")
        let record = ShotRecord(
            profileID: profile.id,
            clubID: club.id,
            roundID: round.id,
            category: .normal,
            power: .full,
            distance: 152,
            strikeQuality: .pure,
            direction: .straight
        )

        try repository.saveClub(club)
        try repository.saveShotRecord(record)

        XCTAssertEqual(try repository.shotRecords(for: profile.id, roundID: round.id), [record])

        try repository.deleteRound(id: round.id)

        XCTAssertTrue(try repository.rounds(for: profile.id).isEmpty)
        let unlinkedRecord = try XCTUnwrap(try repository.shotRecords(for: profile.id).first)
        XCTAssertEqual(unlinkedRecord.id, record.id)
        XCTAssertNil(unlinkedRecord.roundID)
    }

    func testDeleteAllShotRecordsRemovesOnlySelectedProfileShots() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let firstProfile = try repository.createProfile(name: "Rod")
        let secondProfile = try repository.createProfile(name: "Friend")
        let firstClub = Club(
            profileID: firstProfile.id,
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet(full: 155)
        )
        let secondClub = Club(
            profileID: secondProfile.id,
            clubType: .driver,
            swingDistances: SwingDistanceSet(full: 250)
        )
        let firstRecord = ShotRecord(
            profileID: firstProfile.id,
            clubID: firstClub.id,
            category: .normal,
            power: .full,
            distance: 152,
            strikeQuality: .pure,
            direction: .straight
        )
        let secondRecord = ShotRecord(
            profileID: secondProfile.id,
            clubID: secondClub.id,
            category: .normal,
            power: .full,
            distance: 248,
            strikeQuality: .pure,
            direction: .straight
        )

        try repository.saveClub(firstClub)
        try repository.saveClub(secondClub)
        try repository.saveShotRecord(firstRecord)
        try repository.saveShotRecord(secondRecord)

        try repository.deleteAllShotRecords(for: firstProfile.id)

        XCTAssertTrue(try repository.shotRecords(for: firstProfile.id).isEmpty)
        XCTAssertEqual(try repository.shotRecords(for: secondProfile.id), [secondRecord])
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

    func testSaveShotRecordUpdatesExistingRecord() throws {
        let store = InMemoryGolfBagStore()
        let repository = GolfBagRepository(store: store)
        let profile = try repository.createProfile(name: "Rod")
        let club = Club(
            profileID: profile.id,
            clubType: .sevenIron,
            swingDistances: SwingDistanceSet(full: 155)
        )
        let original = ShotRecord(
            profileID: profile.id,
            clubID: club.id,
            category: .normal,
            power: .full,
            distance: 150,
            strikeQuality: .pure,
            direction: .straight
        )
        let edited = ShotRecord(
            id: original.id,
            profileID: profile.id,
            clubID: club.id,
            category: .normal,
            power: .half,
            distance: nil,
            strikeQuality: .thin,
            direction: .fade,
            createdAt: original.createdAt
        )

        try repository.saveClub(club)
        try repository.saveShotRecord(original)
        try repository.saveShotRecord(edited)

        XCTAssertEqual(try repository.shotRecords(for: profile.id), [edited])
    }

    func testDeleteShotRecordRemovesRecord() throws {
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
            power: .full,
            distance: 150,
            strikeQuality: .pure,
            direction: .straight
        )

        try repository.saveClub(club)
        try repository.saveShotRecord(record)
        try repository.deleteShotRecord(id: record.id)

        XCTAssertTrue(try repository.shotRecords(for: profile.id).isEmpty)
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

    func testShotStatsUseAllRecordsForTotalsAndDistributions() {
        let clubID = UUID()
        let calculator = ShotStatsCalculator()
        let records = [
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
                power: .half,
                distance: 90,
                strikeQuality: .thin,
                direction: .fade
            ),
            ShotRecord(
                profileID: UUID(),
                clubID: clubID,
                category: .normal,
                power: .quarter,
                distance: nil,
                strikeQuality: .chunk,
                direction: .fade
            ),
            ShotRecord(
                profileID: UUID(),
                clubID: clubID,
                category: .lowTrajectory,
                power: .stinger,
                distance: 120,
                strikeQuality: .pure,
                direction: .draw
            )
        ]

        XCTAssertEqual(calculator.totalShots(for: records, clubID: clubID, category: .normal), 3)
        XCTAssertEqual(
            calculator.strikeDistributionPercentages(for: records, clubID: clubID, category: .normal)[.pure] ?? -1,
            100.0 / 3.0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            calculator.directionDistributionPercentages(for: records, clubID: clubID, category: .normal)[.fade] ?? -1,
            200.0 / 3.0,
            accuracy: 0.001
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
        XCTAssertThrowsError(try repository.deleteShotRecord(id: UUID())) { error in
            XCTAssertEqual(error as? GolfBagRepositoryError, .shotRecordNotFound)
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
