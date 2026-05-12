import Foundation

@MainActor
final class YardageDashboardViewModel: ObservableObject {
    @Published private(set) var activeClubs: [Club] = []
    @Published var errorMessage: String?

    private let profile: GolferProfile
    private let repository: GolfBagRepository

    init(profile: GolferProfile, repository: GolfBagRepository) {
        self.profile = profile
        self.repository = repository
    }

    func loadClubs() {
        do {
            activeClubs = try repository.clubs(for: profile.id, includeInactive: false)
                .sorted { lhs, rhs in
                    if lhs.createdAt != rhs.createdAt {
                        return lhs.createdAt < rhs.createdAt
                    }

                    return lhs.id.uuidString < rhs.id.uuidString
                }
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load clubs."
        }
    }

    func saveClub(_ club: Club) throws {
        try repository.saveClub(club)
        loadClubs()
    }
}
