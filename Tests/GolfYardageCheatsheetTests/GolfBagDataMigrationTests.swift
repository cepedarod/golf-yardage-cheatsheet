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

    func testV2DataDecodesWithV3ShotAndProfileDefaults() throws {
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        let clubID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
        let recordID = UUID(uuidString: "00000000-0000-0000-0000-000000000303")!
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
        let legacyData = LegacyV2GolfBagData(
            profiles: [profile],
            clubs: [club],
            shotRecords: [record],
            selectedProfileID: profileID
        )

        let decoded = try JSONDecoder().decode(GolfBagData.self, from: JSONEncoder().encode(legacyData))

        XCTAssertEqual(decoded.schemaVersion, GolfBagData.currentSchemaVersion)
        XCTAssertTrue(decoded.rounds.isEmpty)
        XCTAssertEqual(decoded.profiles.first?.shotTrackingMode, .gps)
        XCTAssertEqual(decoded.shotRecords.first?.grassType, .fairway)
        XCTAssertEqual(decoded.shotRecords.first?.distanceSource, .manual)
        XCTAssertNil(decoded.shotRecords.first?.gpsMeasurement)
        XCTAssertNil(decoded.shotRecords.first?.roundID)
    }
}

private struct LegacyV2GolfBagData: Encodable {
    let profiles: [LegacyProfile]
    let clubs: [Club]
    let shotRecords: [LegacyShotRecord]
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
