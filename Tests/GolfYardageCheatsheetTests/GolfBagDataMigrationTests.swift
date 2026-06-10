import XCTest
@testable import GolfYardageCheatsheet

final class GolfBagDataMigrationTests: XCTestCase {
    func testV1ShotTypeClubsMergeIntoV2DistanceCategories() throws {
        let profile = GolferProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Rod",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let baseID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let punchID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        let flopID = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
        let legacyData = LegacyGolfBagData(
            profiles: [profile],
            clubs: [
                LegacyClub(
                    id: baseID,
                    profileID: profile.id,
                    nickname: "Cleveland",
                    clubType: .sandWedge,
                    wedgeLoft: 54,
                    shotType: .normal,
                    isActive: true,
                    swingDistances: SwingDistanceSet(full: 100, threeQuarter: 85),
                    createdAt: Date(timeIntervalSince1970: 100),
                    updatedAt: Date(timeIntervalSince1970: 110)
                ),
                LegacyClub(
                    id: punchID,
                    profileID: profile.id,
                    nickname: "Cleveland",
                    clubType: .sandWedge,
                    wedgeLoft: 54,
                    shotType: .punch,
                    isActive: false,
                    swingDistances: SwingDistanceSet(full: 90, threeQuarter: 78),
                    createdAt: Date(timeIntervalSince1970: 90),
                    updatedAt: Date(timeIntervalSince1970: 120)
                ),
                LegacyClub(
                    id: flopID,
                    profileID: profile.id,
                    nickname: " Cleveland ",
                    clubType: .sandWedge,
                    wedgeLoft: 54,
                    shotType: .flop,
                    isActive: true,
                    swingDistances: SwingDistanceSet(full: 60, half: 35),
                    createdAt: Date(timeIntervalSince1970: 95),
                    updatedAt: Date(timeIntervalSince1970: 130)
                )
            ],
            selectedProfileID: profile.id
        )

        let decoded = try JSONDecoder().decode(GolfBagData.self, from: JSONEncoder().encode(legacyData))

        XCTAssertEqual(decoded.schemaVersion, GolfBagData.currentSchemaVersion)
        XCTAssertEqual(decoded.clubs.count, 1)

        let merged = try XCTUnwrap(decoded.clubs.first)
        XCTAssertEqual(merged.id, baseID)
        XCTAssertEqual(merged.normalDistances?.full, 100)
        XCTAssertEqual(merged.normalDistances?.threeQuarter, 85)
        XCTAssertEqual(merged.lowTrajectoryDistances?.stinger, 90)
        XCTAssertEqual(merged.lowTrajectoryDistances?.punch, 78)
        XCTAssertEqual(merged.flopDistances?.full, 60)
        XCTAssertEqual(merged.flopDistances?.half, 35)
        XCTAssertTrue(merged.isActive)
        XCTAssertEqual(merged.createdAt, Date(timeIntervalSince1970: 90))
        XCTAssertEqual(merged.updatedAt, Date(timeIntervalSince1970: 130))
    }

    func testV1SpecialtyClubWithoutBaseIsPreserved() throws {
        let profile = GolferProfile(name: "Rod")
        let clubID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        let legacyData = LegacyGolfBagData(
            profiles: [profile],
            clubs: [
                LegacyClub(
                    id: clubID,
                    profileID: profile.id,
                    nickname: nil,
                    clubType: .fourIron,
                    wedgeLoft: nil,
                    shotType: .punch,
                    isActive: true,
                    swingDistances: SwingDistanceSet(full: 175, half: 130)
                )
            ],
            selectedProfileID: profile.id
        )

        let decoded = try JSONDecoder().decode(GolfBagData.self, from: JSONEncoder().encode(legacyData))

        let club = try XCTUnwrap(decoded.clubs.first)
        XCTAssertEqual(decoded.clubs.count, 1)
        XCTAssertEqual(club.id, clubID)
        XCTAssertNil(club.normalDistances)
        XCTAssertEqual(club.lowTrajectoryDistances?.stinger, 175)
        XCTAssertEqual(club.lowTrajectoryDistances?.softPunch, 130)
        XCTAssertEqual(club.shotType, .punch)
    }

