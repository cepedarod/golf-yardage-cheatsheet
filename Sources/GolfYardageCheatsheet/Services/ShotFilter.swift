import Foundation

public enum ShotFilter: Hashable, Sendable {
    case all
    case punchOnly

    public func includes(_ club: Club) -> Bool {
        switch self {
        case .all:
            return true
        case .punchOnly:
            return club.shotType == .punch
        }
    }
}
