import CoreLocation
import SwiftUI

struct YardageDashboardView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    @StateObject private var viewModel: YardageDashboardViewModel
    @StateObject private var shotTracker: ShotTrackingFlowViewModel
    @State private var clubForm: ClubForm?
    @State private var didOfferInitialBagSetup = false
    @State private var recordShotContext: RecordShotContext?
    @State private var isConfirmingStartRoundForGPS = false
    @State private var gpsFallbackAlert: GPSFallbackAlert?
    @State private var targetYardageText = ""
    @FocusState private var isTargetYardageFocused: Bool

    private let formatter = ClubDisplayNameFormatter()

    init(profile: GolferProfile, repository: GolfBagRepository, switchProfile: @escaping () -> Void) {
        self.profile = profile
        self.switchProfile = switchProfile
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

    @MainActor
    private static func locationProvider() -> any ShotLocationProviding {
        if let distanceText = ProcessInfo.processInfo.environment["GPS_TEST_DISTANCE_YARDS"],
           let distanceYards = Double(distanceText) {
            let accuracyMeters = ProcessInfo.processInfo.environment["GPS_TEST_ACCURACY_METERS"]
                .flatMap(Double.init) ?? 1
            return SimulatedShotLocationProvider(distanceYards: distanceYards, horizontalAccuracyMeters: accuracyMeters)
        }

        return CoreLocationShotLocationProvider()
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
                                shotRecords: viewModel.shotRecords
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
                    gpsMeasurement: context.gpsMeasurement,
                    onSave: viewModel.saveShotRecord
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
                if viewModel.startRound() {
                    beginGPSShot()
                }
            }

            Button("Manual Entry") {
                recordShotContext = RecordShotContext(roundID: nil, gpsMeasurement: nil)
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
                    recordShotContext = RecordShotContext(roundID: viewModel.activeRoundID, gpsMeasurement: nil)
                },
                secondaryButton: .default(Text("Retry Location")) {
                    retryGPSCapture()
                }
            )
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
                Button {
                    handleShotTrackingTap()
                } label: {
                    HStack(spacing: 8) {
                        if shotTracker.isCapturing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: recordShotSystemImage)
                        }

                        Text(recordShotTitle)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(viewModel.recordableActiveClubs.isEmpty || shotTracker.isCapturing)
                .accessibilityIdentifier("record-shot-button")

                if shotTracker.canAbort {
                    Button {
                        shotTracker.abort()
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
            recordShotContext = RecordShotContext(roundID: viewModel.activeRoundID, gpsMeasurement: nil)
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
        Task {
            do {
                try await shotTracker.captureStart()
            } catch {
                gpsFallbackAlert = GPSFallbackAlert(message: message(for: error))
            }
        }
    }

    private func finishGPSShot() {
        Task {
            do {
                let measurement = try await shotTracker.captureFinish()
                recordShotContext = RecordShotContext(roundID: viewModel.activeRoundID, gpsMeasurement: measurement)
            } catch {
                gpsFallbackAlert = GPSFallbackAlert(message: message(for: error))
            }
        }
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
    let gpsMeasurement: ShotGPSMeasurement?
}

private struct GPSFallbackAlert: Identifiable {
    let id = UUID()
    let title = "GPS Unavailable"
    let message: String
}

@MainActor
private protocol ShotLocationProviding: AnyObject {
    func captureAnchor(durationNanoseconds: UInt64) async throws -> ShotLocationAnchor
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

    func captureStart() async throws {
        phase = .capturingStart

        do {
            let anchor = try await locationProvider.captureAnchor(durationNanoseconds: captureDurationNanoseconds)
            phase = .readyToFinish(anchor)
        } catch {
            phase = .idle
            throw error
        }
    }

    func captureFinish() async throws -> ShotGPSMeasurement {
        guard case let .readyToFinish(startAnchor) = phase else {
            throw ShotLocationCaptureError.locationUnavailable
        }

        phase = .capturingFinish(startAnchor)

        do {
            let endAnchor = try await locationProvider.captureAnchor(durationNanoseconds: captureDurationNanoseconds)
            phase = .idle
            return calculator.measurement(from: startAnchor, to: endAnchor)
        } catch {
            phase = .readyToFinish(startAnchor)
            throw error
        }
    }

    func abort() {
        phase = .idle
    }
}

@MainActor
private final class CoreLocationShotLocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate, ShotLocationProviding {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locations: [CLLocation] = []

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
            manager.stopUpdatingLocation()
        }

        try await Task.sleep(nanoseconds: durationNanoseconds)

        guard let location = bestLocation() else {
            throw ShotLocationCaptureError.locationUnavailable
        }

        return ShotLocationAnchor(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            capturedAt: location.timestamp
        )
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
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
}

@MainActor
private final class SimulatedShotLocationProvider: ShotLocationProviding {
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
}

private struct RecordShotView: View {
    let profile: GolferProfile
    let clubs: [Club]
    let roundID: UUID?
    let gpsMeasurement: ShotGPSMeasurement?
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
    @State private var errorMessage: String?

    init(
        profile: GolferProfile,
        clubs: [Club],
        roundID: UUID? = nil,
        gpsMeasurement: ShotGPSMeasurement? = nil,
        onSave: @escaping (ShotRecord) throws -> Void
    ) {
        self.profile = profile
        self.clubs = clubs
        self.roundID = roundID
        self.gpsMeasurement = gpsMeasurement
        self.onSave = onSave
        _selectedClubID = State(initialValue: clubs.first?.id ?? UUID())
        _distanceText = State(initialValue: gpsMeasurement.map { String($0.measuredDistanceYards) } ?? "")
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
                    .padding(.vertical, 2)
                }

                Section("Distance") {
                    HStack(spacing: 8) {
                        Text("Yards")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 58, alignment: .leading)

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
                            .accessibilityIdentifier("clear-record-shot-distance-button")
                        }

                        NumericTextField(
                            title: "Optional",
                            text: $distanceText,
                            maxDigits: 3,
                            dismissesKeyboardAtMaxDigits: true
                        )
                            .accessibilityIdentifier("record-shot-distance-field")
                            .frame(maxWidth: 92)

                        Text("yds")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    if let gpsMeasurement {
                        HStack(spacing: 6) {
                            Text("GPS")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 58, alignment: .leading)

                            Image(systemName: "location.circle.fill")
                                .font(.caption)

                            Text("+/- \(Int(gpsMeasurement.estimatedUncertaintyYards.rounded())) yds")
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Text(gpsMeasurement.confidence.displayName)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(gpsMeasurement.confidence.tint.opacity(0.16), in: Capsule())
                        }
                        .foregroundStyle(gpsMeasurement.confidence.tint)
                        .padding(.vertical, 2)
                        .accessibilityIdentifier("gps-confidence-row")
                    }
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
    }

    private var selectedClub: Club? {
        clubs.first { $0.id == selectedClubID } ?? clubs.first
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
        .padding(.vertical, 2)
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

        return distance == gpsMeasurement.measuredDistanceYards ? .gps : .editedGPS
    }

    private func savedGPSMeasurement() -> ShotGPSMeasurement? {
        distanceSource() == .manual ? nil : gpsMeasurement
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
