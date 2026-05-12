import Foundation

public struct YardageMatch: Equatable, Identifiable, Sendable {
    public var id: String {
        "\(club.id.uuidString)-\(label.rawValue)-\(distance)"
    }

    public let club: Club
    public let label: DistanceLabel
    public let distance: Int
    public let differenceFromTarget: Int

    public init(club: Club, label: DistanceLabel, distance: Int, targetYardage: Int) {
        self.club = club
        self.label = label
        self.distance = distance
        self.differenceFromTarget = abs(distance - targetYardage)
    }
}

