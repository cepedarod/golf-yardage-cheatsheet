import Foundation

@MainActor
final class ProfileSelectionViewModel: ObservableObject {
    @Published private(set) var profiles: [GolferProfile] = []
    @Published private(set) var selectedProfile: GolferProfile?
    @Published var errorMessage: String?

    private let repository: GolfBagRepository

    init(repository: GolfBagRepository) {
        self.repository = repository
    }

    var shouldForceProfileCreation: Bool {
        profiles.isEmpty
    }

    func load() {
        do {
            let data = try repository.loadData()
            profiles = try repository.profiles()

            if let selectedProfileID = data.selectedProfileID,
               let profile = profiles.first(where: { $0.id == selectedProfileID }) {
                selectedProfile = profile
            } else {
                selectedProfile = nil
            }

            errorMessage = nil
        } catch {
            profiles = []
            selectedProfile = nil
            errorMessage = "Unable to load profiles."
        }
    }

    func createProfile(name: String) {
        do {
            let profile = try repository.createProfile(name: name)
            profiles = try repository.profiles()
            selectedProfile = profile
            errorMessage = nil
        } catch GolfBagRepositoryError.profileNameRequired {
            errorMessage = "Enter a profile name."
        } catch {
            errorMessage = "Unable to create profile."
        }
    }

    func selectProfile(_ profile: GolferProfile) {
        do {
            try repository.selectProfile(id: profile.id)
            selectedProfile = profile
            errorMessage = nil
        } catch {
            errorMessage = "Unable to select profile."
        }
    }

    func deleteProfile(_ profile: GolferProfile) {
        do {
            try repository.deleteProfile(id: profile.id)
            profiles = try repository.profiles()

            if selectedProfile?.id == profile.id {
                selectedProfile = nil
            }

            errorMessage = nil
        } catch {
            errorMessage = "Unable to delete profile."
        }
    }

    func clearSelectedProfile() {
        selectedProfile = nil
    }
}
