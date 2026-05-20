import Foundation

@MainActor
final class YardageDashboardViewModel: ObservableObject {
    @Published private(set) var activeClubs: [Club] = []
    @Published private(set) var inactiveClubs: [Club] = []
    @Published private(set) var shotRecords: [ShotRecord] = []
    @Published private(set) var activeRoundID: UUID?
    @Published private(set) var shotTrackingMode: ShotTrackingMode
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
    private let clubSorter = ClubSorter()
    private let targetClearDelayNanoseconds: UInt64
    private let roundReminderScheduler: RoundReminderScheduler
    private var clearTargetTask: Task<Void, Never>?

    init(
        profile: GolferProfile,
        repository: GolfBagRepository,
        matcher: YardageMatcher = YardageMatcher(),
        targetClearDelayNanoseconds: UInt64 = 120_000_000_000,
        roundReminderScheduler: RoundReminderScheduler = .shared
    ) {
        self.profile = profile
        self.repository = repository
        self.matcher = matcher
        self.distanceValueResolver = DistanceValueResolver()
        self.targetClearDelayNanoseconds = targetClearDelayNanoseconds
        self.roundReminderScheduler = roundReminderScheduler
        self.shotTrackingMode = profile.shotTrackingMode
    }

    deinit {
        clearTargetTask?.cancel()
    }

    func loadClubs() {
        do {
            let data = try repository.loadData()

            guard let currentProfile = data.profiles.first(where: { $0.id == profile.id }) else {
                throw GolfBagRepositoryError.profileNotFound
            }

            let clubs = clubSorter.sortedForDistanceTab(data.clubs(for: profile.id))
            let shotRecords = data.shotRecords
                .filter { $0.profileID == profile.id }
                .sorted(by: oldestShotFirst)
            let activeRound = data.rounds
                .filter { $0.profileID == profile.id && $0.isCompleted == false }
                .sorted(by: newestRoundFirst)
                .first
            activeClubs = clubs.filter(\.isActive)
            inactiveClubs = clubs.filter { $0.isActive == false }
            self.shotRecords = shotRecords
            activeRoundID = activeRound?.id
            if let activeRound, roundReminderScheduler.isStale(activeRound) == false {
                Task {
                    await roundReminderScheduler.scheduleStaleRoundReminder(for: activeRound)
                }
            }
            shotTrackingMode = currentProfile.shotTrackingMode
            updateMatches()
            errorMessage = nil
        } catch {
            activeClubs = []
            inactiveClubs = []
            shotRecords = []
            activeRoundID = nil
            shotTrackingMode = profile.shotTrackingMode
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

    var recordableActiveClubs: [Club] {
        activeClubs.filter { $0.clubType != .putter }
    }

    func setTargetYardageText(_ text: String) {
        targetYardageText = text
    }

    func saveShotRecord(_ record: ShotRecord) throws {
        try repository.saveShotRecord(record)
        loadClubs()
        if record.roundID != nil {
            NotificationCenter.default.post(name: .roundDataDidChange, object: nil)
        }
    }

    @discardableResult
    func startRound(courseName: String? = nil) -> Bool {
        do {
            let suggestedName = courseName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            let roundName = suggestedName ?? Self.defaultRoundName(for: Date())
            let round = try repository.startRound(profileID: profile.id, name: roundName, courseName: suggestedName)
            activeRoundID = round.id
            Task {
                await roundReminderScheduler.scheduleStaleRoundReminder(for: round)
            }
            loadClubs()
            NotificationCenter.default.post(name: .roundDataDidChange, object: nil)
            return true
        } catch {
            errorMessage = "Unable to start round."
            return false
        }
    }

    func deleteShotRecord(_ record: ShotRecord) {
        do {
            try repository.deleteShotRecord(id: record.id)
            loadClubs()
            if record.roundID != nil {
                NotificationCenter.default.post(name: .roundDataDidChange, object: nil)
            }
        } catch {
            errorMessage = "Unable to delete shot."
        }
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

    private static func defaultRoundName(for date: Date) -> String {
        "Round \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func newestRoundFirst(_ lhs: GolfRound, _ rhs: GolfRound) -> Bool {
        if lhs.startedAt != rhs.startedAt {
            return lhs.startedAt > rhs.startedAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func oldestShotFirst(_ lhs: ShotRecord, _ rhs: ShotRecord) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