    func testV2DataDecodesWithV4ShotProfileAndRoundDefaults() throws {
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        let clubID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
        let recordID = UUID(uuidString: "00000000-0000-0000-0000-000000000303")!
        let roundID = UUID(uuidString: "00000000-0000-0000-0000-000000000304")!
        let profile = LegacyProfile(
            id: profileID,
            name: "Rod",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        let club = Club(
            id: clubID,
            profileID: profileID,
            clubType: .sevenIron,
            normalDistances: SwingDistanceSet(full: 155),
            createdAt: Date(timeIntervalSince1970: 30),
            updatedAt: Date(timeIntervalSince1970: 40)
        )
        let record = LegacyShotRecord(
            id: recordID,
            profileID: profileID,
            clubID: clubID,
            category: .normal,
            power: .full,
            distance: 151,
            strikeQuality: .pure,
            direction: .straight,
            createdAt: Date(timeIntervalSince1970: 50)
        )
        let round = LegacyRound(
            id: roundID,
            profileID: profileID,
            name: "Legacy Round",
            startedAt: Date(timeIntervalSince1970: 60),
            endedAt: Date(timeIntervalSince1970: 120),
            courseName: "Legacy Course",
            nameWasEdited: false
        )
        let legacyData = LegacyV2GolfBagData(
            profiles: [profile],
            clubs: [club],
            shotRecords: [record],
            rounds: [round],
            selectedProfileID: profileID
        )

        let decoded = try JSONDecoder().decode(GolfBagData.self, from: JSONEncoder().encode(legacyData))

        XCTAssertEqual(decoded.schemaVersion, GolfBagData.currentSchemaVersion)
        XCTAssertEqual(decoded.profiles.first?.shotTrackingMode, .gps)
        XCTAssertEqual(decoded.profiles.first?.analysisDateRange, .allTime)
        XCTAssertEqual(decoded.profiles.first?.averageDistanceGrassTypes, GolferProfile.defaultAverageDistanceGrassTypes)
        XCTAssertEqual(decoded.profiles.first?.acknowledgedOnboardingGuides, Set(ProfileOnboardingGuide.allCases))
        XCTAssertEqual(decoded.profiles.first?.homeBaseCity, AltitudeDefaults.chicagoCity)
        XCTAssertEqual(decoded.profiles.first?.homeBaseAltitudeFeet, AltitudeDefaults.chicagoFeet)
        XCTAssertEqual(decoded.profiles.first?.altitudeCalculationMode, .adjustForAltitude)
        XCTAssertEqual(decoded.shotRecords.first?.grassType, .fairway)
        XCTAssertEqual(decoded.shotRecords.first?.distanceSource, .manual)
        XCTAssertNil(decoded.shotRecords.first?.gpsMeasurement)
        XCTAssertEqual(decoded.shotRecords.first?.altitudeFeet, AltitudeDefaults.chicagoFeet)
        XCTAssertNil(decoded.shotRecords.first?.roundID)
        XCTAssertEqual(decoded.rounds.first?.altitudeFeet, nil)
        XCTAssertEqual(decoded.rounds.first?.distanceTrackingMode, .accountForAltitude)
    }
}

final class AltitudeDistanceCalculatorTests: XCTestCase {
    private let calculator = AltitudeDistanceCalculator()

    func testDistanceModifierOnlyAppliesAboveThreshold() {
        XCTAssertEqual(
            calculator.distanceModifier(homeBaseAltitudeFeet: 594, altitudeFeet: 1_594),
            1
        )
        XCTAssertEqual(
            calculator.distanceModifier(homeBaseAltitudeFeet: 594, altitudeFeet: 1_595),
            1.01001,
            accuracy: 0.00001
        )
    }

    func testExpectedDistanceCanIncreaseOrDecreaseForRoundAltitude() {
        XCTAssertEqual(
            calculator.expectedDistance(homeBaseDistanceYards: 150, homeBaseAltitudeFeet: 0, roundAltitudeFeet: 5_000),
            158
        )
        XCTAssertEqual(
            calculator.expectedDistance(homeBaseDistanceYards: 150, homeBaseAltitudeFeet: 5_000, roundAltitudeFeet: 0),
            143
        )
    }

    func testRecordedShotsNormalizeBackToHomeBase() {
        XCTAssertEqual(
            calculator.normalizedHomeBaseDistance(recordedDistanceYards: 158, shotAltitudeFeet: 5_000, homeBaseAltitudeFeet: 0),
            150
        )
        XCTAssertEqual(
            calculator.normalizedHomeBaseDistance(recordedDistanceYards: 142, shotAltitudeFeet: 0, homeBaseAltitudeFeet: 5_000),
            149
        )
    }
}

private struct LegacyV2GolfBagData: Encodable {
    let profiles: [LegacyProfile]
    let clubs: [Club]
    let shotRecords: [LegacyShotRecord]
    let rounds: [LegacyRound]
    let selectedProfileID: UUID?
    let schemaVersion = 2
}

private struct LegacyProfile: Encodable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
}

private struct LegacyShotRecord: Encodable {
    let id: UUID
    let profileID: UUID
    let clubID: UUID
    let category: ShotCategory
    let power: ShotPower
    let distance: Int?
    let strikeQuality: StrikeQuality
    let direction: ShotDirection
    let createdAt: Date
}

private struct LegacyRound: Encodable {
    let id: UUID
    let profileID: UUID
    let name: String
    let startedAt: Date
    let endedAt: Date?
    let courseName: String?
    let nameWasEdited: Bool
}

private struct LegacyGolfBagData: Encodable {
    let profiles: [GolferProfile]
    let clubs: [LegacyClub]
    let selectedProfileID: UUID?
}

private struct LegacyClub: Encodable {
    let id: UUID
    let profileID: UUID
    let nickname: String?
    let clubType: ClubType
    let wedgeLoft: Int?
    let shotType: ShotType?
    let isActive: Bool
    let swingDistances: SwingDistanceSet?
    let putterDistances: PutterDistanceSet?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        profileID: UUID,
        nickname: String? = nil,
        clubType: ClubType,
        wedgeLoft: Int? = nil,
        shotType: ShotType? = .normal,
        isActive: Bool = true,
        swingDistances: SwingDistanceSet? = nil,
        putterDistances: PutterDistanceSet? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 100),
        updatedAt: Date = Date(timeIntervalSince1970: 100)
    ) {
        self.id = id
        self.profileID = profileID
        self.nickname = nickname
        self.clubType = clubType
        self.wedgeLoft = wedgeLoft
        self.shotType = shotType
        self.isActive = isActive
        self.swingDistances = swingDistances
        self.putterDistances = putterDistances
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
