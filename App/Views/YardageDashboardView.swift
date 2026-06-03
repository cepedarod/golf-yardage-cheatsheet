import CoreLocation
import MapKit
import CaddieCatLiveActivityShared
import SwiftUI

struct YardageDashboardView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    @StateObject private var viewModel: YardageDashboardViewModel
    @StateObject private var shotTracker: ShotTrackingFlowViewModel
    @State private var clubForm: ClubForm?
    @State private var didOfferInitialBagSetup = false
    @State private var recordShotContext: RecordShotContext?
    @State private var shotDraftContext: ShotDraftFormContext?
    @State private var inAppShotDraft: LiveActivityShotDraft?
    @State private var isConfirmingStartRoundForGPS = false
    @State private var gpsFallbackAlert: GPSFallbackAlert?
    @State private var targetYardageText = ""
    @State private var shotTrackingProgress = 0.0
    @FocusState private var isTargetYardageFocused: Bool

    private let formatter = ClubDisplayNameFormatter()
    private let courseNameProvider: any GolfCourseNameProviding

    init(profile: GolferProfile, repository: GolfBagRepository, switchProfile: @escaping () -> Void) {
        self.profile = profile
        self.switchProfile = switchProfile
        courseNameProvider = Self.courseNameProvider()
        _viewModel = StateObject(wrappedValue: YardageDashboardViewModel(
            profile: profile,
            repository: repository,
            targetClearDelayNanoseconds: Self.targetClearDelayNanoseconds
        ))
        _shotTracker = StateObject(wrappedValue: ShotTrackingFlowViewModel(
            locationProvider: Self.locationProvider(),
            captureDurationNanoseconds: Self.gpsCaptureDurationNanoseconds
        ))
    }

    private static var targetClearDelayNanoseconds: UInt64 {
        ProcessInfo.processInfo.environment["TARGET_YARDAGE_CLEAR_DELAY_NANOSECONDS"]
            .flatMap(UInt64.init) ?? 120_000_000_000
    }

    private static var gpsCaptureDurationNanoseconds: UInt64 {
        ProcessInfo.processInfo.environment["GPS_CAPTURE_DURATION_NANOSECONDS"]
            .flatMap(UInt64.init) ?? 2_000_000_000
    }

    private static var gpsCaptureDurationSeconds: TimeInterval {
        TimeInterval(gpsCaptureDurationNanoseconds) / 1_000_000_000
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
            Section {
                HStack {
                    Text("Target")
                    Spacer()
                    targetYardageField
                }

                Picker("Shot Filter", selection: $viewModel.shotFilter) {
                    Text("Normal")
                        .tag(ShotFilter.normal)
                        .accessibilityIdentifier("shot-filter-normal")
                    Text("Low Trajectory")
                        .tag(ShotFilter.lowTrajectory)
                        .accessibilityIdentifier("shot-filter-low-trajectory")
                }
                .pickerStyle(.segmented)

                Picker("Value Mode", selection: $viewModel.valueMode) {
                    Text("Manual")
                        .tag(DistanceValueMode.manual)
                        .accessibilityIdentifier("value-mode-manual")
                    Text("Real")
                        .tag(DistanceValueMode.real)
                        .accessibilityIdentifier("value-mode-real")
                }
                .pickerStyle(.segmented)

                if viewModel.hasTargetYardage {
                    Button("Clear", action: clearTargetYardage)
                }
            }

            if viewModel.hasTargetYardage {
                Section("Closest") {
                    if viewModel.matches.isEmpty {
                        ContentUnavailableView("No Matches", systemImage: "scope", description: Text("Add active clubs or change the filter."))
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.matches) { match in
                            closestMatchRow(for: match)
                        }
                    }
                }
            }

            if viewModel.hasTargetYardage == false {
                Section {
                    if viewModel.visibleActiveClubs.isEmpty {
                        VStack(spacing: 14) {
                            ContentUnavailableView(
                                emptyClubsTitle,
                                systemImage: "figure.golf",
                                description: Text(emptyClubsDescription)
                            )

                            Button {
                                clubForm = .add
                            } label: {
                                Label(emptyClubsActionTitle, systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.visibleActiveClubs) { club in
                            ClubSummaryRow(
                                club: club,
                                shotFilter: viewModel.shotFilter,
                                valueMode: viewModel.valueMode,
                                shotRecords: viewModel.shotRecords,
                                adjustmentContext: viewModel.distanceAdjustmentContext
                            )
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        clubForm = .edit(club)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        viewModel.deactivateClub(club)
                                    } label: {
                                        Label("Deactivate", systemImage: "archivebox")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                } header: {
                    Text(activeClubSectionTitle)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Distance")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: switchProfile) {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Switch Profile")
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    NavigationLink {
                        InactiveClubsView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    .accessibilityLabel("Inactive Clubs")

                    Button {
                        clubForm = .add
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Club")
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                if isTargetYardageFocused {
                    Spacer()
                    Button("Done") {
                        isTargetYardageFocused = false
                    }
                    .accessibilityIdentifier("dismiss-target-keyboard-button")
                }
            }
        }
        .sheet(item: $clubForm) { form in
            NavigationStack {
                switch form {
                case .add:
                    AddClubView(profile: profile, onSave: viewModel.saveClub)
                case .edit(let club):
                    AddClubView(profile: profile, club: club, onSave: viewModel.saveClub)
                }
            }
        }
        .sheet(item: $recordShotContext) { context in
            NavigationStack {
                RecordShotView(
                    profile: profile,
                    clubs: viewModel.recordableActiveClubs,
                    roundID: context.roundID,
                    gpsCapture: context.gpsCapture,
                    liveActivityDraft: context.liveActivityDraft,
                    onSave: viewModel.saveShotRecord
                )
            }
        }
        .sheet(item: $shotDraftContext) { context in
            NavigationStack {
                ShotDetailsDraftView(
                    clubs: viewModel.recordableActiveClubs,
                    initialDraft: context.draft,
                    onSave: savePendingShotDraft
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isTargetYardageFocused == false {
                recordShotBar
            }
        }
        .task {
            viewModel.loadClubs()
            offerInitialBagSetupIfNeeded()
        }
        .onAppear {
            viewModel.loadClubs()
            syncLocationWarmup()
        }
        .onDisappear {
            shotTracker.stopLocationWarmup()
        }
        .onChange(of: viewModel.activeRoundID) { _, _ in
            syncLocationWarmup()
        }
        .onChange(of: viewModel.shotTrackingMode) { _, _ in
            syncLocationWarmup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .roundDataDidChange)) { _ in
            viewModel.loadClubs()
            syncLocationWarmup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .liveActivityRequestedStartShot)) { _ in
            handleLiveActivityStartShotRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .liveActivityRequestedFinishShot)) { _ in
            handleLiveActivityFinishShotRequest()
        }
        .onChange(of: shotTracker.isCapturing) { _, isCapturing in
            animateShotTrackingProgress(isCapturing: isCapturing)
        }
        .onChange(of: targetYardageText) { _, newValue in
            let digitsOnly = String(newValue.filter(\.isNumber).prefix(3))

            guard digitsOnly == newValue else {
                targetYardageText = digitsOnly
                return
            }

            viewModel.setTargetYardageText(digitsOnly)

            if digitsOnly.count == 3 {
                isTargetYardageFocused = false
            }
        }
        .onChange(of: viewModel.targetYardageText) { _, newValue in
            if targetYardageText != newValue {
                targetYardageText = newValue
            }
        }
        .alert("Start a Round?", isPresented: $isConfirmingStartRoundForGPS) {
            Button("Start Round") {
                startRoundAndBeginGPSShot()
            }

            Button("Manual Entry") {
                recordShotContext = RecordShotContext(roundID: nil, gpsCapture: nil)
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("GPS shot tracking works best inside an active round.")
        }
        .alert(item: $gpsFallbackAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: .default(Text("Manual Entry")) {
                    shotTracker.abort()
                    updateLiveActivityPhase(.idle)
                    recordShotContext = RecordShotContext(roundID: viewModel.activeRoundID, gpsCapture: nil)
                },
                secondaryButton: .default(Text("Retry Location")) {
                    retryGPSCapture()
                }
            )
        }
    }

    private func animateShotTrackingProgress(isCapturing: Bool) {
        guard isCapturing else {
            shotTrackingProgress = 0
            return
        }

        shotTrackingProgress = 0
        withAnimation(.linear(duration: max(Self.gpsCaptureDurationSeconds, 0.2))) {
            shotTrackingProgress = 1
        }
    }

    private func differenceSummary(for match: YardageMatch) -> String {
        if match.differenceFromTarget == 0 {
            return "Exact"
        }

        let targetYardage = Int(targetYardageText) ?? match.distance

        if match.distance < targetYardage {
            return "\(match.differenceFromTarget) short"
        }

        return "\(match.differenceFromTarget) long"
    }

    private func clearTargetYardage() {
        targetYardageText = ""
        viewModel.clearTargetYardage()
    }

    private var targetYardageField: some View {
        TextField("Yards", text: $targetYardageText)
            .focused($isTargetYardageFocused)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .font(.title2.weight(.semibold))
            .accessibilityIdentifier("target-yardage-field")
            .frame(maxWidth: 120)
    }

    private func closestMatchRow(for match: YardageMatch) -> some View {
        let displayName = formatter.displayName(for: match.club)
        let distanceAccessibility = "\(match.displayLabel) \(match.formattedDistance)"

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(displayName)
                    .font(.headline)
                    .accessibilityIdentifier("closest-match-name-\(displayName)")

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(match.displayLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(match.formattedDistance)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()

                    Text("yds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(distanceAccessibility)
                .accessibilityIdentifier("closest-match-distance-\(displayName)")
            }

            Spacer()

            Text(differenceSummary(for: match))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("closest-match-\(displayName)")
    }

    private var recordShotBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                if canPrefillShotDetails {
                    Button {
                        openShotDetailsDraftForm()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .accessibilityLabel("Prefill Shot Details")
                    .accessibilityIdentifier("prefill-shot-details-button")
                }

                Button {
                    handleShotTrackingTap()
                } label: {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(shotTracker.isCapturing ? Color.green.opacity(0.24) : Color.green)

                        if shotTracker.isCapturing {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Color.green)
                                    .frame(width: proxy.size.width * shotTrackingProgress)
                            }
                            .clipShape(Capsule())
                        }

                        HStack(spacing: 8) {
                            Image(systemName: recordShotSystemImage)
                            Text(recordShotTitle)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .opacity(viewModel.recordableActiveClubs.isEmpty ? 0.45 : 1)
                .disabled(viewModel.recordableActiveClubs.isEmpty || shotTracker.isCapturing)
                .accessibilityIdentifier("record-shot-button")

                if shotTracker.canAbort {
                    Button {
                        abortGPSShot()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .accessibilityLabel("Abort Shot")
                    .accessibilityIdentifier("abort-shot-button")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var canPrefillShotDetails: Bool {
        guard effectiveShotTrackingMode == .gps,
              viewModel.activeRoundID != nil,
              viewModel.recordableActiveClubs.isEmpty == false else {
            return false
        }

        return shotTracker.canPrefillDetails
    }

    private var recordShotTitle: String {
        switch effectiveShotTrackingMode {
        case .manual:
            return "Record Shot"
        case .gps:
            return shotTracker.primaryButtonTitle
        }
    }

    private var recordShotSystemImage: String {
        switch effectiveShotTrackingMode {
        case .manual:
            return "plus.circle.fill"
        case .gps:
            return shotTracker.primaryButtonSystemImage
        }
    }

    private var effectiveShotTrackingMode: ShotTrackingMode {
        switch ProcessInfo.processInfo.environment["SHOT_TRACKING_MODE_OVERRIDE"] {
        case "manual":
            return .manual
        case "gps":
            return .gps
        default:
            return viewModel.shotTrackingMode
        }
    }

    private func handleShotTrackingTap() {
        switch effectiveShotTrackingMode {
        case .manual:
            recordShotContext = RecordShotContext(roundID: viewModel.activeRoundID, gpsCapture: nil)
        case .gps:
            switch shotTracker.phase {
            case .idle:
                if viewModel.activeRoundID == nil {
                    isConfirmingStartRoundForGPS = true
                } else {
                    beginGPSShot()
                }
            case .readyToFinish:
                finishGPSShot()
            case .capturingStart, .capturingFinish:
                break
            }
        }
    }

    private func beginGPSShot() {
        inAppShotDraft = nil
        updateLiveActivityPhase(.measuringStart)

        Task {
            do {
                let startAnchor = try await shotTracker.captureStart()
                await updateLiveActivityPhaseAsync(.awaitingFinish, startAnchor: startAnchor)
            } catch {
                await updateLiveActivityPhaseAsync(.idle)
                gpsFallbackAlert = GPSFallbackAlert(message: message(for: error))
            }
        }
    }

    private func startRoundAndBeginGPSShot() {
        Task {
            let context = await suggestedRoundContext()

            if viewModel.startRound(courseName: context.courseName, altitudeFeet: context.altitudeFeet) {
                syncLocationWarmup()
                beginGPSShot()
            }
        }
    }

    private func suggestedCourseName() async -> String? {
        await suggestedRoundContext().courseName
    }

    private func suggestedRoundContext() async -> (courseName: String?, altitudeFeet: Double?) {
        do {
            let anchor = try await shotTracker.currentAnchor()
            return (await courseNameProvider.nearestCourseName(to: anchor.coordinate), anchor.altitudeFeet)
        } catch {
            return (nil, nil)
        }
    }

    private func syncLocationWarmup() {
        guard viewModel.activeRoundID != nil, effectiveShotTrackingMode == .gps else {
            shotTracker.stopLocationWarmup()
            return
        }

        shotTracker.startLocationWarmup()
    }

    private func finishGPSShot() {
        Task {
            await updateLiveActivityPhaseAsync(.measuringFinish)

            do {
                let capture = try await shotTracker.captureFinish()
                let liveActivityDraft = RoundLiveActivityManager.shared.pendingShotDraft(roundID: viewModel.activeRoundID) ?? inAppShotDraft
                recordShotContext = RecordShotContext(
                    roundID: viewModel.activeRoundID,
                    gpsCapture: capture,
                    liveActivityDraft: liveActivityDraft
                )
                await updateLiveActivityPhaseAsync(.idle)
            } catch {
                await updateLiveActivityPhaseAsync(.awaitingFinish)
                gpsFallbackAlert = GPSFallbackAlert(message: message(for: error))
            }
        }
    }

    private func abortGPSShot() {
        shotTracker.abort()
        inAppShotDraft = nil
        updateLiveActivityPhase(.idle)
    }

    private func openShotDetailsDraftForm() {
        let draft = RoundLiveActivityManager.shared.pendingShotDraft(roundID: viewModel.activeRoundID)
            ?? inAppShotDraft
            ?? RoundLiveActivityManager.shared.defaultShotDraft(clubs: viewModel.recordableActiveClubs)
        shotDraftContext = ShotDraftFormContext(draft: draft)
    }

    private func savePendingShotDraft(_ draft: LiveActivityShotDraft) {
        inAppShotDraft = draft

        Task {
            await RoundLiveActivityManager.shared.updatePendingShotDraft(
                draft,
                roundID: viewModel.activeRoundID,
                profile: profile,
                shotCount: activeRoundShotCount,
                clubs: viewModel.recordableActiveClubs
            )
        }
    }

    private func handleLiveActivityStartShotRequest() {
        viewModel.loadClubs()

        guard effectiveShotTrackingMode == .gps,
              viewModel.activeRoundID != nil,
              shotTracker.phase == .idle else {
            return
        }

        beginGPSShot()
    }

    private func handleLiveActivityFinishShotRequest() {
        viewModel.loadClubs()

        guard effectiveShotTrackingMode == .gps,
              viewModel.activeRoundID != nil else {
            return
        }

        switch shotTracker.phase {
        case .idle:
            guard let startAnchor = RoundLiveActivityManager.shared.pendingStartAnchor(roundID: viewModel.activeRoundID) else {
                return
            }

            shotTracker.restoreReadyToFinish(startAnchor)
            updateLiveActivityPhase(.awaitingFinish, startAnchor: startAnchor)
            openShotDetailsDraftForm()
        case .readyToFinish:
            openShotDetailsDraftForm()
        case .capturingStart, .capturingFinish:
            break
        }
    }

    private func updateLiveActivityPhase(
        _ phase: LiveActivityTrackingPhase,
        startAnchor: ShotLocationAnchor? = nil
    ) {
        Task {
            await updateLiveActivityPhaseAsync(phase, startAnchor: startAnchor)
        }
    }

    private func updateLiveActivityPhaseAsync(
        _ phase: LiveActivityTrackingPhase,
        startAnchor: ShotLocationAnchor? = nil
    ) async {
        await RoundLiveActivityManager.shared.updateTrackingPhase(
            phase,
            roundID: viewModel.activeRoundID,
            profile: profile,
            shotCount: activeRoundShotCount,
            clubs: viewModel.recordableActiveClubs,
            startAnchor: startAnchor
        )
    }

    private var activeRoundShotCount: Int {
        guard let activeRoundID = viewModel.activeRoundID else {
            return 0
        }

        return viewModel.shotRecords.filter { $0.roundID == activeRoundID }.count
    }

    private func retryGPSCapture() {
        switch shotTracker.phase {
        case .idle:
            beginGPSShot()
        case .readyToFinish:
            finishGPSShot()
        case .capturingStart, .capturingFinish:
            break
        }
    }

    private func message(for error: Error) -> String {
        if let locationError = error as? ShotLocationCaptureError {
            return locationError.userMessage
        }

        return "Caddie Cat could not get a reliable location. You can retry GPS or enter the shot manually."
    }

    private var emptyClubsTitle: String {
        if viewModel.shotFilter == .lowTrajectory, viewModel.activeClubs.isEmpty == false {
            return "No Low Trajectory Clubs"
        }

        return viewModel.inactiveClubs.isEmpty ? "No Clubs" : "No Active Clubs"
    }

    private var emptyClubsDescription: String {
        if viewModel.shotFilter == .lowTrajectory, viewModel.activeClubs.isEmpty == false {
            return "Switch to Normal or add low trajectory distances."
        }

        return viewModel.inactiveClubs.isEmpty ? "Add your first club." : "Restore one from Inactive Clubs or add a new club."
    }

    private var emptyClubsActionTitle: String {
        if viewModel.shotFilter == .lowTrajectory, viewModel.activeClubs.isEmpty == false {
            return "Add Club"
        }

        return viewModel.inactiveClubs.isEmpty ? "Add First Club" : "Add Club"
    }

    private var activeClubSectionTitle: String {
        switch viewModel.shotFilter {
        case .normal:
            return "\(profile.name)'s Clubs"
        case .lowTrajectory:
            return "Low Trajectory Clubs"
        }
    }

    private func offerInitialBagSetupIfNeeded() {
        guard didOfferInitialBagSetup == false,
              viewModel.activeClubs.isEmpty,
              viewModel.inactiveClubs.isEmpty,
              viewModel.errorMessage == nil else {
            return
        }

        didOfferInitialBagSetup = true
        clubForm = .add
    }

    private enum ClubForm: Identifiable {
        case add
        case edit(Club)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let club):
                return club.id.uuidString
            }
        }
    }
}

#Preview {
    YardageDashboardView(
        profile: GolferProfile(name: "Rod"),
        repository: GolfBagRepository(store: PreviewGolfBagStore()),
        switchProfile: {}
    )
}

private struct RecordShotContext: Identifiable {
    let id = UUID()
    let roundID: UUID?
    let gpsCapture: ShotGPSCapture?
    let liveActivityDraft: LiveActivityShotDraft?

    init(
        roundID: UUID?,
        gpsCapture: ShotGPSCapture?,
        liveActivityDraft: LiveActivityShotDraft? = nil
    ) {
        self.roundID = roundID
        self.gpsCapture = gpsCapture
        self.liveActivityDraft = liveActivityDraft
    }
}

private struct ShotDraftFormContext: Identifiable {
    let id = UUID()
    let draft: LiveActivityShotDraft
}

private struct ShotGPSCapture: Equatable {
    var measurement: ShotGPSMeasurement
    var startAnchor: ShotLocationAnchor
    var endAnchor: ShotLocationAnchor
}

private struct GPSFallbackAlert: Identifiable {
    let id = UUID()
    let title = "GPS Unavailable"
    let message: String
}

@MainActor
protocol ShotLocationProviding: AnyObject {
    func captureAnchor(durationNanoseconds: UInt64) async throws -> ShotLocationAnchor
    func currentAnchor() async throws -> ShotLocationAnchor
    func startWarmingLocation()
    func stopWarmingLocation()
}

@MainActor
extension ShotLocationProviding {
    func currentAnchor() async throws -> ShotLocationAnchor {
        try await captureAnchor(durationNanoseconds: 2_000_000_000)
    }

    func startWarmingLocation() {}

    func stopWarmingLocation() {}
}

private enum ShotLocationCaptureError: Error {
    case locationServicesDisabled
    case permissionDenied
    case reducedAccuracy
    case locationUnavailable

    var userMessage: String {
        switch self {
        case .locationServicesDisabled:
            return "Location Services are turned off. Turn them on or enter this shot manually."
        case .permissionDenied:
            return "GPS shot tracking needs location permission. You can retry after changing permissions or enter this shot manually."
        case .reducedAccuracy:
            return "GPS shot tracking needs Precise Location. Approximate location is too broad for golf yardages."
        case .locationUnavailable:
            return "Caddie Cat could not get a fresh GPS reading in 2 seconds. You can retry GPS or enter the shot manually."
        }
    }
}

@MainActor
private final class ShotTrackingFlowViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case capturingStart
        case readyToFinish(ShotLocationAnchor)
        case capturingFinish(ShotLocationAnchor)
    }

    @Published private(set) var phase: Phase = .idle

    private let locationProvider: any ShotLocationProviding
    private let calculator = ShotGPSMeasurementCalculator()
    private let captureDurationNanoseconds: UInt64

    init(locationProvider: any ShotLocationProviding, captureDurationNanoseconds: UInt64) {
        self.locationProvider = locationProvider
        self.captureDurationNanoseconds = captureDurationNanoseconds
    }

    var isCapturing: Bool {
        switch phase {
        case .capturingStart, .capturingFinish:
            return true
        case .idle, .readyToFinish:
            return false
        }
    }

    var canAbort: Bool {
        switch phase {
        case .readyToFinish, .capturingFinish:
            return true
        case .idle, .capturingStart:
            return false
        }
    }

    var canPrefillDetails: Bool {
        switch phase {
        case .readyToFinish:
            return true
        case .idle, .capturingStart, .capturingFinish:
            return false
        }
    }

    var primaryButtonTitle: String {
        switch phase {
        case .idle:
            return "Track Shot (Start)"
        case .capturingStart:
            return "Measuring Start..."
        case .readyToFinish:
            return "Track Shot (Finish)"
        case .capturingFinish:
            return "Measuring Finish..."
        }
    }

    var primaryButtonSystemImage: String {
        switch phase {
        case .idle, .capturingStart:
            return "location.circle.fill"
        case .readyToFinish, .capturingFinish:
            return "flag.checkered.circle.fill"
        }
    }

    @discardableResult
    func captureStart() async throws -> ShotLocationAnchor {
        phase = .capturingStart

        do {
            let anchor = try await locationProvider.captureAnchor(durationNanoseconds: captureDurationNanoseconds)
            phase = .readyToFinish(anchor)
            return anchor
        } catch {
            phase = .idle
            throw error
        }
    }

    func captureFinish() async throws -> ShotGPSCapture {
        guard case let .readyToFinish(startAnchor) = phase else {
            throw ShotLocationCaptureError.locationUnavailable
        }

        phase = .capturingFinish(startAnchor)

        do {
            let endAnchor = try await locationProvider.captureAnchor(durationNanoseconds: captureDurationNanoseconds)
            let capture = ShotGPSCapture(
                measurement: calculator.measurement(from: startAnchor, to: endAnchor),
                startAnchor: startAnchor,
                endAnchor: endAnchor
            )
            phase = .idle
            return capture
        } catch {
            phase = .readyToFinish(startAnchor)
            throw error
        }
    }

    func abort() {
        phase = .idle
    }

    func restoreReadyToFinish(_ startAnchor: ShotLocationAnchor) {
        phase = .readyToFinish(startAnchor)
    }

    func currentAnchor() async throws -> ShotLocationAnchor {
        try await locationProvider.currentAnchor()
    }

    func startLocationWarmup() {
        locationProvider.startWarmingLocation()
    }

    func stopLocationWarmup() {
        locationProvider.stopWarmingLocation()
    }
}

