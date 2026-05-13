import SwiftUI

struct YardageDashboardView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    @StateObject private var viewModel: YardageDashboardViewModel
    @State private var clubForm: ClubForm?
    @State private var didOfferInitialBagSetup = false
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
                    Text("All")
                        .tag(ShotFilter.all)
                        .accessibilityIdentifier("shot-filter-all")
                    Text("Punch")
                        .tag(ShotFilter.punchOnly)
                        .accessibilityIdentifier("shot-filter-punch")
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
                            ClubSummaryRow(club: club)
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
        let distanceSummary = "\(match.label.rawValue) \(match.distance)"

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

    private var emptyClubsTitle: String {
        if viewModel.shotFilter == .punchOnly, viewModel.activeClubs.isEmpty == false {
            return "No Punch Clubs"
        }

        return viewModel.inactiveClubs.isEmpty ? "No Clubs" : "No Active Clubs"
    }

    private var emptyClubsDescription: String {
        if viewModel.shotFilter == .punchOnly, viewModel.activeClubs.isEmpty == false {
            return "Switch to All or add a punch club."
        }

        return viewModel.inactiveClubs.isEmpty ? "Add your first club." : "Restore one from Inactive Clubs or add a new club."
    }

    private var emptyClubsActionTitle: String {
        if viewModel.shotFilter == .punchOnly, viewModel.activeClubs.isEmpty == false {
            return "Add Club"
        }

        return viewModel.inactiveClubs.isEmpty ? "Add First Club" : "Add Club"
    }

    private var activeClubSectionTitle: String {
        switch viewModel.shotFilter {
        case .all:
            return "\(profile.name)'s Clubs"
        case .punchOnly:
            return "Punch Clubs"
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
