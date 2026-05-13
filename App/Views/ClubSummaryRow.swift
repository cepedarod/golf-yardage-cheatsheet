import SwiftUI

struct ClubSummaryRow: View {
    let club: Club

    private let formatter = ClubDisplayNameFormatter()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(formatter.displayName(for: club))
                .font(.headline)

            distanceGrid
        }
        .padding(.vertical, 8)
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
                        Text("\(entry.distance)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("yds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

    private var distanceEntries: [(label: DistanceLabel, distance: Int)] {
        if club.clubType == .putter {
            return club.putterDistances?.entries() ?? []
        }

        return club.swingDistances?.entries() ?? []
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
