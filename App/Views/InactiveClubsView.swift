import SwiftUI

struct InactiveClubsView: View {
    @ObservedObject var viewModel: YardageDashboardViewModel
    @State private var clubBeingEdited: Club?
    @State private var clubPendingDeletion: Club?

    private let formatter = ClubDisplayNameFormatter()

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
                                    clubPendingDeletion = club
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
        .confirmationDialog(
            "Delete \(deleteConfirmationClubName)?",
            isPresented: isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Club", role: .destructive) {
                if let clubPendingDeletion {
                    viewModel.deleteClub(clubPendingDeletion)
                    self.clubPendingDeletion = nil
                }
            }

            Button("Cancel", role: .cancel) {
                clubPendingDeletion = nil
            }
        } message: {
            Text("This permanently removes the club data.")
        }
    }

    private var deleteConfirmationClubName: String {
        clubPendingDeletion.map { formatter.displayName(for: $0) } ?? "Club"
    }

    private var isConfirmingDelete: Binding<Bool> {
        Binding(
            get: { clubPendingDeletion != nil },
            set: { isPresented in
                if isPresented == false {
                    clubPendingDeletion = nil
                }
            }
        )
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
