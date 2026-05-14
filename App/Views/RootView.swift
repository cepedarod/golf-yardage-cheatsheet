import SwiftUI

struct RootView: View {
    @StateObject private var viewModel: ProfileSelectionViewModel
    private let repository: GolfBagRepository

    init(repository: GolfBagRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: ProfileSelectionViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if let selectedProfile = viewModel.selectedProfile {
                MainTabView(
                    profile: selectedProfile,
                    repository: repository,
                    switchProfile: viewModel.clearSelectedProfile
                )
            } else {
                NavigationStack {
                    ProfileSelectionView(viewModel: viewModel)
                }
            }
        }
        .task {
            viewModel.load()
        }
    }
}

private struct MainTabView: View {
    let profile: GolferProfile
    let repository: GolfBagRepository
    let switchProfile: () -> Void

    var body: some View {
        TabView {
            NavigationStack {
                YardageDashboardView(
                    profile: profile,
                    repository: repository,
                    switchProfile: switchProfile
                )
            }
            .tabItem {
                Label("Distances", systemImage: "scope")
            }
            .accessibilityIdentifier("distances-tab")

            NavigationStack {
                AnalysisView(
                    profile: profile,
                    repository: repository,
                    switchProfile: switchProfile
                )
            }
            .tabItem {
                Label("Analysis", systemImage: "chart.bar.xaxis")
            }
            .accessibilityIdentifier("analysis-tab")
        }
    }
}

private struct AnalysisView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    @StateObject private var viewModel: YardageDashboardViewModel
    private let formatter = ClubDisplayNameFormatter()

    init(profile: GolferProfile, repository: GolfBagRepository, switchProfile: @escaping () -> Void) {
        self.profile = profile
        self.switchProfile = switchProfile
        _viewModel = StateObject(wrappedValue: YardageDashboardViewModel(profile: profile, repository: repository))
    }

    var body: some View {
        List {
            if viewModel.activeClubs.isEmpty, viewModel.inactiveClubs.isEmpty {
                ContentUnavailableView(
                    "No Clubs",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Add clubs from the Distance tab.")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                clubSection(title: "Active Clubs", clubs: viewModel.activeClubs)

                if viewModel.inactiveClubs.isEmpty == false {
                    clubSection(title: "Inactive Clubs", clubs: viewModel.inactiveClubs)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityIdentifier("analysis-list")
        .navigationTitle("Analysis")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: switchProfile) {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Switch Profile")
            }
        }
        .task {
            viewModel.loadClubs()
        }
    }

    private func clubSection(title: String, clubs: [Club]) -> some View {
        Section(title) {
            ForEach(clubs) { club in
                NavigationLink {
                    ClubAnalysisDetailView(club: club, shotRecords: viewModel.shotRecords)
                } label: {
                    AnalysisClubRow(club: club, shotRecords: viewModel.shotRecords)
                }
                .accessibilityIdentifier("analysis-club-row-\(formatter.displayName(for: club))")
            }
        }
    }
}

private struct AnalysisClubRow: View {
    let club: Club
    let shotRecords: [ShotRecord]

    private let formatter = ClubDisplayNameFormatter()
    private let statsCalculator = ShotStatsCalculator()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatter.displayName(for: club))
                    .font(.headline)

                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: club.isActive ? "checkmark.circle.fill" : "archivebox")
                .foregroundStyle(club.isActive ? .green : .secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }

    private var summaryText: String {
        guard club.clubType != .putter else {
            return "Putter distances"
        }

        let totalShots = availableCategories.reduce(0) { partialResult, category in
            partialResult + statsCalculator.totalShots(
                for: shotRecords,
                clubID: club.id,
                category: category
            )
        }

        return totalShots == 1 ? "1 recorded shot" : "\(totalShots) recorded shots"
    }

    private var availableCategories: [ShotCategory] {
        club.clubType.isWedge ? [.normal, .lowTrajectory, .flop] : [.normal, .lowTrajectory]
    }
}

private struct ClubAnalysisDetailView: View {
    let club: Club
    let shotRecords: [ShotRecord]

    @State private var selectedCategory: ShotCategory = .normal

    private let formatter = ClubDisplayNameFormatter()
    private let statsCalculator = ShotStatsCalculator()

    var body: some View {
        List {
            if club.clubType == .putter {
                putterDistancesSection
                Section("Shot Tracking") {
                    Text("Putters are not included in V2 shot recording.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category.displayName)
                                .tag(category)
                                .accessibilityIdentifier("analysis-category-\(category.accessibilityName)")
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("analysis-category-picker")
                }

                distanceComparisonSection
                shotSummarySection
                strikeDistributionSection
                directionDistributionSection
            }
        }
        .navigationTitle(formatter.displayName(for: club))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            normalizeSelectedCategory()
        }
    }