@MainActor
final class CoreLocationShotLocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate, ShotLocationProviding {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locations: [CLLocation] = []
    private var isWarmingLocation = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
    }

    func captureAnchor(durationNanoseconds: UInt64) async throws -> ShotLocationAnchor {
        guard CLLocationManager.locationServicesEnabled() else {
            throw ShotLocationCaptureError.locationServicesDisabled
        }

        try await ensureAuthorized()

        guard manager.accuracyAuthorization == .fullAccuracy else {
            throw ShotLocationCaptureError.reducedAccuracy
        }

        locations = []
        manager.startUpdatingLocation()
        defer {
            if isWarmingLocation == false {
                manager.stopUpdatingLocation()
            }
        }

        try await Task.sleep(nanoseconds: durationNanoseconds)

        guard let location = bestLocation() else {
            throw ShotLocationCaptureError.locationUnavailable
        }

        return ShotLocationAnchor(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            altitudeFeet: Self.altitudeFeet(from: location),
            capturedAt: location.timestamp
        )
    }

    func currentAnchor() async throws -> ShotLocationAnchor {
        if let location = bestLocation() {
            return ShotLocationAnchor(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                horizontalAccuracyMeters: location.horizontalAccuracy,
                altitudeFeet: Self.altitudeFeet(from: location),
                capturedAt: location.timestamp
            )
        }

        return try await captureAnchor(durationNanoseconds: 2_000_000_000)
    }

    func startWarmingLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            return
        }

        isWarmingLocation = true

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            guard manager.accuracyAuthorization == .fullAccuracy else {
                return
            }

            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func stopWarmingLocation() {
        isWarmingLocation = false
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if isWarmingLocation,
           manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse,
           manager.accuracyAuthorization == .fullAccuracy {
            manager.startUpdatingLocation()
        }

        guard let continuation = authorizationContinuation else {
            return
        }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationContinuation = nil
            continuation.resume()
        case .denied, .restricted:
            authorizationContinuation = nil
            continuation.resume(throwing: ShotLocationCaptureError.permissionDenied)
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation = nil
            continuation.resume(throwing: ShotLocationCaptureError.permissionDenied)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.locations.append(contentsOf: locations)
    }

    private func ensureAuthorized() async throws {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .denied, .restricted:
            throw ShotLocationCaptureError.permissionDenied
        case .notDetermined:
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            throw ShotLocationCaptureError.permissionDenied
        }
    }

    private func bestLocation() -> CLLocation? {
        locations
            .filter { $0.horizontalAccuracy > 0 }
            .min { lhs, rhs in
                if lhs.horizontalAccuracy != rhs.horizontalAccuracy {
                    return lhs.horizontalAccuracy < rhs.horizontalAccuracy
                }

                return lhs.timestamp > rhs.timestamp
            }
    }

    private static func altitudeFeet(from location: CLLocation) -> Double? {
        guard location.verticalAccuracy >= 0 else {
            return nil
        }

        return location.altitude * 3.280839895
    }
}

