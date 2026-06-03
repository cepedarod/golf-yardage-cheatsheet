import ActivityKit
import Foundation

public struct RoundActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var roundName: String
        public var shotCount: Int
        public var trackingMode: LiveActivityTrackingMode
        public var trackingPhase: LiveActivityTrackingPhase
        public var draft: LiveActivityShotDraft?
        public var draftStep: LiveActivityDraftStep
        public var clubOptions: [LiveActivityClubOption]
        public var startAnchor: LiveActivityLocationAnchor?

        public init(
            roundName: String,
            shotCount: Int,
            trackingMode: LiveActivityTrackingMode,
            trackingPhase: LiveActivityTrackingPhase,
            draft: LiveActivityShotDraft?,
            draftStep: LiveActivityDraftStep,
            clubOptions: [LiveActivityClubOption],
            startAnchor: LiveActivityLocationAnchor?
        ) {
            self.roundName = roundName
            self.shotCount = shotCount
            self.trackingMode = trackingMode
            self.trackingPhase = trackingPhase
            self.draft = draft
            self.draftStep = draftStep
            self.clubOptions = clubOptions
            self.startAnchor = startAnchor
        }

        public var canStartShot: Bool {
            trackingMode == .gps && trackingPhase == .idle
        }

        public var isAwaitingShotDetails: Bool {
            trackingMode == .gps && trackingPhase == .awaitingFinish
        }

        public mutating func ensureDraft() {
            if draft == nil {
                draft = LiveActivityShotDraft.defaultDraft(clubOptions: clubOptions)
            }

            normalizeDraft()
        }

        public mutating func cycle(_ field: LiveActivityDraftField) {
            ensureDraft()
            var currentDraft = draft ?? LiveActivityShotDraft.defaultDraft(clubOptions: clubOptions)

            switch field {
            case .club:
                currentDraft = cycledClubDraft(currentDraft)
            case .category:
                currentDraft.category = nextCategory(after: currentDraft.category, selectedClubID: currentDraft.clubID)
                currentDraft.power = LiveActivityShotPower.validPowers(for: currentDraft.category).first ?? .full
            case .power:
                currentDraft.power = nextPower(after: currentDraft.power, category: currentDraft.category)
            case .grass:
                currentDraft.grass = LiveActivityGrassType.next(after: currentDraft.grass)
            case .strike:
                currentDraft.strike = LiveActivityStrikeQuality.next(after: currentDraft.strike)
            case .direction:
                currentDraft.direction = LiveActivityShotDirection.next(after: currentDraft.direction)
            }

            draft = currentDraft
            normalizeDraft()
        }

        @discardableResult
        public mutating func select(_ value: String, for step: LiveActivityDraftStep, advances: Bool = true) -> Bool {
            ensureDraft()
            var currentDraft = draft ?? LiveActivityShotDraft.defaultDraft(clubOptions: clubOptions)

            switch step {
            case .club:
                guard let selectedOption = clubOptions.first(where: { $0.id == value }) else {
                    return false
                }
                currentDraft.clubID = selectedOption.id
                currentDraft.clubName = selectedOption.compactName
                if selectedOption.supportsFlop == false, currentDraft.category == .flop {
                    currentDraft.category = .normal
                    currentDraft.power = .full
                    currentDraft.completedFields.subtract([.category, .power])
                }
            case .category:
                guard let category = LiveActivityShotCategory(rawValue: value),
                      availableCategories(selectedClubID: currentDraft.clubID).contains(category) else {
                    return false
                }
                currentDraft.category = category
                currentDraft.power = LiveActivityShotPower.validPowers(for: category).first ?? .full
                currentDraft.completedFields.remove(.power)
            case .power:
                guard let power = LiveActivityShotPower(rawValue: value),
                      LiveActivityShotPower.validPowers(for: currentDraft.category).contains(power) else {
                    return false
                }
                currentDraft.power = power
            case .grass:
                guard let grass = LiveActivityGrassType(rawValue: value) else {
                    return false
                }
                currentDraft.grass = grass
            case .strike:
                guard let strike = LiveActivityStrikeQuality(rawValue: value) else {
                    return false
                }
                currentDraft.strike = strike
            case .direction:
                guard let direction = LiveActivityShotDirection(rawValue: value) else {
                    return false
                }
                currentDraft.direction = direction
            case .review:
                break
            }

            if let field = step.draftField {
                currentDraft.completedFields.insert(field)
            }
            draft = currentDraft
            if advances {
                draftStep = step.next
            } else {
                draftStep = step
            }
            normalizeDraft()
            return true
        }

        public mutating func advanceDraftStep(from step: LiveActivityDraftStep) {
            if draftStep == step {
                draftStep = step.next
            }
        }

        public mutating func moveDraftStepBack() {
            draftStep = draftStep.previous
        }

        public mutating func setDraft(_ draft: LiveActivityShotDraft, step: LiveActivityDraftStep? = nil) {
            self.draft = draft
            normalizeDraft()
            draftStep = step ?? LiveActivityDraftStep.firstIncompleteStep(completedFields: self.draft?.completedFields ?? [])
        }

        private func cycledClubDraft(_ draft: LiveActivityShotDraft) -> LiveActivityShotDraft {
            guard clubOptions.isEmpty == false else {
                return draft
            }

            var updatedDraft = draft
            let currentID = updatedDraft.clubID
            let currentIndex = clubOptions.firstIndex { $0.id == currentID } ?? -1
            let nextIndex = clubOptions.index(after: currentIndex)
            let option = clubOptions[nextIndex % clubOptions.count]
            updatedDraft.clubID = option.id
            updatedDraft.clubName = option.compactName
            return updatedDraft
        }

        private mutating func normalizeDraft() {
            guard var draft else {
                return
            }

            if let selectedOption = clubOptions.first(where: { $0.id == draft.clubID }) {
                draft.clubName = selectedOption.compactName
                if selectedOption.supportsFlop == false, draft.category == .flop {
                    draft.category = .normal
                    draft.power = .full
                    draft.completedFields.subtract([.category, .power])
                }
            } else if let firstOption = clubOptions.first {
                draft.clubID = firstOption.id
                draft.clubName = firstOption.compactName
                draft.completedFields.remove(.club)
            }

            let validPowers = LiveActivityShotPower.validPowers(for: draft.category)
            if validPowers.contains(draft.power) == false {
                draft.power = validPowers.first ?? .full
                draft.completedFields.remove(.power)
            }

            self.draft = draft
        }

        private func nextCategory(
            after category: LiveActivityShotCategory,
            selectedClubID: String?
        ) -> LiveActivityShotCategory {
            let categories = availableCategories(selectedClubID: selectedClubID)
            let currentIndex = categories.firstIndex(of: category) ?? -1
            return categories[categories.index(after: currentIndex) % categories.count]
        }

        private func availableCategories(selectedClubID: String?) -> [LiveActivityShotCategory] {
            let selectedClub = clubOptions.first { $0.id == selectedClubID }
            return selectedClub?.supportsFlop == true
                ? [.normal, .lowTrajectory, .flop]
                : [.normal, .lowTrajectory]
        }

        private func nextPower(
            after power: LiveActivityShotPower,
            category: LiveActivityShotCategory
        ) -> LiveActivityShotPower {
            let powers = LiveActivityShotPower.validPowers(for: category)
            let currentIndex = powers.firstIndex(of: power) ?? -1
            return powers[powers.index(after: currentIndex) % powers.count]
        }
    }

    public var roundID: String
    public var profileID: String
    public var profileName: String

    public init(roundID: String, profileID: String, profileName: String) {
        self.roundID = roundID
        self.profileID = profileID
        self.profileName = profileName
    }
}

