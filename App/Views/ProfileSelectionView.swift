import SwiftUI

struct ProfileSelectionView: View {
    @ObservedObject var viewModel: ProfileSelectionViewModel
    @State private var isShowingCreateProfile = false

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
}

#Preview {
    let repository = GolfBagRepository(store: PreviewGolfBagStore())
    let viewModel = ProfileSelectionViewModel(repository: repository)
    ProfileSelectionView(viewModel: viewModel)
}

