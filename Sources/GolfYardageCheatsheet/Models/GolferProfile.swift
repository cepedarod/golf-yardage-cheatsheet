import Foundation

public struct GolferProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var shotTrackingMode: ShotTrackingMode
    public var homeBaseCity: String
    public var homeBaseAltitudeFeet: Double
    public var altitudeCalculationMode: AltitudeCalculationMode
    public var createdAt: Date
    public var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case shotTrackingMode
        case homeBaseCity
        case homeBaseAltitudeFeet
        case altitudeCalculationMode
        case createdAt
        case updatedAt
    }

    public init(
        id: UUID = UUID(),
        name: String,
        shotTrackingMode: ShotTrackingMode = .gps,
        homeBaseCity: String = AltitudeDefaults.chicagoCity,
        homeBaseAltitudeFeet: Double = AltitudeDefaults.chicagoFeet,
        altitudeCalculationMode: AltitudeCalculationMode = .adjustForAltitude,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.shotTrackingMode = shotTrackingMode
        self.homeBaseCity = homeBaseCity
        self.homeBaseAltitudeFeet = homeBaseAltitudeFeet
        self.altitudeCalculationMode = altitudeCalculationMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        shotTrackingMode = try container.decodeIfPresent(ShotTrackingMode.self, forKey: .shotTrackingMode) ?? .gps
        homeBaseCity = try container.decodeIfPresent(String.self, forKey: .homeBaseCity) ?? AltitudeDefaults.chicagoCity
        homeBaseAltitudeFeet = try container.decodeIfPresent(Double.self, forKey: .homeBaseAltitudeFeet) ?? AltitudeDefaults.chicagoFeet
        altitudeCalculationMode = try container.decodeIfPresent(AltitudeCalculationMode.self, forKey: .altitudeCalculationMode) ?? .adjustForAltitude
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

public enum AltitudeDefaults {
    public static let chicagoCity = "Chicago, IL"
    public static let chicagoFeet = 594.0
    public static let adjustmentThresholdFeet = 1_000.0
    public static let distanceModifierPerFoot = 0.00001
}

public enum ShotTrackingMode: String, CaseIterable, Codable, Equatable, Sendable {
    case gps
    case manual

    public var displayName: String {
        switch self {
        case .gps:
            "GPS"
        case .manual:
            "Manual"
        }
    }
}

public enum AltitudeCalculationMode: String, CaseIterable, Codable, Equatable, Sendable {
    case adjustForAltitude
    case ignoreAltitude

    public var displayName: String {
        switch self {
        case .adjustForAltitude:
            "Adjust for Altitude"
        case .ignoreAltitude:
            "Ignore Altitude"
        }
    }
}

public enum RoundDistanceTrackingMode: String, CaseIterable, Codable, Equatable, Sendable {
    case accountForAltitude
    case ignoreAltitude

    public var displayName: String {
        switch self {
        case .accountForAltitude:
            "Account for Altitude"
        case .ignoreAltitude:
            "Ignore Altitude"
        }
    }
}

public struct AltitudeDistanceCalculator: Sendable {
    public init() {}

    public func shouldAdjust(from homeBaseAltitudeFeet: Double, to altitudeFeet: Double) -> Bool {
        abs(altitudeFeet - homeBaseAltitudeFeet) > AltitudeDefaults.adjustmentThresholdFeet
    }

    public func distanceModifier(homeBaseAltitudeFeet: Double, altitudeFeet: Double) -> Double {
        guard shouldAdjust(from: homeBaseAltitudeFeet, to: altitudeFeet) else {
            return 1
        }

        return max(0, 1 + ((altitudeFeet - homeBaseAltitudeFeet) * AltitudeDefaults.distanceModifierPerFoot))
    }

    public func expectedDistance(
        homeBaseDistanceYards: Int,
        homeBaseAltitudeFeet: Double,
        roundAltitudeFeet: Double
    ) -> Int {
        let modifier = distanceModifier(
            homeBaseAltitudeFeet: homeBaseAltitudeFeet,
            altitudeFeet: roundAltitudeFeet
        )

        return Int((Double(homeBaseDistanceYards) * modifier).rounded())
    }

    public func normalizedHomeBaseDistance(
        recordedDistanceYards: Int,
        shotAltitudeFeet: Double,
        homeBaseAltitudeFeet: Double
    ) -> Int {
        let modifier = distanceModifier(
            homeBaseAltitudeFeet: homeBaseAltitudeFeet,
            altitudeFeet: shotAltitudeFeet
        )

        guard modifier > 0 else {
            return recordedDistanceYards
        }

        return Int((Double(recordedDistanceYards) / modifier).rounded())
    }
}

public struct DistanceAdjustmentContext: Equatable, Sendable {
    public var homeBaseAltitudeFeet: Double
    public var targetAltitudeFeet: Double

    private var calculator: AltitudeDistanceCalculator {
        AltitudeDistanceCalculator()
    }

    public init(homeBaseAltitudeFeet: Double, targetAltitudeFeet: Double) {
        self.homeBaseAltitudeFeet = homeBaseAltitudeFeet
        self.targetAltitudeFeet = targetAltitudeFeet
    }

    public func adjustedHomeBaseDistance(_ distanceYards: Int) -> Int {
        calculator.expectedDistance(
            homeBaseDistanceYards: distanceYards,
            homeBaseAltitudeFeet: homeBaseAltitudeFeet,
            roundAltitudeFeet: targetAltitudeFeet
        )
    }

    public func adjustedRecordedDistance(_ distanceYards: Int, shotAltitudeFeet: Double) -> Int {
        let normalizedDistance = calculator.normalizedHomeBaseDistance(
            recordedDistanceYards: distanceYards,
            shotAltitudeFeet: shotAltitudeFeet,
            homeBaseAltitudeFeet: homeBaseAltitudeFeet
        )

        return adjustedHomeBaseDistance(normalizedDistance)
    }
}

public struct GolfRound: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var profileID: UUID
    public var name: String
    public var startedAt: Date
    public var endedAt: Date?
    public var courseName: String?
    public var nameWasEdited: Bool
    public var altitudeFeet: Double?
    public var distanceTrackingMode: RoundDistanceTrackingMode

    private enum CodingKeys: String, CodingKey {
        case id
        case profileID
        case name
        case startedAt
        case endedAt
        case courseName
        case nameWasEdited
        case altitudeFeet
        case distanceTrackingMode
    }

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        name: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        courseName: String? = nil,
        nameWasEdited: Bool = false,
        altitudeFeet: Double? = nil,
        distanceTrackingMode: RoundDistanceTrackingMode = .accountForAltitude
    ) {
        self.id = id
        self.profileID = profileID
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.courseName = courseName
        self.nameWasEdited = nameWasEdited
        self.altitudeFeet = altitudeFeet
        self.distanceTrackingMode = distanceTrackingMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        profileID = try container.decode(UUID.self, forKey: .profileID)
        name = try container.decode(String.self, forKey: .name)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        courseName = try container.decodeIfPresent(String.self, forKey: .courseName)
        nameWasEdited = try container.decodeIfPresent(Bool.self, forKey: .nameWasEdited) ?? false
        altitudeFeet = try container.decodeIfPresent(Double.self, forKey: .altitudeFeet)
        distanceTrackingMode = try container.decodeIfPresent(RoundDistanceTrackingMode.self, forKey: .distanceTrackingMode) ?? .accountForAltitude
    }

    public var isCompleted: Bool {
        endedAt != nil
    }
}