    private var putterDistancesSection: some View {
        Section("Distances") {
            putterDistanceRow(label: "Long", distance: club.putterDistances?.long)
            putterDistanceRow(label: "Medium", distance: club.putterDistances?.medium)
            putterDistanceRow(label: "Short", distance: club.putterDistances?.short)
        }
    }

    private var distanceComparisonSection: some View {
        Section("Distances") {
            ForEach(distanceRows, id: \.power) { row in
                DistanceComparisonRowView(row: row)
                .accessibilityIdentifier("analysis-distance-\(row.power.accessibilityName)")
            }
        }
    }

    private var shotSummarySection: some View {
        Section("Summary") {
            HStack {
                Text("Total Shots")
                Spacer()
                Text(totalShots == 1 ? "1 shot" : "\(totalShots) shots")
                    .font(.headline)
                    .accessibilityIdentifier("analysis-total-shots")
            }
        }
    }

    private var strikeDistributionSection: some View {
        Section("Strike Quality") {
            DistributionSummaryRow(
                rows: StrikeQuality.allCases.map {
                    DistributionRowData(
                        id: $0.displayName,
                        title: $0.displayName,
                        percentage: strikeDistribution[$0] ?? 0,
                        systemImage: $0.systemImage,
                        tint: $0.tint
                    )
                }
            )
            .accessibilityIdentifier("analysis-strike-distribution")
        }
    }

    private var directionDistributionSection: some View {
        Section("Direction") {
            ForEach(ShotDirection.allCases, id: \.self) { direction in
                PercentageRow(
                    title: direction.displayName,
                    percentage: directionDistribution[direction] ?? 0,
                    systemImage: direction.systemImage,
                    tint: direction.tint
                )
            }
        }
    }

    private func putterDistanceRow(label: String, distance: Int?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(formattedDistance(distance))
                .font(.headline)
        }
    }

    private var availableCategories: [ShotCategory] {
        club.clubType.isWedge ? [.normal, .lowTrajectory, .flop] : [.normal, .lowTrajectory]
    }

    private var distanceRows: [DistanceComparisonRow] {
        powers(for: selectedCategory).map { power in
            DistanceComparisonRow(
                power: power,
                label: power.displayName,
                manualDistance: manualDistance(for: selectedCategory, power: power),
                averageDistance: roundedAverage(for: power)
            )
        }
    }

    private var totalShots: Int {
        statsCalculator.totalShots(
            for: shotRecords,
            clubID: club.id,
            category: selectedCategory
        )
    }

    private var strikeDistribution: [StrikeQuality: Double] {
        statsCalculator.strikeDistributionPercentages(
            for: shotRecords,
            clubID: club.id,
            category: selectedCategory
        )
    }

    private var directionDistribution: [ShotDirection: Double] {
        statsCalculator.directionDistributionPercentages(
            for: shotRecords,
            clubID: club.id,
            category: selectedCategory
        )
    }

    private func normalizeSelectedCategory() {
        if availableCategories.contains(selectedCategory) == false {
            selectedCategory = availableCategories.first ?? .normal
        }
    }

    private func powers(for category: ShotCategory) -> [ShotPower] {
        switch category {
        case .normal, .flop:
            [.full, .threeQuarter, .half, .quarter]
        case .lowTrajectory:
            [.stinger, .punch, .softPunch, .chip]
        }
    }

    private func manualDistance(for category: ShotCategory, power: ShotPower) -> Int? {
        switch category {
        case .normal:
            swingDistance(from: club.normalDistances, power: power)
        case .flop:
            swingDistance(from: club.flopDistances, power: power)
        case .lowTrajectory:
            lowTrajectoryDistance(from: club.lowTrajectoryDistances, power: power)
        }
    }

    private func swingDistance(from distances: SwingDistanceSet?, power: ShotPower) -> Int? {
        switch power {
        case .full:
            distances?.full
        case .threeQuarter:
            distances?.threeQuarter
        case .half:
            distances?.half
        case .quarter:
            distances?.quarter
        case .stinger, .punch, .softPunch, .chip:
            nil
        }
    }

    private func lowTrajectoryDistance(from distances: LowTrajectoryDistanceSet?, power: ShotPower) -> Int? {
        switch power {
        case .stinger:
            distances?.stinger
        case .punch:
            distances?.punch
        case .softPunch:
            distances?.softPunch
        case .chip:
            distances?.chip
        case .full, .threeQuarter, .half, .quarter:
            nil
        }
    }

    private func formattedDistance(_ distance: Int?) -> String {
        guard let distance, distance > 0 else {
            return "-"
        }

        return "\(distance) yds"
    }

    private func roundedAverage(for power: ShotPower) -> Int? {
        guard let average = statsCalculator.averageDistance(
            for: shotRecords,
            clubID: club.id,
            category: selectedCategory,
            power: power
        ) else {
            return nil
        }

        return Int(average.rounded())
    }

}

