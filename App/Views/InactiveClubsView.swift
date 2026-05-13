import SwiftUI

struct InactiveClubsView: View {
    @ObservedObject var viewModel: YardageDashboardViewModel
    @State private var clubBeingEdited: Club?

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
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    clubBeingEdited = club
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)

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
        .sheet(item: $clubBeingEdited) { club in
            NavigationStack {
                AddClubView(profile: viewModel.profile, club: club, onSave: viewModel.saveClub)
            }
        }
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
