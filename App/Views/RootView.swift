import SwiftUI

struct RootView: View {
    @StateObject private var viewModel: ProfileSelectionViewModel
    private let repository: GolfBagRepository

    init(repository: GolfBagRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: ProfileSelectionViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if let selectedProfile = viewModel.selectedProfile {
                MainTabView(
                    profile: selectedProfile,
                    repository: repository,
                    switchProfile: viewModel.clearSelectedProfile
                )
            } else {
                NavigationStack {
                    ProfileSelectionView(viewModel: viewModel)
                }
            }
        }
        .task {
            viewModel.load()
        }
        .onAppear {
            viewModel.load()
        }
    }
}

private struct MainTabView: View {
    private enum Tab: Hashable {
        case distances
        case round
        case analysis
        case profile
    }

    let profile: GolferProfile
    let repository: GolfBagRepository
    let switchProfile: () -> Void

    @StateObject private var boundaryMonitor: RoundBoundaryMonitorViewModel
    @State private var selectedTab: Tab = .distances

    init(profile: GolferProfile, repository: GolfBagRepository, switchProfile: @escaping () -> Void) {
        self.profile = profile
        self.repository = repository
        self.switchProfile = switchProfile
        _boundaryMonitor = StateObject(wrappedValue: RoundBoundaryMonitorViewModel(
            profile: profile,
            repository: repository,
            locationProvider: Self.locationProvider()
        ))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CurrentRoundView(
                    profile: profile,
                    repository: repository,
                    switchProfile: switchProfile
                )
            }
            .tabItem {
                Label("Round", systemImage: "flag.fill")
            }
            .tag(Tab.round)
            .accessibilityIdentifier("round-tab")

            NavigationStack {
                YardageDashboardView(
                    profile: profile,
                    repository: repository,
                    switchProfile: switchProfile
                )
            }
            .tabItem {
                Label("Distances", systemImage: "scope")
            }
            .tag(Tab.distances)
            .accessibilityIdentifier("distances-tab")

            NavigationStack {
                AnalysisView(
                    profile: profile,
                    repository: repository,
                    switchProfile: switchProfile
                )
            }
            .tabItem {
                Label("Analysis", systemImage: "chart.bar.xaxis")
            }
            .tag(Tab.analysis)
            .accessibilityIdentifier("analysis-tab")

