import SwiftUI

struct RootView: View {
    @StateObject private var viewModel: ProfileSelectionViewModel

    init(repository: GolfBagRepository) {
        _viewModel = StateObject(wrappedValue: ProfileSelectionViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selectedProfile = viewModel.selectedProfile {
                    YardageDashboardPlaceholderView(
                        profile: selectedProfile,
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

