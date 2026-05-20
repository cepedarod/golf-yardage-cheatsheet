import ActivityKit
import AppIntents
import Foundation

struct CycleShotDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Cycle Shot Field"
    static let description = IntentDescription("Cycles one pending shot field on the Caddie Cat Live Activity.")
    static let openAppWhenRun = false

    @Parameter(title: "Round ID")
    var roundID: String

    @Parameter(title: "Field")
    var field: LiveActivityDraftFieldIntentValue

    init() {}

    init(roundID: String, field: LiveActivityDraftField) {
        self.roundID = roundID
        self.field = LiveActivityDraftFieldIntentValue(field)
    }

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<RoundActivityAttributes>.activities.first(where: { $0.attributes.roundID == roundID }) else {
            return .result()
        }

        var state = activity.content.state
        state.cycle(field.value)
        await activity.update(ActivityContent(state: state, staleDate: nil))
        return .result()
    }
}

enum LiveActivityDraftFieldIntentValue: String, AppEnum {
    case club
    case category
    case power
    case grass
    case strike
    case direction

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shot Field")

    static let caseDisplayRepresentations: [LiveActivityDraftFieldIntentValue: DisplayRepresentation] = [
        .club: "Club",
        .category: "Shot",
        .power: "Power",
        .grass: "Grass",
        .strike: "Strike",
        .direction: "Direction"
    ]

    init(_ field: LiveActivityDraftField) {
        switch field {
        case .club:
            self = .club
        case .category:
            self = .category
        case .power:
            self = .power
        case .grass:
            self = .grass
        case .strike:
            self = .strike
        case .direction:
            self = .direction
        }
    }

    var value: LiveActivityDraftField {
        switch self {
        case .club:
            .club
        case .category:
            .category
        case .power:
            .power
        case .grass:
            .grass
        case .strike:
            .strike
        case .direction:
            .direction
        }
    }
}
