import Foundation

public struct GolfBagData: Codable, Equatable, Sendable {
    public var profiles: [GolferProfile]
    public var clubs: [Club]
    public var selectedProfileID: UUID?

    public init(
        profiles: [GolferProfile] = [],
        clubs: [Club] = [],
        selectedProfileID: UUID? = nil
    ) {
        self.profiles = profiles
        self.clubs = clubs
        self.selectedProfileID = selectedProfileID
    }

    public static let empty = GolfBagData()

    public func clubs(for profileID: UUID) -> [Club] {
        clubs
            .filter { $0.profileID == profileID }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
    }
}

