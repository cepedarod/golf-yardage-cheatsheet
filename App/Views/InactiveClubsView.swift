import SwiftUI

struct InactiveClubsView: View {
    @ObservedObject var viewModel: YardageDashboardViewModel

    var body: some View {
        List {
            Section {
                if viewModel.inactiveClubs.isEmpty {
                    ContentUnavailableView("No Inactive Clubs", systemImage: "archivebox", description: Text("Deactivated clubs appear here."))
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.inactiveClubs) { club in
                        ClubSummaryRow(club: club)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    viewModel.restoreClub(club)
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteClub(club)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Inactive Clubs")
    }
}

#Preview {
    let repository = GolfBagRepository(store: PreviewGolfBagStore())
    let profile = GolferProfile(name: "Rod")
    let viewModel = YardageDashboardViewModel(profile: profile, repository: repository)
    NavigationStack {
        InactiveClubsView(viewModel: viewModel)
    }
}