public enum LiveActivityTrackingMode: String, Codable, Hashable, Sendable {
    case gps
    case manual
}

public enum LiveActivityTrackingPhase: String, Codable, Hashable, Sendable {
    case idle
    case measuringStart
    case awaitingFinish
    case measuringFinish
}

public enum LiveActivityDraftStep: String, Codable, CaseIterable, Hashable, Sendable {
    case club
    case category
    case power
    case grass
    case strike
    case direction
    case review

    public var next: LiveActivityDraftStep {
        switch self {
        case .club:
            .category
        case .category:
            .power
        case .power:
            .grass
        case .grass:
            .strike
        case .strike:
            .direction
        case .direction, .review:
            .review
        }
    }

    public var previous: LiveActivityDraftStep {
        switch self {
        case .club, .category:
            .club
        case .power:
            .category
        case .grass:
            .power
        case .strike:
            .grass
        case .direction:
            .strike
        case .review:
            .direction
        }
    }

    public var stepNumber: Int {
        switch self {
        case .club:
            1
        case .category:
            2
        case .power:
            3
        case .grass:
            4
        case .strike:
            5
        case .direction, .review:
            6
        }
    }

    public var draftField: LiveActivityDraftField? {
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
        case .review:
            nil
        }
    }

    public static func firstIncompleteStep(completedFields: Set<LiveActivityDraftField>) -> LiveActivityDraftStep {
        for field in LiveActivityDraftField.orderedFields where completedFields.contains(field) == false {
            return field.draftStep
        }

        return .review
    }
}

