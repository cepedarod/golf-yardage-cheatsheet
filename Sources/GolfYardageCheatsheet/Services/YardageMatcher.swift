import Foundation

public enum DistanceValueSource: Sendable {
    case selectedMode
    case supplementalMode
}

public struct ResolvedDistanceValue: Equatable, Sendable {
    public let distance: Int
    public let source: DistanceValueSource

    public init(distance: Int, source: DistanceValueSource) {
        self.distance = distance
        self.source = source
    }

    public var isSupplemental: Bool {
        source == .supplementalMode
    }

    public var formattedDistance: String {
        isSupplemental ? "(\(distance))" : "\(distance)"
    }
}

public struct DistanceDisplayEntry: Equatable, Sendable {
    public let category: ShotCategory?
    public let power: ShotPower?
    public let label: DistanceLabel
    public let manualDistance: Int?
    public let realDistance: Int?

    public init(
        category: ShotCategory?,
        power: ShotPower?,
        label: DistanceLabel,
        manualDistance: Int?,
        realDistance: Int?
    ) {
        self.category = category
        self.power = power
        self.label = label
        self.manualDistance = manualDistance
        self.realDistance = realDistance
    }

    public func selectedDistance(for mode: DistanceValueMode) -> Int? {
        switch mode {
        case .manual:
            manualDistance
        case .real:
            realDistance
        }
    }

    public func supplementalDistance(for mode: DistanceValueMode) -> Int? {
        guard selectedDistance(for: mode) == nil else {
            return nil
        }

        switch mode {
        case .manual:
            return realDistance
        case .real:
            return manualDistance
        }
    }

    public func resolvedValue(for mode: DistanceValueMode) -> ResolvedDistanceValue? {
        if let selectedDistance = selectedDistance(for: mode) {
            return ResolvedDistanceValue(distance: selectedDistance, source: .selectedMode)
        }

        if let supplementalDistance = supplementalDistance(for: mode) {
            return ResolvedDistanceValue(distance: supplementalDistance, source: .supplementalMode)
        }

        return nil
    }
}

public struct DistanceDisplaySection: Equatable, Sendable {
    public let title: String?
    public let entries: [DistanceDisplayEntry]

    public init(title: String?, entries: [DistanceDisplayEntry]) {
        self.title = title
        self.entries = entries
    }

    public func titled(_ title: String?) -> DistanceDisplaySection {
        DistanceDisplaySection(title: title, entries: entries)
    }
}

public struct DistanceValueResolver: Sendable {
    private let statsCalculator: ShotStatsCalculator

    public init(statsCalculator: ShotStatsCalculator = ShotStatsCalculator()) {
        self.statsCalculator = statsCalculator
    }

    public func hasDisplayableDistances(
        for club: Club,
        filter: ShotFilter,
        mode: DistanceValueMode,
        shotRecords: [ShotRecord]
    ) -> Bool {
        displaySections(for: club, filter: filter, mode: mode, shotRecords: shotRecords).isEmpty == false
    }