@MainActor
final class SimulatedShotLocationProvider: ShotLocationProviding {
    private var captureCount = 0
    private let distanceYards: Double
    private let horizontalAccuracyMeters: Double

    init(distanceYards: Double, horizontalAccuracyMeters: Double) {
        self.distanceYards = distanceYards
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
    }

    func captureAnchor(durationNanoseconds: UInt64) async throws -> ShotLocationAnchor {
        try await Task.sleep(nanoseconds: durationNanoseconds)
        captureCount += 1

        let latitude = 41.0
        let startLongitude = -87.0

        guard captureCount > 1 else {
            return ShotLocationAnchor(
                latitude: latitude,
                longitude: startLongitude,
                horizontalAccuracyMeters: horizontalAccuracyMeters
            )
        }

        let distanceMeters = distanceYards / ShotGPSMeasurementCalculator.yardsPerMeter
        let earthRadiusMeters = 6_371_000.0
        let longitudeDelta = (distanceMeters / (earthRadiusMeters * cos(latitude * .pi / 180))) * 180 / .pi

        return ShotLocationAnchor(
            latitude: latitude,
            longitude: startLongitude + longitudeDelta,
            horizontalAccuracyMeters: horizontalAccuracyMeters
        )
    }

    func currentAnchor() async throws -> ShotLocationAnchor {
        ShotLocationAnchor(
            latitude: 41.0,
            longitude: -87.0,
            horizontalAccuracyMeters: horizontalAccuracyMeters
        )
    }
}