public struct LiveActivityClubOption: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var compactName: String
    public var supportsFlop: Bool

    public init(id: String, compactName: String, supportsFlop: Bool) {
        self.id = id
        self.compactName = compactName
        self.supportsFlop = supportsFlop
    }
}

public struct LiveActivityLocationAnchor: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var horizontalAccuracyMeters: Double
    public var capturedAt: Date

    public init(latitude: Double, longitude: Double, horizontalAccuracyMeters: Double, capturedAt: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.capturedAt = capturedAt
    }
}

public struct LiveActivityShotDraft: Codable, Hashable, Sendable {
    public var clubID: String?
    public var clubName: String
    public var category: LiveActivityShotCategory
    public var power: LiveActivityShotPower
    public var grass: LiveActivityGrassType
    public var strike: LiveActivityStrikeQuality
    public var direction: LiveActivityShotDirection
    public var completedFields: Set<LiveActivityDraftField>

    public init(
        clubID: String?,
        clubName: String,
        category: LiveActivityShotCategory,
        power: LiveActivityShotPower,
        grass: LiveActivityGrassType,
        strike: LiveActivityStrikeQuality,
        direction: LiveActivityShotDirection,
        completedFields: Set<LiveActivityDraftField> = []
    ) {
        self.clubID = clubID
        self.clubName = clubName
        self.category = category
        self.power = power
        self.grass = grass
        self.strike = strike
        self.direction = direction
        self.completedFields = completedFields
    }

    private enum CodingKeys: String, CodingKey {
        case clubID
        case clubName
        case category
        case power
        case grass
        case strike
        case direction
        case completedFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clubID = try container.decodeIfPresent(String.self, forKey: .clubID)
        clubName = try container.decode(String.self, forKey: .clubName)
        category = try container.decode(LiveActivityShotCategory.self, forKey: .category)
        power = try container.decode(LiveActivityShotPower.self, forKey: .power)
        grass = try container.decode(LiveActivityGrassType.self, forKey: .grass)
        strike = try container.decode(LiveActivityStrikeQuality.self, forKey: .strike)
        direction = try container.decode(LiveActivityShotDirection.self, forKey: .direction)
        completedFields = try container.decodeIfPresent(Set<LiveActivityDraftField>.self, forKey: .completedFields) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(clubID, forKey: .clubID)
        try container.encode(clubName, forKey: .clubName)
        try container.encode(category, forKey: .category)
        try container.encode(power, forKey: .power)
        try container.encode(grass, forKey: .grass)
        try container.encode(strike, forKey: .strike)
        try container.encode(direction, forKey: .direction)
        try container.encode(completedFields, forKey: .completedFields)
    }

    public static func defaultDraft(clubOptions: [LiveActivityClubOption]) -> LiveActivityShotDraft {
        let club = clubOptions.first

        return LiveActivityShotDraft(
            clubID: club?.id,
            clubName: club?.compactName ?? "Club",
            category: .normal,
            power: .full,
            grass: .fairway,
            strike: .pure,
            direction: .straight,
            completedFields: []
        )
    }
}

public enum LiveActivityDraftField: String, Codable, CaseIterable, Hashable, Sendable {
    case club
    case category
    case power
    case grass
    case strike
    case direction

    public static var orderedFields: [LiveActivityDraftField] {
        [.club, .category, .power, .grass, .strike, .direction]
    }

