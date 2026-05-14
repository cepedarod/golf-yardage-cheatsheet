import SwiftUI

struct ProfileSelectionView: View {
    @ObservedObject var viewModel: ProfileSelectionViewModel
    @State private var isShowingCreateProfile = false
    @State private var profilePendingDelete: GolferProfile?

    var body: some View {
        Group {
            if viewModel.shouldForceProfileCreation {
                CreateProfileView(
                    title: "Create Profile",
                    submitTitle: "Create",
                    errorMessage: viewModel.errorMessage,
                    onSubmit: viewModel.createProfile
                )
                .padding()
            } else {
                List {
                    Section {
                        ForEach(viewModel.profiles) { profile in
                            Button {
                                viewModel.selectProfile(profile)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.title2)
                                        .foregroundStyle(.green)

                                    Text(profile.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("profile-row-\(profile.name)")
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    profilePendingDelete = profile
                                } label: {
                                    Label("Delete Profile", systemImage: "trash")
                                }
                                .accessibilityIdentifier("delete-profile-\(profile.name)-button")
                            }
                        }
                    }
                }
                .navigationTitle("Profiles")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingCreateProfile = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Profile")
                    }
                }
            }
        }
        .alert("Delete Profile?", isPresented: isConfirmingProfileDelete, presenting: profilePendingDelete) { profile in
            Button("Cancel", role: .cancel) {}
            Button("Delete Profile", role: .destructive) {
                viewModel.deleteProfile(profile)
            }
        } message: { profile in
            Text("This removes \(profile.name), their clubs, and their recorded shots from this device.")
        }
        .sheet(isPresented: $isShowingCreateProfile) {
            NavigationStack {
                CreateProfileView(
                    title: "New Profile",
                    submitTitle: "Create",
                    errorMessage: viewModel.errorMessage,
                    onSubmit: { name in
                        viewModel.createProfile(name: name)
                        if viewModel.selectedProfile != nil {
                            isShowingCreateProfile = false
                        }
                    }
                )
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingCreateProfile = false
                        }
                    }
                }
            }
        }
    }

    private var isConfirmingProfileDelete: Binding<Bool> {
        Binding(
            get: { profilePendingDelete != nil },
            set: { isPresented in
                if isPresented == false {
                    profilePendingDelete = nil
                }
            }
        )
    }
}

#Preview {
    let repository = GolfBagRepository(store: PreviewGolfBagStore())
    let viewModel = ProfileSelectionViewModel(repository: repository)
    ProfileSelectionView(viewModel: viewModel)
}