private struct RecordShotView: View {
    let profile: GolferProfile
    let clubs: [Club]
    let roundID: UUID?
    let onSave: (ShotRecord) throws -> Void

    @Environment(\.dismiss) private var dismiss

    private let formatter = ClubDisplayNameFormatter()

    @State private var selectedClubID: UUID
    @State private var selectedCategory: ShotCategory = .normal
    @State private var selectedPower: ShotPower = .full
    @State private var distanceText = ""
    @State private var strikeQuality: StrikeQuality = .pure
    @State private var direction: ShotDirection = .straight
    @State private var grassType: GrassType = .fairway
    @State private var gpsCapture: ShotGPSCapture?
    @State private var isGPSManuallyVerified: Bool
    @State private var isShowingGPSAudit = false
    @State private var errorMessage: String?

    init(
        profile: GolferProfile,
        clubs: [Club],
        roundID: UUID? = nil,
        gpsCapture: ShotGPSCapture? = nil,
        liveActivityDraft: LiveActivityShotDraft? = nil,
        onSave: @escaping (ShotRecord) throws -> Void
    ) {
        self.profile = profile
        self.clubs = clubs
        self.roundID = roundID
        self.onSave = onSave
        let draftClubID = liveActivityDraft?.clubID.flatMap(UUID.init(uuidString:))
        let draftCategory = Self.shotCategory(from: liveActivityDraft?.category)
        let compatibleDraftClubID = draftClubID.flatMap { id in
            clubs.first { $0.id == id && Self.club($0, supports: draftCategory) }?.id
        }
        _selectedClubID = State(initialValue: compatibleDraftClubID ?? Self.preferredClubID(for: draftCategory, clubs: clubs) ?? UUID())
        _selectedCategory = State(initialValue: draftCategory ?? .normal)
        _selectedPower = State(initialValue: Self.shotPower(from: liveActivityDraft?.power) ?? .full)
        _distanceText = State(initialValue: gpsCapture.map { String($0.measurement.measuredDistanceYards) } ?? "")
        _strikeQuality = State(initialValue: Self.strikeQuality(from: liveActivityDraft?.strike) ?? .pure)
        _direction = State(initialValue: Self.shotDirection(from: liveActivityDraft?.direction) ?? .straight)
        _grassType = State(initialValue: Self.grassType(from: liveActivityDraft?.grass) ?? .fairway)
        _gpsCapture = State(initialValue: gpsCapture)
        _isGPSManuallyVerified = State(initialValue: false)
    }

