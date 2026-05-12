import Foundation

public struct ClubDisplayNameFormatter: Sendable {
    public init() {}

    public func displayName(for club: Club) -> String {
        let baseName = baseDisplayName(for: club)

        switch club.shotType {
        case .flop:
            return "\(baseName) (Flop)"
        case .punch:
            return "\(baseName) (Punch)"
        case .normal, .none:
            return baseName
        }
    }

    private func baseDisplayName(for club: Club) -> String {
        if let nickname = club.nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
           nickname.isEmpty == false {
            return nickname
        }

        if club.clubType.isWedge, let wedgeLoft = club.wedgeLoft {
            return "\(wedgeLoft)\u{00B0} Wedge"
        }

        return club.clubType.displayName
    }
}

