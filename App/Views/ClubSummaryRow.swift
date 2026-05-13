import SwiftUI

struct ClubSummaryRow: View {
    let club: Club

    private let formatter = ClubDisplayNameFormatter()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayName)
                .font(.headline)

            distanceGrid
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club-row-\(displayName)")
    }

    private var displayName: String {
        formatter.displayName(for: club)
    }

    private var distanceGrid: some View {
        HStack(spacing: 0) {
            ForEach(Array(distanceEntries.enumerated()), id: \.offset) { index, entry in
                VStack(spacing: 6) {
                    Text(entry.label.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(entry.distance.map(String.init) ?? "-")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        if entry.distance != nil {
                            Text("yds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)

                if index < distanceEntries.count - 1 {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var distanceEntries: [(label: DistanceLabel, distance: Int?)] {
        if club.clubType == .putter {
            return [
                (.long, club.putterDistances?.long),
                (.medium, club.putterDistances?.medium),
                (.short, club.putterDistances?.short)
            ]
        }

        return [
            (.full, club.swingDistances?.full),
            (.threeQuarter, club.swingDistances?.threeQuarter),
            (.half, club.swingDistances?.half),
            (.quarter, club.swingDistances?.quarter)
        ]
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
