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

        let candidates = clubs
            .filter { $0.isActive }
            .filter(filter.includesTargetMatch)
            .flatMap { matches(for: $0, targetYardage: targetYardage, filter: filter) }

        let exactMatches = candidates
            .filter { $0.distance == targetYardage }
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage)
            }

        if exactMatches.isEmpty == false {
            return exactMatches
                .prefix(limit)
                .map { $0 }
        }

        let closestLong = candidates
            .filter { $0.distance > targetYardage }
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage)
            }
            .first

        let closestShort = candidates
            .filter { $0.distance < targetYardage }
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage)
            }
            .first

        return [closestLong, closestShort]
            .compactMap { $0 }
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage)
            }
            .prefix(limit)
            .map { $0 }
    }

    private func matches(for club: Club, targetYardage: Int, filter: ShotFilter) -> [YardageMatch] {
        let entries: [(category: ShotCategory?, label: DistanceLabel, distance: Int)]

        switch filter {
        case .normal:
            if club.clubType == .putter {
                entries = (club.putterDistances?.entries() ?? [])
                    .map { (nil, $0.label, $0.distance) }
            } else {
                let normalEntries = (club.normalDistances?.entries() ?? [])
                    .map { (ShotCategory.normal as ShotCategory?, $0.label, $0.distance) }
                let flopEntries = club.clubType.isWedge
                    ? (club.flopDistances?.entries() ?? []).map { (ShotCategory.flop as ShotCategory?, $0.label, $0.distance) }
                    : []

                entries = normalEntries + flopEntries
            }
        case .lowTrajectory:
            entries = (club.lowTrajectoryDistances?.entries() ?? [])
                .map { (ShotCategory.lowTrajectory as ShotCategory?, label(for: $0.power), $0.distance) }
        }

        return entries
            .filter { $0.distance > 0 }
            .map {
                YardageMatch(
                    club: club,
                    category: $0.category,
                    label: $0.label,
                    distance: $0.distance,
                    targetYardage: targetYardage
                )
            }
    }

    private func sort(_ lhs: YardageMatch, before rhs: YardageMatch, targetYardage: Int) -> Bool {
        if lhs.differenceFromTarget != rhs.differenceFromTarget {
            return lhs.differenceFromTarget < rhs.differenceFromTarget
        }

        let lhsFullSwingDifference = fullSwingDifference(for: lhs, targetYardage: targetYardage)
        let rhsFullSwingDifference = fullSwingDifference(for: rhs, targetYardage: targetYardage)

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

    private func fullSwingDifference(for match: YardageMatch, targetYardage: Int) -> Int {
        let fullSwingDistance: Int?

        switch match.category {
        case .normal:
            fullSwingDistance = match.club.normalDistances?.full
        case .flop:
            fullSwingDistance = match.club.flopDistances?.full
        case .lowTrajectory:
            fullSwingDistance = match.club.lowTrajectoryDistances?.stinger
        case .none:
            fullSwingDistance = match.club.putterDistances?.long
        }

        guard let fullSwingDistance, fullSwingDistance > 0 else {
            return Int.max
        }

        return abs(fullSwingDistance - targetYardage)
    }

    private func label(for power: ShotPower) -> DistanceLabel {
        switch power {
        case .full:
            .full
        case .threeQuarter:
            .threeQuarter
        case .half:
            .half
        case .quarter:
            .quarter
        case .stinger:
            .stinger
        case .punch:
            .punch
        case .softPunch:
            .softPunch
        case .chip:
            .chip
        }
    }
}
