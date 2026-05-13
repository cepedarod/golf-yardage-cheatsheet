import SwiftUI

struct ClubSummaryRow: View {
    let club: Club

    private let formatter = ClubDisplayNameFormatter()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(formatter.displayName(for: club))
                .font(.headline)

            Text(distanceSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var distanceSummary: String {
        let entries: [(label: DistanceLabel, distance: Int)]

        if club.clubType == .putter {
            entries = club.putterDistances?.entries() ?? []
        } else {
            entries = club.swingDistances?.entries() ?? []
        }

        return entries.map { "\($0.label.rawValue) \($0.distance)" }
            .joined(separator: " \u{00B7} ")
    }
}

#Preview {
    ClubSummaryRow(
        club: Club(
            profileID: UUID(),
            clubType: .sandWedge,
            wedgeLoft: 54,
            shotType: .flop,
            swingDistances: SwingDistanceSet(full: 85, threeQuarter: 65, half: 45, quarter: 25)
        )
    )
}