    var body: some View {
        Form {
            if clubs.isEmpty {
                ContentUnavailableView("No Clubs", systemImage: "figure.golf", description: Text("Add an active non-putter club."))
            } else {
                Section("Club") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(clubGroups, id: \.title) { group in
                            HStack(alignment: .center, spacing: 8) {
                                Text(group.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 48, alignment: .leading)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(group.clubs) { club in
                                            clubTile(for: club)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 0)
                }

                Section("Distance") {
                    HStack(spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            NumericTextField(
                                title: "Optional",
                                text: $distanceText,
                                maxDigits: 3,
                                dismissesKeyboardAtMaxDigits: true,
                                textAlignment: .leading
                            )
                                .accessibilityIdentifier("record-shot-distance-field")
                                .font(.title.weight(.semibold))
                                .frame(width: 54, alignment: .leading)

                            Text("yds")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 14)

                        if distanceText.isEmpty == false {
                            Button {
                                distanceText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear Distance")
                            .accessibilityIdentifier("clear-record-shot-distance-button")
                        }

                        Spacer(minLength: 6)

                        if let gpsMeasurement {
                            gpsStatus(for: gpsMeasurement)
                                .accessibilityIdentifier("gps-confidence-row")

                            Button {
                                isShowingGPSAudit = true
                            } label: {
                                Image(systemName: "map")
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 30, height: 26)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .accessibilityLabel("Audit GPS Distance")
                            .accessibilityIdentifier("gps-audit-button")
                        }
                    }
                    .padding(.vertical, 0)
                }

                Section("Shot") {
                    choiceRow(title: "Type") {
                        LazyVGrid(columns: categoryColumns, spacing: 6) {
                            ForEach(availableCategories, id: \.self) { category in
                                ShotChoiceButton(
                                    title: category.displayName,
                                    isSelected: selectedCategory == category,
                                    accessibilityIdentifier: "shot-category-\(category.accessibilityName)"
                                ) {
                                    selectedCategory = category
                                    selectedPower = powers(for: category).first ?? .full
                                }
                            }
                        }
                    }

                    choiceRow(title: selectedCategory == .lowTrajectory ? "Shot" : "Swing") {
                        LazyVGrid(columns: powerColumns, spacing: 6) {
                            ForEach(powers(for: selectedCategory), id: \.self) { power in
                                powerButton(category: selectedCategory, power: power)
                            }
                        }
                    }
                }

                Section("Details") {
                    choiceRow(title: "Grass") {
                        LazyVGrid(columns: threeChoiceColumns, spacing: 6) {
                            ForEach(GrassType.allCases, id: \.self) { grassType in
                                ShotChoiceButton(
                                    title: grassType.displayName,
                                    isSelected: self.grassType == grassType,
                                    accessibilityIdentifier: "grass-type-\(grassType.accessibilityName)"
                                ) {
                                    self.grassType = grassType
                                }
                            }
                        }
                    }

                    choiceRow(title: "Strike") {
                        LazyVGrid(columns: threeChoiceColumns, spacing: 6) {
                            ForEach(StrikeQuality.allCases, id: \.self) { strikeQuality in
                                ShotChoiceButton(
                                    title: strikeQuality.displayName,
                                    isSelected: self.strikeQuality == strikeQuality,
                                    accessibilityIdentifier: "strike-quality-\(strikeQuality.accessibilityName)"
                                ) {
                                    self.strikeQuality = strikeQuality
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("strike-quality-picker")

                    choiceRow(title: "Direction") {
                        LazyVGrid(columns: directionChoiceColumns, spacing: 6) {
                            ForEach(ShotDirection.allCases, id: \.self) { direction in
                                ShotChoiceButton(
                                    title: direction.displayName,
                                    isSelected: self.direction == direction,
                                    accessibilityIdentifier: "shot-direction-\(direction.accessibilityName)"
                                ) {
                                    self.direction = direction
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("shot-direction-picker")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityIdentifier("record-shot-form")
        .listSectionSpacing(6)
        .navigationTitle("Record Shot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(clubs.isEmpty)
                    .accessibilityIdentifier("save-shot-button")
            }
        }
        .onChange(of: selectedClubID) { _, _ in
            normalizeSelectedShot()
        }
        .onAppear {
            normalizeSelectedShot()
        }
        .sheet(isPresented: $isShowingGPSAudit) {
            if let gpsCapture {
                GPSAuditMapView(capture: gpsCapture) { auditedCapture in
                    self.gpsCapture = auditedCapture
                    isGPSManuallyVerified = true
                    distanceText = String(auditedCapture.measurement.measuredDistanceYards)
                }
            }
        }
    }

    private var selectedClub: Club? {
        clubs.first { $0.id == selectedClubID } ?? clubs.first
    }

    private var gpsMeasurement: ShotGPSMeasurement? {
        gpsCapture?.measurement
    }

    private func gpsStatus(for measurement: ShotGPSMeasurement) -> some View {
        HStack(spacing: 5) {
            Image(systemName: isGPSManuallyVerified ? "checkmark.seal.fill" : "location.circle.fill")
                .font(.caption)

            if isGPSManuallyVerified {
                Text("Manually Verified")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                ViewThatFits(in: .horizontal) {
                    Text("+/- \(Int(measurement.estimatedUncertaintyYards.rounded())) yds")
                    Text(measurement.confidence.displayName)
                }
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(measurement.confidence.tint.opacity(0.16), in: Capsule())
            }
        }
        .foregroundStyle(isGPSManuallyVerified ? .green : measurement.confidence.tint)
    }

    private var threeChoiceColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
    }

    private var categoryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: max(availableCategories.count, 1))
    }

    private var powerColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    }

    private var directionChoiceColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 38), spacing: 4), count: 5)
    }

    private var clubGroups: [(title: String, clubs: [Club])] {
        RecordClubGroup.allCases.compactMap { group in
            let groupClubs = clubs.filter { clubGroup(for: $0) == group }
            return groupClubs.isEmpty ? nil : (group.title, groupClubs)
        }
    }

    private var availableCategories: [ShotCategory] {
        guard let selectedClub else {
            return []
        }

        return selectedClub.clubType.isWedge ? [.normal, .lowTrajectory, .flop] : [.normal, .lowTrajectory]
    }

    private func clubTile(for club: Club) -> some View {
        let displayName = formatter.displayName(for: club)
        let compactName = compactClubName(for: club)
        let isSelected = selectedClubID == club.id

        return Button {
            selectedClubID = club.id
            normalizeSelectedShot()
        } label: {
            Text(compactName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(minWidth: 36, minHeight: 30)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(isSelected ? Color.green : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.green : Color(.separator).opacity(0.55), lineWidth: 1)
        }
        .accessibilityLabel(displayName)
        .accessibilityIdentifier("record-shot-club-tile-\(displayName)")
    }

    private func powerButton(category: ShotCategory, power: ShotPower) -> some View {
        let isSelected = selectedCategory == category && selectedPower == power

        return Button {
            selectedCategory = category
            selectedPower = power
        } label: {
            Text(power.displayName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .green)
        .background(isSelected ? Color.green : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.green : Color.green.opacity(0.45), lineWidth: 1)
        }
        .accessibilityIdentifier("shot-power-\(category.accessibilityName)-\(power.accessibilityName)")
    }

    private func choiceRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            content()
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 0)
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
            selectedCategory = .normal
            selectedPower = .full
            return
        }

        if powers(for: selectedCategory).contains(selectedPower) == false {
            selectedPower = powers(for: selectedCategory).first ?? .full
        }
    }

    private func save() {
        guard let selectedClub else {
            errorMessage = "Add an active non-putter club first."
            return
        }

        let record = ShotRecord(
            profileID: profile.id,
            clubID: selectedClub.id,
            roundID: roundID,
            category: selectedCategory,
            power: selectedPower,
            distance: distance(from: distanceText),
            distanceSource: distanceSource(),
            gpsMeasurement: savedGPSMeasurement(),
            altitudeFeet: savedAltitudeFeet(),
            strikeQuality: strikeQuality,
            direction: direction,
            grassType: grassType,
            createdAt: Date()
        )

        do {
            try onSave(record)
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

    private func distanceSource() -> ShotDistanceSource {
        guard let gpsMeasurement,
              let distance = distance(from: distanceText) else {
            return .manual
        }

        if isGPSManuallyVerified {
            return .editedGPS
        }

        return distance == gpsMeasurement.measuredDistanceYards ? .gps : .editedGPS
    }

    private func savedGPSMeasurement() -> ShotGPSMeasurement? {
        distanceSource() == .manual ? nil : gpsMeasurement
    }

    private func savedAltitudeFeet() -> Double {
        gpsCapture?.startAnchor.altitudeFeet ?? AltitudeDefaults.chicagoFeet
    }

    private func clubGroup(for club: Club) -> RecordClubGroup {
        switch club.clubType {
        case .driver, .threeWood, .fiveWood, .sevenWood, .twoHybrid, .threeHybrid, .fourHybrid, .fiveHybrid:
            return .woods
        case .twoIron, .threeIron, .fourIron, .fiveIron, .sixIron, .sevenIron, .eightIron, .nineIron:
            return .irons
        case .pitchingWedge, .gapWedge, .sandWedge, .lobWedge:
            return .wedges
        case .putter:
            return .woods
        }
    }

    private func compactClubName(for club: Club) -> String {
        if club.clubType.isWedge, let wedgeLoft = club.wedgeLoft {
            return "\(wedgeLoft)\u{00B0}"
        }

        switch club.clubType {
        case .driver:
            return "Driver"
        case .threeWood:
            return "3W"
        case .fiveWood:
            return "5W"
        case .sevenWood:
            return "7W"
        case .twoHybrid:
            return "2H"
        case .threeHybrid:
            return "3H"
        case .fourHybrid:
            return "4H"
        case .fiveHybrid:
            return "5H"
        case .twoIron:
            return "2"
        case .threeIron:
            return "3"
        case .fourIron:
            return "4"
        case .fiveIron:
            return "5"
        case .sixIron:
            return "6"
        case .sevenIron:
            return "7"
        case .eightIron:
            return "8"
        case .nineIron:
            return "9"
        case .pitchingWedge:
            return "PW"
        case .gapWedge:
            return "GW"
        case .sandWedge:
            return "SW"
        case .lobWedge:
            return "LW"
        case .putter:
            return "Putter"
        }
    }

    private func validationMessage(for errors: [ShotRecordValidationError]) -> String {
        if errors.contains(.nonPositiveDistance) {
            return "Distance must be greater than 0."
        }

        if errors.contains(.putterShotRecordsNotSupported) {
            return "Putters are not supported for shot recording."
        }

        if errors.contains(.unsupportedCategoryForClubType) || errors.contains(.unsupportedPowerForCategory) {
            return "Choose a valid shot type."
        }

        return "Check the shot details and try again."
    }

    private static func shotCategory(from category: LiveActivityShotCategory?) -> ShotCategory? {
        switch category {
        case .normal:
            .normal
        case .lowTrajectory:
            .lowTrajectory
        case .flop:
            .flop
        case nil:
            nil
        }
    }

    private static func preferredClubID(for category: ShotCategory?, clubs: [Club]) -> UUID? {
        if category == .flop {
            return clubs.first { $0.clubType.isWedge }?.id ?? clubs.first?.id
        }

        return clubs.first?.id
    }

    private static func club(_ club: Club, supports category: ShotCategory?) -> Bool {
        guard let category else {
            return true
        }

        switch category {
        case .normal, .lowTrajectory:
            return club.clubType != .putter
        case .flop:
            return club.clubType.isWedge
        }
    }

    private static func shotPower(from power: LiveActivityShotPower?) -> ShotPower? {
        switch power {
        case .full:
            .full
        case .threeQuarter:
            .threeQuarter
        case .half:
            .half
        case .quarter:
            .quarter
        case .stinger:
            .stinger
        case .punch:
            .punch
        case .softPunch:
            .softPunch
        case .chip:
            .chip
        case nil:
            nil
        }
    }

    private static func grassType(from grassType: LiveActivityGrassType?) -> GrassType? {
        switch grassType {
        case .fairway:
            .fairway
        case .rough:
            .rough
        case .deepRough:
            .deepRough
        case nil:
            nil
        }
    }

    private static func strikeQuality(from strikeQuality: LiveActivityStrikeQuality?) -> StrikeQuality? {
        switch strikeQuality {
        case .thin:
            .thin
        case .pure:
            .pure
        case .chunk:
            .chunk
        case nil:
            nil
        }
    }

    private static func shotDirection(from direction: LiveActivityShotDirection?) -> ShotDirection? {
        switch direction {
        case .hook:
            .hook
        case .draw:
            .draw
        case .straight:
            .straight
        case .fade:
            .fade
        case .slice:
            .slice
        case nil:
            nil
        }
    }
}

private struct ShotDetailsDraftView: View {
    let clubs: [Club]
    let onSave: (LiveActivityShotDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    private let formatter = ClubDisplayNameFormatter()

    @State private var selectedClubID: UUID
    @State private var selectedCategory: ShotCategory = .normal
    @State private var selectedPower: ShotPower = .full
    @State private var strikeQuality: StrikeQuality = .pure
    @State private var direction: ShotDirection = .straight
    @State private var grassType: GrassType = .fairway
    @State private var completedFields: Set<LiveActivityDraftField>
    @State private var didPersistDraft = false

    init(
        clubs: [Club],
        initialDraft: LiveActivityShotDraft,
        onSave: @escaping (LiveActivityShotDraft) -> Void
    ) {
        self.clubs = clubs
        self.onSave = onSave

        let draftClubID = initialDraft.clubID.flatMap(UUID.init(uuidString:))
        let draftCategory = Self.shotCategory(from: initialDraft.category)
        let compatibleDraftClubID = draftClubID.flatMap { id in
            clubs.first { $0.id == id && Self.club($0, supports: draftCategory) }?.id
        }

        _selectedClubID = State(initialValue: compatibleDraftClubID ?? Self.preferredClubID(for: draftCategory, clubs: clubs) ?? UUID())
        _selectedCategory = State(initialValue: draftCategory ?? .normal)
        _selectedPower = State(initialValue: Self.shotPower(from: initialDraft.power) ?? .full)
        _strikeQuality = State(initialValue: Self.strikeQuality(from: initialDraft.strike) ?? .pure)
        _direction = State(initialValue: Self.shotDirection(from: initialDraft.direction) ?? .straight)
        _grassType = State(initialValue: Self.grassType(from: initialDraft.grass) ?? .fairway)
        _completedFields = State(initialValue: initialDraft.completedFields)
    }

    var body: some View {
        Form {
            if clubs.isEmpty {
                ContentUnavailableView("No Clubs", systemImage: "figure.golf", description: Text("Add an active non-putter club."))
            } else {
                Section("Club") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(clubGroups, id: \.title) { group in
                            HStack(alignment: .center, spacing: 8) {
                                Text(group.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 48, alignment: .leading)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(group.clubs) { club in
                                            clubTile(for: club)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 0)
                }

                Section("Shot") {
                    choiceRow(title: "Type") {
                        LazyVGrid(columns: categoryColumns, spacing: 6) {
                            ForEach(availableCategories, id: \.self) { category in
                                ShotChoiceButton(
                                    title: category.displayName,
                                    isSelected: selectedCategory == category,
                                    accessibilityIdentifier: "draft-shot-category-\(category.accessibilityName)"
                                ) {
                                    selectedCategory = category
                                    selectedPower = powers(for: category).first ?? .full
                                    completedFields.insert(.category)
                                    completedFields.remove(.power)
                                }
                            }
                        }
                    }

                    choiceRow(title: selectedCategory == .lowTrajectory ? "Shot" : "Swing") {
                        LazyVGrid(columns: powerColumns, spacing: 6) {
                            ForEach(powers(for: selectedCategory), id: \.self) { power in
                                powerButton(category: selectedCategory, power: power)
                            }
                        }
                    }
                }

                Section("Details") {
                    choiceRow(title: "Grass") {
                        LazyVGrid(columns: threeChoiceColumns, spacing: 6) {
                            ForEach(GrassType.allCases, id: \.self) { grassType in
                                ShotChoiceButton(
                                    title: grassType.displayName,
                                    isSelected: self.grassType == grassType,
                                    accessibilityIdentifier: "draft-grass-type-\(grassType.accessibilityName)"
                                ) {
                                    self.grassType = grassType
                                    completedFields.insert(.grass)
                                }
                            }
                        }
                    }

                    choiceRow(title: "Strike") {
                        LazyVGrid(columns: threeChoiceColumns, spacing: 6) {
                            ForEach(StrikeQuality.allCases, id: \.self) { strikeQuality in
                                ShotChoiceButton(
                                    title: strikeQuality.displayName,
                                    isSelected: self.strikeQuality == strikeQuality,
                                    accessibilityIdentifier: "draft-strike-quality-\(strikeQuality.accessibilityName)"
                                ) {
                                    self.strikeQuality = strikeQuality
                                    completedFields.insert(.strike)
                                }
                            }
                        }
                    }

                    choiceRow(title: "Direction") {
                        LazyVGrid(columns: directionChoiceColumns, spacing: 6) {
                            ForEach(ShotDirection.allCases, id: \.self) { direction in
                                ShotChoiceButton(
                                    title: direction.displayName,
                                    isSelected: self.direction == direction,
                                    accessibilityIdentifier: "draft-shot-direction-\(direction.accessibilityName)"
                                ) {
                                    self.direction = direction
                                    completedFields.insert(.direction)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listSectionSpacing(6)
        .navigationTitle("Shot Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    persistDraftIfNeeded(completedFields: Set(LiveActivityDraftField.orderedFields))
                    dismiss()
                }
                .disabled(clubs.isEmpty)
                .accessibilityIdentifier("done-shot-details-draft-button")
            }
        }
        .onChange(of: selectedClubID) { _, _ in
            normalizeSelectedShot()
        }
        .onAppear {
            normalizeSelectedShot()
        }
        .onDisappear {
            persistDraftIfNeeded(completedFields: completedFields)
        }
    }

    private var selectedClub: Club? {
        clubs.first { $0.id == selectedClubID } ?? clubs.first
    }

    private var clubGroups: [(title: String, clubs: [Club])] {
        RecordClubGroup.allCases.compactMap { group in
            let groupClubs = clubs.filter { clubGroup(for: $0) == group }
            return groupClubs.isEmpty ? nil : (group.title, groupClubs)
        }
    }

    private var availableCategories: [ShotCategory] {
        guard let selectedClub else {
            return []
        }

        return selectedClub.clubType.isWedge ? [.normal, .lowTrajectory, .flop] : [.normal, .lowTrajectory]
    }

    private var threeChoiceColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
    }

    private var categoryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: max(availableCategories.count, 1))
    }

    private var powerColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    }

    private var directionChoiceColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 38), spacing: 4), count: 5)
    }

    private func clubTile(for club: Club) -> some View {
        let displayName = formatter.displayName(for: club)
        let compactName = compactClubName(for: club)
        let isSelected = selectedClubID == club.id

        return Button {
            selectedClubID = club.id
            completedFields.insert(.club)
            normalizeSelectedShot()
        } label: {
            Text(compactName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(minWidth: 36, minHeight: 30)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(isSelected ? Color.green : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.green : Color(.separator).opacity(0.55), lineWidth: 1)
        }
        .accessibilityLabel(displayName)
        .accessibilityIdentifier("draft-shot-club-tile-\(displayName)")
    }

    private func powerButton(category: ShotCategory, power: ShotPower) -> some View {
        let isSelected = selectedCategory == category && selectedPower == power

        return Button {
            selectedCategory = category
            selectedPower = power
            completedFields.insert(.power)
        } label: {
            Text(power.displayName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .green)
        .background(isSelected ? Color.green : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.green : Color.green.opacity(0.45), lineWidth: 1)
        }
        .accessibilityIdentifier("draft-shot-power-\(category.accessibilityName)-\(power.accessibilityName)")
    }

    private func choiceRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            content()
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 0)
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
            selectedCategory = .normal
            selectedPower = .full
            completedFields.subtract([.category, .power])
            return
        }

        if powers(for: selectedCategory).contains(selectedPower) == false {
            selectedPower = powers(for: selectedCategory).first ?? .full
            completedFields.remove(.power)
        }
    }

