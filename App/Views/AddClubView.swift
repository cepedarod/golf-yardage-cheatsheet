import SwiftUI

struct AddClubView: View {
    let profile: GolferProfile
    let onSave: (Club) throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var clubType: ClubType = .driver
    @State private var shotType: ShotType = .normal
    @State private var nickname = ""
    @State private var wedgeLoft = ""
    @State private var fullDistance = ""
    @State private var threeQuarterDistance = ""
    @State private var halfDistance = ""
    @State private var quarterDistance = ""
    @State private var longPutterDistance = ""
    @State private var mediumPutterDistance = ""
    @State private var shortPutterDistance = ""
    @State private var errorMessage: String?

    private let validator = ClubValidator()

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
                Section("Shot") {
                    Picker("Shot", selection: $shotType) {
                        ForEach(availableShotTypes, id: \.self) { shotType in
                            Text(shotType.rawValue).tag(shotType)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Distances") {
                    distanceRow("Full", text: $fullDistance)
                    distanceRow("3/4", text: $threeQuarterDistance)
                    distanceRow("Half", text: $halfDistance)
                    distanceRow("Quarter", text: $quarterDistance)
                }
            } else {
                Section("Distances") {
                    distanceRow("Long", text: $longPutterDistance)
                    distanceRow("Medium", text: $mediumPutterDistance)
                    distanceRow("Short", text: $shortPutterDistance)
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
        .navigationTitle("Add Club")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
        .onChange(of: clubType) { _, newValue in
            if availableShotTypes.contains(shotType) == false {
                shotType = .normal
            }

            if newValue.isWedge == false {
                wedgeLoft = ""
            }
        }
    }

    private var availableShotTypes: [ShotType] {
        if clubType == .putter {
            return []
        }

        return clubType.isWedge ? [.normal, .flop] : [.normal, .punch]
    }

    private func distanceRow(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            NumericTextField(title: "Yards", text: text)
                .frame(maxWidth: 96)
        }
    }

    private func save() {
        let club = makeClub()
        let validationErrors = validator.validate(club)

        guard validationErrors.isEmpty else {
            errorMessage = validationMessage(for: validationErrors)
            return
        }

        do {
            try onSave(club)
            dismiss()
        } catch GolfBagRepositoryError.invalidClub(let validationErrors) {
            errorMessage = validationMessage(for: validationErrors)
        } catch {
            errorMessage = "Unable to save club."
        }
    }

    private func makeClub() -> Club {
        Club(
            profileID: profile.id,
            nickname: normalizedNickname,
            clubType: clubType,
            wedgeLoft: normalizedWedgeLoft,
            shotType: clubType == .putter ? nil : shotType,
            swingDistances: clubType == .putter ? nil : SwingDistanceSet(
                full: distance(from: fullDistance),
                threeQuarter: distance(from: threeQuarterDistance),
                half: distance(from: halfDistance),
                quarter: distance(from: quarterDistance)
            ),
            putterDistances: clubType == .putter ? PutterDistanceSet(
                long: distance(from: longPutterDistance),
                medium: distance(from: mediumPutterDistance),
                short: distance(from: shortPutterDistance)
            ) : nil
        )
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
            if case .nonPositiveDistance = error {
                return true
            }

            return false
        }) {
            return "Distances must be greater than 0."
        }

        return "Check the club details and try again."
    }
}

#Preview {
    NavigationStack {
        AddClubView(profile: GolferProfile(name: "Rod")) { _ in }
    }
}
