import Foundation

public struct GolfBagData: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var profiles: [GolferProfile]
    public var clubs: [Club]
    public var shotRecords: [ShotRecord]
    public var selectedProfileID: UUID?
    public var schemaVersion: Int

    private enum CodingKeys: String, CodingKey {
        case profiles
        case clubs
        case shotRecords
        case selectedProfileID
        case schemaVersion
    }

    public init(
        profiles: [GolferProfile] = [],
        clubs: [Club] = [],
        shotRecords: [ShotRecord] = [],
        selectedProfileID: UUID? = nil,
        schemaVersion: Int = GolfBagData.currentSchemaVersion
    ) {
        self.profiles = profiles
        self.clubs = clubs
        self.shotRecords = shotRecords
        self.selectedProfileID = selectedProfileID
        self.schemaVersion = schemaVersion
    }

    public static let empty = GolfBagData()

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let decodedClubs = try container.decode([Club].self, forKey: .clubs)

        profiles = try container.decode([GolferProfile].self, forKey: .profiles)
        clubs = decodedSchemaVersion < Self.currentSchemaVersion
            ? ClubV2Migrator.migrate(decodedClubs)
            : decodedClubs
        shotRecords = try container.decodeIfPresent([ShotRecord].self, forKey: .shotRecords) ?? []
        selectedProfileID = try container.decodeIfPresent(UUID.self, forKey: .selectedProfileID)
        schemaVersion = Self.currentSchemaVersion
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(clubs, forKey: .clubs)
        try container.encode(shotRecords, forKey: .shotRecords)
        try container.encodeIfPresent(selectedProfileID, forKey: .selectedProfileID)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
    }

    public func clubs(for profileID: UUID) -> [Club] {
        clubs
            .filter { $0.profileID == profileID }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
    }
}

private enum ClubV2Migrator {
    static func migrate(_ clubs: [Club]) -> [Club] {
        Dictionary(grouping: clubs, by: ClubMergeKey.init)
            .values
            .flatMap(migrateGroup)
            .sorted(by: sortClubs)
    }

    private static func migrateGroup(_ group: [Club]) -> [Club] {
        let sortedGroup = group.sorted(by: sortClubs)

        guard let base = sortedGroup.first(where: isMergeBase) else {
            return sortedGroup.map(refreshed)
        }

        var merged = base
        merged.normalDistances = bestSwingDistances(in: sortedGroup, category: \.normalDistances)
        merged.lowTrajectoryDistances = bestLowTrajectoryDistances(in: sortedGroup)
        merged.flopDistances = bestSwingDistances(in: sortedGroup, category: \.flopDistances)
        merged.putterDistances = bestPutterDistances(in: sortedGroup)
        merged.isActive = sortedGroup.contains { $0.isActive }
        merged.createdAt = sortedGroup.map(\.createdAt).min() ?? base.createdAt
        merged.updatedAt = sortedGroup.map(\.updatedAt).max() ?? base.updatedAt
        merged.refreshCompatibilityFields(preferredShotType: .normal)

        return [merged]
    }

    private static func refreshed(_ club: Club) -> Club {
        var club = club
        club.refreshCompatibilityFields(preferredShotType: club.shotType)
        return club
    }

    private static func isMergeBase(_ club: Club) -> Bool {
        club.clubType == .putter || club.shotType == .normal || club.normalDistances != nil
    }

    private static func bestSwingDistances(
        in clubs: [Club],
        category: (Club) -> SwingDistanceSet?
    ) -> SwingDistanceSet? {
        let distances = SwingDistanceSet(
            full: bestDistance(in: clubs) { category($0)?.full },
            threeQuarter: bestDistance(in: clubs) { category($0)?.threeQuarter },
            half: bestDistance(in: clubs) { category($0)?.half },
            quarter: bestDistance(in: clubs) { category($0)?.quarter }
        )

        return distances.hasAtLeastOneDistance ? distances : nil
    }

    private static func bestLowTrajectoryDistances(in clubs: [Club]) -> LowTrajectoryDistanceSet? {
        let distances = LowTrajectoryDistanceSet(
            stinger: bestDistance(in: clubs) { $0.lowTrajectoryDistances?.stinger },
            punch: bestDistance(in: clubs) { $0.lowTrajectoryDistances?.punch },
            softPunch: bestDistance(in: clubs) { $0.lowTrajectoryDistances?.softPunch },
            chip: bestDistance(in: clubs) { $0.lowTrajectoryDistances?.chip }
        )

        return distances.hasAtLeastOneDistance ? distances : nil
    }

    private static func bestPutterDistances(in clubs: [Club]) -> PutterDistanceSet? {
        let distances = PutterDistanceSet(
            long: bestDistance(in: clubs) { $0.putterDistances?.long },
            medium: bestDistance(in: clubs) { $0.putterDistances?.medium },
            short: bestDistance(in: clubs) { $0.putterDistances?.short }
        )

        return distances.hasAtLeastOneDistance ? distances : nil
    }

    private static func bestDistance(in clubs: [Club], value: (Club) -> Int?) -> Int? {
        clubs
            .compactMap { club -> (distance: Int, updatedAt: Date, id: UUID)? in
                guard let distance = value(club) else {
                    return nil
                }

                return (distance, club.updatedAt, club.id)
            }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
            .first?
            .distance
    }

    private static func sortClubs(_ lhs: Club, _ rhs: Club) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private struct ClubMergeKey: Hashable {
    let profileID: UUID
    let clubType: ClubType
    let normalizedNickname: String
    let wedgeLoft: Int?

    init(club: Club) {
        profileID = club.profileID
        clubType = club.clubType
        normalizedNickname = club.nickname?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        wedgeLoft = club.wedgeLoft
    }
}
