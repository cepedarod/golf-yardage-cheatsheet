import ActivityKit
import SwiftUI
import WidgetKit

@main
struct CaddieCatLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        CaddieCatLiveActivity()
    }
}

struct CaddieCatLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundActivityAttributes.self) { context in
            CaddieCatLockScreenActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.green)
                .widgetURL(CaddieCatLiveActivityDeepLink.openRound.url(roundID: context.attributes.roundID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Caddie Cat")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(context.state.roundName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.shotCount)")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                        Text(context.state.shotCount == 1 ? "shot" : "shots")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    CaddieCatExpandedIslandAction(context: context)
                }
            } compactLeading: {
                Image(systemName: context.state.trackingPhase == .awaitingFinish ? "flag.checkered.circle.fill" : "flag.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text("\(context.state.shotCount)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.green)
            }
            .widgetURL(CaddieCatLiveActivityDeepLink.openRound.url(roundID: context.attributes.roundID))
            .keylineTint(.green)
        }
    }
}

private struct CaddieCatLockScreenActivityView: View {
    let context: ActivityViewContext<RoundActivityAttributes>

    private var draft: LiveActivityShotDraft {
        context.state.draft ?? .defaultDraft(clubOptions: context.state.clubOptions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.roundName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(context.state.shotCount)")
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                    Text(context.state.shotCount == 1 ? "shot" : "shots")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if context.state.isAwaitingShotDetails {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
                    draftButton(title: "Club", value: draft.clubName, field: .club)
                    draftButton(title: "Shot", value: draft.category.displayName, field: .category)
                    draftButton(title: "Power", value: draft.power.displayName, field: .power)
                    draftButton(title: "Grass", value: draft.grass.displayName, field: .grass)
                    draftButton(title: "Strike", value: draft.strike.displayName, field: .strike)
                    draftButton(title: "Dir", value: draft.direction.displayName, field: .direction)
                }

                Link(destination: CaddieCatLiveActivityDeepLink.openFinish.url(roundID: context.attributes.roundID)) {
                    Label("Open to Finish", systemImage: "arrow.up.forward.app.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else if context.state.canStartShot {
                Link(destination: CaddieCatLiveActivityDeepLink.startShot.url(roundID: context.attributes.roundID)) {
                    Label("Track Shot", systemImage: "location.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Link(destination: CaddieCatLiveActivityDeepLink.openRound.url(roundID: context.attributes.roundID)) {
                    Label("Open Round", systemImage: "arrow.up.forward.app.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        }
        .padding()
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 7), count: 3)
    }

    private var statusText: String {
        switch context.state.trackingPhase {
        case .idle:
            context.state.trackingMode == .gps ? "Ready to track" : "Round in progress"
        case .measuringStart:
            "Measuring start"
        case .awaitingFinish:
            "Set details, then finish in app"
        case .measuringFinish:
            "Measuring finish"
        }
    }

    private func draftButton(
        title: String,
        value: String,
        field: LiveActivityDraftField
    ) -> some View {
        Button(intent: CycleShotDraftIntent(roundID: context.attributes.roundID, field: field)) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct CaddieCatExpandedIslandAction: View {
    let context: ActivityViewContext<RoundActivityAttributes>

    var body: some View {
        if context.state.isAwaitingShotDetails {
            HStack(spacing: 8) {
                Text(context.state.draftSummary)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 6)

                Link(destination: CaddieCatLiveActivityDeepLink.openFinish.url(roundID: context.attributes.roundID)) {
                    Text("Finish")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        } else if context.state.canStartShot {
            Link(destination: CaddieCatLiveActivityDeepLink.startShot.url(roundID: context.attributes.roundID)) {
                Label("Track Shot", systemImage: "location.circle.fill")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        } else {
            Text("Round active")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private extension RoundActivityAttributes.ContentState {
    var draftSummary: String {
        let draft = draft ?? .defaultDraft(clubOptions: clubOptions)
        return "\(draft.clubName) · \(draft.power.displayName) \(draft.category.displayName)"
    }
}