    private func persistDraftIfNeeded(completedFields fields: Set<LiveActivityDraftField>) {
        guard didPersistDraft == false,
              var draft = currentDraft else {
            return
        }

        draft.completedFields = fields
        didPersistDraft = true
        onSave(draft)
    }

    private var currentDraft: LiveActivityShotDraft? {
        guard let selectedClub else {
            return nil
        }

        return LiveActivityShotDraft(
            clubID: selectedClub.id.uuidString,
            clubName: compactClubName(for: selectedClub),
            category: Self.liveActivityShotCategory(from: selectedCategory),
            power: Self.liveActivityShotPower(from: selectedPower),
            grass: Self.liveActivityGrassType(from: grassType),
            strike: Self.liveActivityStrikeQuality(from: strikeQuality),
            direction: Self.liveActivityShotDirection(from: direction),
            completedFields: completedFields
        )
    }

    private func clubGroup(for club: Club) -> RecordClubGroup {
        switch club.clubType {
        case .driver, .threeWood, .fiveWood, .sevenWood, .twoHybrid, .threeHybrid, .fourHybrid, .fiveHybrid:
            return .woods
        case .twoIron, .threeIron, .fourIron, .fiveIron, .sixIron, .sevenIron, .eightIron, .nineIron:
            return .irons
        case .pitchingWedge, .gapWedge, .sandWedge, .lobWedge:
            return .wedges
        case .putter:
            return .woods
        }
    }

