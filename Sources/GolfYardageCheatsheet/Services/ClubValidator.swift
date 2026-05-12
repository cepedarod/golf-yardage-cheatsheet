import Foundation

public enum ClubValidationError: Error, Equatable, Sendable {
    case missingSwingDistance
    case missingPutterDistance
    case nonPositiveDistance(label: DistanceLabel)
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

        if let swingDistances = club.swingDistances, swingDistances.entries().isEmpty == false {
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

        if club.clubType.isWedge {
            if club.shotType == .punch {
                errors.append(.invalidWedgeShotType)
            }
        } else if club.shotType == .flop {
            errors.append(.invalidNonWedgeShotType)
        }

        guard let swingDistances = club.swingDistances else {
            errors.append(.missingSwingDistance)
            return errors
        }

        errors.append(contentsOf: validateDistances(swingDistances.entries()))

        if swingDistances.hasAtLeastOneDistance == false {
            errors.append(.missingSwingDistance)
        }

        return errors
    }

    private func validateDistances(_ entries: [(label: DistanceLabel, distance: Int)]) -> [ClubValidationError] {
        entries.compactMap { entry in
            entry.distance > 0 ? nil : .nonPositiveDistance(label: entry.label)
        }
    }
}

