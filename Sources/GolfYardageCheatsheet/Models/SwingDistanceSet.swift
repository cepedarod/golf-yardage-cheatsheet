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

