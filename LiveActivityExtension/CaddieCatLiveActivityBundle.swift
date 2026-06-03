import ActivityKit
import AppIntents
import CaddieCatLiveActivityShared
import SwiftUI
import WidgetKit

@main
struct CaddieCatLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        CaddieCatLiveActivity()
    }
}

extension CaddieCatLiveActivityBundle: AppIntentsPackage {
    nonisolated static var includedPackages: [any AppIntentsPackage.Type] {
        [CaddieCatLiveActivitySharedIntentsPackage.self]
    }
}

struct CaddieCatLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundActivityAttributes.self) { context in
            CaddieCatLockScreenActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.green)
                .widgetURL(CaddieCatLiveActivityDeepLink.openDistance.url(roundID: context.attributes.roundID))
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
            .widgetURL(CaddieCatLiveActivityDeepLink.openDistance.url(roundID: context.attributes.roundID))
            .keylineTint(.green)
        }
    }
}

private struct CaddieCatLockScreenActivityView: View {
    let context: ActivityViewContext<RoundActivityAttributes>

    private var draft: LiveActivityShotDraft {
        context.state.draft ?? .defaultDraft(clubOptions: context.state.clubOptions)
    }

    private var currentStep: LiveActivityDraftStep {
        context.state.draftStep
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if context.state.isAwaitingShotDetails {
                awaitingFinishContent
            } else if context.state.canStartShot {
                idleContent
            } else {
                measuringContent
            }
        }
        .padding()
        .id("\(context.state.trackingPhase.rawValue)-\(currentStep.rawValue)")
        .transaction { transaction in
            transaction.disablesAnimations = true
            transaction.animation = nil
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            liveActivityHeader

            Link(destination: CaddieCatLiveActivityDeepLink.startShot.url(roundID: context.attributes.roundID)) {
                Label("Track Shot", systemImage: "location.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    private var measuringContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            liveActivityHeader

            Link(destination: CaddieCatLiveActivityDeepLink.openDistance.url(roundID: context.attributes.roundID)) {
                Label("Open Distance", systemImage: "arrow.up.forward.app.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.green)
        }
    }

    private var awaitingFinishContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Step \(currentStep.stepNumber)/6")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(stepPrompt)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 4)

                Link(destination: CaddieCatLiveActivityDeepLink.openFinish.url(roundID: context.attributes.roundID)) {
                    Image(systemName: "square.and.pencil")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 24)
                        .background(Color.green.opacity(0.22), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Shot Details in App")
            }

            stepPicker
        }
    }

    private var liveActivityHeader: some View {
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
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(context.state.shotCount == 1 ? "shot" : "shots")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stepPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if currentStep != .club {
                    Button(intent: PreviousShotDraftStepIntent(roundID: context.attributes.roundID)) {
                        Label("Back", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 24)
                            .background(Color.white.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous Detail")
                }

                Text(currentSelectionText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()
            }

            optionsContent
        }
        .padding(8)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var optionsContent: some View {
        if currentStep == .review {
            reviewSummary
        } else {
            VStack(spacing: 5) {
                ForEach(optionRows) { row in
                    HStack(spacing: 5) {
                        ForEach(row.options) { option in
                            optionButton(option)
                        }
                    }
                }
            }
        }
    }

    private var reviewSummary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(draft.power.displayName) \(draft.category.displayName)")
                .font(.caption.weight(.bold))
                .lineLimit(1)
            Text("\(draft.clubName) · \(draft.grass.displayName) · \(draft.strike.displayName) · \(draft.direction.displayName)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
                .padding(.vertical, 6)
        .background(Color.green.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
    }

    private var stepPrompt: String {
        switch currentStep {
        case .club:
            "Choose club"
        case .category:
            "Choose shot type"
        case .power:
            draft.category == .lowTrajectory ? "Choose low shot" : "Choose swing"
        case .grass:
            "Choose grass"
        case .strike:
            "Choose strike"
        case .direction:
            "Choose direction"
        case .review:
            "Details ready"
        }
    }

    private var currentSelectionText: String {
        switch currentStep {
        case .club:
            draft.clubName
        case .category:
            draft.category.displayName
        case .power:
            draft.power.displayName
        case .grass:
            draft.grass.displayName
        case .strike:
            draft.strike.displayName
        case .direction, .review:
            draft.direction.displayName
        }
    }

    private var stepOptions: [DraftStepOption] {
        switch currentStep {
        case .club:
            context.state.clubOptions.map { DraftStepOption(title: $0.compactName, value: $0.id) }
        case .category:
            availableCategories.map { DraftStepOption(title: $0.displayName, value: $0.rawValue) }
        case .power:
            LiveActivityShotPower.validPowers(for: draft.category).map { DraftStepOption(title: $0.displayName, value: $0.rawValue) }
        case .grass:
            LiveActivityGrassType.allCases.map { DraftStepOption(title: $0.displayName, value: $0.rawValue) }
        case .strike:
            LiveActivityStrikeQuality.allCases.map { DraftStepOption(title: $0.displayName, value: $0.rawValue) }
        case .direction:
            LiveActivityShotDirection.allCases.map { DraftStepOption(title: $0.displayName, value: $0.rawValue) }
        case .review:
            []
        }
    }

    private var optionRows: [DraftStepOptionRow] {
        let columnCount: Int
        switch currentStep {
        case .club:
            columnCount = 5
        case .direction:
            columnCount = 5
        default:
            columnCount = max(stepOptions.count, 1)
        }

        return stride(from: 0, to: stepOptions.count, by: columnCount).map { startIndex in
            let endIndex = min(startIndex + columnCount, stepOptions.count)
            return DraftStepOptionRow(options: Array(stepOptions[startIndex..<endIndex]))
        }
    }

    private func optionButton(_ option: DraftStepOption) -> some View {
        let isSelected = option.value == currentStepValue

        return Button(intent: SelectShotDraftOptionIntent(
            roundID: context.attributes.roundID,
            step: currentStep,
            value: option.value
        )) {
            Text(option.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, minHeight: 24)
                .padding(.horizontal, 4)
                .foregroundStyle(isSelected ? Color.black : Color.primary)
                .background(isSelected ? Color.green : Color.white.opacity(0.11), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var currentStepValue: String {
        switch currentStep {
        case .club:
            draft.clubID ?? ""
        case .category:
            draft.category.rawValue
        case .power:
            draft.power.rawValue
        case .grass:
            draft.grass.rawValue
        case .strike:
            draft.strike.rawValue
        case .direction, .review:
            draft.direction.rawValue
        }
    }

    private var availableCategories: [LiveActivityShotCategory] {
        let selectedClub = context.state.clubOptions.first { $0.id == draft.clubID }
        return selectedClub?.supportsFlop == true
            ? [.normal, .lowTrajectory, .flop]
            : [.normal, .lowTrajectory]
    }

    private var statusText: String {
        switch context.state.trackingPhase {
        case .idle:
            context.state.trackingMode == .gps ? "Ready to track" : "Round in progress"
        case .measuringStart:
            "Measuring start"
        case .awaitingFinish:
            "Set details while you walk"
        case .measuringFinish:
            "Measuring finish"
        }
    }
}

private struct DraftStepOption: Identifiable {
    var title: String
    var value: String

    var id: String {
        value
    }
}

private struct DraftStepOptionRow: Identifiable {
    var options: [DraftStepOption]

    var id: String {
        options.map(\.id).joined(separator: "-")
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
                    Text("Details")
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