    public func displaySections(
        for club: Club,
        filter: ShotFilter,
        mode: DistanceValueMode,
        shotRecords: [ShotRecord]
    ) -> [DistanceDisplaySection] {
        if club.clubType == .putter {
            guard filter == .normal else {
                return []
            }

            return visibleSections(
                [
                    DistanceDisplaySection(
                        title: nil,
                        entries: [
                            putterEntry(label: .long, manualDistance: club.putterDistances?.long),
                            putterEntry(label: .medium, manualDistance: club.putterDistances?.medium),
                            putterEntry(label: .short, manualDistance: club.putterDistances?.short)
                        ]
                    )
                ],
                mode: mode
            )
        }

        switch filter {
        case .normal:
            let normalSection = visibleSection(
                DistanceDisplaySection(
                    title: nil,
                    entries: swingEntries(
                        club: club,
                        category: .normal,
                        distances: club.normalDistances,
                        shotRecords: shotRecords
                    )
                ),
                mode: mode
            )
            let flopSection = club.clubType.isWedge
                ? visibleSection(
                    DistanceDisplaySection(
                        title: ShotCategory.flop.displayName,
                        entries: swingEntries(
                            club: club,
                            category: .flop,
                            distances: club.flopDistances,
                            shotRecords: shotRecords
                        )
                    ),
                    mode: mode
                )
                : nil

            switch (normalSection, flopSection) {
            case (.some(let normalSection), .some(let flopSection)):
                return [normalSection.titled(ShotCategory.normal.displayName), flopSection]
            case (.some(let normalSection), .none):
                return [normalSection]
            case (.none, .some(let flopSection)):
                return [flopSection]
            case (.none, .none):
                return []
            }
        case .lowTrajectory:
            return visibleSections(
                [
                    DistanceDisplaySection(
                        title: nil,
                        entries: [
                            lowTrajectoryEntry(
                                club: club,
                                power: .stinger,
                                label: .stinger,
                                manualDistance: club.lowTrajectoryDistances?.stinger,
                                shotRecords: shotRecords
                            ),
                            lowTrajectoryEntry(
                                club: club,
                                power: .punch,
                                label: .punch,
                                manualDistance: club.lowTrajectoryDistances?.punch,
                                shotRecords: shotRecords
                            ),
                            lowTrajectoryEntry(
                                club: club,
                                power: .softPunch,
                                label: .softPunch,
                                manualDistance: club.lowTrajectoryDistances?.softPunch,
                                shotRecords: shotRecords
                            ),
                            lowTrajectoryEntry(
                                club: club,
                                power: .chip,
                                label: .chip,
                                manualDistance: club.lowTrajectoryDistances?.chip,
                                shotRecords: shotRecords
                            )
                        ]
                    )
                ],
                mode: mode
            )
        }
    }

    public func displayEntries(
        for club: Club,
        filter: ShotFilter,
        mode: DistanceValueMode,
        shotRecords: [ShotRecord]
    ) -> [DistanceDisplayEntry] {
        displaySections(for: club, filter: filter, mode: mode, shotRecords: shotRecords)
            .flatMap(\.entries)
    }

    private func visibleSections(_ sections: [DistanceDisplaySection], mode: DistanceValueMode) -> [DistanceDisplaySection] {
        sections.compactMap { visibleSection($0, mode: mode) }
    }

    private func visibleSection(_ section: DistanceDisplaySection, mode: DistanceValueMode) -> DistanceDisplaySection? {
        guard section.entries.contains(where: { $0.resolvedValue(for: mode) != nil }) else {
            return nil
        }

        return section
    }

    private func swingEntries(
        club: Club,
        category: ShotCategory,
        distances: SwingDistanceSet?,
        shotRecords: [ShotRecord]
    ) -> [DistanceDisplayEntry] {
        [
            swingEntry(
                club: club,
                category: category,
                power: .full,
                label: .full,
                manualDistance: distances?.full,
                shotRecords: shotRecords
            ),
            swingEntry(
                club: club,
                category: category,
                power: .threeQuarter,
                label: .threeQuarter,
                manualDistance: distances?.threeQuarter,
                shotRecords: shotRecords
            ),
            swingEntry(
                club: club,
                category: category,
                power: .half,
                label: .half,
                manualDistance: distances?.half,
                shotRecords: shotRecords
            ),
            swingEntry(
                club: club,
                category: category,
                power: .quarter,
                label: .quarter,
                manualDistance: distances?.quarter,
                shotRecords: shotRecords
            )
        ]
    }

    private func swingEntry(
        club: Club,
        category: ShotCategory,
        power: ShotPower,
        label: DistanceLabel,
        manualDistance: Int?,
        shotRecords: [ShotRecord]
    ) -> DistanceDisplayEntry {
        DistanceDisplayEntry(
            category: category,
            power: power,
            label: label,
            manualDistance: positiveDistance(manualDistance),
            realDistance: realDistance(
                clubID: club.id,
                category: category,
                power: power,
                shotRecords: shotRecords
            )
        )
    }

