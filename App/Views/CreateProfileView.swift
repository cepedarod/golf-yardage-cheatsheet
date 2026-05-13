import SwiftUI

struct CreateProfileView: View {
    let title: String
    let submitTitle: String
    let errorMessage: String?
    let onSubmit: (String) -> Void

    @State private var profileName = ""

    private var canSubmit: Bool {
        profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            TextField("Name", text: $profileName)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .font(.title3)
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("profile-name-field")
                .onSubmit(submit)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Button(action: submit) {
                Label(submitTitle, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(canSubmit == false)
            .accessibilityIdentifier("create-profile-button")

            Spacer()
        }
        .navigationTitle(title)
    }

    private func submit() {
        guard canSubmit else {
            return
        }

        onSubmit(profileName)
    }
}

#Preview {
    CreateProfileView(
        title: "Create Profile",
        submitTitle: "Create",
        errorMessage: nil,
        onSubmit: { _ in }
    )
    .padding()
}
