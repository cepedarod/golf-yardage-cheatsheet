import Foundation

@MainActor
final class YardageDashboardViewModel: ObservableObject {
    @Published private(set) var activeClubs: [Club] = []
    @Published private(set) var inactiveClubs: [Club] = []
    @Published private(set) var shotRecords: [ShotRecord] = []
    @Published private(set) var matches: [YardageMatch] = []
    @Published private(set) var targetYardageText = "" {
        didSet {
            guard targetYardageText != oldValue else {
                return
            }

            updateMatches()
            scheduleTargetClearIfNeeded()
        }
    }
    @Published var shotFilter: ShotFilter = .all {
        didSet {
            updateMatches()
        }
    }
    @Published var valueMode: DistanceValueMode = .manual {
        didSet {
            updateMatches()
        }
    }
    @Published var errorMessage: String?

    let profile: GolferProfile
    private let repository: GolfBagRepository
    private let matcher: YardageMatcher
    private let distanceValueResolver: DistanceValueResolver
    private let targetClearDelayNanoseconds: UInt64
    private var clearTargetTask: Task<Void, Never>?

    init(
        profile: GolferProfile,
        repository: GolfBagRepository,
        matcher: YardageMatcher = YardageMatcher(),
        targetClearDelayNanoseconds: UInt64 = 120_000_000_000
    ) {
        self.profile = profile
        self.repository = repository
        self.matcher = matcher
        self.distanceValueResolver = DistanceValueResolver()
        self.targetClearDelayNanoseconds = targetClearDelayNanoseconds
    }

    deinit {
        clearTargetTask?.cancel()
    }

    func loadClubs() {
        do {
            let clubs = try repository.clubs(for: profile.id, includeInactive: true)
                .sorted { lhs, rhs in
                    if lhs.createdAt != rhs.createdAt {
                        return lhs.createdAt < rhs.createdAt
                    }

                    return lhs.id.uuidString < rhs.id.uuidString
                }
            let shotRecords = try repository.shotRecords(for: profile.id)
            activeClubs = clubs.filter(\.isActive)
            inactiveClubs = clubs.filter { $0.isActive == false }
            self.shotRecords = shotRecords
            updateMatches()
            errorMessage = nil
        } catch {
            activeClubs = []
            inactiveClubs = []
            shotRecords = []
            matches = []
            errorMessage = "Unable to load clubs."
        }
    }

    func saveClub(_ club: Club) throws {
        try repository.saveClub(club)
        loadClubs()
    }

    func deactivateClub(_ club: Club) {
        setClub(club, active: false, errorMessage: "Unable to deactivate club.")
    }

    func restoreClub(_ club: Club) {
        setClub(club, active: true, errorMessage: "Unable to restore club.")
    }

    func deleteClub(_ club: Club) {
        do {
            try repository.deleteClub(id: club.id)
            loadClubs()
        } catch {
            errorMessage = "Unable to delete club."
        }
    }

    func clearTargetYardage() {
        clearTargetTask?.cancel()
        targetYardageText = ""
    }

    var hasTargetYardage: Bool {
        targetYardage != nil
    }

    var visibleActiveClubs: [Club] {
        activeClubs.filter {
            distanceValueResolver.hasDisplayableDistances(
                for: $0,
                filter: shotFilter,
                mode: valueMode,
                shotRecords: shotRecords
            )
        }
    }

    func setTargetYardageText(_ text: String) {
        targetYardageText = text
    }

    private var targetYardage: Int? {
        guard let targetYardage = Int(targetYardageText), targetYardage > 0 else {
            return nil
        }

        return targetYardage
    }

    private func updateMatches() {
        guard let targetYardage else {
            matches = []
            return
        }

        matches = matcher.closestMatches(
            targetYardage: targetYardage,
            clubs: activeClubs,
            filter: shotFilter,
            valueMode: valueMode,
            shotRecords: shotRecords
        )
    }

    private func scheduleTargetClearIfNeeded() {
        clearTargetTask?.cancel()

        guard targetYardageText.isEmpty == false else {
            return
        }

        let delay = targetClearDelayNanoseconds
        clearTargetTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }

            self?.clearTargetYardage()
        }
    }

    private func setClub(_ club: Club, active: Bool, errorMessage: String) {
        do {
            try repository.setClubActive(active, clubID: club.id)
            loadClubs()
        } catch {
            self.errorMessage = errorMessage
        }
    }
}
