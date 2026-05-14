import Foundation

public struct ClubDisplayNameFormatter: Sendable {
    public init() {}

    public func displayName(for club: Club) -> String {
        baseDisplayName(for: club)
    }

    private func baseDisplayName(for club: Club) -> String {
        let clubName = clubTypeDisplayName(for: club)

        if let nickname = club.nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
           nickname.isEmpty == false {
            return "\(nickname) \(clubName)"
        }

        return clubName
    }

    private func clubTypeDisplayName(for club: Club) -> String {
        if club.clubType.isWedge, let wedgeLoft = club.wedgeLoft {
            return "\(wedgeLoft)\u{00B0} Wedge"
        }

        return club.clubType.displayName
    }
}
