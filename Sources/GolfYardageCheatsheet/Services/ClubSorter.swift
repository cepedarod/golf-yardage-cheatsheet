import Foundation

public struct ClubSorter: Sendable {
    public init() {}

    public func sortedForDistanceTab(_ clubs: [Club]) -> [Club] {
        clubs.sorted(by: comesBefore)
    }

    private func comesBefore(_ lhs: Club, _ rhs: Club) -> Bool {
        if lhs.clubType.isWedge, rhs.clubType.isWedge {
            return wedgeComesBefore(lhs, rhs)
        }

        let lhsRank = clubTypeRank(lhs.clubType)
        let rhsRank = clubTypeRank(rhs.clubType)

        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        return fallback(lhs, rhs)
    }

    private func wedgeComesBefore(_ lhs: Club, _ rhs: Club) -> Bool {
        let lhsLoft = lhs.wedgeLoft
        let rhsLoft = rhs.wedgeLoft

        if let lhsLoft, let rhsLoft, lhsLoft != rhsLoft {
            return lhsLoft < rhsLoft
        }

        let lhsFullDistance = lhs.normalDistances?.full
        let rhsFullDistance = rhs.normalDistances?.full

        if lhsLoft == nil || rhsLoft == nil {
            if let lhsFullDistance, let rhsFullDistance, lhsFullDistance != rhsFullDistance {
                return lhsFullDistance > rhsFullDistance
            }

            if (lhsLoft == nil) != (rhsLoft == nil) {
                return lhsLoft == nil
            }
        }

        if let lhsFullDistance, let rhsFullDistance, lhsFullDistance != rhsFullDistance {
            return lhsFullDistance > rhsFullDistance
        }

        let lhsRank = clubTypeRank(lhs.clubType)
        let rhsRank = clubTypeRank(rhs.clubType)

        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        return fallback(lhs, rhs)
    }

    private func clubTypeRank(_ clubType: ClubType) -> Int {
        ClubType.allCases.firstIndex(of: clubType) ?? Int.max
    }

    private func fallback(_ lhs: Club, _ rhs: Club) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}
