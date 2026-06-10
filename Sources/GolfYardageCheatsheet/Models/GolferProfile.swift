import Foundation

public struct GolferProfile: Codable, Equatable, Identifiable, Sendable {
    public static let defaultAverageDistanceGrassTypes: Set<GrassType> = [.fairway]

    public var id: UUID
    public var name: String
    public var shotTrackingMode: ShotTrackingMode
    public var analysisDateRange: AnalysisDateRange
    public var averageDistanceGrassTypes: Set<GrassType>
    public var acknowledgedOnboardingGuides: Set<ProfileOnboardingGuide>
    public var homeBaseCity: String
    public var homeBaseAltitudeFeet: Double
    public var altitudeCalculationMode: AltitudeCalculationMode
    public var createdAt: Date
    public var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case shotTrackingMode
        case analysisDateRange
        case averageDistanceGrassTypes
        case acknowledgedOnboardingGuides
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
        analysisDateRange: AnalysisDateRange = .allTime,
        averageDistanceGrassTypes: Set<GrassType> = GolferProfile.defaultAverageDistanceGrassTypes,
        acknowledgedOnboardingGuides: Set<ProfileOnboardingGuide> = [],
        homeBaseCity: String = AltitudeDefaults.chicagoCity,
        homeBaseAltitudeFeet: Double = AltitudeDefaults.chicagoFeet,
        altitudeCalculationMode: AltitudeCalculationMode = .adjustForAltitude,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.shotTrackingMode = shotTrackingMode
        self.analysisDateRange = analysisDateRange
        self.averageDistanceGrassTypes = averageDistanceGrassTypes
        self.acknowledgedOnboardingGuides = acknowledgedOnboardingGuides
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
        analysisDateRange = try container.decodeIfPresent(AnalysisDateRange.self, forKey: .analysisDateRange) ?? .allTime
        let decodedAverageDistanceGrassTypes = try container.decodeIfPresent(Set<GrassType>.self, forKey: .averageDistanceGrassTypes) ?? GolferProfile.defaultAverageDistanceGrassTypes
        averageDistanceGrassTypes = decodedAverageDistanceGrassTypes.isEmpty
            ? GolferProfile.defaultAverageDistanceGrassTypes
            : decodedAverageDistanceGrassTypes
        acknowledgedOnboardingGuides = try container.decodeIfPresent(Set<ProfileOnboardingGuide>.self, forKey: .acknowledgedOnboardingGuides) ?? Set(ProfileOnboardingGuide.allCases)
        homeBaseCity = try container.decodeIfPresent(String.self, forKey: .homeBaseCity) ?? AltitudeDefaults.chicagoCity
        homeBaseAltitudeFeet = try container.decodeIfPresent(Double.self, forKey: .homeBaseAltitudeFeet) ?? AltitudeDefaults.chicagoFeet
        altitudeCalculationMode = try container.decodeIfPresent(AltitudeCalculationMode.self, forKey: .altitudeCalculationMode) ?? .adjustForAltitude
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

public enum ProfileOnboardingGuide: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case distance
    case addClub
    case profile

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .distance:
            "Distance Tab"
        case .addClub:
            "Adding Clubs"
        case .profile:
            "Profile Controls"
        }
    }

    public var message: String {
        switch self {
        case .distance:
            "This is the distance tab, use it as your on-course cheat sheet. Enter the distance you need to hit as a target and the app will show you your best options."
        case .addClub:
            "Add baseline hit distances you know for each swing type. Every distance field is optional, and you can add or edit values later."
        case .profile:
            "The profile tab is where you can set how Caddie Cat processes and displays shot data. Changes here will update other pages real time."
        }
    }
}

public enum AnalysisDateRangeKind: String, CaseIterable, Codable, Equatable, Sendable {
    case allTime
    case lastYear
    case lastMonth
    case custom

    public var displayName: String {
        switch self {
        case .allTime:
            "All Time"
        case .lastYear:
            "Last Year"
        case .lastMonth:
            "Last Month"
        case .custom:
            "Custom"
        }
    }
}

public struct AnalysisDateRange: Codable, Equatable, Sendable {
    public var kind: AnalysisDateRangeKind
    public var customStartDate: Date?
    public var customEndDate: Date?

    public init(
        kind: AnalysisDateRangeKind = .allTime,
        customStartDate: Date? = nil,
        customEndDate: Date? = nil
    ) {
        self.kind = kind
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
    }

    public static let allTime = AnalysisDateRange(kind: .allTime)

    public func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch kind {
        case .allTime:
            return true
        case .lastYear:
            guard let startDate = calendar.date(byAdding: .year, value: -1, to: now) else {
                return true
            }

            return date >= startDate && date <= now
        case .lastMonth:
            guard let startDate = calendar.date(byAdding: .month, value: -1, to: now) else {
                return true
            }

            return date >= startDate && date <= now
        case .custom:
            guard let customStartDate, let customEndDate else {
                return true
            }

            let lowerBound = min(customStartDate, customEndDate)
            let upperBound = max(customStartDate, customEndDate)
            let startOfLowerBound = calendar.startOfDay(for: lowerBound)
            let startOfUpperBound = calendar.startOfDay(for: upperBound)
            let upperBoundEndOfDay = calendar.date(byAdding: .day, value: 1, to: startOfUpperBound) ?? upperBound

            return date >= startOfLowerBound && date < upperBoundEndOfDay
        }
    }

    public func filtered(_ records: [ShotRecord], now: Date = Date(), calendar: Calendar = .current) -> [ShotRecord] {
        records.filter { contains($0.createdAt, now: now, calendar: calendar) }
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
