import ActivityKit
import AppIntents
import Foundation

public struct CaddieCatLiveActivitySharedIntentsPackage: AppIntentsPackage {}

public struct CycleShotDraftIntent: AppIntent, LiveActivityIntent {
    public static let title: LocalizedStringResource = "Cycle Shot Field"
    public static let description = IntentDescription("Cycles one pending shot field on the Caddie Cat Live Activity.")
    public static let openAppWhenRun = false
    public static let isDiscoverable = false
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Round ID")
    public var roundID: String

    @Parameter(title: "Field")
    public var field: String

    public init() {}

    public init(roundID: String, field: LiveActivityDraftField) {
        self.roundID = roundID
        self.field = field.rawValue
    }

    public func perform() async throws -> some IntentResult {
        guard let activity = Activity<RoundActivityAttributes>.activities.first(where: { $0.attributes.roundID == roundID }) else {
            return .result()
        }
        guard let field = LiveActivityDraftField(rawValue: field) else {
            return .result()
        }

        var state = activity.content.state
        state.cycle(field)
        await updateActivity(activity, with: state)
        return .result()
    }
}

public struct SelectShotDraftOptionIntent: AppIntent, LiveActivityIntent {
    public static let title: LocalizedStringResource = "Select Shot Detail"
    public static let description = IntentDescription("Sets the current pending shot detail on the Caddie Cat Live Activity.")
    public static let openAppWhenRun = false
    public static let isDiscoverable = false
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Round ID")
    public var roundID: String

    @Parameter(title: "Step")
    public var step: String

    @Parameter(title: "Value")
    public var value: String

    public init() {}

    public init(roundID: String, step: LiveActivityDraftStep, value: String) {
        self.roundID = roundID
        self.step = step.rawValue
        self.value = value
    }

    public func perform() async throws -> some IntentResult {
        guard let activity = Activity<RoundActivityAttributes>.activities.first(where: { $0.attributes.roundID == roundID }) else {
            return .result()
        }
        guard let step = LiveActivityDraftStep(rawValue: step) else {
            return .result()
        }

        var state = activity.content.state
        guard state.select(value, for: step, advances: false) else {
            return .result()
        }

        await updateActivity(activity, with: state)
        try? await Task.sleep(nanoseconds: 250_000_000)

        var advancedState = state
        advancedState.advanceDraftStep(from: step)
        await updateActivity(activity, with: advancedState)
        return .result()
    }
}

public struct PreviousShotDraftStepIntent: AppIntent, LiveActivityIntent {
    public static let title: LocalizedStringResource = "Previous Shot Detail"
    public static let description = IntentDescription("Moves back one pending shot detail on the Caddie Cat Live Activity.")
    public static let openAppWhenRun = false
    public static let isDiscoverable = false
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Round ID")
    public var roundID: String

    public init() {}

    public init(roundID: String) {
        self.roundID = roundID
    }

    public func perform() async throws -> some IntentResult {
        guard let activity = Activity<RoundActivityAttributes>.activities.first(where: { $0.attributes.roundID == roundID }) else {
            return .result()
        }

        var state = activity.content.state
        state.moveDraftStepBack()
        await updateActivity(activity, with: state)
        return .result()
    }
}

private func updateActivity(
    _ activity: Activity<RoundActivityAttributes>,
    with state: RoundActivityAttributes.ContentState
) async {
    await activity.update(ActivityContent(state: state, staleDate: nil))
}