    private func lowTrajectoryEntry(
        club: Club,
        power: ShotPower,
        label: DistanceLabel,
        manualDistance: Int?,
        shotRecords: [ShotRecord]
    ) -> DistanceDisplayEntry {
        DistanceDisplayEntry(
            category: .lowTrajectory,
            power: power,
            label: label,
            manualDistance: positiveDistance(manualDistance),
            realDistance: realDistance(
                clubID: club.id,
                category: .lowTrajectory,
                power: power,
                shotRecords: shotRecords
            )
        )
    }

    private func putterEntry(label: DistanceLabel, manualDistance: Int?) -> DistanceDisplayEntry {
        DistanceDisplayEntry(
            category: nil,
            power: nil,
            label: label,
            manualDistance: positiveDistance(manualDistance),
            realDistance: nil
        )
    }

    private func realDistance(
        clubID: UUID,
        category: ShotCategory,
        power: ShotPower,
        shotRecords: [ShotRecord]
    ) -> Int? {
        guard let average = statsCalculator.averageDistance(
            for: shotRecords,
            clubID: clubID,
            category: category,
            power: power
        ) else {
            return nil
        }

        return positiveDistance(Int(average.rounded()))
    }

    private func positiveDistance(_ distance: Int?) -> Int? {
        guard let distance, distance > 0 else {
            return nil
        }

        return distance
    }
}

public struct YardageMatcher: Sendable {
    private let statsCalculator: ShotStatsCalculator
    private let resolver: DistanceValueResolver

    public init(statsCalculator: ShotStatsCalculator = ShotStatsCalculator()) {
        self.statsCalculator = statsCalculator
        self.resolver = DistanceValueResolver(statsCalculator: statsCalculator)
    }

    public func closestMatches(
        targetYardage: Int,
        clubs: [Club],
        filter: ShotFilter = .all,
        valueMode: DistanceValueMode = .manual,
        shotRecords: [ShotRecord] = [],
        limit: Int = 2
    ) -> [YardageMatch] {
        guard targetYardage > 0, limit > 0 else {
            return []
        }

        let candidates = clubs
            .filter { $0.isActive }
            .flatMap { club in
                resolver.displayEntries(
                    for: club,
                    filter: filter,
                    mode: valueMode,
                    shotRecords: shotRecords
                )
                .map { Candidate(club: club, entry: $0) }
            }

        let primaryMatches = closestPrimaryMatches(
            targetYardage: targetYardage,
            candidates: candidates,
            valueMode: valueMode,
            shotRecords: shotRecords,
            limit: limit
        )

        guard primaryMatches.count == limit,
              let supplementalMatch = closestSupplementalMatch(
                targetYardage: targetYardage,
                candidates: candidates,
                primaryMatches: primaryMatches,
                valueMode: valueMode,
                shotRecords: shotRecords
              ) else {
            return primaryMatches
        }

        return primaryMatches + [supplementalMatch]
    }

