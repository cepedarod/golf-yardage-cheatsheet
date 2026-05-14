import Foundation

public enum ShotFilter: Hashable, Sendable {
    case normal
    case lowTrajectory

    public static var all: ShotFilter { .normal }
    public static var punchOnly: ShotFilter { .lowTrajectory }

    public func includes(_ club: Club) -> Bool {
        switch self {
        case .normal:
            return club.clubType == .putter ||
                club.normalDistances?.entries().isEmpty == false ||
                club.flopDistances?.entries().isEmpty == false
        case .lowTrajectory:
            return club.clubType != .putter &&
                club.lowTrajectoryDistances?.entries().isEmpty == false
        }
    }

    public func includesTargetMatch(_ club: Club) -> Bool {
        includes(club)
    }

    public var displayName: String {
        switch self {
        case .normal:
            "Normal"
        case .lowTrajectory:
            "Low Trajectory"
        }
    }
}