    private func compactClubName(for club: Club) -> String {
        if club.clubType.isWedge, let wedgeLoft = club.wedgeLoft {
            return "\(wedgeLoft)\u{00B0}"
        }

        switch club.clubType {
        case .driver:
            return "Driver"
        case .threeWood:
            return "3W"
        case .fiveWood:
            return "5W"
        case .sevenWood:
            return "7W"
        case .twoHybrid:
            return "2H"
        case .threeHybrid:
            return "3H"
        case .fourHybrid:
            return "4H"
        case .fiveHybrid:
            return "5H"
        case .twoIron:
            return "2I"
        case .threeIron:
            return "3I"
        case .fourIron:
            return "4I"
        case .fiveIron:
            return "5I"
        case .sixIron:
            return "6I"
        case .sevenIron:
            return "7I"
        case .eightIron:
            return "8I"
        case .nineIron:
            return "9I"
        case .pitchingWedge:
            return "PW"
        case .gapWedge:
            return "GW"
        case .sandWedge:
            return "SW"
        case .lobWedge:
            return "LW"
        case .putter:
            return "Putter"
        }
    }

    private static func shotCategory(from category: LiveActivityShotCategory) -> ShotCategory? {
        switch category {
        case .normal:
            .normal
        case .lowTrajectory:
            .lowTrajectory
        case .flop:
            .flop
        }
    }

    private static func preferredClubID(for category: ShotCategory?, clubs: [Club]) -> UUID? {
        if category == .flop {
            return clubs.first { $0.clubType.isWedge }?.id ?? clubs.first?.id
        }

        return clubs.first?.id
    }

    private static func club(_ club: Club, supports category: ShotCategory?) -> Bool {
        guard let category else {
            return true
        }

        switch category {
        case .normal, .lowTrajectory:
            return club.clubType != .putter
        case .flop:
            return club.clubType.isWedge
        }
    }

    private static func shotPower(from power: LiveActivityShotPower) -> ShotPower? {
        switch power {
        case .full:
            .full
        case .threeQuarter:
            .threeQuarter
        case .half:
            .half
        case .quarter:
            .quarter
        case .stinger:
            .stinger
        case .punch:
            .punch
        case .softPunch:
            .softPunch
        case .chip:
            .chip
        }
    }

    private static func strikeQuality(from strikeQuality: LiveActivityStrikeQuality) -> StrikeQuality? {
        switch strikeQuality {
        case .thin:
            .thin
        case .pure:
            .pure
        case .chunk:
            .chunk
        }
    }

    private static func shotDirection(from direction: LiveActivityShotDirection) -> ShotDirection? {
        switch direction {
        case .hook:
            .hook
        case .draw:
            .draw
        case .straight:
            .straight
        case .fade:
            .fade
        case .slice:
            .slice
        }
    }

    private static func grassType(from grassType: LiveActivityGrassType) -> GrassType? {
        switch grassType {
        case .fairway:
            .fairway
        case .rough:
            .rough
        case .deepRough:
            .deepRough
        }
    }

    private static func liveActivityShotCategory(from category: ShotCategory) -> LiveActivityShotCategory {
        switch category {
        case .normal:
            .normal
        case .lowTrajectory:
            .lowTrajectory
        case .flop:
            .flop
        }
    }

