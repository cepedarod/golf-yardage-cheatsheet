import Foundation

public struct YardageMatcher: Sendable {
    public init() {}

    public func closestMatches(
        targetYardage: Int,
        clubs: [Club],
        filter: ShotFilter = .all,
        limit: Int = 2
    ) -> [YardageMatch] {
        guard targetYardage > 0, limit > 0 else {
            return []
        }

        let bestMatchByClub = clubs
            .filter { $0.isActive }
            .filter { club in
                filter == .all || club.shotType == .punch
            }
            .compactMap { bestMatch(for: $0, targetYardage: targetYardage) }

        return bestMatchByClub
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage)
            }
            .prefix(limit)
            .map { $0 }
    }

    private func bestMatch(for club: Club, targetYardage: Int) -> YardageMatch? {
        let entries: [(label: DistanceLabel, distance: Int)]

        if club.clubType == .putter {
            entries = club.putterDistances?.entries() ?? []
        } else {
            entries = club.swingDistances?.entries() ?? []
        }

        return entries
            .filter { $0.distance > 0 }
            .map { YardageMatch(club: club, label: $0.label, distance: $0.distance, targetYardage: targetYardage) }
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage)
            }
            .first
    }

    private func sort(_ lhs: YardageMatch, before rhs: YardageMatch, targetYardage: Int) -> Bool {
        if lhs.differenceFromTarget != rhs.differenceFromTarget {
            return lhs.differenceFromTarget < rhs.differenceFromTarget
        }

        let lhsFullSwingDifference = fullSwingDifference(for: lhs.club, targetYardage: targetYardage)
        let rhsFullSwingDifference = fullSwingDifference(for: rhs.club, targetYardage: targetYardage)

        if lhsFullSwingDifference != rhsFullSwingDifference {
            return lhsFullSwingDifference < rhsFullSwingDifference
        }

        if lhs.club.createdAt != rhs.club.createdAt {
            return lhs.club.createdAt < rhs.club.createdAt
        }

        if lhs.distance != rhs.distance {
            return lhs.distance < rhs.distance
        }

        return lhs.club.id.uuidString < rhs.club.id.uuidString
    }

    private func fullSwingDifference(for club: Club, targetYardage: Int) -> Int {
        guard let fullSwingDistance = club.swingDistances?.full, fullSwingDistance > 0 else {
            return Int.max
        }

        return abs(fullSwingDistance - targetYardage)
    }
}

