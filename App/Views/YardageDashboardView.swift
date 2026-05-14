import SwiftUI

struct YardageDashboardView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    @StateObject private var viewModel: YardageDashboardViewModel
    @State private var clubForm: ClubForm?
    @State private var didOfferInitialBagSetup = false
    @State private var isShowingRecordShot = false
    @State private var targetYardageText = ""

    private let formatter = ClubDisplayNameFormatter()

    init(profile: GolferProfile, repository: GolfBagRepository, switchProfile: @escaping () -> Void) {
        self.profile = profile
        self.switchProfile = switchProfile
        _viewModel = StateObject(wrappedValue: YardageDashboardViewModel(
            profile: profile,
            repository: repository,
            targetClearDelayNanoseconds: Self.targetClearDelayNanoseconds
        ))
    }

    private static var targetClearDelayNanoseconds: UInt64 {
        ProcessInfo.processInfo.environment["TARGET_YARDAGE_CLEAR_DELAY_NANOSECONDS"]
            .flatMap(UInt64.init) ?? 120_000_000_000
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Target")
                    Spacer()
                    NumericTextField(title: "Yards", text: $targetYardageText)
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("target-yardage-field")
                        .frame(maxWidth: 120)
                }

                Picker("Shot Filter", selection: $viewModel.shotFilter) {
                    Text("Normal")
                        .tag(ShotFilter.normal)
                        .accessibilityIdentifier("shot-filter-normal")
                    Text("Low Trajectory")
                        .tag(ShotFilter.lowTrajectory)
                        .accessibilityIdentifier("shot-filter-low-trajectory")
                }
                .pickerStyle(.segmented)

                Picker("Value Mode", selection: $viewModel.valueMode) {
                    Text("Manual")
                        .tag(DistanceValueMode.manual)
                        .accessibilityIdentifier("value-mode-manual")
                    Text("Real")
                        .tag(DistanceValueMode.real)
                        .accessibilityIdentifier("value-mode-real")
                }
                .pickerStyle(.segmented)

                if viewModel.hasTargetYardage {
                    Button("Clear", action: clearTargetYardage)
                }
            }

            if viewModel.hasTargetYardage {
                Section("Closest") {
                    if viewModel.matches.isEmpty {
                        ContentUnavailableView("No Matches", systemImage: "scope", description: Text("Add active clubs or change the filter."))
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.matches) { match in
                            closestMatchRow(for: match)
                        }
                    }
                }
            }

            if viewModel.hasTargetYardage == false {
                Section {
                    if viewModel.visibleActiveClubs.isEmpty {
                        VStack(spacing: 14) {
                            ContentUnavailableView(
                                emptyClubsTitle,
                                systemImage: "figure.golf",
                                description: Text(emptyClubsDescription)
                            )

                            Button {
                                clubForm = .add
                            } label: {
                                Label(emptyClubsActionTitle, systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.visibleActiveClubs) { club in
                            ClubSummaryRow(
                                club: club,
                                shotFilter: viewModel.shotFilter,
                                valueMode: viewModel.valueMode,
                                shotRecords: viewModel.shotRecords
                            )
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        clubForm = .edit(club)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        viewModel.deactivateClub(club)
                                    } label: {
                                        Label("Deactivate", systemImage: "archivebox")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                } header: {
                    Text(activeClubSectionTitle)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Distance")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: switchProfile) {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Switch Profile")
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    NavigationLink {
                        InactiveClubsView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    .accessibilityLabel("Inactive Clubs")

                    Button {
                        clubForm = .add
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Club")
                }
            }
        }
        .sheet(item: $clubForm) { form in
            NavigationStack {
                switch form {
                case .add:
                    AddClubView(profile: profile, onSave: viewModel.saveClub)
                case .edit(let club):
                    AddClubView(profile: profile, club: club, onSave: viewModel.saveClub)
                }
            }
        }
        .sheet(isPresented: $isShowingRecordShot) {
            NavigationStack {
                RecordShotView(
                    profile: profile,
                    clubs: viewModel.recordableActiveClubs,
                    onSave: viewModel.saveShotRecord
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            recordShotBar
        }
        .task {
            viewModel.loadClubs()
            offerInitialBagSetupIfNeeded()
        }
        .onChange(of: targetYardageText) { _, newValue in
            viewModel.setTargetYardageText(newValue)
        }
        .onChange(of: viewModel.targetYardageText) { _, newValue in
            if targetYardageText != newValue {
                targetYardageText = newValue
            }
        }
    }

    private func differenceSummary(for match: YardageMatch) -> String {
        if match.differenceFromTarget == 0 {
            return "Exact"
        }

        let targetYardage = Int(targetYardageText) ?? match.distance

        if match.distance < targetYardage {
            return "\(match.differenceFromTarget) short"
        }

        return "\(match.differenceFromTarget) long"
    }

    private func clearTargetYardage() {
        targetYardageText = ""
        viewModel.clearTargetYardage()
    }

    private func closestMatchRow(for match: YardageMatch) -> some View {
        let displayName = formatter.displayName(for: match.club)
        let distanceSummary = "\(match.displayLabel) \(match.formattedDistance)"

        return VStack(alignment: .leading, spacing: 6) {
            Text(displayName)
                .font(.headline)
                .accessibilityIdentifier("closest-match-name-\(displayName)")

            HStack {
                Text(distanceSummary)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("closest-match-distance-\(displayName)")

                Spacer()

                Text(differenceSummary(for: match))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("closest-match-\(displayName)")
    }

    private var recordShotBar: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                isShowingRecordShot = true
            } label: {
                Label("Record Shot", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(viewModel.recordableActiveClubs.isEmpty)
            .accessibilityIdentifier("record-shot-button")
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var emptyClubsTitle: String {
        if viewModel.shotFilter == .lowTrajectory, viewModel.activeClubs.isEmpty == false {
            return "No Low Trajectory Clubs"
        }

        return viewModel.inactiveClubs.isEmpty ? "No Clubs" : "No Active Clubs"
    }

    private var emptyClubsDescription: String {
        if viewModel.shotFilter == .lowTrajectory, viewModel.activeClubs.isEmpty == false {
            return "Switch to Normal or add low trajectory distances."
        }

        return viewModel.inactiveClubs.isEmpty ? "Add your first club." : "Restore one from Inactive Clubs or add a new club."
    }

    private var emptyClubsActionTitle: String {
        if viewModel.shotFilter == .lowTrajectory, viewModel.activeClubs.isEmpty == false {
            return "Add Club"
        }

        return viewModel.inactiveClubs.isEmpty ? "Add First Club" : "Add Club"
    }

    private var activeClubSectionTitle: String {
        switch viewModel.shotFilter {
        case .normal:
            return "\(profile.name)'s Clubs"
        case .lowTrajectory:
            return "Low Trajectory Clubs"
        }
    }

    private func offerInitialBagSetupIfNeeded() {
        guard didOfferInitialBagSetup == false,
              viewModel.activeClubs.isEmpty,
              viewModel.inactiveClubs.isEmpty,
              viewModel.errorMessage == nil else {
            return
        }

        didOfferInitialBagSetup = true
        clubForm = .add
    }

    private enum ClubForm: Identifiable {
        case add
        case edit(Club)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let club):
                return club.id.uuidString
            }
        }
    }
}

#Preview {
    YardageDashboardView(
        profile: GolferProfile(name: "Rod"),
        repository: GolfBagRepository(store: PreviewGolfBagStore()),
        switchProfile: {}
    )
}

private struct RecordShotView: View {
    let profile: GolferProfile
    let clubs: [Club]
    let onSave: (ShotRecord) throws -> Void

    @Environment(\.dismiss) private var dismiss

    private let formatter = ClubDisplayNameFormatter()

    @State private var selectedClubID: UUID
    @State private var selectedCategory: ShotCategory = .normal
    @State private var selectedPower: ShotPower = .full
    @State private var distanceText = ""
    @State private var strikeQuality: StrikeQuality = .pure
    @State private var direction: ShotDirection = .straight
    @State private var errorMessage: String?

    init(profile: GolferProfile, clubs: [Club], onSave: @escaping (ShotRecord) throws -> Void) {
        self.profile = profile
        self.clubs = clubs
        self.onSave = onSave
        _selectedClubID = State(initialValue: clubs.first?.id ?? UUID())
    }

    var body: some View {
        Form {
            if clubs.isEmpty {
                ContentUnavailableView("No Clubs", systemImage: "figure.golf", description: Text("Add an active non-putter club."))
            } else {
                Section("Club") {
                    Picker("Club", selection: $selectedClubID) {
                        ForEach(clubs) { club in
                            Text(formatter.displayName(for: club))
                                .tag(club.id)
                        }
                    }
                    .accessibilityIdentifier("record-shot-club-picker")
                }

                Section("Shot") {
                    ForEach(availableCategories, id: \.self) { category in
                        powerRow(for: category)
                    }
                }

                Section("Distance") {
                    HStack {
                        Text("Distance (Yards)")
                        Spacer()
                        NumericTextField(title: "Optional", text: $distanceText)
                            .accessibilityIdentifier("record-shot-distance-field")
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
                    .accessibilityIdentifier("strike-quality-picker")
                }

                Section("Direction") {
                    Picker("Direction", selection: $direction) {
                        ForEach(ShotDirection.allCases, id: \.self) { direction in
                            Label(direction.displayName, systemImage: direction.systemImage)
                                .tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("shot-direction-picker")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityIdentifier("record-shot-form")
        .navigationTitle("Record Shot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(clubs.isEmpty)
                    .accessibilityIdentifier("save-shot-button")
            }
        }
        .onChange(of: selectedClubID) { _, _ in
            normalizeSelectedShot()
        }
    }

    private var selectedClub: Club? {
        clubs.first { $0.id == selectedClubID } ?? clubs.first
    }

    private var availableCategories: [ShotCategory] {
        guard let selectedClub else {
            return []
        }

        return selectedClub.clubType.isWedge ? [.normal, .lowTrajectory, .flop] : [.normal, .lowTrajectory]
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
            selectedCategory = category
            selectedPower = power
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
        .accessibilityIdentifier("shot-power-\(category.accessibilityName)-\(power.accessibilityName)")
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
            selectedCategory = .normal
            selectedPower = .full
            return
        }

        if powers(for: selectedCategory).contains(selectedPower) == false {
            selectedPower = powers(for: selectedCategory).first ?? .full
        }
    }

    private func save() {
        guard let selectedClub else {
            errorMessage = "Add an active non-putter club first."
            return
        }

        let record = ShotRecord(
            profileID: profile.id,
            clubID: selectedClub.id,
            category: selectedCategory,
            power: selectedPower,
            distance: distance(from: distanceText),
            strikeQuality: strikeQuality,
            direction: direction,
            createdAt: Date()
        )

        do {
            try onSave(record)
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

        if errors.contains(.putterShotRecordsNotSupported) {
            return "Putters are not supported for shot recording."
        }

        if errors.contains(.unsupportedCategoryForClubType) || errors.contains(.unsupportedPowerForCategory) {
            return "Choose a valid shot type."
        }

        return "Check the shot details and try again."
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
}
