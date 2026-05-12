import Foundation

public struct PutterDistanceSet: Codable, Equatable, Sendable {
    public var long: Int?
    public var medium: Int?
    public var short: Int?

    public init(long: Int? = nil, medium: Int? = nil, short: Int? = nil) {
        self.long = long
        self.medium = medium
        self.short = short
    }

    public var hasAtLeastOneDistance: Bool {
        entries().isEmpty == false
    }

    public func entries() -> [(label: DistanceLabel, distance: Int)] {
        [
            long.map { (.long, $0) },
            medium.map { (.medium, $0) },
            short.map { (.short, $0) }
        ].compactMap { $0 }
    }
}