    private func closestPrimaryMatches(
        targetYardage: Int,
        candidates: [Candidate],
        valueMode: DistanceValueMode,
        shotRecords: [ShotRecord],
        limit: Int
    ) -> [YardageMatch] {
        let matches = candidates.compactMap {
            match(
                for: $0,
                targetYardage: targetYardage,
                valueMode: valueMode,
                isSupplemental: false
            )
        }

        let exactMatches = matches
            .filter { $0.distance == targetYardage }
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage, valueMode: valueMode, shotRecords: shotRecords)
            }

        if exactMatches.isEmpty == false {
            return exactMatches
                .prefix(limit)
                .map { $0 }
        }

        let closestLong = matches
            .filter { $0.distance > targetYardage }
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage, valueMode: valueMode, shotRecords: shotRecords)
            }
            .first

        let closestShort = matches
            .filter { $0.distance < targetYardage }
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage, valueMode: valueMode, shotRecords: shotRecords)
            }
            .first

        return [closestLong, closestShort]
            .compactMap { $0 }
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage, valueMode: valueMode, shotRecords: shotRecords)
            }
            .prefix(limit)
            .map { $0 }
    }

    private func closestSupplementalMatch(
        targetYardage: Int,
        candidates: [Candidate],
        primaryMatches: [YardageMatch],
        valueMode: DistanceValueMode,
        shotRecords: [ShotRecord]
    ) -> YardageMatch? {
        let supplementalMatches = candidates.compactMap {
            match(
                for: $0,
                targetYardage: targetYardage,
                valueMode: valueMode,
                isSupplemental: true
            )
        }

        return supplementalMatches
            .filter { supplemental in
                primaryMatches.allSatisfy { supplemental.differenceFromTarget < $0.differenceFromTarget }
            }
            .sorted { lhs, rhs in
                sort(lhs, before: rhs, targetYardage: targetYardage, valueMode: valueMode, shotRecords: shotRecords)
            }
            .first
    }

    private func match(
        for candidate: Candidate,
        targetYardage: Int,
        valueMode: DistanceValueMode,
        isSupplemental: Bool
    ) -> YardageMatch? {
        let distance = isSupplemental
            ? candidate.entry.supplementalDistance(for: valueMode)
            : candidate.entry.selectedDistance(for: valueMode)

        guard let distance, distance > 0 else {
            return nil
        }

        return YardageMatch(
            club: candidate.club,
            category: candidate.entry.category,
            label: candidate.entry.label,
            distance: distance,
            targetYardage: targetYardage,
            isSupplemental: isSupplemental
        )
    }

    private func sort(
        _ lhs: YardageMatch,
        before rhs: YardageMatch,
        targetYardage: Int,
        valueMode: DistanceValueMode,
        shotRecords: [ShotRecord]
    ) -> Bool {
        if lhs.differenceFromTarget != rhs.differenceFromTarget {
            return lhs.differenceFromTarget < rhs.differenceFromTarget
        }

        let lhsFullSwingDifference = fullSwingDifference(
            for: lhs,
            targetYardage: targetYardage,
            valueMode: valueMode,
            shotRecords: shotRecords
        )
        let rhsFullSwingDifference = fullSwingDifference(
            for: rhs,
            targetYardage: targetYardage,
            valueMode: valueMode,
            shotRecords: shotRecords
        )

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

    private func fullSwingDifference(
        for match: YardageMatch,
        targetYardage: Int,
        valueMode: DistanceValueMode,
        shotRecords: [ShotRecord]
    ) -> Int {
        let fullSwingDistance: Int?
        let sourceMode = match.isSupplemental ? valueMode.supplementalMode : valueMode

        switch match.category {
        case .normal:
            fullSwingDistance = distance(
                manualDistance: match.club.normalDistances?.full,
                clubID: match.club.id,
                category: .normal,
                power: .full,
                mode: sourceMode,
                shotRecords: shotRecords
            )
        case .flop:
            fullSwingDistance = distance(
                manualDistance: match.club.flopDistances?.full,
                clubID: match.club.id,
                category: .flop,
                power: .full,
                mode: sourceMode,
                shotRecords: shotRecords
            )
        case .lowTrajectory:
            fullSwingDistance = distance(
                manualDistance: match.club.lowTrajectoryDistances?.stinger,
                clubID: match.club.id,
                category: .lowTrajectory,
                power: .stinger,
                mode: sourceMode,
                shotRecords: shotRecords
            )
        case .none:
            fullSwingDistance = sourceMode == .manual ? match.club.putterDistances?.long : nil
        }

        guard let fullSwingDistance, fullSwingDistance > 0 else {
            return Int.max
        }

        return abs(fullSwingDistance - targetYardage)
    }

    private func distance(
        manualDistance: Int?,
        clubID: UUID,
        category: ShotCategory,
        power: ShotPower,
        mode: DistanceValueMode,
        shotRecords: [ShotRecord]
    ) -> Int? {
        switch mode {
        case .manual:
            guard let manualDistance, manualDistance > 0 else {
                return nil
            }

            return manualDistance
        case .real:
            guard let average = statsCalculator.averageDistance(
                for: shotRecords,
                clubID: clubID,
                category: category,
                power: power
            ) else {
                return nil
            }

            let distance = Int(average.rounded())
            return distance > 0 ? distance : nil
        }
    }

    private struct Candidate: Sendable {
        let club: Club
        let entry: DistanceDisplayEntry
    }
}
