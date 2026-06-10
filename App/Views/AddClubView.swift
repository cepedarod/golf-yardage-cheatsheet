import SwiftUI

struct AddClubView: View {
    let profile: GolferProfile
    let onboardingGuide: ProfileOnboardingGuide?
    let onAcknowledgeOnboardingGuide: ((ProfileOnboardingGuide) -> Void)?
    let onSave: (Club) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusedField?

    private let existingClub: Club?
    private let validator = ClubValidator()

    @State private var clubType: ClubType = .driver
    @State private var distanceCategory: ClubDistanceCategory = .normal
    @State private var nickname = ""
    @State private var wedgeLoft = ""
    @State private var normalFullDistance = ""
    @State private var normalThreeQuarterDistance = ""
    @State private var normalHalfDistance = ""
    @State private var normalQuarterDistance = ""
    @State private var lowStingerDistance = ""
    @State private var lowPunchDistance = ""
    @State private var lowSoftPunchDistance = ""
    @State private var lowChipDistance = ""
    @State private var flopFullDistance = ""
    @State private var flopThreeQuarterDistance = ""
    @State private var flopHalfDistance = ""
    @State private var flopQuarterDistance = ""
    @State private var longPutterDistance = ""
    @State private var mediumPutterDistance = ""
    @State private var shortPutterDistance = ""
    @State private var errorMessage: String?
    @State private var pendingOnboardingGuide: ProfileOnboardingGuide?
    @State private var didPresentOnboardingGuide = false

    init(
        profile: GolferProfile,
        club: Club? = nil,
        onboardingGuide: ProfileOnboardingGuide? = nil,
        onAcknowledgeOnboardingGuide: ((ProfileOnboardingGuide) -> Void)? = nil,
        onSave: @escaping (Club) throws -> Void
    ) {
        self.profile = profile
        self.existingClub = club
        self.onboardingGuide = onboardingGuide
        self.onAcknowledgeOnboardingGuide = onAcknowledgeOnboardingGuide
        self.onSave = onSave

        _clubType = State(initialValue: club?.clubType ?? .driver)
        _distanceCategory = State(initialValue: Self.initialDistanceCategory(for: club))
        _nickname = State(initialValue: club?.nickname ?? "")
        _wedgeLoft = State(initialValue: club?.wedgeLoft.map(String.init) ?? "")
        _normalFullDistance = State(initialValue: club?.normalDistances?.full.map(String.init) ?? "")
        _normalThreeQuarterDistance = State(initialValue: club?.normalDistances?.threeQuarter.map(String.init) ?? "")
        _normalHalfDistance = State(initialValue: club?.normalDistances?.half.map(String.init) ?? "")
        _normalQuarterDistance = State(initialValue: club?.normalDistances?.quarter.map(String.init) ?? "")
        _lowStingerDistance = State(initialValue: club?.lowTrajectoryDistances?.stinger.map(String.init) ?? "")
        _lowPunchDistance = State(initialValue: club?.lowTrajectoryDistances?.punch.map(String.init) ?? "")
        _lowSoftPunchDistance = State(initialValue: club?.lowTrajectoryDistances?.softPunch.map(String.init) ?? "")
        _lowChipDistance = State(initialValue: club?.lowTrajectoryDistances?.chip.map(String.init) ?? "")
        _flopFullDistance = State(initialValue: club?.flopDistances?.full.map(String.init) ?? "")
        _flopThreeQuarterDistance = State(initialValue: club?.flopDistances?.threeQuarter.map(String.init) ?? "")
        _flopHalfDistance = State(initialValue: club?.flopDistances?.half.map(String.init) ?? "")
        _flopQuarterDistance = State(initialValue: club?.flopDistances?.quarter.map(String.init) ?? "")
        _longPutterDistance = State(initialValue: club?.putterDistances?.long.map(String.init) ?? "")
        _mediumPutterDistance = State(initialValue: club?.putterDistances?.medium.map(String.init) ?? "")
        _shortPutterDistance = State(initialValue: club?.putterDistances?.short.map(String.init) ?? "")
    }

