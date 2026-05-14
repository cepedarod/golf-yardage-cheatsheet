import Foundation

public struct YardageMatch: Equatable, Identifiable, Sendable {
    public var id: String {
        "\(club.id.uuidString)-\(category?.rawValue ?? "putter")-\(label.rawValue)-\(distance)-\(isSupplemental)"
    }

    public let club: Club
    public let category: ShotCategory?
    public let label: DistanceLabel
    public let distance: Int
    public let differenceFromTarget: Int
    public let isSupplemental: Bool

    public init(
        club: Club,
        category: ShotCategory? = .normal,
        label: DistanceLabel,
        distance: Int,
        targetYardage: Int,
        isSupplemental: Bool = false
    ) {
        self.club = club
        self.category = category
        self.label = label
        self.distance = distance
        self.differenceFromTarget = abs(distance - targetYardage)
        self.isSupplemental = isSupplemental
    }

    public var displayLabel: String {
        switch category {
        case .flop:
            "Flop \(label.rawValue)"
        case .normal, .lowTrajectory, .none:
            label.rawValue
        }
    }

    public var formattedDistance: String {
        isSupplemental ? "(\(distance))" : "\(distance)"
    }
}
