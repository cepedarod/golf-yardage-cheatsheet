import SwiftUI

struct ClubSummaryRow: View {
    let club: Club
    var shotFilter: ShotFilter = .normal

    private let formatter = ClubDisplayNameFormatter()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayName)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(distanceSections.enumerated()), id: \.offset) { _, section in
                    if let title = section.title {
                        Text(title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    distanceGrid(entries: section.entries)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club-row-\(displayName)")
    }

    private var displayName: String {
        formatter.displayName(for: club)
    }

    private func distanceGrid(entries: [DistanceEntry]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                VStack(spacing: 6) {
                    Text(entry.label)
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

                if index < entries.count - 1 {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var distanceSections: [(title: String?, entries: [DistanceEntry])] {
        if club.clubType == .putter {
            return [(
                title: nil,
                entries: [
                    DistanceEntry(label: DistanceLabel.long.rawValue, distance: club.putterDistances?.long),
                    DistanceEntry(label: DistanceLabel.medium.rawValue, distance: club.putterDistances?.medium),
                    DistanceEntry(label: DistanceLabel.short.rawValue, distance: club.putterDistances?.short)
                ]
            )]
        }

        switch shotFilter {
        case .normal:
            var sections: [(title: String?, entries: [DistanceEntry])] = []

            if club.normalDistances != nil {
                sections.append((
                    title: club.flopDistances == nil ? nil : ShotCategory.normal.displayName,
                    entries: swingEntries(from: club.normalDistances)
                ))
            }

            if club.clubType.isWedge, club.flopDistances != nil {
                sections.append((
                    title: ShotCategory.flop.displayName,
                    entries: swingEntries(from: club.flopDistances)
                ))
            }

            return sections
        case .lowTrajectory:
            return [(
                title: nil,
                entries: [
                    DistanceEntry(label: DistanceLabel.stinger.rawValue, distance: club.lowTrajectoryDistances?.stinger),
                    DistanceEntry(label: DistanceLabel.punch.rawValue, distance: club.lowTrajectoryDistances?.punch),
                    DistanceEntry(label: DistanceLabel.softPunch.rawValue, distance: club.lowTrajectoryDistances?.softPunch),
                    DistanceEntry(label: DistanceLabel.chip.rawValue, distance: club.lowTrajectoryDistances?.chip)
                ]
            )]
        }
    }

    private func swingEntries(from distances: SwingDistanceSet?) -> [DistanceEntry] {
        [
            DistanceEntry(label: DistanceLabel.full.rawValue, distance: distances?.full),
            DistanceEntry(label: DistanceLabel.threeQuarter.rawValue, distance: distances?.threeQuarter),
            DistanceEntry(label: DistanceLabel.half.rawValue, distance: distances?.half),
            DistanceEntry(label: DistanceLabel.quarter.rawValue, distance: distances?.quarter)
        ]
    }

    private struct DistanceEntry {
        let label: String
        let distance: Int?
    }
}

#Preview {
    ClubSummaryRow(
        club: Club(
            profileID: UUID(),
            clubType: .sandWedge,
            wedgeLoft: 54,
            normalDistances: SwingDistanceSet(full: 100, threeQuarter: 85, half: 70),
            flopDistances: SwingDistanceSet(full: 85, threeQuarter: 65, half: 45, quarter: 25)
        )
    )
}