            NavigationStack {
                ProfileView(
                    profile: profile,
                    repository: repository,
                    switchProfile: switchProfile
                )
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(Tab.profile)
            .accessibilityIdentifier("profile-tab")
        }
        .onAppear {
            boundaryMonitor.refresh()
            syncLiveActivity()
        }
        .onDisappear {
            boundaryMonitor.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .roundDataDidChange)) { _ in
            boundaryMonitor.refresh()
            syncLiveActivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: .roundReminderOpenRound)) { _ in
            selectedTab = .round
        }
        .onOpenURL(perform: handleDeepLink)
    }

    @MainActor
    private static func locationProvider() -> any ShotLocationProviding {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-data") {
            let distanceYards = ProcessInfo.processInfo.environment["GPS_TEST_DISTANCE_YARDS"]
                .flatMap(Double.init) ?? 1
            let accuracyMeters = ProcessInfo.processInfo.environment["GPS_TEST_ACCURACY_METERS"]
                .flatMap(Double.init) ?? 1
            return SimulatedShotLocationProvider(distanceYards: distanceYards, horizontalAccuracyMeters: accuracyMeters)
        }

        if let distanceText = ProcessInfo.processInfo.environment["GPS_TEST_DISTANCE_YARDS"],
           let distanceYards = Double(distanceText) {
            let accuracyMeters = ProcessInfo.processInfo.environment["GPS_TEST_ACCURACY_METERS"]
                .flatMap(Double.init) ?? 1
            return SimulatedShotLocationProvider(distanceYards: distanceYards, horizontalAccuracyMeters: accuracyMeters)
        }

        return CoreLocationShotLocationProvider()
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "caddiecat" else {
            return
        }

        switch url.host {
        case "distance":
            selectedTab = .distances
        case "round":
            selectedTab = .round
        case "track-shot-start":
            selectedTab = .distances
            Task { @MainActor in
                await Task.yield()
                NotificationCenter.default.post(name: .liveActivityRequestedStartShot, object: nil)
            }
        case "track-shot-finish":
            selectedTab = .distances
            Task { @MainActor in
                await Task.yield()
                NotificationCenter.default.post(name: .liveActivityRequestedFinishShot, object: nil)
            }
        default:
            break
        }
    }

    private func syncLiveActivity() {
        Task {
            do {
                let data = try repository.loadData()

                guard let currentProfile = data.profiles.first(where: { $0.id == profile.id }) else {
                    return
                }

                let activeRound = data.rounds
                    .filter { $0.profileID == profile.id && $0.isCompleted == false }
                    .sorted(by: newestRoundFirst)
                    .first
                let shotCount = activeRound.map { round in
                    data.shotRecords.filter { $0.roundID == round.id }.count
                } ?? 0
                let clubs = ClubSorter()
                    .sortedForDistanceTab(data.clubs(for: profile.id))
                    .filter { $0.isActive && $0.clubType != .putter }

                await RoundLiveActivityManager.shared.sync(
                    activeRound: activeRound,
                    profile: currentProfile,
                    shotCount: shotCount,
                    clubs: clubs
                )
            } catch {
                return
            }
        }
    }

    private func newestRoundFirst(_ lhs: GolfRound, _ rhs: GolfRound) -> Bool {
        if lhs.startedAt != rhs.startedAt {
            return lhs.startedAt > rhs.startedAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}

@MainActor
private final class RoundBoundaryMonitorViewModel: ObservableObject {
    private let profileID: UUID
    private let repository: GolfBagRepository
    private let locationProvider: any ShotLocationProviding
    private let roundReminderScheduler: RoundReminderScheduler
    private let calculator = ShotGPSMeasurementCalculator()

    private var monitoredRoundID: UUID?
    private var boundaryAnchor: ShotLocationAnchor?
    private var monitorTask: Task<Void, Never>?
    private var didNotifyBoundaryExit = false

    init(
        profile: GolferProfile,
        repository: GolfBagRepository,
        locationProvider: any ShotLocationProviding,
        roundReminderScheduler: RoundReminderScheduler = .shared
    ) {
        profileID = profile.id
        self.repository = repository
        self.locationProvider = locationProvider
        self.roundReminderScheduler = roundReminderScheduler
    }

    deinit {
        monitorTask?.cancel()
    }

    func refresh() {
        guard isMonitoringEnabled else {
            stop()
            return
        }

        guard let round = try? repository.activeRound(for: profileID) else {
            stop()
            return
        }

        if monitoredRoundID == round.id, monitorTask != nil {
            return
        }

        startMonitoring(round)
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        monitoredRoundID = nil
        boundaryAnchor = nil
        didNotifyBoundaryExit = false
        locationProvider.stopWarmingLocation()
    }

    private func startMonitoring(_ round: GolfRound) {
        stop()
        monitoredRoundID = round.id
        locationProvider.startWarmingLocation()

        monitorTask = Task { [weak self] in
            await self?.monitor(round)
        }
    }

    private func monitor(_ round: GolfRound) async {
        await updateBoundaryAnchor()

        while Task.isCancelled == false {
            guard (try? repository.activeRound(for: profileID)?.id) == round.id else {
                stop()
                return
            }

            await checkBoundary(for: round)

            do {
                try await Task.sleep(nanoseconds: boundaryCheckIntervalNanoseconds)
            } catch {
                return
            }
        }
    }

    private func updateBoundaryAnchor() async {
        do {
            boundaryAnchor = try await locationProvider.currentAnchor()
        } catch {
            boundaryAnchor = nil
        }
    }

    private func checkBoundary(for round: GolfRound) async {
        guard didNotifyBoundaryExit == false else {
            return
        }

        do {
            let currentAnchor = try await locationProvider.currentAnchor()

            guard let boundaryAnchor else {
                self.boundaryAnchor = currentAnchor
                return
            }

            let distanceMeters = calculator.distanceMeters(from: boundaryAnchor, to: currentAnchor)
            guard distanceMeters > boundaryRadiusMeters else {
                return
            }

            didNotifyBoundaryExit = true
            await roundReminderScheduler.scheduleBoundaryExitReminder(for: round)
            NotificationCenter.default.post(
                name: .roundMayBeFinished,
                object: nil,
                userInfo: [RoundReminderScheduler.roundIDUserInfoKey: round.id.uuidString]
            )
        } catch {
            return
        }
    }

    private var boundaryRadiusMeters: Double {
        ProcessInfo.processInfo.environment["ROUND_BOUNDARY_RADIUS_METERS"]
            .flatMap(Double.init) ?? 5_000
    }

    private var boundaryCheckIntervalNanoseconds: UInt64 {
        let intervalSeconds = ProcessInfo.processInfo.environment["ROUND_BOUNDARY_CHECK_INTERVAL_SECONDS"]
            .flatMap(Double.init) ?? 60
        return UInt64(max(5, intervalSeconds) * 1_000_000_000)
    }

    private var isMonitoringEnabled: Bool {
        ProcessInfo.processInfo.environment["ROUND_BOUNDARY_MONITORING_DISABLED"] != "1"
    }
}

@MainActor
private final class ProfileDashboardViewModel: ObservableObject {
    @Published var shotTrackingMode: ShotTrackingMode
    @Published var homeBaseCity: String
    @Published var homeBaseAltitudeText: String
    @Published var altitudeCalculationMode: AltitudeCalculationMode
    @Published private(set) var profileName: String
    @Published private(set) var shotRows: [ProfileShotRow] = []
    @Published private(set) var completedRounds: [GolfRound] = []
    @Published private(set) var shotCountsByRoundID: [UUID: Int] = [:]
    @Published private(set) var clubStrikeRows: [ProfileClubStrikeRow] = []
    @Published var errorMessage: String?

    private let profileID: UUID
    private let repository: GolfBagRepository
    private let formatter = ClubDisplayNameFormatter()
    private let clubSorter = ClubSorter()

    init(profile: GolferProfile, repository: GolfBagRepository) {
        profileID = profile.id
        profileName = profile.name
        shotTrackingMode = profile.shotTrackingMode
        homeBaseCity = profile.homeBaseCity
        homeBaseAltitudeText = Self.formattedAltitude(profile.homeBaseAltitudeFeet)
        altitudeCalculationMode = profile.altitudeCalculationMode
        self.repository = repository
    }

    func load() {
        do {
            let data = try repository.loadData()

            guard let profile = data.profiles.first(where: { $0.id == profileID }) else {
                throw GolfBagRepositoryError.profileNotFound
            }

            let clubsByID = Dictionary(uniqueKeysWithValues: data.clubs.map { ($0.id, $0) })
            let sortedClubs = clubSorter.sortedForDistanceTab(data.clubs(for: profileID))
            profileName = profile.name
            shotTrackingMode = profile.shotTrackingMode
            homeBaseCity = profile.homeBaseCity
            homeBaseAltitudeText = Self.formattedAltitude(profile.homeBaseAltitudeFeet)
            altitudeCalculationMode = profile.altitudeCalculationMode
            shotRows = data.shotRecords
                .filter { $0.profileID == profileID }
                .sorted(by: newestShotFirst)
                .map { record in
                    ProfileShotRow(
                        record: record,
                        club: clubsByID[record.clubID],
                        clubName: clubsByID[record.clubID].map(formatter.displayName(for:)) ?? "Deleted Club"
                    )
                }
            completedRounds = data.rounds
                .filter { $0.profileID == profileID && $0.isCompleted }
                .sorted(by: newestRoundFirst)
            shotCountsByRoundID = data.shotRecords
                .filter { $0.profileID == profileID }
                .reduce(into: [:]) { counts, record in
                    if let roundID = record.roundID {
                        counts[roundID, default: 0] += 1
                    }
                }
            clubStrikeRows = sortedClubs.compactMap { club in
                guard club.clubType != .putter else {
                    return nil
                }

                let clubRecords = data.shotRecords.filter { $0.profileID == profileID && $0.clubID == club.id }
                let pureCount = clubRecords.filter { $0.strikeQuality == .pure }.count
                let mishitCount = clubRecords.filter { $0.strikeQuality == .thin || $0.strikeQuality == .chunk }.count
                let totalCount = pureCount + mishitCount

                guard totalCount > 0 else {
                    return nil
                }

                return ProfileClubStrikeRow(
                    clubName: formatter.displayName(for: club),
                    pureCount: pureCount,
                    mishitCount: mishitCount
                )
            }
            errorMessage = nil
        } catch {
            shotRows = []
            completedRounds = []
            shotCountsByRoundID = [:]
            clubStrikeRows = []
            errorMessage = "Unable to load profile details."
        }
    }

    func updateShotTrackingMode(_ mode: ShotTrackingMode) {
        do {
            try repository.updateProfileShotTrackingMode(profileID: profileID, mode: mode)
            errorMessage = nil
            load()
        } catch {
            errorMessage = "Unable to update shot tracking mode."
            load()
        }
    }

    func updateAltitudeSettings() {
        do {
            try repository.updateProfileAltitudeSettings(
                profileID: profileID,
                homeBaseCity: homeBaseCity,
                homeBaseAltitudeFeet: Double(homeBaseAltitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? AltitudeDefaults.chicagoFeet,
                altitudeCalculationMode: altitudeCalculationMode
            )
            errorMessage = nil
            load()
            NotificationCenter.default.post(name: .roundDataDidChange, object: nil)
        } catch GolfBagRepositoryError.homeBaseCityRequired {
            errorMessage = "Home base city is required."
            load()
        } catch {
            errorMessage = "Unable to update altitude settings."
            load()
        }
    }

    func saveShotRecord(_ record: ShotRecord) throws {
        try repository.saveShotRecord(record)
        load()
    }

    func deleteShotRecord(_ row: ProfileShotRow) {
        do {
            try repository.deleteShotRecord(id: row.record.id)
            load()
        } catch {
            errorMessage = "Unable to delete shot."
        }
    }

    func deleteAllShots() {
        do {
            try repository.deleteAllShotRecords(for: profileID)
            load()
        } catch {
            errorMessage = "Unable to delete shots."
        }
    }

    func deleteRound(_ round: GolfRound) {
        do {
            try repository.deleteRound(id: round.id)
            load()
        } catch {
            errorMessage = "Unable to delete round."
        }
    }

    func shotCount(for round: GolfRound) -> Int {
        shotCountsByRoundID[round.id] ?? 0
    }

    func shotRows(for round: GolfRound) -> [ProfileShotRow] {
        shotRows
            .filter { $0.record.roundID == round.id }
            .sorted(by: oldestShotFirst)
    }

    private func newestShotFirst(_ lhs: ShotRecord, _ rhs: ShotRecord) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func oldestShotFirst(_ lhs: ProfileShotRow, _ rhs: ProfileShotRow) -> Bool {
        if lhs.record.createdAt != rhs.record.createdAt {
            return lhs.record.createdAt < rhs.record.createdAt
        }

        return lhs.record.id.uuidString < rhs.record.id.uuidString
    }

    private func newestRoundFirst(_ lhs: GolfRound, _ rhs: GolfRound) -> Bool {
        if lhs.startedAt != rhs.startedAt {
            return lhs.startedAt > rhs.startedAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func formattedAltitude(_ altitudeFeet: Double) -> String {
        "\(Int(altitudeFeet.rounded()))"
    }
}

private struct ProfileShotRow: Identifiable, Equatable {
    var id: UUID { record.id }

    let record: ShotRecord
    let club: Club?
    let clubName: String
}

private struct ProfileClubStrikeRow: Identifiable, Equatable {
    var id: String { clubName }

    let clubName: String
    let pureCount: Int
    let mishitCount: Int

    var totalCount: Int {
        pureCount + mishitCount
    }

    var purePercentage: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(pureCount) / Double(totalCount) * 100
    }

    var mishitPercentage: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(mishitCount) / Double(totalCount) * 100
    }
}

@MainActor
private final class CurrentRoundViewModel: ObservableObject {
    @Published private(set) var activeRound: GolfRound?
    @Published private(set) var shotRows: [ProfileShotRow] = []
    @Published private(set) var isRoundStale = false
    @Published private(set) var isStartingRound = false
    @Published var roundNameDraft: String
    @Published var distanceTrackingMode: RoundDistanceTrackingMode = .accountForAltitude
    @Published var errorMessage: String?

    private let profileID: UUID
    private let repository: GolfBagRepository
    private let formatter = ClubDisplayNameFormatter()
    private let locationProvider: any ShotLocationProviding
    private let courseNameProvider: any GolfCourseNameProviding
    private let roundReminderScheduler: RoundReminderScheduler

    init(
        profile: GolferProfile,
        repository: GolfBagRepository,
        locationProvider: any ShotLocationProviding,
        courseNameProvider: any GolfCourseNameProviding,
        roundReminderScheduler: RoundReminderScheduler = .shared
    ) {
        profileID = profile.id
        self.repository = repository
        self.locationProvider = locationProvider
        self.courseNameProvider = courseNameProvider
        self.roundReminderScheduler = roundReminderScheduler
        roundNameDraft = Self.defaultRoundName(for: Date())
    }

    func load() {
        do {
            let data = try repository.loadData()

            guard data.profiles.contains(where: { $0.id == profileID }) else {
                throw GolfBagRepositoryError.profileNotFound
            }

            let clubsByID = Dictionary(uniqueKeysWithValues: data.clubs.map { ($0.id, $0) })
            let round = data.rounds
                .filter { $0.profileID == profileID && $0.isCompleted == false }
                .sorted(by: newestRoundFirst)
                .first

            activeRound = round
            isRoundStale = round.map { roundReminderScheduler.isStale($0) } ?? false

            if let round {
                roundNameDraft = round.name
                distanceTrackingMode = round.distanceTrackingMode
                if roundReminderScheduler.isStale(round) == false {
                    Task {
                        await roundReminderScheduler.scheduleStaleRoundReminder(for: round)
                    }
                }
                shotRows = data.shotRecords
                    .filter { $0.profileID == profileID && $0.roundID == round.id }
                    .sorted(by: oldestShotFirst)
                    .map { record in
                        ProfileShotRow(
                            record: record,
                            club: clubsByID[record.clubID],
                            clubName: clubsByID[record.clubID].map(formatter.displayName(for:)) ?? "Deleted Club"
                        )
                    }
            } else {
                if roundNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    roundNameDraft = Self.defaultRoundName(for: Date())
                }
                shotRows = []
                isRoundStale = false
                distanceTrackingMode = .accountForAltitude
            }

            errorMessage = nil
        } catch {
            activeRound = nil
            shotRows = []
            isRoundStale = false
            errorMessage = "Unable to load round."
        }
    }

    func startRound() {
        guard isStartingRound == false else {
            return
        }

        isStartingRound = true
        Task { @MainActor in
            await startRoundWithSuggestedCourse()
        }
    }

    func saveRoundName() {
        guard let activeRound else {
            return
        }

        do {
            _ = try repository.updateRoundName(id: activeRound.id, name: normalizedRoundName())
            load()
        } catch GolfBagRepositoryError.roundNameRequired {
            errorMessage = "Round name is required."
        } catch {
            errorMessage = "Unable to update round name."
        }
    }

    func updateDistanceTrackingMode(_ mode: RoundDistanceTrackingMode) {
        guard let activeRound else {
            return
        }

        do {
            _ = try repository.updateRoundDistanceTrackingMode(id: activeRound.id, mode: mode)
            errorMessage = nil
            load()
            NotificationCenter.default.post(name: .roundDataDidChange, object: nil)
        } catch {
            errorMessage = "Unable to update distance tracking."
            load()
        }
    }

    func endRound() {
        guard let activeRound else {
            return
        }

        do {
            _ = try repository.endRound(id: activeRound.id)
            roundReminderScheduler.cancelReminder(for: activeRound.id)
            roundNameDraft = Self.defaultRoundName(for: Date())
            load()
            NotificationCenter.default.post(name: .roundDataDidChange, object: nil)
        } catch {
            errorMessage = "Unable to end round."
        }
    }

    func abortRound() {
        guard let activeRound else {
            return
        }

        do {
            try repository.abortRound(id: activeRound.id)
            roundReminderScheduler.cancelReminder(for: activeRound.id)
            roundNameDraft = Self.defaultRoundName(for: Date())
            load()
            NotificationCenter.default.post(name: .roundDataDidChange, object: nil)
        } catch {
            errorMessage = "Unable to abort round."
        }
    }

    func saveShotRecord(_ record: ShotRecord) throws {
        try repository.saveShotRecord(record)
        load()
    }

    func deleteShotRecord(_ row: ProfileShotRow) {
        do {
            try repository.deleteShotRecord(id: row.record.id)
            load()
        } catch {
            errorMessage = "Unable to delete shot."
        }
    }

    var hasRoundNameChanges: Bool {
        guard let activeRound else {
            return false
        }

        let trimmedName = roundNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty == false && trimmedName != activeRound.name
    }

    func startLocationWarmup() {
        locationProvider.startWarmingLocation()
    }

    func stopLocationWarmup() {
        locationProvider.stopWarmingLocation()
    }

    func keepPlaying() {
        guard let activeRound else {
            return
        }

        isRoundStale = false
        Task {
            await roundReminderScheduler.scheduleKeepPlayingReminder(for: activeRound)
        }
    }

    func markRoundPossiblyFinished(roundID: UUID) {
        guard activeRound?.id == roundID else {
            return
        }

        isRoundStale = true
    }

    private func startRoundWithSuggestedCourse() async {
        defer {
            isStartingRound = false
        }

        do {
            let name = normalizedRoundName()
            let defaultName = Self.defaultRoundName(for: Date())
            let userEditedName = name != defaultName
            let context = userEditedName ? (courseName: nil as String?, altitudeFeet: await currentAltitudeFeet()) : await suggestedRoundContext()
            let courseName = context.courseName
            let roundName = courseName ?? name
            let round = try repository.startRound(
                profileID: profileID,
                name: roundName,
                courseName: courseName,
                altitudeFeet: context.altitudeFeet
            )
            Task {
                await roundReminderScheduler.scheduleStaleRoundReminder(for: round)
            }
            load()
            NotificationCenter.default.post(name: .roundDataDidChange, object: nil)
        } catch {
            errorMessage = "Unable to start round."
        }
    }

    private func suggestedRoundContext() async -> (courseName: String?, altitudeFeet: Double?) {
        do {
            let anchor = try await locationProvider.currentAnchor()
            return (await courseNameProvider.nearestCourseName(to: anchor.coordinate), anchor.altitudeFeet)
        } catch {
            return (nil, nil)
        }
    }

    private func currentAltitudeFeet() async -> Double? {
        do {
            return try await locationProvider.currentAnchor().altitudeFeet
        } catch {
            return nil
        }
    }

    private func normalizedRoundName() -> String {
        let trimmedName = roundNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? Self.defaultRoundName(for: Date()) : trimmedName
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
}

private struct CurrentRoundView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    @StateObject private var viewModel: CurrentRoundViewModel
    @State private var isConfirmingEndRound = false
    @State private var isConfirmingAbortRound = false
    @FocusState private var isRoundNameFocused: Bool

    init(profile: GolferProfile, repository: GolfBagRepository, switchProfile: @escaping () -> Void) {
        self.profile = profile
        self.switchProfile = switchProfile
        _viewModel = StateObject(wrappedValue: CurrentRoundViewModel(
            profile: profile,
            repository: repository,
            locationProvider: Self.locationProvider(),
            courseNameProvider: Self.courseNameProvider()
        ))
    }

    @MainActor
    private static func locationProvider() -> any ShotLocationProviding {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-data") {
            let distanceYards = ProcessInfo.processInfo.environment["GPS_TEST_DISTANCE_YARDS"]
                .flatMap(Double.init) ?? 1
            let accuracyMeters = ProcessInfo.processInfo.environment["GPS_TEST_ACCURACY_METERS"]
                .flatMap(Double.init) ?? 1
            return SimulatedShotLocationProvider(distanceYards: distanceYards, horizontalAccuracyMeters: accuracyMeters)
        }

        if let distanceText = ProcessInfo.processInfo.environment["GPS_TEST_DISTANCE_YARDS"],
           let distanceYards = Double(distanceText) {
            let accuracyMeters = ProcessInfo.processInfo.environment["GPS_TEST_ACCURACY_METERS"]
                .flatMap(Double.init) ?? 1
            return SimulatedShotLocationProvider(distanceYards: distanceYards, horizontalAccuracyMeters: accuracyMeters)
        }

        return CoreLocationShotLocationProvider()
    }

    private static func courseNameProvider() -> any GolfCourseNameProviding {
        if let courseName = ProcessInfo.processInfo.environment["ROUND_TEST_COURSE_NAME"] {
            return StaticGolfCourseNameProvider(name: courseName)
        }

        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-data") {
            return StaticGolfCourseNameProvider(name: nil)
        }

        if ProcessInfo.processInfo.environment["GPS_TEST_DISTANCE_YARDS"] != nil {
            return StaticGolfCourseNameProvider(name: nil)
        }

        return MapKitGolfCourseNameProvider()
    }

    var body: some View {
        List {
            if let activeRound = viewModel.activeRound {
                activeRoundSection(activeRound)
                activeRoundShotsSection
                if viewModel.isRoundStale {
                    staleRoundSection
                }
                activeRoundActionsSection
            } else {
                startRoundSection
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityIdentifier("current-round-list")
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Current Round")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: switchProfile) {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Switch Profile")
            }

            ToolbarItemGroup(placement: .keyboard) {
                if isRoundNameFocused {
                    Spacer()
                    Button("Done") {
                        isRoundNameFocused = false
                    }
                    .accessibilityIdentifier("dismiss-round-name-keyboard-button")
                }
            }
        }
        .alert("End Round?", isPresented: $isConfirmingEndRound) {
            Button("End Round") {
                viewModel.endRound()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This saves the round to your profile history.")
        }
        .alert("Abort Round?", isPresented: $isConfirmingAbortRound) {
            Button("Abort Round", role: .destructive) {
                viewModel.abortRound()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This discards the active round and shots tied to it.")
        }
        .onAppear {
            viewModel.load()
            syncLocationWarmup()
        }
        .onDisappear {
            viewModel.stopLocationWarmup()
        }
        .onChange(of: viewModel.activeRound?.id) { _, _ in
            syncLocationWarmup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .roundDataDidChange)) { _ in
            viewModel.load()
            syncLocationWarmup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .roundMayBeFinished)) { notification in
            guard let roundID = RoundReminderScheduler.roundID(from: notification.userInfo ?? [:]) else {
                return
            }

            viewModel.markRoundPossiblyFinished(roundID: roundID)
        }
    }

    private var startRoundSection: some View {
        Section {
            roundNameEditor(accessibilityIdentifier: "round-name-field")

            Button {
                viewModel.startRound()
            } label: {
                Label(
                    viewModel.isStartingRound ? "Starting Round" : "Start Round",
                    systemImage: viewModel.isStartingRound ? "location.circle.fill" : "play.circle.fill"
                )
            }
            .disabled(viewModel.isStartingRound)
            .accessibilityIdentifier("start-round-button")
        } header: {
            Text("Round")
        } footer: {
            Text("Start a round to group tracked shots together.")
        }
    }

    private func syncLocationWarmup() {
        if viewModel.activeRound == nil {
            viewModel.stopLocationWarmup()
        } else {
            viewModel.startLocationWarmup()
        }
    }

    private func activeRoundSection(_ round: GolfRound) -> some View {
        Section("Round") {
            HStack {
                Text("Name")
                Spacer()
                roundNameEditor(
                    alignment: .trailing,
                    accessibilityIdentifier: "active-round-name-field"
                )
                .frame(maxWidth: 240)
            }

            if viewModel.hasRoundNameChanges {
                Button("Save Name") {
                    viewModel.saveRoundName()
                }
                .accessibilityIdentifier("save-round-name-button")
            }

            HStack {
                Text("Started")
                Spacer()
                Text(round.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            if let altitudeFeet = round.altitudeFeet {
                HStack {
                    Text("Altitude")
                    Spacer()
                    Text("\(Int(altitudeFeet.rounded())) ft")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Picker("Distance Tracking", selection: $viewModel.distanceTrackingMode) {
                ForEach(RoundDistanceTrackingMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("round-distance-tracking-picker")
            .onChange(of: viewModel.distanceTrackingMode) { _, newMode in
                viewModel.updateDistanceTrackingMode(newMode)
            }
        }
    }

    private func roundNameEditor(
        alignment: TextAlignment = .leading,
        accessibilityIdentifier: String
    ) -> some View {
        HStack(spacing: 6) {
            TextField("Round Name", text: $viewModel.roundNameDraft)
                .multilineTextAlignment(alignment)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($isRoundNameFocused)
                .onSubmit {
                    isRoundNameFocused = false
                }
                .accessibilityIdentifier(accessibilityIdentifier)

            if viewModel.roundNameDraft.isEmpty == false {
                Button {
                    viewModel.roundNameDraft = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Round Name")
                .accessibilityIdentifier("\(accessibilityIdentifier)-clear-button")
            }
        }
    }

    private var activeRoundShotsSection: some View {
        Section("Shots") {
            NavigationLink {
                CurrentRoundShotListView(viewModel: viewModel)
            } label: {
                ProfileMetricRow(
                    title: "Total Shots",
                    value: "\(viewModel.shotRows.count)",
                    systemImage: "list.bullet.rectangle",
                    valueAccessibilityIdentifier: "current-round-shot-count"
                )
            }
            .accessibilityIdentifier("current-round-total-shots-row")
        }
    }

    private var staleRoundSection: some View {
        Section("Reminder") {
            Text("Caddie Cat thinks this round may be finished.")
                .foregroundStyle(.secondary)

            Button {
                isConfirmingEndRound = true
            } label: {
                Label("Finish Round", systemImage: "checkmark.circle.fill")
            }
            .accessibilityIdentifier("finish-stale-round-button")

            Button {
                viewModel.keepPlaying()
            } label: {
                Label("Keep Playing", systemImage: "figure.golf")
            }
            .accessibilityIdentifier("keep-playing-button")
        }
    }

    private var activeRoundActionsSection: some View {
        Section {
            Button {
                isConfirmingEndRound = true
            } label: {
                Text("End Round")
            }
            .accessibilityIdentifier("end-round-button")

            Button(role: .destructive) {
                isConfirmingAbortRound = true
            } label: {
                Text("Abort Round")
            }
            .tint(.red)
            .accessibilityIdentifier("abort-round-button")
        }
    }
}

private struct CurrentRoundShotListView: View {
    @ObservedObject var viewModel: CurrentRoundViewModel

    @State private var editingRow: ProfileShotRow?

    var body: some View {
        List {
            if viewModel.shotRows.isEmpty {
                ContentUnavailableView(
                    "No Round Shots",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Shots recorded during this round will appear here.")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.shotRows) { row in
                    Button {
                        if row.club != nil {
                            editingRow = row
                        }
                    } label: {
                        ProfileShotRecordRowView(row: row)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("current-round-shot-row-\(row.record.id.uuidString)")
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if row.club != nil {
                            Button {
                                editingRow = row
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteShotRecord(row)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("current-round-shot-list")
        .navigationTitle("Round Shots")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingRow) { row in
            if let club = row.club {
                NavigationStack {
                    ShotRecordEditView(club: club, record: row.record, onSave: viewModel.saveShotRecord)
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
    }
}

private struct ProfileView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    @StateObject private var viewModel: ProfileDashboardViewModel
    @State private var isShowingPrivacyPolicy = false

    init(profile: GolferProfile, repository: GolfBagRepository, switchProfile: @escaping () -> Void) {
        self.profile = profile
        self.switchProfile = switchProfile
        _viewModel = StateObject(wrappedValue: ProfileDashboardViewModel(profile: profile, repository: repository))
    }

    var body: some View {
        List {
            Section("Shot Tracking") {
                Picker("Shot Tracking Mode", selection: $viewModel.shotTrackingMode) {
                    ForEach(ShotTrackingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("shot-tracking-mode-picker")
                .onChange(of: viewModel.shotTrackingMode) { _, newMode in
                    viewModel.updateShotTrackingMode(newMode)
                }
            }

            Section {
                TextField("Home Base City", text: $viewModel.homeBaseCity)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .accessibilityIdentifier("home-base-city-field")

                HStack {
                    Text("Home Altitude")

                    Spacer()

                    TextField("Feet", text: $viewModel.homeBaseAltitudeText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                        .accessibilityIdentifier("home-base-altitude-field")

                    Text("ft")
                        .foregroundStyle(.secondary)
                }

                Picker("Shot Calculations", selection: $viewModel.altitudeCalculationMode) {
                    ForEach(AltitudeCalculationMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("altitude-calculation-mode-picker")

                Button("Save Altitude Settings") {
                    viewModel.updateAltitudeSettings()
                }
                .accessibilityIdentifier("save-altitude-settings-button")
            } header: {
                Text("Altitude")
            } footer: {
                Text("Caddie Cat uses home altitude to normalize shot distances when altitude adjustments are enabled.")
            }

            Section("Overview") {
                NavigationLink {
                    ProfileAllShotsView(viewModel: viewModel)
                } label: {
                    ProfileMetricRow(
                        title: "All Shots",
                        value: "\(viewModel.shotRows.count)",
                        systemImage: "list.bullet.rectangle",
                        valueAccessibilityIdentifier: "profile-all-shots-count"
                    )
                }
                .accessibilityIdentifier("profile-all-shots-row")

                NavigationLink {
                    ProfileRoundsListView(viewModel: viewModel)
                } label: {
                    ProfileMetricRow(
                        title: "Number of Rounds",
                        value: "\(viewModel.completedRounds.count)",
                        systemImage: "flag.checkered",
                        valueAccessibilityIdentifier: "profile-rounds-count"
                    )
                }
                .accessibilityIdentifier("profile-rounds-row")
            }

            if viewModel.clubStrikeRows.isEmpty == false {
                Section("Club Strike") {
                    ProfileClubStrikeChartView(rows: viewModel.clubStrikeRows)
                        .accessibilityIdentifier("profile-club-strike-chart")
                }
            }

            Section("App") {
                Button {
                    isShowingPrivacyPolicy = true
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("privacy-policy-button")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityIdentifier("profile-list")
        .navigationTitle(profile.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: switchProfile) {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Switch Profile")
            }
        }
        .task {
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .roundDataDidChange)) { _ in
            viewModel.load()
        }
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            NavigationStack {
                PrivacyPolicyView()
            }
        }
    }
}

private struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                policySection(
                    title: "Local Data",
                    text: "Caddie Cat stores your profiles, clubs, yardages, rounds, shot records, GPS shot measurements, altitude values, and Live Activity draft selections locally on your device so the app can calculate yardages, show recommendations, and summarize your golf data."
                )

                policySection(
                    title: "Location",
                    text: "If you enable location access, Caddie Cat uses your device location while the app is in use to measure shot distances, estimate altitude, support active-round reminders, and show GPS confidence. Recorded location-derived shot data remains on your device."
                )

                policySection(
                    title: "Notifications",
                    text: "Caddie Cat may ask for notification permission to send local reminders for active rounds. These notifications are generated on your device."
                )

                policySection(
                    title: "Tracking",
                    text: "Caddie Cat does not require an account, does not use your data for advertising, does not track you across apps or websites, and does not sell personal information."
                )

                policySection(
                    title: "Deleting Data",
                    text: "If you delete the app, locally stored Caddie Cat data is deleted from the device by iOS. If future versions add sync, export, or sharing features, this policy should be updated before release."
                )
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func policySection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProfileMetricRow: View {
    let title: String
    let value: String
    let systemImage: String
    let valueAccessibilityIdentifier: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.green)
                .frame(width: 32)

            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier(valueAccessibilityIdentifier)
        }
        .padding(.vertical, 6)
    }
}

private struct ProfileClubStrikeChartView: View {
    let rows: [ProfileClubStrikeRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                legendItem(title: "Pure", tint: .green)
                legendItem(title: "Thin + Chunk", tint: .red)
            }

            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.clubName)
                            .font(.caption.weight(.semibold))

                        Spacer()

                        Text("\(row.pureCount)/\(row.totalCount) pure")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    DistributionStackedBar(
                        rows: [
                            DistributionSegmentData(id: "\(row.id)-pure", percentage: row.purePercentage, tint: .green),
                            DistributionSegmentData(id: "\(row.id)-mishit", percentage: row.mishitPercentage, tint: .red)
                        ],
                        totalCount: row.totalCount
                    )
                    .frame(height: 12)
                }
                .accessibilityIdentifier("profile-club-strike-row-\(row.clubName)")
            }
        }
        .padding(.vertical, 6)
    }

    private func legendItem(title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProfileAllShotsView: View {
    @ObservedObject var viewModel: ProfileDashboardViewModel

    @State private var editingRow: ProfileShotRow?
    @State private var isConfirmingDeleteAll = false

    var body: some View {
        List {
            if viewModel.shotRows.isEmpty {
                ContentUnavailableView(
                    "No Shots",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Tracked shots will appear here.")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.shotRows) { row in
                    Button {
                        if row.club != nil {
                            editingRow = row
                        }
                    } label: {
                        ProfileShotRecordRowView(row: row)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile-shot-row-\(row.record.id.uuidString)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteShotRecord(row)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("profile-all-shots-list")
        .navigationTitle("All Shots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.shotRows.isEmpty == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete All", role: .destructive) {
                        isConfirmingDeleteAll = true
                    }
                    .accessibilityIdentifier("delete-all-shots-button")
                }
            }
        }
        .alert("Delete All Shots?", isPresented: $isConfirmingDeleteAll) {
            Button("Delete All", role: .destructive) {
                viewModel.deleteAllShots()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every shot for this profile.")
        }
        .sheet(item: $editingRow) { row in
            if let club = row.club {
                NavigationStack {
                    ShotRecordEditView(club: club, record: row.record, onSave: viewModel.saveShotRecord)
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
    }
}

private struct ProfileShotRecordRowView: View {
    let row: ProfileShotRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.clubName)
                        .font(.headline)

                    Text(shotTypeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(distanceText)
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Label(dateText, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(row.record.grassType.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                StrikeQualityIcon(quality: row.record.strikeQuality, size: 22)
                    .accessibilityLabel(row.record.strikeQuality.displayName)

                Image(systemName: row.record.direction.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(row.record.direction.tint)
                    .accessibilityLabel(row.record.direction.displayName)
            }
        }
        .padding(.vertical, 6)
    }

    private var shotTypeText: String {
        switch row.record.category {
        case .normal, .flop:
            "\(row.record.power.displayName) \(row.record.category.displayName)"
        case .lowTrajectory:
            row.record.power.displayName
        }
    }

    private var distanceText: String {
        guard let distance = row.record.distance else {
            return "- yds"
        }

        return "\(distance) yds"
    }

    private var dateText: String {
        row.record.createdAt.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct ProfileRoundsListView: View {
    @ObservedObject var viewModel: ProfileDashboardViewModel

    var body: some View {
        List {
            if viewModel.completedRounds.isEmpty {
                ContentUnavailableView(
                    "No Rounds",
                    systemImage: "flag.checkered",
                    description: Text("Completed rounds will appear here.")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.completedRounds) { round in
                    NavigationLink {
                        RoundDetailView(round: round, viewModel: viewModel)
                    } label: {
                        RoundHistoryRow(round: round, shotCount: viewModel.shotCount(for: round))
                    }
                    .accessibilityIdentifier("round-row-\(round.id.uuidString)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteRound(round)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("profile-rounds-list")
        .navigationTitle("Rounds")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
        }
    }
}

private struct RoundHistoryRow: View {
    let round: GolfRound
    let shotCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(round.name)
                .font(.headline)

            HStack {
                Text(dateText)
                Spacer()
                Text(shotText)
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var dateText: String {
        round.startedAt.formatted(date: .abbreviated, time: .omitted)
    }

    private var shotText: String {
        shotCount == 1 ? "1 shot" : "\(shotCount) shots"
    }
}

private struct RoundDetailView: View {
    let round: GolfRound
    @ObservedObject var viewModel: ProfileDashboardViewModel

    var body: some View {
        List {
            Section("Round") {
                detailRow(title: "Name", value: round.name)
                detailRow(title: "Started", value: round.startedAt.formatted(date: .abbreviated, time: .shortened))

                if let endedAt = round.endedAt {
                    detailRow(title: "Ended", value: endedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section {
                NavigationLink {
                    CompletedRoundShotListView(round: round, viewModel: viewModel)
                } label: {
                    ProfileMetricRow(
                        title: "Total Tracked Shots",
                        value: "\(viewModel.shotCount(for: round))",
                        systemImage: "list.bullet.rectangle",
                        valueAccessibilityIdentifier: "round-detail-shot-count"
                    )
                }
                .accessibilityIdentifier("round-detail-total-shots-row")
            }
        }
        .navigationTitle(round.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct CompletedRoundShotListView: View {
    let round: GolfRound
    @ObservedObject var viewModel: ProfileDashboardViewModel

    @State private var editingRow: ProfileShotRow?

    var body: some View {
        List {
            if roundShotRows.isEmpty {
                ContentUnavailableView(
                    "No Round Shots",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Shots tracked during this round will appear here.")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(roundShotRows) { row in
                    Button {
                        if row.club != nil {
                            editingRow = row
                        }
                    } label: {
                        ProfileShotRecordRowView(row: row)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("completed-round-shot-row-\(row.record.id.uuidString)")
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if row.club != nil {
                            Button {
                                editingRow = row
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteShotRecord(row)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("completed-round-shot-list")
        .navigationTitle("Round Shots")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingRow) { row in
            if let club = row.club {
                NavigationStack {
                    ShotRecordEditView(club: club, record: row.record, onSave: viewModel.saveShotRecord)
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
    }

    private var roundShotRows: [ProfileShotRow] {
        viewModel.shotRows(for: round)
    }
}

private struct AnalysisView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    @StateObject private var viewModel: YardageDashboardViewModel
    private let formatter = ClubDisplayNameFormatter()

    init(profile: GolferProfile, repository: GolfBagRepository, switchProfile: @escaping () -> Void) {
        self.profile = profile
        self.switchProfile = switchProfile
        _viewModel = StateObject(wrappedValue: YardageDashboardViewModel(profile: profile, repository: repository))
    }

    var body: some View {
        List {
            if viewModel.activeClubs.isEmpty, viewModel.inactiveClubs.isEmpty {
                ContentUnavailableView(
                    "No Clubs",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Add clubs from the Distance tab.")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                clubSection(title: "Active Clubs", clubs: viewModel.activeClubs, enablesPaging: true)

                if viewModel.inactiveClubs.isEmpty == false {
                    clubSection(title: "Inactive Clubs", clubs: viewModel.inactiveClubs, enablesPaging: false)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityIdentifier("analysis-list")
        .navigationTitle("Analysis")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: switchProfile) {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Switch Profile")
            }
        }
        .task {
            viewModel.loadClubs()
        }
    }

    private func clubSection(title: String, clubs: [Club], enablesPaging: Bool) -> some View {
        Section(title) {
            ForEach(clubs) { club in
                NavigationLink {
                    if enablesPaging {
                        ClubAnalysisPagerView(
                            clubs: clubs,
                            selectedClubID: club.id,
                            shotRecords: viewModel.shotRecords,
                            onSaveClub: viewModel.saveClub,
                            onSaveShotRecord: viewModel.saveShotRecord,
                            onDeleteShotRecord: viewModel.deleteShotRecord
                        )
                    } else {
                        ClubAnalysisDetailView(
                            club: club,
                            shotRecords: viewModel.shotRecords,
                            onSaveClub: viewModel.saveClub,
                            onSaveShotRecord: viewModel.saveShotRecord,
                            onDeleteShotRecord: viewModel.deleteShotRecord
                        )
                    }
                } label: {
                    AnalysisClubRow(club: club, shotRecords: viewModel.shotRecords)
                }
                .accessibilityIdentifier("analysis-club-row-\(formatter.displayName(for: club))")
            }
        }
    }
}

private struct AnalysisClubRow: View {
    let club: Club
    let shotRecords: [ShotRecord]

    private let formatter = ClubDisplayNameFormatter()
    private let statsCalculator = ShotStatsCalculator()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatter.displayName(for: club))
                    .font(.headline)

                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: club.isActive ? "checkmark.circle.fill" : "archivebox")
                .foregroundStyle(club.isActive ? .green : .secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }

    private var summaryText: String {
        guard club.clubType != .putter else {
            return "Putter distances"
        }

        let totalShots = availableCategories.reduce(0) { partialResult, category in
            partialResult + statsCalculator.totalShots(
                for: shotRecords,
                clubID: club.id,
                category: category
            )
        }

        return totalShots == 1 ? "1 recorded shot" : "\(totalShots) recorded shots"
    }

    private var availableCategories: [ShotCategory] {
        club.clubType.isWedge ? [.normal, .lowTrajectory, .flop] : [.normal, .lowTrajectory]
    }
}

private struct ClubAnalysisPagerView: View {
    let clubs: [Club]
    let shotRecords: [ShotRecord]
    let onSaveClub: (Club) throws -> Void
    let onSaveShotRecord: (ShotRecord) throws -> Void
    let onDeleteShotRecord: (ShotRecord) -> Void

    @State private var selectedClubID: UUID

    private let formatter = ClubDisplayNameFormatter()

    init(
        clubs: [Club],
        selectedClubID: UUID,
        shotRecords: [ShotRecord],
        onSaveClub: @escaping (Club) throws -> Void,
        onSaveShotRecord: @escaping (ShotRecord) throws -> Void,
        onDeleteShotRecord: @escaping (ShotRecord) -> Void
    ) {
        self.clubs = clubs
        self.shotRecords = shotRecords
        self.onSaveClub = onSaveClub
        self.onSaveShotRecord = onSaveShotRecord
        self.onDeleteShotRecord = onDeleteShotRecord
        _selectedClubID = State(initialValue: selectedClubID)
    }

    var body: some View {
        TabView(selection: $selectedClubID) {
            ForEach(clubs) { club in
                ClubAnalysisDetailView(
                    club: club,
                    shotRecords: shotRecords,
                    onSaveClub: onSaveClub,
                    onSaveShotRecord: onSaveShotRecord,
                    onDeleteShotRecord: onDeleteShotRecord,
                    showsNavigationTitle: false
                )
                .tag(club.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(currentClubName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("club-analysis-pager")
    }

    private var currentClubName: String {
        guard let currentClub = clubs.first(where: { $0.id == selectedClubID }) ?? clubs.first else {
            return "Analysis"
        }

        return formatter.displayName(for: currentClub)
    }
}

private struct ClubAnalysisDetailView: View {
    @State private var club: Club

    let shotRecords: [ShotRecord]
    let onSaveClub: (Club) throws -> Void
    let onSaveShotRecord: (ShotRecord) throws -> Void
    let onDeleteShotRecord: (ShotRecord) -> Void
    let showsNavigationTitle: Bool

    @State private var selectedCategory: ShotCategory = .normal
    @State private var errorMessage: String?

    private let formatter = ClubDisplayNameFormatter()
    private let statsCalculator = ShotStatsCalculator()

    init(
        club: Club,
        shotRecords: [ShotRecord],
        onSaveClub: @escaping (Club) throws -> Void,
        onSaveShotRecord: @escaping (ShotRecord) throws -> Void,
        onDeleteShotRecord: @escaping (ShotRecord) -> Void,
        showsNavigationTitle: Bool = true
    ) {
        _club = State(initialValue: club)
        self.shotRecords = shotRecords
        self.onSaveClub = onSaveClub
        self.onSaveShotRecord = onSaveShotRecord
        self.onDeleteShotRecord = onDeleteShotRecord
        self.showsNavigationTitle = showsNavigationTitle
    }

    var body: some View {
        List {
            if club.clubType == .putter {
                putterDistancesSection
                Section("Shot Tracking") {
                    Text("Putters are not included in V2 shot recording.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category.displayName)
                                .tag(category)
                                .accessibilityIdentifier("analysis-category-\(category.accessibilityName)")
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("analysis-category-picker")
                }

                distanceComparisonSection
                grassModifierSection
                shotSummarySection
                strikeDistributionSection
                directionDistributionSection
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(showsNavigationTitle ? formatter.displayName(for: club) : "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            normalizeSelectedCategory()
        }
    }

    private var putterDistancesSection: some View {
        Section("Distances") {
            putterDistanceRow(label: "Long", distance: club.putterDistances?.long)
            putterDistanceRow(label: "Medium", distance: club.putterDistances?.medium)
            putterDistanceRow(label: "Short", distance: club.putterDistances?.short)
        }
    }

    private var distanceComparisonSection: some View {
        Section("Distances") {
            ForEach(distanceRows, id: \.power) { row in
                VStack(alignment: .leading, spacing: 8) {
                    DistanceComparisonRowView(row: row)

                    if row.canAdoptAverage {
                        Button {
                            adoptAverage(for: row)
                        } label: {
                            Label("Adopt", systemImage: "arrow.down.doc")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .accessibilityLabel("Adopt \(row.label) pure average")
                        .accessibilityIdentifier("adopt-average-\(row.power.accessibilityName)")
                    }
                }
                .accessibilityIdentifier("analysis-distance-\(row.power.accessibilityName)")
            }
        }
    }

    private var shotSummarySection: some View {
        Section("Summary") {
            NavigationLink {
                ShotRecordListView(
                    club: club,
                    shotRecords: shotRecords,
                    onSave: onSaveShotRecord,
                    onDelete: onDeleteShotRecord
                )
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Total Shots")
                        Text(totalShotsSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    summaryValue
                }
            }
            .accessibilityIdentifier("analysis-total-shots-row")
        }
    }

    @ViewBuilder
    private var grassModifierSection: some View {
        if grassModifierRows.isEmpty == false {
            Section("Grass Modifier") {
                ForEach(grassModifierRows, id: \.id) { row in
                    GrassModifierRowView(row: row)
                        .accessibilityIdentifier("analysis-grass-modifier-\(row.id)")
                }
            }
        }
    }

    private var strikeDistributionSection: some View {
        Section("Strike Quality") {
            StrikeQualityDistributionView(
                rows: StrikeQuality.allCases.map {
                    DistributionRowData(
                        id: $0.displayName,
                        quality: $0,
                        title: $0.displayName,
                        count: strikeCount(for: $0),
                        percentage: strikeDistribution[$0] ?? 0,
                        tint: $0.tint
                    )
                },
                totalCount: categoryShotRecords.count
            )
            .accessibilityIdentifier("analysis-strike-distribution")
        }
    }

    private var directionDistributionSection: some View {
        Section("Direction") {
            DirectionDistributionView(
                rows: ShotDirection.allCases.map { direction in
                    DirectionDistributionRowData(
                        id: direction.displayName,
                        direction: direction,
                        title: direction.displayName,
                        count: directionCount(for: direction),
                        percentage: directionDistribution[direction] ?? 0,
                        tint: direction.tint
                    )
                },
                totalCount: categoryShotRecords.count
            )
            .accessibilityIdentifier("analysis-direction-distribution")
        }
    }

    private func putterDistanceRow(label: String, distance: Int?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(formattedDistance(distance))
                .font(.headline)
        }
    }

    private var availableCategories: [ShotCategory] {
        club.clubType.isWedge ? [.normal, .lowTrajectory, .flop] : [.normal, .lowTrajectory]
    }

    private var distanceRows: [DistanceComparisonRow] {
        powers(for: selectedCategory).map { power in
            DistanceComparisonRow(
                category: selectedCategory,
                power: power,
                label: power.displayName,
                manualDistance: manualDistance(for: selectedCategory, power: power),
                averageDistance: roundedAverage(for: power)
            )
        }
    }

    private var grassModifierRows: [GrassModifierRow] {
        powers(for: selectedCategory).flatMap { power in
            statsCalculator.grassDistanceModifiers(
                for: shotRecords,
                clubID: club.id,
                category: selectedCategory,
                power: power
            )
            .map { modifier in
                GrassModifierRow(
                    grassType: modifier.grassType,
                    power: power,
                    fairwayDistance: Int(modifier.fairwayAverageDistance.rounded()),
                    grassDistance: Int(modifier.grassAverageDistance.rounded()),
                    delta: Int(modifier.deltaYards.rounded())
                )
            }
        }
    }

    private var totalShots: Int {
        shotRecords.filter { $0.clubID == club.id }.count
    }

    private var categoryShotRecords: [ShotRecord] {
        shotRecords.filter { $0.clubID == club.id && $0.category == selectedCategory }
    }

    private func strikeCount(for quality: StrikeQuality) -> Int {
        categoryShotRecords.filter { $0.strikeQuality == quality }.count
    }

    private func directionCount(for direction: ShotDirection) -> Int {
        categoryShotRecords.filter { $0.direction == direction }.count
    }

    private var primaryStrikeQuality: StrikeQuality? {
        StrikeQuality.allCases.max {
            strikeCount(for: $0) < strikeCount(for: $1)
        }.flatMap {
            strikeCount(for: $0) > 0 ? $0 : nil
        }
    }

    private var primaryDirection: ShotDirection? {
        ShotDirection.allCases.max {
            directionCount(for: $0) < directionCount(for: $1)
        }.flatMap {
            directionCount(for: $0) > 0 ? $0 : nil
        }
    }

    private var totalShotsSubtitle: String {
        guard let primaryStrikeQuality, let primaryDirection else {
            return categoryShotRecords.isEmpty ? "No \(selectedCategory.displayName.lowercased()) shots yet" : selectedCategory.displayName
        }

        return "\(primaryStrikeQuality.displayName) / \(primaryDirection.displayName)"
    }

    private var totalShotsValueText: String {
        totalShots == 1 ? "1 shot" : "\(totalShots) shots"
    }

    private var categoryShotCaption: String {
        if categoryShotRecords.count == totalShots {
            return "All recorded shots"
        }

        return "\(categoryShotRecords.count) of \(totalShotsValueText)"
    }

    private var summaryValue: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(totalShotsValueText)
                .font(.headline)
                .accessibilityIdentifier("analysis-total-shots")

            if totalShots > 0 {
                Text(categoryShotCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var strikeDistribution: [StrikeQuality: Double] {
        statsCalculator.strikeDistributionPercentages(
            for: shotRecords,
            clubID: club.id,
            category: selectedCategory
        )
    }

    private var directionDistribution: [ShotDirection: Double] {
        statsCalculator.directionDistributionPercentages(
            for: shotRecords,
            clubID: club.id,
            category: selectedCategory
        )
    }

    private func normalizeSelectedCategory() {
        if availableCategories.contains(selectedCategory) == false {
            selectedCategory = availableCategories.first ?? .normal
        }
    }

    private func powers(for category: ShotCategory) -> [ShotPower] {
        switch category {
        case .normal, .flop:
            [.full, .threeQuarter, .half, .quarter]
        case .lowTrajectory:
            [.stinger, .punch, .softPunch, .chip]
        }
    }

    private func manualDistance(for category: ShotCategory, power: ShotPower) -> Int? {
        switch category {
        case .normal:
            swingDistance(from: club.normalDistances, power: power)
        case .flop:
            swingDistance(from: club.flopDistances, power: power)
        case .lowTrajectory:
            lowTrajectoryDistance(from: club.lowTrajectoryDistances, power: power)
        }
    }

    private func swingDistance(from distances: SwingDistanceSet?, power: ShotPower) -> Int? {
        switch power {
        case .full:
            distances?.full
        case .threeQuarter:
            distances?.threeQuarter
        case .half:
            distances?.half
        case .quarter:
            distances?.quarter
        case .stinger, .punch, .softPunch, .chip:
            nil
        }
    }

    private func lowTrajectoryDistance(from distances: LowTrajectoryDistanceSet?, power: ShotPower) -> Int? {
        switch power {
        case .stinger:
            distances?.stinger
        case .punch:
            distances?.punch
        case .softPunch:
            distances?.softPunch
        case .chip:
            distances?.chip
        case .full, .threeQuarter, .half, .quarter:
            nil
        }
    }

    private func formattedDistance(_ distance: Int?) -> String {
        guard let distance, distance > 0 else {
            return "-"
        }

        return "\(distance) yds"
    }

    private func roundedAverage(for power: ShotPower) -> Int? {
        guard let average = statsCalculator.averageDistance(
            for: shotRecords,
            clubID: club.id,
            category: selectedCategory,
            power: power
        ) else {
            return nil
        }

        return Int(average.rounded())
    }

    private func adoptAverage(for row: DistanceComparisonRow) {
        guard let averageDistance = row.averageDistance else {
            return
        }

        var updatedClub = club
        switch row.category {
        case .normal:
            setSwingDistance(averageDistance, for: row.power, distances: &updatedClub.normalDistances)
        case .flop:
            setSwingDistance(averageDistance, for: row.power, distances: &updatedClub.flopDistances)
        case .lowTrajectory:
            setLowTrajectoryDistance(averageDistance, for: row.power, distances: &updatedClub.lowTrajectoryDistances)
        }

        updatedClub.updatedAt = Date()
        updatedClub.refreshCompatibilityFields(preferredShotType: updatedClub.shotType)

        do {
            try onSaveClub(updatedClub)
            club = updatedClub
            errorMessage = nil
        } catch {
            errorMessage = "Unable to adopt distance."
        }
    }

    private func setSwingDistance(_ distance: Int, for power: ShotPower, distances: inout SwingDistanceSet?) {
        var updatedDistances = distances ?? SwingDistanceSet()

        switch power {
        case .full:
            updatedDistances.full = distance
        case .threeQuarter:
            updatedDistances.threeQuarter = distance
        case .half:
            updatedDistances.half = distance
        case .quarter:
            updatedDistances.quarter = distance
        case .stinger, .punch, .softPunch, .chip:
            return
        }

        distances = updatedDistances
    }

    private func setLowTrajectoryDistance(_ distance: Int, for power: ShotPower, distances: inout LowTrajectoryDistanceSet?) {
        var updatedDistances = distances ?? LowTrajectoryDistanceSet()

        switch power {
        case .stinger:
            updatedDistances.stinger = distance
        case .punch:
            updatedDistances.punch = distance
        case .softPunch:
            updatedDistances.softPunch = distance
        case .chip:
            updatedDistances.chip = distance
        case .full, .threeQuarter, .half, .quarter:
            return
        }

        distances = updatedDistances
    }

}

private struct ShotRecordListView: View {
    let club: Club
    let shotRecords: [ShotRecord]
    let onSave: (ShotRecord) throws -> Void
    let onDelete: (ShotRecord) -> Void

    @State private var editingRecord: ShotRecord?

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(
                    "No Recorded Shots",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Shots recorded for this club will appear here.")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(records) { record in
                    Button {
                        editingRecord = record
                    } label: {
                        ShotRecordRowView(record: record)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("shot-record-row-\(record.power.accessibilityName)")
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            editingRecord = record
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(record)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("shot-record-list")
        .navigationTitle("Recorded Shots")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingRecord) { record in
            NavigationStack {
                ShotRecordEditView(club: club, record: record, onSave: onSave)
            }
        }
    }

    private var records: [ShotRecord] {
        shotRecords
            .filter { $0.clubID == club.id }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
    }
}

private struct ShotRecordRowView: View {
    let record: ShotRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(shotTypeText)
                    .font(.headline)

                Spacer()

                Text(distanceText)
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .accessibilityIdentifier("shot-record-distance-\(record.power.accessibilityName)")
            }

            HStack(spacing: 12) {
                Label(dateText, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                StrikeQualityIcon(quality: record.strikeQuality, size: 22)
                    .accessibilityLabel(record.strikeQuality.displayName)

                Image(systemName: record.direction.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(record.direction.tint)
                    .accessibilityLabel(record.direction.displayName)
            }
        }
        .padding(.vertical, 6)
    }

    private var shotTypeText: String {
        switch record.category {
        case .normal, .flop:
            return "\(record.power.displayName) \(record.category.displayName)"
        case .lowTrajectory:
            return record.power.displayName
        }
    }

    private var distanceText: String {
        guard let distance = record.distance else {
            return "- yds"
        }

        return "\(distance) yds"
    }

    private var dateText: String {
        record.createdAt.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct ShotRecordEditView: View {
    let club: Club
    let record: ShotRecord
    let onSave: (ShotRecord) throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: ShotCategory
    @State private var selectedPower: ShotPower
    @State private var distanceText: String
    @State private var strikeQuality: StrikeQuality
    @State private var direction: ShotDirection
    @State private var grassType: GrassType
    @State private var createdAt: Date
    @State private var errorMessage: String?

    init(club: Club, record: ShotRecord, onSave: @escaping (ShotRecord) throws -> Void) {
        self.club = club
        self.record = record
        self.onSave = onSave
        _selectedCategory = State(initialValue: record.category)
        _selectedPower = State(initialValue: record.power)
        _distanceText = State(initialValue: record.distance.map(String.init) ?? "")
        _strikeQuality = State(initialValue: record.strikeQuality)
        _direction = State(initialValue: record.direction)
        _grassType = State(initialValue: record.grassType)
        _createdAt = State(initialValue: record.createdAt)
    }

    var body: some View {
        Form {
            Section("Shot") {
                ForEach(availableCategories, id: \.self) { category in
                    powerRow(for: category)
                }
            }

            Section("Date") {
                DatePicker("Date", selection: $createdAt, displayedComponents: [.date, .hourAndMinute])
                    .accessibilityIdentifier("edit-shot-date-picker")
            }

            Section("Grass") {
                Picker("Grass", selection: $grassType) {
                    ForEach(GrassType.allCases, id: \.self) { grassType in
                        Text(grassType.displayName).tag(grassType)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("edit-grass-type-picker")
            }

            Section("Distance") {
                HStack {
                    Text("Distance (Yards)")
                    Spacer()
                    if distanceText.isEmpty == false {
                        Button {
                            distanceText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear Distance")
                        .accessibilityIdentifier("clear-edit-shot-distance-button")
                    }
                    NumericTextField(
                        title: "Optional",
                        text: $distanceText,
                        maxDigits: 3,
                        dismissesKeyboardAtMaxDigits: true
                    )
                        .accessibilityIdentifier("edit-shot-distance-field")
                        .frame(maxWidth: 112)
                }
            }

            Section("Strike") {
                Picker("Strike", selection: $strikeQuality) {
                    ForEach(StrikeQuality.allCases, id: \.self) { strikeQuality in
                        Text(strikeQuality.displayName).tag(strikeQuality)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("edit-strike-quality-picker")
            }

            Section("Direction") {
                Picker("Direction", selection: $direction) {
                    ForEach(ShotDirection.allCases, id: \.self) { direction in
                        Label(direction.displayName, systemImage: direction.systemImage)
                            .tag(direction)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("edit-shot-direction-picker")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Edit Shot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .accessibilityIdentifier("save-shot-edit-button")
            }
        }
        .onAppear {
            normalizeSelectedShot()
        }
    }

    private var availableCategories: [ShotCategory] {
        club.clubType.isWedge ? [.normal, .lowTrajectory, .flop] : [.normal, .lowTrajectory]
    }

    private func powerRow(for category: ShotCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(powers(for: category), id: \.self) { power in
                    powerButton(category: category, power: power)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func powerButton(category: ShotCategory, power: ShotPower) -> some View {
        let isSelected = selectedCategory == category && selectedPower == power

        return Button {
            if selectedCategory != category {
                selectedPower = powers(for: category).first ?? power
            }

            selectedCategory = category
            selectedPower = power
            normalizeSelectedShot()
        } label: {
            Text(power.displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .green)
        .background(isSelected ? Color.green : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.green : Color.green.opacity(0.45), lineWidth: 1)
        }
        .accessibilityIdentifier("edit-shot-power-\(category.accessibilityName)-\(power.accessibilityName)")
    }

    private func powers(for category: ShotCategory) -> [ShotPower] {
        switch category {
        case .normal, .flop:
            [.full, .threeQuarter, .half, .quarter]
        case .lowTrajectory:
            [.stinger, .punch, .softPunch, .chip]
        }
    }

    private func normalizeSelectedShot() {
        if availableCategories.contains(selectedCategory) == false {
            selectedCategory = availableCategories.first ?? .normal
        }

        if powers(for: selectedCategory).contains(selectedPower) == false {
            selectedPower = powers(for: selectedCategory).first ?? .full
        }
    }

    private func save() {
        let editedRecord = ShotRecord(
            id: record.id,
            profileID: record.profileID,
            clubID: record.clubID,
            roundID: record.roundID,
            category: selectedCategory,
            power: selectedPower,
            distance: distance(from: distanceText),
            distanceSource: record.distanceSource,
            gpsMeasurement: record.gpsMeasurement,
            altitudeFeet: record.altitudeFeet,
            strikeQuality: strikeQuality,
            direction: direction,
            grassType: grassType,
            createdAt: createdAt
        )

        do {
            try onSave(editedRecord)
            dismiss()
        } catch GolfBagRepositoryError.invalidShotRecord(let validationErrors) {
            errorMessage = validationMessage(for: validationErrors)
        } catch {
            errorMessage = "Unable to save shot."
        }
    }

    private func distance(from text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func validationMessage(for errors: [ShotRecordValidationError]) -> String {
        if errors.contains(.nonPositiveDistance) {
            return "Distance must be greater than 0."
        }

        if errors.contains(.unsupportedCategoryForClubType) || errors.contains(.unsupportedPowerForCategory) {
            return "Choose a valid shot type."
        }

        return "Check the shot details and try again."
    }
}

private struct DistanceComparisonRow {
    let category: ShotCategory
    let power: ShotPower
    let label: String
    let manualDistance: Int?
    let averageDistance: Int?

    var delta: Int? {
        guard let manualDistance, let averageDistance else {
            return nil
        }

        return averageDistance - manualDistance
    }

    var canAdoptAverage: Bool {
        guard let averageDistance, averageDistance > 0 else {
            return false
        }

        return manualDistance != averageDistance
    }
}

private struct GrassModifierRow: Identifiable {
    let grassType: GrassType
    let power: ShotPower
    let fairwayDistance: Int
    let grassDistance: Int
    let delta: Int

    var id: String {
        "\(grassType.rawValue)-\(power.rawValue)"
    }
}

private struct GrassModifierRowView: View {
    let row: GrassModifierRow

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(row.grassType.displayName) \(row.power.displayName)")
                    .font(.headline)

                Text("Fairway \(row.fairwayDistance) yds | \(row.grassType.displayName) \(row.grassDistance) yds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(deltaText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(deltaTint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(deltaTint.opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 4)
    }

    private var deltaText: String {
        if row.delta == 0 {
            return "Even"
        }

        return row.delta > 0 ? "+\(row.delta) yds" : "\(row.delta) yds"
    }

    private var deltaTint: Color {
        if row.delta == 0 {
            return .secondary
        }

        return row.delta < 0 ? .orange : .green
    }
}

private struct DistanceComparisonRowView: View {
    let row: DistanceComparisonRow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.label)
                    .font(.headline)

                Spacer()

                if let deltaText {
                    Text(deltaText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(deltaTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(deltaTint.opacity(0.12), in: Capsule())
                        .accessibilityIdentifier("analysis-distance-delta-\(row.power.accessibilityName)")
                }
            }

            HStack(spacing: 0) {
                ComparisonValue(title: "Manual", distance: row.manualDistance)

                Divider()
                    .padding(.vertical, 3)

                ComparisonValue(title: "Pure Avg", distance: row.averageDistance)
            }
        }
        .padding(.vertical, 4)
    }

    private var deltaText: String? {
        guard let delta = row.delta else {
            return nil
        }

        if delta == 0 {
            return "Even"
        }

        return delta > 0 ? "+\(delta) yds" : "\(delta) yds"
    }

    private var deltaTint: Color {
        guard let delta = row.delta else {
            return .secondary
        }

        if delta == 0 {
            return .secondary
        }

        return delta > 0 ? .blue : .orange
    }
}

private struct ComparisonValue: View {
    let title: String
    let distance: Int?

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(formattedDistance)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()

                if distance != nil {
                    Text("yds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedDistance: String {
        guard let distance, distance > 0 else {
            return "-"
        }

        return "\(distance)"
    }
}

private struct DistributionRowData: Identifiable {
    let id: String
    let quality: StrikeQuality
    let title: String
    let count: Int
    let percentage: Double
    let tint: Color
}

private struct DirectionDistributionRowData: Identifiable {
    let id: String
    let direction: ShotDirection
    let title: String
    let count: Int
    let percentage: Double
    let tint: Color
}

private struct StrikeQualityDistributionView: View {
    let rows: [DistributionRowData]
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DistributionStackedBar(
                rows: rows.map {
                    DistributionSegmentData(
                        id: $0.id,
                        percentage: $0.percentage,
                        tint: $0.tint
                    )
                },
                totalCount: totalCount
            )

            HStack(alignment: .top, spacing: 0) {
                ForEach(rows) { row in
                    StrikeQualityBucket(row: row)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DirectionDistributionView: View {
    let rows: [DirectionDistributionRowData]
    let totalCount: Int

    var body: some View {
        VStack(spacing: 12) {
            DirectionFanChart(rows: rows, totalCount: totalCount)
                .frame(height: 190)

            HStack(alignment: .top, spacing: 0) {
                ForEach(rows) { row in
                    VStack(spacing: 4) {
                        Text(row.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text(row.count == 1 ? "1" : "\(row.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(row.count > 0 ? row.tint : .secondary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DistributionSegmentData: Identifiable {
    let id: String
    let percentage: Double
    let tint: Color
}

private struct DistributionStackedBar: View {
    let rows: [DistributionSegmentData]
    let totalCount: Int

    var body: some View {
        Canvas { context, size in
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
                return
            }

            let rect = CGRect(origin: .zero, size: size)
            let cornerRadius = size.height / 2

            if totalCount == 0 {
                context.fill(
                    Path(roundedRect: rect, cornerRadius: cornerRadius),
                    with: .color(Color.secondary.opacity(0.16))
                )
                return
            }

            let activeRows = rows.filter { $0.percentage > 0 }
            let totalGap = CGFloat(max(0, activeRows.count - 1)) * 3
            let availableWidth = max(0, size.width - totalGap)
            var x: CGFloat = 0

            for row in activeRows {
                let segmentWidth = max(0, availableWidth * row.percentage / 100)
                guard segmentWidth > 0 else {
                    continue
                }

                let segmentRect = CGRect(x: x, y: 0, width: segmentWidth, height: size.height)

                context.fill(
                    Path(roundedRect: segmentRect, cornerRadius: cornerRadius),
                    with: .color(row.tint)
                )

                x += segmentWidth + 3
            }
        }
        .frame(height: 10)
    }
}

private struct StrikeQualityBucket: View {
    let row: DistributionRowData

    var body: some View {
        VStack(spacing: 7) {
            StrikeQualityIcon(quality: row.quality, size: 30)

            Text(row.title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formattedPercentage(row.percentage))
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier("analysis-percentage-\(row.title)")

            Text(row.count == 1 ? "1 shot" : "\(row.count) shots")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DirectionFanChart: View {
    let rows: [DirectionDistributionRowData]
    let totalCount: Int

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let center = CGPoint(x: size.width / 2, y: size.height - 16)
            let maxRadius = min(size.width * 0.37, size.height * 0.72)
            let labels = labelPositions(in: size, center: center, radius: maxRadius)

            ZStack {
                Canvas { context, canvasSize in
                    guard canvasSize.width.isFinite,
                          canvasSize.height.isFinite,
                          canvasSize.width > 0,
                          canvasSize.height > 0 else {
                        return
                    }

                    for guideAngle in [-121.0, -59.0] {
                        var guidePath = Path()
                        guidePath.move(to: center)
                        guidePath.addLine(to: point(from: center, radius: maxRadius + 34, degrees: guideAngle))
                        context.stroke(
                            guidePath,
                            with: .color(Color.secondary.opacity(0.18)),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                        )
                    }

                    for (index, row) in rows.enumerated() {
                        let geometry = sliceGeometry(for: index)
                        let share = totalCount > 0 ? max(0, min(1, row.percentage / 100)) : 0
                        let radius = maxRadius * (0.36 + share * 0.64)
                        let opacity = 0.16 + share * 0.78
                        let path = fanSlicePath(
                            center: center,
                            radius: radius,
                            startDegrees: geometry.startDegrees,
                            endDegrees: geometry.endDegrees
                        )

                        context.fill(path, with: .color(row.tint.opacity(opacity)))
                    }
                }

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    DirectionFanLabel(row: row)
                        .position(labels[index])
                }
            }
        }
    }

    private func sliceGeometry(for index: Int) -> (startDegrees: Double, endDegrees: Double) {
        let sliceWidth = 24.0
        let sliceSpacing = 27.0
        let straightIndex = 2.0
        let midpoint = -90.0 + (Double(index) - straightIndex) * sliceSpacing

        return (midpoint - sliceWidth / 2, midpoint + sliceWidth / 2)
    }

    private func labelPositions(in size: CGSize, center: CGPoint, radius: CGFloat) -> [CGPoint] {
        let labelRadius = radius + 22

        return rows.indices.map { index in
            let geometry = sliceGeometry(for: index)
            let midpoint = (geometry.startDegrees + geometry.endDegrees) / 2
            let radians = midpoint * .pi / 180
            let x = center.x + cos(radians) * labelRadius
            let y = center.y + sin(radians) * labelRadius

            return CGPoint(
                x: min(max(x, 34), size.width - 34),
                y: min(max(y, 14), size.height - 20)
            )
        }
    }

    private func fanSlicePath(center: CGPoint, radius: CGFloat, startDegrees: Double, endDegrees: Double) -> Path {
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }

    private func point(from center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        CGPoint(
            x: center.x + cos(degrees * .pi / 180) * radius,
            y: center.y + sin(degrees * .pi / 180) * radius
        )
    }
}

private struct DirectionFanLabel: View {
    let row: DirectionDistributionRowData

    var body: some View {
        VStack(spacing: 2) {
            Text(formattedPercentage(row.percentage))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier("analysis-percentage-\(row.title)")

            Text(row.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }
}

private func formattedPercentage(_ percentage: Double) -> String {
    "\(Int(percentage.rounded()))%"
}

private struct StrikeQualityIcon: View {
    let quality: StrikeQuality
    var size: CGFloat

    var body: some View {
        ZStack {
            GroundStrikeShape(quality: quality)
                .stroke(
                    groundTint,
                    style: StrokeStyle(
                        lineWidth: max(1, size * 0.045),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size, height: size)

            ClubShaftShape()
                .stroke(
                    quality.tint.opacity(0.62),
                    style: StrokeStyle(
                        lineWidth: max(0.8, size * 0.035),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size, height: size)
                .offset(shaftOffset)

            ironFace
                .rotationEffect(.degrees(ironRotation))
                .offset(ironOffset)

            Circle()
                .fill(.background)
                .overlay {
                    Circle()
                        .stroke(quality.tint.opacity(0.95), lineWidth: max(1.25, size * 0.07))
                }
                .frame(width: size * 0.31, height: size * 0.31)
                .offset(x: size * 0.24, y: size * 0.12)

            impactMark
        }
        .frame(width: size, height: size)
        .accessibilityLabel(quality.displayName)
    }

    private var groundTint: Color {
        quality == .chunk ? quality.tint.opacity(0.72) : Color.secondary.opacity(0.22)
    }

    private var ironFace: some View {
        IronFaceSilhouetteShape()
            .fill(quality.tint.opacity(0.88))
            .overlay {
                IronFaceSilhouetteShape()
                    .stroke(quality.tint, lineWidth: max(0.9, size * 0.045))
            }
            .frame(width: size * 0.42, height: size * 0.6)
    }

    @ViewBuilder
    private var impactMark: some View {
        switch quality {
        case .thin:
            Capsule()
                .fill(quality.tint)
                .frame(width: size * 0.16, height: max(1, size * 0.045))
                .rotationEffect(.degrees(-4))
                .offset(x: size * 0.11, y: size * 0.1)
        case .pure:
            Capsule()
                .fill(quality.tint)
                .frame(width: max(1, size * 0.05), height: size * 0.17)
                .rotationEffect(.degrees(-12))
                .offset(x: size * 0.1, y: size * 0.08)
        case .chunk:
            EmptyView()
        }
    }

    private var shaftOffset: CGSize {
        switch quality {
        case .thin:
            CGSize(width: -size * 0.07, height: -size * 0.08)
        case .pure:
            CGSize(width: -size * 0.08, height: -size * 0.01)
        case .chunk:
            CGSize(width: -size * 0.18, height: size * 0.12)
        }
    }

    private var ironOffset: CGSize {
        switch quality {
        case .thin:
            CGSize(width: -size * 0.22, height: -size * 0.08)
        case .pure:
            CGSize(width: -size * 0.21, height: size * 0.03)
        case .chunk:
            CGSize(width: -size * 0.31, height: size * 0.19)
        }
    }

    private var ironRotation: Double {
        switch quality {
        case .thin:
            -6
        case .pure:
            -6
        case .chunk:
            15
        }
    }
}

private struct IronFaceSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.05))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.04),
            control: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY - rect.height * 0.02)
        )
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.maxY - rect.height * 0.13))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.maxY - rect.height * 0.02),
            control: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY + rect.height * 0.07)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.minY + rect.height * 0.28))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.05),
            control: CGPoint(x: rect.minX + rect.width * 0.03, y: rect.minY + rect.height * 0.11)
        )
        path.closeSubpath()

        return path
    }
}

private struct ClubShaftShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.41, y: rect.minY + rect.height * 0.58))

        return path
    }
}

private struct GroundStrikeShape: Shape {
    let quality: StrikeQuality

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let groundY = rect.minY + rect.height * 0.78

        switch quality {
        case .chunk:
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.06, y: groundY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.26, y: groundY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.34, y: groundY + rect.height * 0.11))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.47, y: groundY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: groundY))
        case .thin, .pure:
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: groundY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: groundY))
        }


        return path
    }
}

private extension StrikeQuality {
    var tint: Color {
        switch self {
        case .thin:
            .orange
        case .pure:
            .green
        case .chunk:
            .red
        }
    }
}

private extension ShotDirection {
    var systemImage: String {
        switch self {
        case .hook:
            "arrowshape.turn.up.left.fill"
        case .draw:
            "arrow.up.left"
        case .straight:
            "arrow.up"
        case .fade:
            "arrow.up.right"
        case .slice:
            "arrowshape.turn.up.right.fill"
        }
    }

    var tint: Color {
        switch self {
        case .hook, .slice:
            .red
        case .draw, .fade:
            .blue
        case .straight:
            .green
        }
    }
}

private extension ShotCategory {
    var accessibilityName: String {
        switch self {
        case .normal:
            "normal"
        case .lowTrajectory:
            "low-trajectory"
        case .flop:
            "flop"
        }
    }
}

private extension ShotPower {
    var accessibilityName: String {
        switch self {
        case .full:
            "full"
        case .threeQuarter:
            "three-quarter"
        case .half:
            "half"
        case .quarter:
            "quarter"
        case .stinger:
            "stinger"
        case .punch:
            "punch"
        case .softPunch:
            "soft-punch"
        case .chip:
            "chip"
        }
    }
}
