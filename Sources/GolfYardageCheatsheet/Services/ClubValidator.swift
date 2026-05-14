import Foundation

public enum ClubValidationError: Error, Equatable, Sendable {
    case missingSwingDistance
    case missingPutterDistance
    case nonPositiveDistance(label: DistanceLabel)
    case nonPositiveLowTrajectoryDistance(power: ShotPower)
    case putterCannotHaveShotType
    case putterCannotHaveSwingDistances
    case nonPutterCannotHavePutterDistances
    case invalidWedgeShotType
    case invalidNonWedgeShotType
    case wedgeLoftOutOfRange
    case wedgeLoftNotAllowedForClubType
}

public struct ClubValidator: Sendable {
    public init() {}

    public func validate(_ club: Club) -> [ClubValidationError] {
        var errors: [ClubValidationError] = []

        errors.append(contentsOf: validateWedgeLoft(for: club))

        if club.clubType == .putter {
            errors.append(contentsOf: validatePutter(club))
        } else {
            errors.append(contentsOf: validateNonPutter(club))
        }

        return errors
    }

    public func isValid(_ club: Club) -> Bool {
        validate(club).isEmpty
    }

    private func validateWedgeLoft(for club: Club) -> [ClubValidationError] {
        guard let wedgeLoft = club.wedgeLoft else {
            return []
        }

        var errors: [ClubValidationError] = []

        if club.clubType.isWedge == false {
            errors.append(.wedgeLoftNotAllowedForClubType)
        }

        if wedgeLoft < 30 || wedgeLoft > 80 {
            errors.append(.wedgeLoftOutOfRange)
        }

        return errors
    }

    private func validatePutter(_ club: Club) -> [ClubValidationError] {
        var errors: [ClubValidationError] = []

        if club.shotType != nil {
            errors.append(.putterCannotHaveShotType)
        }

        if hasNonPutterDistances(club) {
            errors.append(.putterCannotHaveSwingDistances)
        }

        guard let putterDistances = club.putterDistances else {
            errors.append(.missingPutterDistance)
            return errors
        }

        errors.append(contentsOf: validateDistances(putterDistances.entries()))

        if putterDistances.hasAtLeastOneDistance == false {
            errors.append(.missingPutterDistance)
        }

        return errors
    }

    private func validateNonPutter(_ club: Club) -> [ClubValidationError] {
        var errors: [ClubValidationError] = []

        if let putterDistances = club.putterDistances, putterDistances.entries().isEmpty == false {
            errors.append(.nonPutterCannotHavePutterDistances)
        }

        if club.clubType.isWedge == false,
           club.flopDistances?.entries().isEmpty == false || club.shotType == .flop {
            errors.append(.invalidNonWedgeShotType)
        }

        let swingDistanceSets = [
            club.normalDistances,
            club.flopDistances
        ].compactMap { $0 }
        let legacySwingDistances = swingDistanceSets.isEmpty ? club.swingDistances : nil
        let swingEntries = swingDistanceSets.flatMap { $0.entries() }
        let legacyEntries = legacySwingDistances?.entries() ?? []
        let lowTrajectoryEntries = club.lowTrajectoryDistances?.entries() ?? []

        if swingEntries.isEmpty, legacyEntries.isEmpty, lowTrajectoryEntries.isEmpty {
            errors.append(.missingSwingDistance)
        }

        errors.append(contentsOf: validateDistances(swingEntries))
        errors.append(contentsOf: validateDistances(legacyEntries))
        errors.append(contentsOf: validateLowTrajectoryDistances(lowTrajectoryEntries))

        return errors
    }

    private func validateDistances(_ entries: [(label: DistanceLabel, distance: Int)]) -> [ClubValidationError] {
        entries.compactMap { entry in
            entry.distance > 0 ? nil : .nonPositiveDistance(label: entry.label)
        }
    }

    private func validateLowTrajectoryDistances(
        _ entries: [(power: ShotPower, distance: Int)]
    ) -> [ClubValidationError] {
        entries.compactMap { entry in
            entry.distance > 0 ? nil : .nonPositiveLowTrajectoryDistance(power: entry.power)
        }
    }

    private func hasNonPutterDistances(_ club: Club) -> Bool {
        club.swingDistances?.entries().isEmpty == false ||
            club.normalDistances?.entries().isEmpty == false ||
            club.lowTrajectoryDistances?.entries().isEmpty == false ||
            club.flopDistances?.entries().isEmpty == false
    }
}

public enum ShotRecordValidationError: Error, Equatable, Sendable {
    case inactiveClub
    case putterShotRecordsNotSupported
    case unsupportedCategoryForClubType
    case unsupportedPowerForCategory
    case nonPositiveDistance
}

public struct ShotRecordValidator: Sendable {
    public init() {}

    public func validate(_ record: ShotRecord, club: Club) -> [ShotRecordValidationError] {
        var errors: [ShotRecordValidationError] = []

        if club.isActive == false {
            errors.append(.inactiveClub)
        }

        if club.clubType == .putter {
            errors.append(.putterShotRecordsNotSupported)
        }

        if record.category == .flop, club.clubType.isWedge == false {
            errors.append(.unsupportedCategoryForClubType)
        }

        if supports(record.power, in: record.category) == false {
            errors.append(.unsupportedPowerForCategory)
        }

        if let distance = record.distance, distance <= 0 {
            errors.append(.nonPositiveDistance)
        }

        return errors
    }

    private func supports(_ power: ShotPower, in category: ShotCategory) -> Bool {
        switch category {
        case .normal, .flop:
            switch power {
            case .full, .threeQuarter, .half, .quarter:
                true
            case .stinger, .punch, .softPunch, .chip:
                false
            }
        case .lowTrajectory:
            switch power {
            case .stinger, .punch, .softPunch, .chip:
                true
            case .full, .threeQuarter, .half, .quarter:
                false
            }
        }
    }
}