    var body: some View {
        Form {
            Section("Club") {
                Picker("Type", selection: $clubType) {
                    ForEach(ClubType.allCases, id: \.self) { clubType in
                        Text(clubType.displayName).tag(clubType)
                    }
                }

                TextField("Nickname", text: $nickname)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .nickname)
                    .accessibilityIdentifier("nickname-field")
                    .onSubmit {
                        focusedField = nil
                    }

                if clubType.isWedge {
                    HStack {
                        Text("Loft")
                        Spacer()
                        NumericTextField(title: "Optional", text: $wedgeLoft)
                            .frame(maxWidth: 96)
                        Text("\u{00B0}")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if clubType != .putter {
                Section("Distance Category") {
                    Picker("Distance Category", selection: $distanceCategory) {
                        ForEach(availableDistanceCategories) { category in
                            Text(category.displayName)
                                .tag(category)
                                .accessibilityIdentifier("distance-category-\(category.accessibilityName)")
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("\(distanceCategory.displayName) Distances (Yards)") {
                    switch distanceCategory {
                    case .normal:
                        distanceRow("Full", identifier: "full-distance-field", text: $normalFullDistance)
                        distanceRow("3/4", identifier: "three-quarter-distance-field", text: $normalThreeQuarterDistance)
                        distanceRow("Half", identifier: "half-distance-field", text: $normalHalfDistance)
                        distanceRow("Quarter", identifier: "quarter-distance-field", text: $normalQuarterDistance)
                    case .lowTrajectory:
                        distanceRow("Stinger", identifier: "low-stinger-distance-field", text: $lowStingerDistance)
                        distanceRow("Punch", identifier: "low-punch-distance-field", text: $lowPunchDistance)
                        distanceRow("Soft Punch", identifier: "low-soft-punch-distance-field", text: $lowSoftPunchDistance)
                        distanceRow("Chip", identifier: "low-chip-distance-field", text: $lowChipDistance)
                    case .flop:
                        distanceRow("Full", identifier: "flop-full-distance-field", text: $flopFullDistance)
                        distanceRow("3/4", identifier: "flop-three-quarter-distance-field", text: $flopThreeQuarterDistance)
                        distanceRow("Half", identifier: "flop-half-distance-field", text: $flopHalfDistance)
                        distanceRow("Quarter", identifier: "flop-quarter-distance-field", text: $flopQuarterDistance)
                    }
                }
            } else {
                Section("Distances (Yards)") {
                    distanceRow("Long", identifier: "long-putter-distance-field", text: $longPutterDistance)
                    distanceRow("Medium", identifier: "medium-putter-distance-field", text: $mediumPutterDistance)
                    distanceRow("Short", identifier: "short-putter-distance-field", text: $shortPutterDistance)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            if existingClub == nil {
                Section {
                    Button(action: saveAndAddAnother) {
                        Label("Save & Add Another", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("save-and-add-another-button")
                }
            }
        }
        .accessibilityIdentifier("club-form")
        .navigationTitle(existingClub == nil ? "Add Club" : "Edit Club")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(existingClub == nil ? "Finish" : "Save", action: saveAndFinish)
                    .accessibilityIdentifier(existingClub == nil ? "finish-club-button" : "save-club-button")
            }

            ToolbarItemGroup(placement: .keyboard) {
                if focusedField == .nickname {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .accessibilityIdentifier("dismiss-nickname-keyboard-button")
                }
            }
        }
        .onChange(of: clubType) { _, newValue in
            if availableDistanceCategories.contains(distanceCategory) == false {
                distanceCategory = .normal
            }

            if newValue.isWedge == false {
                wedgeLoft = ""
            }
        }
        .onAppear {
            guard existingClub == nil,
                  pendingOnboardingGuide == nil,
                  didPresentOnboardingGuide == false else {
                return
            }

            pendingOnboardingGuide = onboardingGuide
            didPresentOnboardingGuide = onboardingGuide != nil
        }
        .alert(item: $pendingOnboardingGuide) { guide in
            Alert(
                title: Text(guide.title),
                message: Text(guide.message),
                dismissButton: .default(Text("Got it")) {
                    acknowledgePendingOnboardingGuide()
                }
            )
        }
    }

    private var availableDistanceCategories: [ClubDistanceCategory] {
        guard clubType != .putter else {
            return []
        }

        return clubType.isWedge ? [.normal, .lowTrajectory, .flop] : [.normal, .lowTrajectory]
    }

    private func distanceRow(_ title: String, identifier: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            if text.wrappedValue.isEmpty == false {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear \(title)")
                .accessibilityIdentifier("clear-\(identifier)-button")
            }
            NumericTextField(title: "Yards", text: text)
                .accessibilityIdentifier(identifier)
                .frame(maxWidth: 96)
        }
    }

    private func saveAndFinish() {
        save(shouldDismiss: true)
    }

    private func saveAndAddAnother() {
        save(shouldDismiss: false)
    }

    private func acknowledgePendingOnboardingGuide() {
        guard let guide = pendingOnboardingGuide else {
            return
        }

        pendingOnboardingGuide = nil
        onAcknowledgeOnboardingGuide?(guide)
    }

    private func save(shouldDismiss: Bool) {
        let club = makeClub()
        let validationErrors = validator.validate(club)

        guard validationErrors.isEmpty else {
            errorMessage = validationMessage(for: validationErrors)
            return
        }

        do {
            try onSave(club)
            if shouldDismiss {
                dismiss()
            } else {
                resetForNextClub()
            }
        } catch GolfBagRepositoryError.invalidClub(let validationErrors) {
            errorMessage = validationMessage(for: validationErrors)
        } catch {
            errorMessage = "Unable to save club."
        }
    }

    private func makeClub() -> Club {
        let now = Date()

        return Club(
            id: existingClub?.id ?? UUID(),
            profileID: profile.id,
            nickname: normalizedNickname,
            clubType: clubType,
            wedgeLoft: normalizedWedgeLoft,
            isActive: existingClub?.isActive ?? true,
            normalDistances: clubType == .putter ? nil : swingDistanceSet(
                full: normalFullDistance,
                threeQuarter: normalThreeQuarterDistance,
                half: normalHalfDistance,
                quarter: normalQuarterDistance
            ),
            lowTrajectoryDistances: clubType == .putter ? nil : lowTrajectoryDistanceSet(),
            flopDistances: clubType.isWedge ? swingDistanceSet(
                full: flopFullDistance,
                threeQuarter: flopThreeQuarterDistance,
                half: flopHalfDistance,
                quarter: flopQuarterDistance
            ) : nil,
            putterDistances: clubType == .putter ? putterDistanceSet() : nil,
            createdAt: existingClub?.createdAt ?? now,
            updatedAt: now
        )
    }

    private func resetForNextClub() {
        clubType = nextClubType(after: clubType)
        distanceCategory = .normal
        nickname = ""
        wedgeLoft = ""
        normalFullDistance = ""
        normalThreeQuarterDistance = ""
        normalHalfDistance = ""
        normalQuarterDistance = ""
        lowStingerDistance = ""
        lowPunchDistance = ""
        lowSoftPunchDistance = ""
        lowChipDistance = ""
        flopFullDistance = ""
        flopThreeQuarterDistance = ""
        flopHalfDistance = ""
        flopQuarterDistance = ""
        longPutterDistance = ""
        mediumPutterDistance = ""
        shortPutterDistance = ""
        errorMessage = nil
    }

    private func nextClubType(after clubType: ClubType) -> ClubType {
        let allClubTypes = ClubType.allCases

        guard let currentIndex = allClubTypes.firstIndex(of: clubType) else {
            return .driver
        }

        let nextIndex = allClubTypes.index(after: currentIndex)
        return nextIndex < allClubTypes.endIndex ? allClubTypes[nextIndex] : clubType
    }

    private var normalizedNickname: String? {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNickname.isEmpty ? nil : trimmedNickname
    }

    private var normalizedWedgeLoft: Int? {
        guard clubType.isWedge else {
            return nil
        }

        return distance(from: wedgeLoft)
    }

    private func swingDistanceSet(
        full: String,
        threeQuarter: String,
        half: String,
        quarter: String
    ) -> SwingDistanceSet? {
        let distances = SwingDistanceSet(
            full: distance(from: full),
            threeQuarter: distance(from: threeQuarter),
            half: distance(from: half),
            quarter: distance(from: quarter)
        )

        return distances.entries().isEmpty ? nil : distances
    }

    private func lowTrajectoryDistanceSet() -> LowTrajectoryDistanceSet? {
        let distances = LowTrajectoryDistanceSet(
            stinger: distance(from: lowStingerDistance),
            punch: distance(from: lowPunchDistance),
            softPunch: distance(from: lowSoftPunchDistance),
            chip: distance(from: lowChipDistance)
        )

        return distances.entries().isEmpty ? nil : distances
    }

    private func putterDistanceSet() -> PutterDistanceSet? {
        let distances = PutterDistanceSet(
            long: distance(from: longPutterDistance),
            medium: distance(from: mediumPutterDistance),
            short: distance(from: shortPutterDistance)
        )

        return distances.entries().isEmpty ? nil : distances
    }

    private func distance(from text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func validationMessage(for errors: [ClubValidationError]) -> String {
        if errors.contains(.missingSwingDistance) || errors.contains(.missingPutterDistance) {
            return "Enter at least one distance."
        }

        if errors.contains(.wedgeLoftOutOfRange) {
            return "Wedge loft must be from 30 to 80."
        }

        if errors.contains(where: { error in
            switch error {
            case .nonPositiveDistance, .nonPositiveLowTrajectoryDistance:
                true
            default:
                false
            }
        }) {
            return "Distances must be greater than 0."
        }

        return "Check the club details and try again."
    }

    private static func initialDistanceCategory(for club: Club?) -> ClubDistanceCategory {
        guard let club, club.clubType != .putter else {
            return .normal
        }

        if club.normalDistances?.hasAtLeastOneDistance == true {
            return .normal
        }

        if club.lowTrajectoryDistances?.hasAtLeastOneDistance == true {
            return .lowTrajectory
        }

        if club.flopDistances?.hasAtLeastOneDistance == true {
            return .flop
        }

        return .normal
    }

    private enum ClubDistanceCategory: Hashable, Identifiable {
        case normal
        case lowTrajectory
        case flop

        var id: Self { self }

        var displayName: String {
            switch self {
            case .normal:
                ShotCategory.normal.displayName
            case .lowTrajectory:
                ShotCategory.lowTrajectory.displayName
            case .flop:
                ShotCategory.flop.displayName
            }
        }

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

    private enum FocusedField: Hashable {
        case nickname
    }
}

#Preview {
    NavigationStack {
        AddClubView(profile: GolferProfile(name: "Rod")) { _ in }
    }
}
