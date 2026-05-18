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
                    ClubAnalysisDetailView(
                        club: club,
                        shotRecords: viewModel.shotRecords,
                        onSaveShotRecord: viewModel.saveShotRecord,
                        onDeleteShotRecord: viewModel.deleteShotRecord
                    )
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
    let onSaveShotRecord: (ShotRecord) throws -> Void
    let onDeleteShotRecord: (ShotRecord) -> Void

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
            NavigationLink {
                ShotRecordListView(
                    club: club,
                    shotRecords: shotRecords,
                    onSave: onSaveShotRecord,
                    onDelete: onDeleteShotRecord
                )
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Total Shots")
                        Text(totalShotsSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    summaryValue
                }
            }
            .accessibilityIdentifier("analysis-total-shots-row")
        }
    }

    private var strikeDistributionSection: some View {
        Section("Strike Quality") {
            StrikeQualityDistributionView(
                rows: StrikeQuality.allCases.map {
                    DistributionRowData(
                        id: $0.displayName,
                        quality: $0,
                        title: $0.displayName,
                        count: strikeCount(for: $0),
                        percentage: strikeDistribution[$0] ?? 0,
                        tint: $0.tint
                    )
                },
                totalCount: categoryShotRecords.count
            )
            .accessibilityIdentifier("analysis-strike-distribution")
        }
    }

    private var directionDistributionSection: some View {
        Section("Direction") {
            DirectionDistributionView(
                rows: ShotDirection.allCases.map { direction in
                    DirectionDistributionRowData(
                        id: direction.displayName,
                        direction: direction,
                        title: direction.displayName,
                        count: directionCount(for: direction),
                        percentage: directionDistribution[direction] ?? 0,
                        tint: direction.tint
                    )
                },
                totalCount: categoryShotRecords.count
            )
            .accessibilityIdentifier("analysis-direction-distribution")
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
        shotRecords.filter { $0.clubID == club.id }.count
    }

    private var categoryShotRecords: [ShotRecord] {
        shotRecords.filter { $0.clubID == club.id && $0.category == selectedCategory }
    }

    private func strikeCount(for quality: StrikeQuality) -> Int {
        categoryShotRecords.filter { $0.strikeQuality == quality }.count
    }

    private func directionCount(for direction: ShotDirection) -> Int {
        categoryShotRecords.filter { $0.direction == direction }.count
    }

    private var primaryStrikeQuality: StrikeQuality? {
        StrikeQuality.allCases.max {
            strikeCount(for: $0) < strikeCount(for: $1)
        }.flatMap {
            strikeCount(for: $0) > 0 ? $0 : nil
        }
    }

    private var primaryDirection: ShotDirection? {
        ShotDirection.allCases.max {
            directionCount(for: $0) < directionCount(for: $1)
        }.flatMap {
            directionCount(for: $0) > 0 ? $0 : nil
        }
    }

    private var totalShotsSubtitle: String {
        guard let primaryStrikeQuality, let primaryDirection else {
            return categoryShotRecords.isEmpty ? "No \(selectedCategory.displayName.lowercased()) shots yet" : selectedCategory.displayName
        }

        return "\(primaryStrikeQuality.displayName) / \(primaryDirection.displayName)"
    }

    private var totalShotsValueText: String {
        totalShots == 1 ? "1 shot" : "\(totalShots) shots"
    }

    private var categoryShotCaption: String {
        if categoryShotRecords.count == totalShots {
            return "All recorded shots"
        }

        return "\(categoryShotRecords.count) of \(totalShotsValueText)"
    }

    private var summaryValue: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(totalShotsValueText)
                .font(.headline)
                .accessibilityIdentifier("analysis-total-shots")

            if totalShots > 0 {
                Text(categoryShotCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

private struct ShotRecordListView: View {
    let club: Club
    let shotRecords: [ShotRecord]
    let onSave: (ShotRecord) throws -> Void
    let onDelete: (ShotRecord) -> Void

    @State private var editingRecord: ShotRecord?

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(
                    "No Recorded Shots",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Shots recorded for this club will appear here.")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(records) { record in
                    Button {
                        editingRecord = record
                    } label: {
                        ShotRecordRowView(record: record)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("shot-record-row-\(record.power.accessibilityName)")
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            editingRecord = record
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(record)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("shot-record-list")
        .navigationTitle("Recorded Shots")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingRecord) { record in
            NavigationStack {
                ShotRecordEditView(club: club, record: record, onSave: onSave)
            }
        }
    }

    private var records: [ShotRecord] {
        shotRecords
            .filter { $0.clubID == club.id }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
    }
}

private struct ShotRecordRowView: View {
    let record: ShotRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(shotTypeText)
                    .font(.headline)

                Spacer()

                Text(distanceText)
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .accessibilityIdentifier("shot-record-distance-\(record.power.accessibilityName)")
            }

            HStack(spacing: 12) {
                Label(dateText, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                StrikeQualityIcon(quality: record.strikeQuality, size: 22)
                    .accessibilityLabel(record.strikeQuality.displayName)

                Image(systemName: record.direction.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(record.direction.tint)
                    .accessibilityLabel(record.direction.displayName)
            }
        }
        .padding(.vertical, 6)
    }

    private var shotTypeText: String {
        switch record.category {
        case .normal, .flop:
            return "\(record.power.displayName) \(record.category.displayName)"
        case .lowTrajectory:
            return record.power.displayName
        }
    }

    private var distanceText: String {
        guard let distance = record.distance else {
            return "- yds"
        }

        return "\(distance) yds"
    }

    private var dateText: String {
        record.createdAt.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct ShotRecordEditView: View {
    let club: Club
    let record: ShotRecord
    let onSave: (ShotRecord) throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: ShotCategory
    @State private var selectedPower: ShotPower
    @State private var distanceText: String
    @State private var strikeQuality: StrikeQuality
    @State private var direction: ShotDirection
    @State private var createdAt: Date
    @State private var errorMessage: String?

    init(club: Club, record: ShotRecord, onSave: @escaping (ShotRecord) throws -> Void) {
        self.club = club
        self.record = record
        self.onSave = onSave
        _selectedCategory = State(initialValue: record.category)
        _selectedPower = State(initialValue: record.power)
        _distanceText = State(initialValue: record.distance.map(String.init) ?? "")
        _strikeQuality = State(initialValue: record.strikeQuality)
        _direction = State(initialValue: record.direction)
        _createdAt = State(initialValue: record.createdAt)
    }

    var body: some View {
        Form {
            Section("Shot") {
                ForEach(availableCategories, id: \.self) { category in
                    powerRow(for: category)
                }
            }

            Section("Date") {
                DatePicker("Date", selection: $createdAt, displayedComponents: [.date, .hourAndMinute])
                    .accessibilityIdentifier("edit-shot-date-picker")
            }

            Section("Distance") {
                HStack {
                    Text("Distance (Yards)")
                    Spacer()
                    if distanceText.isEmpty == false {
                        Button {
                            distanceText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear Distance")
                        .accessibilityIdentifier("clear-edit-shot-distance-button")
                    }
                    NumericTextField(
                        title: "Optional",
                        text: $distanceText,
                        maxDigits: 3,
                        dismissesKeyboardAtMaxDigits: true
                    )
                        .accessibilityIdentifier("edit-shot-distance-field")
                        .frame(maxWidth: 112)
                }
            }

            Section("Strike") {
                Picker("Strike", selection: $strikeQuality) {
                    ForEach(StrikeQuality.allCases, id: \.self) { strikeQuality in
                        Text(strikeQuality.displayName).tag(strikeQuality)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("edit-strike-quality-picker")
            }

            Section("Direction") {
                Picker("Direction", selection: $direction) {
                    ForEach(ShotDirection.allCases, id: \.self) { direction in
                        Label(direction.displayName, systemImage: direction.systemImage)
                            .tag(direction)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("edit-shot-direction-picker")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Edit Shot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .accessibilityIdentifier("save-shot-edit-button")
            }
        }
        .onAppear {
            normalizeSelectedShot()
        }
    }

    private var availableCategories: [ShotCategory] {
        club.clubType.isWedge ? [.normal, .lowTrajectory, .flop] : [.normal, .lowTrajectory]
    }

    private func powerRow(for category: ShotCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(powers(for: category), id: \.self) { power in
                    powerButton(category: category, power: power)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func powerButton(category: ShotCategory, power: ShotPower) -> some View {
        let isSelected = selectedCategory == category && selectedPower == power

        return Button {
            if selectedCategory != category {
                selectedPower = powers(for: category).first ?? power
            }

            selectedCategory = category
            selectedPower = power
            normalizeSelectedShot()
        } label: {
            Text(power.displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .green)
        .background(isSelected ? Color.green : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.green : Color.green.opacity(0.45), lineWidth: 1)
        }
        .accessibilityIdentifier("edit-shot-power-\(category.accessibilityName)-\(power.accessibilityName)")
    }

    private func powers(for category: ShotCategory) -> [ShotPower] {
        switch category {
        case .normal, .flop:
            [.full, .threeQuarter, .half, .quarter]
        case .lowTrajectory:
            [.stinger, .punch, .softPunch, .chip]
        }
    }

    private func normalizeSelectedShot() {
        if availableCategories.contains(selectedCategory) == false {
            selectedCategory = availableCategories.first ?? .normal
        }

        if powers(for: selectedCategory).contains(selectedPower) == false {
            selectedPower = powers(for: selectedCategory).first ?? .full
        }
    }

    private func save() {
        let editedRecord = ShotRecord(
            id: record.id,
            profileID: record.profileID,
            clubID: record.clubID,
            roundID: record.roundID,
            category: selectedCategory,
            power: selectedPower,
            distance: distance(from: distanceText),
            distanceSource: record.distanceSource,
            gpsMeasurement: record.gpsMeasurement,
            strikeQuality: strikeQuality,
            direction: direction,
            grassType: record.grassType,
            createdAt: createdAt
        )

        do {
            try onSave(editedRecord)
            dismiss()
        } catch GolfBagRepositoryError.invalidShotRecord(let validationErrors) {
            errorMessage = validationMessage(for: validationErrors)
        } catch {
            errorMessage = "Unable to save shot."
        }
    }

    private func distance(from text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func validationMessage(for errors: [ShotRecordValidationError]) -> String {
        if errors.contains(.nonPositiveDistance) {
            return "Distance must be greater than 0."
        }

        if errors.contains(.unsupportedCategoryForClubType) || errors.contains(.unsupportedPowerForCategory) {
            return "Choose a valid shot type."
        }

        return "Check the shot details and try again."
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
    let quality: StrikeQuality
    let title: String
    let count: Int
    let percentage: Double
    let tint: Color
}

private struct DirectionDistributionRowData: Identifiable {
    let id: String
    let direction: ShotDirection
    let title: String
    let count: Int
    let percentage: Double
    let tint: Color
}

private struct StrikeQualityDistributionView: View {
    let rows: [DistributionRowData]
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DistributionStackedBar(
                rows: rows.map {
                    DistributionSegmentData(
                        id: $0.id,
                        percentage: $0.percentage,
                        tint: $0.tint
                    )
                },
                totalCount: totalCount
            )

            HStack(alignment: .top, spacing: 0) {
                ForEach(rows) { row in
                    StrikeQualityBucket(row: row)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DirectionDistributionView: View {
    let rows: [DirectionDistributionRowData]
    let totalCount: Int

    var body: some View {
        VStack(spacing: 12) {
            DirectionFanChart(rows: rows, totalCount: totalCount)
                .frame(height: 190)

            HStack(alignment: .top, spacing: 0) {
                ForEach(rows) { row in
                    VStack(spacing: 4) {
                        Text(row.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text(row.count == 1 ? "1" : "\(row.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(row.count > 0 ? row.tint : .secondary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DistributionSegmentData: Identifiable {
    let id: String
    let percentage: Double
    let tint: Color
}

private struct DistributionStackedBar: View {
    let rows: [DistributionSegmentData]
    let totalCount: Int

    var body: some View {
        Canvas { context, size in
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
                return
            }

            let rect = CGRect(origin: .zero, size: size)
            let cornerRadius = size.height / 2

            if totalCount == 0 {
                context.fill(
                    Path(roundedRect: rect, cornerRadius: cornerRadius),
                    with: .color(Color.secondary.opacity(0.16))
                )
                return
            }

            let activeRows = rows.filter { $0.percentage > 0 }
            let totalGap = CGFloat(max(0, activeRows.count - 1)) * 3
            let availableWidth = max(0, size.width - totalGap)
            var x: CGFloat = 0

            for row in activeRows {
                let segmentWidth = max(0, availableWidth * row.percentage / 100)
                guard segmentWidth > 0 else {
                    continue
                }

                let segmentRect = CGRect(x: x, y: 0, width: segmentWidth, height: size.height)

                context.fill(
                    Path(roundedRect: segmentRect, cornerRadius: cornerRadius),
                    with: .color(row.tint)
                )

                x += segmentWidth + 3
            }
        }
        .frame(height: 10)
    }
}

private struct StrikeQualityBucket: View {
    let row: DistributionRowData

    var body: some View {
        VStack(spacing: 7) {
            StrikeQualityIcon(quality: row.quality, size: 30)

            Text(row.title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formattedPercentage(row.percentage))
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier("analysis-percentage-\(row.title)")

            Text(row.count == 1 ? "1 shot" : "\(row.count) shots")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DirectionFanChart: View {
    let rows: [DirectionDistributionRowData]
    let totalCount: Int

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let center = CGPoint(x: size.width / 2, y: size.height - 16)
            let maxRadius = min(size.width * 0.37, size.height * 0.72)
            let labels = labelPositions(in: size, center: center, radius: maxRadius)

            ZStack {
                Canvas { context, canvasSize in
                    guard canvasSize.width.isFinite,
                          canvasSize.height.isFinite,
                          canvasSize.width > 0,
                          canvasSize.height > 0 else {
                        return
                    }

                    for guideAngle in [-121.0, -59.0] {
                        var guidePath = Path()
                        guidePath.move(to: center)
                        guidePath.addLine(to: point(from: center, radius: maxRadius + 34, degrees: guideAngle))
                        context.stroke(
                            guidePath,
                            with: .color(Color.secondary.opacity(0.18)),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                        )
                    }

                    for (index, row) in rows.enumerated() {
                        let geometry = sliceGeometry(for: index)
                        let share = totalCount > 0 ? max(0, min(1, row.percentage / 100)) : 0
                        let radius = maxRadius * (0.36 + share * 0.64)
                        let opacity = 0.16 + share * 0.78
                        let path = fanSlicePath(
                            center: center,
                            radius: radius,
                            startDegrees: geometry.startDegrees,
                            endDegrees: geometry.endDegrees
                        )

                        context.fill(path, with: .color(row.tint.opacity(opacity)))
                    }
                }

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    DirectionFanLabel(row: row)
                        .position(labels[index])
                }
            }
        }
    }

    private func sliceGeometry(for index: Int) -> (startDegrees: Double, endDegrees: Double) {
        let sliceWidth = 24.0
        let sliceSpacing = 27.0
        let straightIndex = 2.0
        let midpoint = -90.0 + (Double(index) - straightIndex) * sliceSpacing

        return (midpoint - sliceWidth / 2, midpoint + sliceWidth / 2)
    }

    private func labelPositions(in size: CGSize, center: CGPoint, radius: CGFloat) -> [CGPoint] {
        let labelRadius = radius + 22

        return rows.indices.map { index in
            let geometry = sliceGeometry(for: index)
            let midpoint = (geometry.startDegrees + geometry.endDegrees) / 2
            let radians = midpoint * .pi / 180
            let x = center.x + cos(radians) * labelRadius
            let y = center.y + sin(radians) * labelRadius

            return CGPoint(
                x: min(max(x, 34), size.width - 34),
                y: min(max(y, 14), size.height - 20)
            )
        }
    }

    private func fanSlicePath(center: CGPoint, radius: CGFloat, startDegrees: Double, endDegrees: Double) -> Path {
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }

    private func point(from center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        CGPoint(
            x: center.x + cos(degrees * .pi / 180) * radius,
            y: center.y + sin(degrees * .pi / 180) * radius
        )
    }
}

private struct DirectionFanLabel: View {
    let row: DirectionDistributionRowData

    var body: some View {
        VStack(spacing: 2) {
            Text(formattedPercentage(row.percentage))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier("analysis-percentage-\(row.title)")

            Text(row.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }
}

private func formattedPercentage(_ percentage: Double) -> String {
    "\(Int(percentage.rounded()))%"
}

private struct StrikeQualityIcon: View {
    let quality: StrikeQuality
    var size: CGFloat

    var body: some View {
        ZStack {
            GroundStrikeShape(quality: quality)
                .stroke(
                    groundTint,
                    style: StrokeStyle(
                        lineWidth: max(1, size * 0.045),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size, height: size)

            ClubShaftShape()
                .stroke(
                    quality.tint.opacity(0.62),
                    style: StrokeStyle(
                        lineWidth: max(0.8, size * 0.035),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size, height: size)
                .offset(shaftOffset)

            ironFace
                .rotationEffect(.degrees(ironRotation))
                .offset(ironOffset)

            Circle()
                .fill(.background)
                .overlay {
                    Circle()
                        .stroke(quality.tint.opacity(0.95), lineWidth: max(1.25, size * 0.07))
                }
                .frame(width: size * 0.31, height: size * 0.31)
                .offset(x: size * 0.24, y: size * 0.12)

            impactMark
        }
        .frame(width: size, height: size)
        .accessibilityLabel(quality.displayName)
    }

    private var groundTint: Color {
        quality == .chunk ? quality.tint.opacity(0.72) : Color.secondary.opacity(0.22)
    }

    private var ironFace: some View {
        IronFaceSilhouetteShape()
            .fill(quality.tint.opacity(0.88))
            .overlay {
                IronFaceSilhouetteShape()
                    .stroke(quality.tint, lineWidth: max(0.9, size * 0.045))
            }
            .frame(width: size * 0.42, height: size * 0.6)
    }

    @ViewBuilder
    private var impactMark: some View {
        switch quality {
        case .thin:
            Capsule()
                .fill(quality.tint)
                .frame(width: size * 0.16, height: max(1, size * 0.045))
                .rotationEffect(.degrees(-4))
                .offset(x: size * 0.11, y: size * 0.1)
        case .pure:
            Capsule()
                .fill(quality.tint)
                .frame(width: max(1, size * 0.05), height: size * 0.17)
                .rotationEffect(.degrees(-12))
                .offset(x: size * 0.1, y: size * 0.08)
        case .chunk:
            EmptyView()
        }
    }

    private var shaftOffset: CGSize {
        switch quality {
        case .thin:
            CGSize(width: -size * 0.07, height: -size * 0.08)
        case .pure:
            CGSize(width: -size * 0.08, height: -size * 0.01)
        case .chunk:
            CGSize(width: -size * 0.18, height: size * 0.12)
        }
    }

    private var ironOffset: CGSize {
        switch quality {
        case .thin:
            CGSize(width: -size * 0.22, height: -size * 0.08)
        case .pure:
            CGSize(width: -size * 0.21, height: size * 0.03)
        case .chunk:
            CGSize(width: -size * 0.31, height: size * 0.19)
        }
    }

    private var ironRotation: Double {
        switch quality {
        case .thin:
            -6
        case .pure:
            -6
        case .chunk:
            15
        }
    }
}

private struct IronFaceSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.05))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.04),
            control: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY - rect.height * 0.02)
        )
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.maxY - rect.height * 0.13))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.maxY - rect.height * 0.02),
            control: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY + rect.height * 0.07)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.minY + rect.height * 0.28))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.05),
            control: CGPoint(x: rect.minX + rect.width * 0.03, y: rect.minY + rect.height * 0.11)
        )
        path.closeSubpath()

        return path
    }
}

private struct ClubShaftShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.41, y: rect.minY + rect.height * 0.58))

        return path
    }
}

private struct GroundStrikeShape: Shape {
    let quality: StrikeQuality

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let groundY = rect.minY + rect.height * 0.78

        switch quality {
        case .chunk:
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.06, y: groundY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.26, y: groundY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.34, y: groundY + rect.height * 0.11))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.47, y: groundY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: groundY))
        case .thin, .pure:
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: groundY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: groundY))
        }


        return path
    }
}

private extension StrikeQuality {
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
