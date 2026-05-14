import SwiftUI

struct ClubSummaryRow: View {
    let club: Club
    var shotFilter: ShotFilter = .normal
    var valueMode: DistanceValueMode = .manual
    var shotRecords: [ShotRecord] = []

    private let formatter = ClubDisplayNameFormatter()
    private let distanceValueResolver = DistanceValueResolver()

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
                        Text(entry.value?.formattedDistance ?? "-")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        if entry.value != nil {
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
        distanceValueResolver
            .displaySections(for: club, filter: shotFilter, mode: valueMode, shotRecords: shotRecords)
            .map { section in
                (
                    title: section.title,
                    entries: section.entries.map {
                        DistanceEntry(label: $0.label.rawValue, value: $0.resolvedValue(for: valueMode))
                    }
                )
            }
    }

    private struct DistanceEntry {
        let label: String
        let value: ResolvedDistanceValue?
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
