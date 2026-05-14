import Foundation

public enum ShotType: String, CaseIterable, Codable, Equatable, Sendable {
    case normal = "Normal"
    case punch = "Punch"
    case flop = "Flop"
}

public enum ShotCategory: String, CaseIterable, Codable, Equatable, Sendable {
    case normal
    case lowTrajectory
    case flop

    public var displayName: String {
        switch self {
        case .normal:
            "Normal"
        case .lowTrajectory:
            "Low Trajectory"
        case .flop:
            "Flop"
        }
    }
}

public enum ShotPower: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case full
    case threeQuarter
    case half
    case quarter
    case stinger
    case punch
    case softPunch
    case chip

    public var displayName: String {
        switch self {
        case .full:
            "Full"
        case .threeQuarter:
            "3/4"
        case .half:
            "Half"
        case .quarter:
            "Quarter"
        case .stinger:
            "Stinger"
        case .punch:
            "Punch"
        case .softPunch:
            "Soft Punch"
        case .chip:
            "Chip"
        }
    }

}

public enum StrikeQuality: String, CaseIterable, Codable, Equatable, Sendable {
    case thin
    case pure
    case chunk

    public var displayName: String {
        switch self {
        case .thin:
            "Thin"
        case .pure:
            "Pure"
        case .chunk:
            "Chunk"
        }
    }
}

public enum ShotDirection: String, CaseIterable, Codable, Equatable, Sendable {
    case hook
    case draw
    case straight
    case fade
    case slice

    public var displayName: String {
        switch self {
        case .hook:
            "Hook"
        case .draw:
            "Draw"
        case .straight:
            "Straight"
        case .fade:
            "Fade"
        case .slice:
            "Slice"
        }
    }
}

public struct ShotRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var profileID: UUID
    public var clubID: UUID
    public var category: ShotCategory
    public var power: ShotPower
    public var distance: Int?
    public var strikeQuality: StrikeQuality
    public var direction: ShotDirection
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        clubID: UUID,
        category: ShotCategory,
        power: ShotPower,
        distance: Int? = nil,
        strikeQuality: StrikeQuality,
        direction: ShotDirection,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.profileID = profileID
        self.clubID = clubID
        self.category = category
        self.power = power
        self.distance = distance
        self.strikeQuality = strikeQuality
        self.direction = direction
        self.createdAt = createdAt
    }
}

public struct ShotStatsCalculator: Sendable {
    public init() {}

    public func averageDistance(
        for records: [ShotRecord],
        clubID: UUID,
        category: ShotCategory,
        power: ShotPower
    ) -> Double? {
        let distances = records.compactMap { record -> Int? in
            guard record.clubID == clubID,
                  record.category == category,
                  record.power == power,
                  record.strikeQuality == .pure else {
                return nil
            }

            return record.distance
        }

        guard distances.isEmpty == false else {
            return nil
        }

        return Double(distances.reduce(0, +)) / Double(distances.count)
    }

    public func averageDistances(
        for records: [ShotRecord],
        clubID: UUID,
        category: ShotCategory
    ) -> [ShotPower: Double] {
        let powers: [ShotPower] = {
            switch category {
            case .normal, .flop:
                [.full, .threeQuarter, .half, .quarter]
            case .lowTrajectory:
                [.stinger, .punch, .softPunch, .chip]
            }
        }()

        return powers.reduce(into: [:]) { result, power in
            if let average = averageDistance(for: records, clubID: clubID, category: category, power: power) {
                result[power] = average
            }
        }
    }
}