    private static func liveActivityShotPower(from power: ShotPower) -> LiveActivityShotPower {
        switch power {
        case .full:
            .full
        case .threeQuarter:
            .threeQuarter
        case .half:
            .half
        case .quarter:
            .quarter
        case .stinger:
            .stinger
        case .punch:
            .punch
        case .softPunch:
            .softPunch
        case .chip:
            .chip
        }
    }

    private static func liveActivityGrassType(from grassType: GrassType) -> LiveActivityGrassType {
        switch grassType {
        case .fairway:
            .fairway
        case .rough:
            .rough
        case .deepRough:
            .deepRough
        }
    }

    private static func liveActivityStrikeQuality(from strikeQuality: StrikeQuality) -> LiveActivityStrikeQuality {
        switch strikeQuality {
        case .thin:
            .thin
        case .pure:
            .pure
        case .chunk:
            .chunk
        }
    }

    private static func liveActivityShotDirection(from direction: ShotDirection) -> LiveActivityShotDirection {
        switch direction {
        case .hook:
            .hook
        case .draw:
            .draw
        case .straight:
            .straight
        case .fade:
            .fade
        case .slice:
            .slice
        }
    }
}

private struct GPSAuditMapView: View {
    private enum EditableAnchor {
        case start
        case end
    }

    let capture: ShotGPSCapture
    let onApply: (ShotGPSCapture) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var startAnchor: ShotLocationAnchor
    @State private var endAnchor: ShotLocationAnchor
    @State private var position: MapCameraPosition

    private let calculator = ShotGPSMeasurementCalculator()

    init(capture: ShotGPSCapture, onApply: @escaping (ShotGPSCapture) -> Void) {
        self.capture = capture
        self.onApply = onApply
        _startAnchor = State(initialValue: capture.startAnchor)
        _endAnchor = State(initialValue: capture.endAnchor)
        _position = State(initialValue: Self.cameraPosition(start: capture.startAnchor, end: capture.endAnchor))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $position, interactionModes: [.pan, .zoom, .rotate]) {
                        MapPolyline(coordinates: [startCoordinate, endCoordinate])
                            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

                        MapPolyline(coordinates: [startCoordinate, endCoordinate])
                            .stroke(Color.green.opacity(0.85), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))

                        Annotation("Start", coordinate: startCoordinate, anchor: .center) {
                            auditMarker(systemName: "figure.golf", color: .blue)
                                .gesture(anchorDragGesture(.start, proxy: proxy))
                                .accessibilityIdentifier("gps-audit-start-marker")
                        }

                        Annotation("Finish", coordinate: endCoordinate, anchor: .center) {
                            auditMarker(systemName: "flag.checkered", color: .green)
                                .gesture(anchorDragGesture(.end, proxy: proxy))
                                .accessibilityIdentifier("gps-audit-end-marker")
                        }
                    }
                    .mapStyle(.imagery(elevation: .realistic))
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if let coordinate = proxy.convert(value.location, from: .local) {
                                    moveNearestAnchor(to: coordinate)
                                }
                            }
                    )
                }

                auditControls
            }
            .navigationTitle("Audit Distance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(auditedCapture)
                        dismiss()
                    }
                    .accessibilityIdentifier("apply-gps-audit-button")
                }
            }
        }
    }

    private var auditControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GPS Distance")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(capture.measurement.measuredDistanceYards) yds")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text("+/- \(Int(capture.measurement.estimatedUncertaintyYards.rounded())) yds")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(capture.measurement.confidence.tint)
                        .monospacedDigit()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("New Distance")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(auditedMeasurement.measuredDistanceYards) yds")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .accessibilityIdentifier("gps-audit-distance")
                }
            }

            HStack {
                Button {
                    resetAnchors()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Spacer()

                HStack(spacing: 12) {
                    auditLegendItem("Start", color: .blue)
                    auditLegendItem("Finish", color: .green)
                }
            }
        }
        .padding()
        .background(.bar)
    }

    private var startCoordinate: CLLocationCoordinate2D {
        startAnchor.coordinate
    }

    private var endCoordinate: CLLocationCoordinate2D {
        endAnchor.coordinate
    }

    private var auditedMeasurement: ShotGPSMeasurement {
        calculator.measurement(
            from: startAnchor,
            to: endAnchor,
            capturedAt: capture.measurement.capturedAt
        )
    }

    private var auditedCapture: ShotGPSCapture {
        ShotGPSCapture(
            measurement: auditedMeasurement,
            startAnchor: startAnchor,
            endAnchor: endAnchor
        )
    }

    private func auditMarker(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color, in: Circle())
            .shadow(radius: 3, y: 1)
    }

    private func anchorDragGesture(_ anchor: EditableAnchor, proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.08)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case let .second(true, drag?) = value,
                      let coordinate = proxy.convert(drag.location, from: .global) else {
                    return
                }

                move(anchor, to: coordinate)
            }
    }

    private func auditLegendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.secondary)
    }

    private func move(_ anchor: EditableAnchor, to coordinate: CLLocationCoordinate2D) {
        switch anchor {
        case .start:
            startAnchor.latitude = coordinate.latitude
            startAnchor.longitude = coordinate.longitude
        case .end:
            endAnchor.latitude = coordinate.latitude
            endAnchor.longitude = coordinate.longitude
        }
    }

    private func moveNearestAnchor(to coordinate: CLLocationCoordinate2D) {
        let tappedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let startLocation = CLLocation(latitude: startAnchor.latitude, longitude: startAnchor.longitude)
        let endLocation = CLLocation(latitude: endAnchor.latitude, longitude: endAnchor.longitude)

        if tappedLocation.distance(from: startLocation) <= tappedLocation.distance(from: endLocation) {
            move(.start, to: coordinate)
        } else {
            move(.end, to: coordinate)
        }
    }

    private func resetAnchors() {
        startAnchor = capture.startAnchor
        endAnchor = capture.endAnchor
        position = Self.cameraPosition(start: capture.startAnchor, end: capture.endAnchor)
    }

    private static func cameraPosition(start: ShotLocationAnchor, end: ShotLocationAnchor) -> MapCameraPosition {
        let center = CLLocationCoordinate2D(
            latitude: (start.latitude + end.latitude) / 2,
            longitude: (start.longitude + end.longitude) / 2
        )
        let distance = max(distanceMeters(from: start, to: end) * 3.2, 240)

        return .camera(MapCamera(
            centerCoordinate: center,
            distance: distance,
            heading: bearingDegrees(from: start, to: end),
            pitch: 0
        ))
    }

    private static func distanceMeters(from start: ShotLocationAnchor, to end: ShotLocationAnchor) -> CLLocationDistance {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }

    private static func bearingDegrees(from start: ShotLocationAnchor, to end: ShotLocationAnchor) -> CLLocationDirection {
        let startLatitude = start.latitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let deltaLongitude = (end.longitude - start.longitude) * .pi / 180

        let y = sin(deltaLongitude) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude) -
            sin(startLatitude) * cos(endLatitude) * cos(deltaLongitude)
        let bearing = atan2(y, x) * 180 / .pi

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

}

private enum RecordClubGroup: CaseIterable {
    case woods
    case irons
    case wedges

    var title: String {
        switch self {
        case .woods:
            return "Woods"
        case .irons:
            return "Irons"
        case .wedges:
            return "Wedges"
        }
    }
}

private struct ShotChoiceButton: View {
    let title: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, minHeight: 30)
                .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .green)
        .background(isSelected ? Color.green : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.green : Color.green.opacity(0.45), lineWidth: 1)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private extension GPSConfidence {
    var tint: Color {
        switch self {
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .orange:
            return .orange
        case .red:
            return .red
        }
    }
}

extension ShotLocationAnchor {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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

private extension GrassType {
    var accessibilityName: String {
        switch self {
        case .fairway:
            "Fairway"
        case .rough:
            "Rough"
        case .deepRough:
            "Deep Rough"
        }
    }
}

private extension StrikeQuality {
    var accessibilityName: String {
        rawValue
    }
}

private extension ShotDirection {
    var accessibilityName: String {
        rawValue
    }

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
}
