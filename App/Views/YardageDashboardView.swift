import SwiftUI

struct YardageDashboardView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    @StateObject private var viewModel: YardageDashboardViewModel
    @State private var isShowingAddClub = false

    private let formatter = ClubDisplayNameFormatter()

    init(profile: GolferProfile, repository: GolfBagRepository, switchProfile: @escaping () -> Void) {
        self.profile = profile
        self.switchProfile = switchProfile
        _viewModel = StateObject(wrappedValue: YardageDashboardViewModel(profile: profile, repository: repository))
    }

    var body: some View {
        List {
            Section {
                if viewModel.activeClubs.isEmpty {
                    ContentUnavailableView("No Clubs", systemImage: "figure.golf", description: Text("Add your first club."))
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.activeClubs) { club in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(formatter.displayName(for: club))
                                .font(.headline)

                            Text(distanceSummary(for: club))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            } header: {
                Text(profile.name)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Yardage")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: switchProfile) {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Switch Profile")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddClub = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Club")
            }
        }
        .sheet(isPresented: $isShowingAddClub) {
            NavigationStack {
                AddClubView(profile: profile, onSave: viewModel.saveClub)
            }
        }
        .task {
            viewModel.loadClubs()
        }
    }

    private func distanceSummary(for club: Club) -> String {
        let entries: [(label: DistanceLabel, distance: Int)]

        if club.clubType == .putter {
            entries = club.putterDistances?.entries() ?? []
        } else {
            entries = club.swingDistances?.entries() ?? []
        }

        return entries.map { "\($0.label.rawValue) \($0.distance)" }
            .joined(separator: " \u{00B7} ")
    }
}

#Preview {
    YardageDashboardView(
        profile: GolferProfile(name: "Rod"),
        repository: GolfBagRepository(store: PreviewGolfBagStore()),
        switchProfile: {}
    )
}
