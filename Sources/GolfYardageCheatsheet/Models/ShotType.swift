import Foundation

public enum ShotType: String, CaseIterable, Codable, Equatable, Sendable {
    case normal = "Normal"
    case punch = "Punch"
    case flop = "Flop"
}

public enum DistanceValueMode: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case manual
    case real

    public var displayName: String {
        switch self {
        case .manual:
            "Manual"
        case .real:
            "Real"
        }
    }

    public var supplementalMode: DistanceValueMode {
        switch self {
        case .manual:
            .real
        case .real:
            .manual
        }
    }
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

public enum GrassType: String, CaseIterable, Codable, Equatable, Sendable {
    case fairway
    case rough
    case deepRough

    public var displayName: String {
        switch self {
        case .fairway:
            "Fairway"
        case .rough:
            "Rough"
        case .deepRough:
            "Deep Rough"
        }
    }
}

public enum ShotDistanceSource: String, CaseIterable, Codable, Equatable, Sendable {
    case manual
    case gps
    case editedGPS

    public var displayName: String {
        switch self {
        case .manual:
            "Manual"
        case .gps:
            "GPS"
        case .editedGPS:
            "Edited GPS"
        }
    }
}

public enum GPSConfidence: String, CaseIterable, Codable, Equatable, Sendable {
    case green
    case yellow
    case orange
    case red

    public var displayName: String {
        switch self {
        case .green:
            "High"
        case .yellow:
            "Good"
        case .orange:
            "Caution"
        case .red:
            "Low"
        }
    }

    public static func confidence(forEstimatedUncertaintyYards uncertainty: Double) -> GPSConfidence {
        if uncertainty <= 3 {
            return .green
        }

        if uncertainty <= 7 {
            return .yellow
        }

        if uncertainty < 10 {
            return .orange
        }

        return .red
    }
}

public struct ShotGPSMeasurement: Codable, Equatable, Sendable {
    public var measuredDistanceYards: Int
    public var estimatedUncertaintyYards: Double
    public var confidence: GPSConfidence
    public var startHorizontalAccuracyMeters: Double
    public var endHorizontalAccuracyMeters: Double
    public var capturedAt: Date

    public init(
        measuredDistanceYards: Int,
        estimatedUncertaintyYards: Double,
        confidence: GPSConfidence? = nil,
        startHorizontalAccuracyMeters: Double,
        endHorizontalAccuracyMeters: Double,
        capturedAt: Date = Date()
    ) {
        self.measuredDistanceYards = measuredDistanceYards
        self.estimatedUncertaintyYards = estimatedUncertaintyYards
        self.confidence = confidence ?? GPSConfidence.confidence(forEstimatedUncertaintyYards: estimatedUncertaintyYards)
        self.startHorizontalAccuracyMeters = startHorizontalAccuracyMeters
        self.endHorizontalAccuracyMeters = endHorizontalAccuracyMeters
        self.capturedAt = capturedAt
    }
}

public struct ShotRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var profileID: UUID
    public var clubID: UUID
    public var roundID: UUID?
    public var category: ShotCategory
    public var power: ShotPower
    public var distance: Int?
    public var distanceSource: ShotDistanceSource
    public var gpsMeasurement: ShotGPSMeasurement?
    public var strikeQuality: StrikeQuality
    public var direction: ShotDirection
    public var grassType: GrassType
    public var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case profileID
        case clubID
        case roundID
        case category
        case power
        case distance
        case distanceSource
        case gpsMeasurement
        case strikeQuality
        case direction
        case grassType
        case createdAt
    }

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        clubID: UUID,
        roundID: UUID? = nil,
        category: ShotCategory,
        power: ShotPower,
        distance: Int? = nil,
        distanceSource: ShotDistanceSource = .manual,
        gpsMeasurement: ShotGPSMeasurement? = nil,
        strikeQuality: StrikeQuality,
        direction: ShotDirection,
        grassType: GrassType = .fairway,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.profileID = profileID
        self.clubID = clubID
        self.roundID = roundID
        self.category = category
        self.power = power
        self.distance = distance
        self.distanceSource = distanceSource
        self.gpsMeasurement = gpsMeasurement
        self.strikeQuality = strikeQuality
        self.direction = direction
        self.grassType = grassType
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        profileID = try container.decode(UUID.self, forKey: .profileID)
        clubID = try container.decode(UUID.self, forKey: .clubID)
        roundID = try container.decodeIfPresent(UUID.self, forKey: .roundID)
        category = try container.decode(ShotCategory.self, forKey: .category)
        power = try container.decode(ShotPower.self, forKey: .power)
        distance = try container.decodeIfPresent(Int.self, forKey: .distance)
        distanceSource = try container.decodeIfPresent(ShotDistanceSource.self, forKey: .distanceSource) ?? .manual
        gpsMeasurement = try container.decodeIfPresent(ShotGPSMeasurement.self, forKey: .gpsMeasurement)
        strikeQuality = try container.decode(StrikeQuality.self, forKey: .strikeQuality)
        direction = try container.decode(ShotDirection.self, forKey: .direction)
        grassType = try container.decodeIfPresent(GrassType.self, forKey: .grassType) ?? .fairway
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

public struct ShotStatsCalculator: Sendable {
    public init() {}

    public func totalShots(
        for records: [ShotRecord],
        clubID: UUID,
        category: ShotCategory
    ) -> Int {
        records.filter {
            $0.clubID == clubID && $0.category == category
        }.count
    }

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

    public func strikeDistributionPercentages(
        for records: [ShotRecord],
        clubID: UUID,
        category: ShotCategory
    ) -> [StrikeQuality: Double] {
        distributionPercentages(
            for: records.filter { $0.clubID == clubID && $0.category == category },
            allCases: StrikeQuality.allCases,
            keyPath: \.strikeQuality
        )
    }

    public func directionDistributionPercentages(
        for records: [ShotRecord],
        clubID: UUID,
        category: ShotCategory
    ) -> [ShotDirection: Double] {
        distributionPercentages(
            for: records.filter { $0.clubID == clubID && $0.category == category },
            allCases: ShotDirection.allCases,
            keyPath: \.direction
        )
    }

    private func distributionPercentages<Value: CaseIterable & Hashable>(
        for records: [ShotRecord],
        allCases: Value.AllCases,
        keyPath: KeyPath<ShotRecord, Value>
    ) -> [Value: Double] where Value.AllCases: Collection {
        guard records.isEmpty == false else {
            return allCases.reduce(into: [:]) { result, value in
                result[value] = 0
            }
        }

        return allCases.reduce(into: [:]) { result, value in
            let matchingCount = records.filter { $0[keyPath: keyPath] == value }.count
            result[value] = Double(matchingCount) / Double(records.count) * 100
        }
    }
}
