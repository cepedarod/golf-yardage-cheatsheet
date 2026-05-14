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
                distributionSection(
                    title: "Strike Quality",
                    rows: StrikeQuality.allCases.map {
                        DistributionRowData(
                            title: $0.displayName,
                            percentage: strikeDistribution[$0] ?? 0
                        )
                    }
                )
                distributionSection(
                    title: "Direction",
                    rows: ShotDirection.allCases.map {
                        DistributionRowData(
                            title: $0.displayName,
                            percentage: directionDistribution[$0] ?? 0
                        )
                    }
                )
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
                HStack(alignment: .firstTextBaseline) {
                    Text(row.label)
                        .font(.headline)

                    Spacer()

                    LabeledDistanceValue(title: "Manual", value: formattedDistance(row.manualDistance))
                    LabeledDistanceValue(title: "Avg", value: formattedAverage(row.averageDistance))
                }
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

    private func distributionSection(title: String, rows: [DistributionRowData]) -> some View {
        Section(title) {
            ForEach(rows) { row in
                PercentageRow(title: row.title, percentage: row.percentage)
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
                averageDistance: statsCalculator.averageDistance(
                    for: shotRecords,
                    clubID: club.id,
                    category: selectedCategory,
                    power: power
                )
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

    private func formattedAverage(_ average: Double?) -> String {
        guard let average else {
            return "-"
        }

        return "\(Int(average.rounded())) yds"
    }

    private struct DistanceComparisonRow {
        let power: ShotPower
        let label: String
        let manualDistance: Int?
        let averageDistance: Double?
    }
}

private struct LabeledDistanceValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minWidth: 70, alignment: .trailing)
    }
}

private struct PercentageRow: View {
    let title: String
    let percentage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(formattedPercentage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: percentage, total: 100)
                .tint(.green)
        }
        .padding(.vertical, 3)
        .accessibilityIdentifier("analysis-percentage-\(title)")
    }

    private var formattedPercentage: String {
        "\(Int(percentage.rounded()))%"
    }
}

private struct DistributionRowData: Identifiable {
    let title: String
    let percentage: Double

    var id: String {
        title
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
