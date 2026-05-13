import SwiftUI

struct YardageDashboardView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    @StateObject private var viewModel: YardageDashboardViewModel
    @State private var clubForm: ClubForm?

    private let formatter = ClubDisplayNameFormatter()

    init(profile: GolferProfile, repository: GolfBagRepository, switchProfile: @escaping () -> Void) {
        self.profile = profile
        self.switchProfile = switchProfile
        _viewModel = StateObject(wrappedValue: YardageDashboardViewModel(profile: profile, repository: repository))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Target")
                    Spacer()
                    NumericTextField(title: "Yards", text: $viewModel.targetYardageText)
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: 120)
                }

                Picker("Shot Filter", selection: $viewModel.shotFilter) {
                    Text("All").tag(ShotFilter.all)
                    Text("Punch").tag(ShotFilter.punchOnly)
                }
                .pickerStyle(.segmented)

                if viewModel.hasTargetYardage {
                    Button("Clear", action: viewModel.clearTargetYardage)
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
                            VStack(alignment: .leading, spacing: 6) {
                                Text(formatter.displayName(for: match.club))
                                    .font(.headline)

                                HStack {
                                    Text("\(match.label.rawValue) \(match.distance)")
                                        .font(.title3.weight(.semibold))

                                    Spacer()

                                    Text(differenceSummary(for: match))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }

            if viewModel.hasTargetYardage == false {
                Section {
                    if viewModel.activeClubs.isEmpty {
                        ContentUnavailableView("No Clubs", systemImage: "figure.golf", description: Text("Add your first club."))
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.activeClubs) { club in
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
                    Text("\(profile.name)'s Clubs")
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
        }
    }

    private func differenceSummary(for match: YardageMatch) -> String {
        if match.differenceFromTarget == 0 {
            return "Exact"
        }

        let targetYardage = Int(viewModel.targetYardageText) ?? match.distance

        if match.distance < targetYardage {
            return "\(match.differenceFromTarget) short"
        }

        return "\(match.differenceFromTarget) long"
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
