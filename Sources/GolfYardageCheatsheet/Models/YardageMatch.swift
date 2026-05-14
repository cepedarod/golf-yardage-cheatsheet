import Foundation

public struct YardageMatch: Equatable, Identifiable, Sendable {
    public var id: String {
        "\(club.id.uuidString)-\(category?.rawValue ?? "putter")-\(label.rawValue)-\(distance)"
    }

    public let club: Club
    public let category: ShotCategory?
    public let label: DistanceLabel
    public let distance: Int
    public let differenceFromTarget: Int

    public init(
        club: Club,
        category: ShotCategory? = .normal,
        label: DistanceLabel,
        distance: Int,
        targetYardage: Int
    ) {
        self.club = club
        self.category = category
        self.label = label
        self.distance = distance
        self.differenceFromTarget = abs(distance - targetYardage)
    }

    public var displayLabel: String {
        switch category {
        case .flop:
            "Flop \(label.rawValue)"
        case .normal, .lowTrajectory, .none:
            label.rawValue
        }
    }
}