    public var draftStep: LiveActivityDraftStep {
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

public enum LiveActivityShotCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case normal
    case lowTrajectory
    case flop

    public var displayName: String {
        switch self {
        case .normal:
            "Normal"
        case .lowTrajectory:
            "Low"
        case .flop:
            "Flop"
        }
    }
}

public enum LiveActivityShotPower: String, Codable, CaseIterable, Hashable, Sendable {
    case full
    case threeQuarter
    case half
    case quarter
    case stinger
    case punch
    case softPunch
    case chip

    public var displayName: String {
        switch self {
        case .full:
            "Full"
        case .threeQuarter:
            "3/4"
        case .half:
            "Half"
        case .quarter:
            "Quarter"
        case .stinger:
            "Stinger"
        case .punch:
            "Punch"
        case .softPunch:
            "Soft"
        case .chip:
            "Chip"
        }
    }

    public static func validPowers(for category: LiveActivityShotCategory) -> [LiveActivityShotPower] {
        switch category {
        case .normal, .flop:
            [.full, .threeQuarter, .half, .quarter]
        case .lowTrajectory:
            [.stinger, .punch, .softPunch, .chip]
        }
    }
}

public enum LiveActivityGrassType: String, Codable, CaseIterable, Hashable, Sendable {
    case fairway
    case rough
    case deepRough

    public var displayName: String {
        switch self {
        case .fairway:
            "Fairway"
        case .rough:
            "Rough"
        case .deepRough:
            "Deep"
        }
    }

    public static func next(after value: LiveActivityGrassType) -> LiveActivityGrassType {
        nextValue(value, in: allCases)
    }
}

public enum LiveActivityStrikeQuality: String, Codable, CaseIterable, Hashable, Sendable {
    case thin
    case pure
    case chunk

    public var displayName: String {
        switch self {
        case .thin:
            "Thin"
        case .pure:
            "Pure"
        case .chunk:
            "Chunk"
        }
    }

    public static func next(after value: LiveActivityStrikeQuality) -> LiveActivityStrikeQuality {
        nextValue(value, in: allCases)
    }
}

public enum LiveActivityShotDirection: String, Codable, CaseIterable, Hashable, Sendable {
    case hook
    case draw
    case straight
    case fade
    case slice

    public var displayName: String {
        switch self {
        case .hook:
            "Hook"
        case .draw:
            "Draw"
        case .straight:
            "Straight"
        case .fade:
            "Fade"
        case .slice:
            "Slice"
        }
    }

    public static func next(after value: LiveActivityShotDirection) -> LiveActivityShotDirection {
        nextValue(value, in: allCases)
    }
}

public enum CaddieCatLiveActivityDeepLink {
    case openRound
    case startShot
    case openFinish

    public func url(roundID: String) -> URL {
        var components = URLComponents()
        components.scheme = "caddiecat"

        switch self {
        case .openRound:
            components.host = "round"
        case .startShot:
            components.host = "track-shot-start"
        case .openFinish:
            components.host = "track-shot-finish"
        }

        components.queryItems = [URLQueryItem(name: "roundID", value: roundID)]
        return components.url ?? URL(string: "caddiecat://round")!
    }
}

public enum LiveActivityDraftBufferStore {
    private struct StoredDraft: Codable {
        var draft: LiveActivityShotDraft
        var step: LiveActivityDraftStep
        var updatedAt: Date
    }

    private static let keyPrefix = "liveActivityDraft."

    public static func save(draft: LiveActivityShotDraft?, step: LiveActivityDraftStep, roundID: String) {
        guard let draft,
              let data = try? JSONEncoder().encode(StoredDraft(draft: draft, step: step, updatedAt: Date())) else {
            clear(roundID: roundID)
            return
        }

        UserDefaults.standard.set(data, forKey: keyPrefix + roundID)
    }

    public static func draft(roundID: String) -> LiveActivityShotDraft? {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + roundID),
              let storedDraft = try? JSONDecoder().decode(StoredDraft.self, from: data) else {
            return nil
        }

        return storedDraft.draft
    }

    public static func clear(roundID: String) {
        UserDefaults.standard.removeObject(forKey: keyPrefix + roundID)
    }
}

private func nextValue<Value: Equatable>(_ value: Value, in values: [Value]) -> Value {
    guard values.isEmpty == false else {
        return value
    }

    let currentIndex = values.firstIndex(of: value) ?? -1
    return values[values.index(after: currentIndex) % values.count]
}
