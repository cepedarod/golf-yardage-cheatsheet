import SwiftUI

struct YardageDashboardPlaceholderView: View {
    let profile: GolferProfile
    let switchProfile: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.largeTitle.bold())

                    Text("Bag setup")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Spacer()

            Image(systemName: "figure.golf")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Add Bag")
                .font(.title.bold())

            Button {
            } label: {
                Label("Add Club", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(true)

            Spacer()
        }
        .padding()
        .navigationTitle("Yardage")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: switchProfile) {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Switch Profile")
            }
        }
    }
}

#Preview {
    YardageDashboardPlaceholderView(
        profile: GolferProfile(name: "Rod"),
        switchProfile: {}
    )
}

