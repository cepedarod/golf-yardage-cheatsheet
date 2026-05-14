import Foundation

public struct SwingDistanceSet: Codable, Equatable, Sendable {
    public var full: Int?
    public var threeQuarter: Int?
    public var half: Int?
    public var quarter: Int?

    public init(full: Int? = nil, threeQuarter: Int? = nil, half: Int? = nil, quarter: Int? = nil) {
        self.full = full
        self.threeQuarter = threeQuarter
        self.half = half
        self.quarter = quarter
    }

    public var hasAtLeastOneDistance: Bool {
        entries().isEmpty == false
    }

    public func entries() -> [(label: DistanceLabel, distance: Int)] {
        [
            full.map { (.full, $0) },
            threeQuarter.map { (.threeQuarter, $0) },
            half.map { (.half, $0) },
            quarter.map { (.quarter, $0) }
        ].compactMap { $0 }
    }
}

public struct LowTrajectoryDistanceSet: Codable, Equatable, Sendable {
    public var stinger: Int?
    public var punch: Int?
    public var softPunch: Int?
    public var chip: Int?

    public init(stinger: Int? = nil, punch: Int? = nil, softPunch: Int? = nil, chip: Int? = nil) {
        self.stinger = stinger
        self.punch = punch
        self.softPunch = softPunch
        self.chip = chip
    }

    public init(swingDistances: SwingDistanceSet) {
        self.init(
            stinger: swingDistances.full,
            punch: swingDistances.threeQuarter,
            softPunch: swingDistances.half,
            chip: swingDistances.quarter
        )
    }

    public var hasAtLeastOneDistance: Bool {
        entries().isEmpty == false
    }

    public func entries() -> [(power: ShotPower, distance: Int)] {
        [
            stinger.map { (.stinger, $0) },
            punch.map { (.punch, $0) },
            softPunch.map { (.softPunch, $0) },
            chip.map { (.chip, $0) }
        ].compactMap { $0 }
    }

    public func asSwingDistanceSet() -> SwingDistanceSet {
        SwingDistanceSet(
            full: stinger,
            threeQuarter: punch,
            half: softPunch,
            quarter: chip
        )
    }
}
