import SwiftUI

struct RootView: View {
    @StateObject private var viewModel: ProfileSelectionViewModel
    private let repository: GolfBagRepository

    init(repository: GolfBagRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: ProfileSelectionViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selectedProfile = viewModel.selectedProfile {
                    YardageDashboardView(
                        profile: selectedProfile,
                        repository: repository,
                        switchProfile: viewModel.clearSelectedProfile
                    )
                } else {
                    ProfileSelectionView(viewModel: viewModel)
                }
            }
        }
        .task {
            viewModel.load()
        }
    }
}