private struct DistanceComparisonRow {
    let power: ShotPower
    let label: String
    let manualDistance: Int?
    let averageDistance: Int?

    var delta: Int? {
        guard let manualDistance, let averageDistance else {
            return nil
        }

        return averageDistance - manualDistance
    }
}

private struct DistanceComparisonRowView: View {
    let row: DistanceComparisonRow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.label)
                    .font(.headline)

                Spacer()

                if let deltaText {
                    Text(deltaText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(deltaTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(deltaTint.opacity(0.12), in: Capsule())
                        .accessibilityIdentifier("analysis-distance-delta-\(row.power.accessibilityName)")
                }
            }

            HStack(spacing: 0) {
                ComparisonValue(title: "Manual", distance: row.manualDistance)

                Divider()
                    .padding(.vertical, 3)

                ComparisonValue(title: "Pure Avg", distance: row.averageDistance)
            }
        }
        .padding(.vertical, 4)
    }

    private var deltaText: String? {
        guard let delta = row.delta else {
            return nil
        }

        if delta == 0 {
            return "Even"
        }

        return delta > 0 ? "+\(delta) yds" : "\(delta) yds"
    }

    private var deltaTint: Color {
        guard let delta = row.delta else {
            return .secondary
        }

        if delta == 0 {
            return .secondary
        }

        return delta > 0 ? .blue : .orange
    }
}

private struct ComparisonValue: View {
    let title: String
    let distance: Int?

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(formattedDistance)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()

                if distance != nil {
                    Text("yds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedDistance: String {
        guard let distance, distance > 0 else {
            return "-"
        }

        return "\(distance)"
    }
}

private struct DistributionRowData: Identifiable {
    let id: String
    let title: String
    let percentage: Double
    let systemImage: String
    let tint: Color
}

private struct DistributionSummaryRow: View {
    let rows: [DistributionRowData]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(rows) { row in
                VStack(spacing: 7) {
                    Image(systemName: row.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(row.tint)

                    Text(row.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formattedPercentage(row.percentage))
                        .font(.headline.weight(.semibold))
                        .monospacedDigit()
                        .accessibilityIdentifier("analysis-percentage-\(row.title)")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedPercentage(_ percentage: Double) -> String {
        "\(Int(percentage.rounded()))%"
    }
}

private struct PercentageRow: View {
    let title: String
    let percentage: Double
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22)

                Text(title)

                Spacer()

                Text(formattedPercentage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.14))

                    Capsule()
                        .fill(tint)
                        .frame(width: percentage <= 0 ? 0 : max(6, proxy.size.width * percentage / 100))
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("analysis-percentage-\(title)")
    }

    private var formattedPercentage: String {
        "\(Int(percentage.rounded()))%"
    }
}

private extension StrikeQuality {
    var systemImage: String {
        switch self {
        case .thin:
            "minus.circle"
        case .pure:
            "checkmark.circle.fill"
        case .chunk:
            "exclamationmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .thin:
            .orange
        case .pure:
            .green
        case .chunk:
            .red
        }
    }
}

private extension ShotDirection {
    var systemImage: String {
        switch self {
        case .hook:
            "arrowshape.turn.up.left.fill"
        case .draw:
            "arrow.up.left"
        case .straight:
            "arrow.up"
        case .fade:
            "arrow.up.right"
        case .slice:
            "arrowshape.turn.up.right.fill"
        }
    }

    var tint: Color {
        switch self {
        case .hook, .slice:
            .red
        case .draw, .fade:
            .blue
        case .straight:
            .green
        }
    }
}

private extension ShotCategory {
    var accessibilityName: String {
        switch self {
        case .normal:
            "normal"
        case .lowTrajectory:
            "low-trajectory"
        case .flop:
            "flop"
        }
    }
}

private extension ShotPower {
    var accessibilityName: String {
        switch self {
        case .full:
            "full"
        case .threeQuarter:
            "three-quarter"
        case .half:
            "half"
        case .quarter:
            "quarter"
        case .stinger:
            "stinger"
        case .punch:
            "punch"
        case .softPunch:
            "soft-punch"
        case .chip:
            "chip"
        }
    }
}
